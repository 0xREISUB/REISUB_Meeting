import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:v_meeting/meeting/web_wake_lock.dart';

/// Creates the LiveKit room for a meeting. Tests override this with a fake.
final meetingRoomFactoryProvider = Provider<Room Function()>(
  (ref) => createMeetingRoom,
);

/// Operating-system services the meeting needs. Tests override this to avoid
/// real permission prompts.
final meetingPlatformProvider = Provider<MeetingPlatform>(
  (ref) => const MeetingPlatform(),
);

Room createMeetingRoom() => Room(
  roomOptions: const RoomOptions(
    adaptiveStream: true,
    dynacast: true,
    // Reduce camera/encoder load while keeping lower simulcast layers
    // available for participants on slower connections.
    defaultCameraCaptureOptions: CameraCaptureOptions(
      params: VideoParametersPresets.h540_169,
    ),
  ),
);

/// How a desktop can capture computer audio together with the screen.
enum SystemAudioSupport {
  /// No computer audio capture.
  none,

  /// Windows: every app except this one, or only the shared window's app.
  excludesMeeting,

  /// Linux: everything the speakers play, including the meeting itself.
  includesMeeting,
}

/// What the user picked in the screen picker.
class ScreenShareChoice {
  const ScreenShareChoice({required this.sourceId, required this.shareAudio});

  final String sourceId;
  final bool shareAudio;
}

/// Text for an Android foreground-service notification.
typedef NotificationText = ({String channelName, String title, String body});

class MeetingPlatform {
  const MeetingPlatform();

  static const _display = MethodChannel('reisub_meeting/display');

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  SystemAudioSupport get systemAudioSupport {
    if (kIsWeb) return SystemAudioSupport.none;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows => SystemAudioSupport.excludesMeeting,
      TargetPlatform.linux => SystemAudioSupport.includesMeeting,
      _ => SystemAudioSupport.none,
    };
  }

  /// Lists screens and windows on desktop platforms.
  rtc.DesktopCapturer get desktopCapturer => rtc.desktopCapturer;

  /// Android 12+ requires runtime permission for Bluetooth headsets. Denial
  /// still allows using the phone's microphone and speaker.
  Future<void> requestBluetoothPermission() async {
    if (_isAndroid) await Permission.bluetoothConnect.request();
  }

  /// Asks Android for screen capture consent. Other platforms need none.
  Future<bool> requestScreenCapturePermission() async =>
      !_isAndroid || await rtc.Helper.requestCapturePermission();

  Future<void> setFullscreen(bool enabled) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Use Android's insets controller directly for target SDK 36 as well.
      await _display.invokeMethod<void>('setFullscreen', enabled);
    } else {
      await SystemChrome.setEnabledSystemUIMode(
        enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    }
  }

  /// Android requires a foreground service while the screen is captured.
  /// Returns whether a service was started.
  Future<bool> startScreenShareService(NotificationText text) async {
    if (!_isAndroid) return false;
    await _display.invokeMethod<void>('startScreenShareService', {
      'channelName': text.channelName,
      'title': text.title,
      'body': text.body,
    });
    return true;
  }

  Future<void> stopScreenShareService() =>
      _display.invokeMethod<void>('stopScreenShareService');

  /// Android: keeps the app, its microphone and the meeting's audio running
  /// while it is in the background, with an ongoing notification.
  Future<void> startMeetingService(NotificationText text) async {
    if (!_isAndroid) return;
    // Android 13+ hides the notification unless the user allows it; the
    // service itself runs either way.
    await _quietly(() => Permission.notification.request());
    await _quietly(
      () => _display.invokeMethod<void>('startMeetingService', {
        'channelName': text.channelName,
        'title': text.title,
        'body': text.body,
      }),
    );
  }

  Future<void> stopMeetingService() async {
    if (_isAndroid) {
      await _quietly(() => _display.invokeMethod<void>('stopMeetingService'));
    }
  }

  /// No screen timeout while a meeting is on screen: Android natively, and
  /// in browsers that support the Screen Wake Lock API.
  Future<void> setKeepScreenOn(bool enabled) async {
    if (kIsWeb) {
      await _quietly(() => setWebWakeLock(enabled));
    } else if (_isAndroid) {
      await _quietly(
        () => _display.invokeMethod<void>('setKeepScreenOn', enabled),
      );
    }
  }

  /// Android: sends the app to the background, like the Home button, so the
  /// back button does not end the meeting.
  Future<void> moveToBackground() async {
    if (_isAndroid) {
      await _quietly(() => _display.invokeMethod<bool>('moveToBackground'));
    }
  }

  /// Background support must never break the meeting itself.
  static Future<void> _quietly(Future<Object?> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }
}
