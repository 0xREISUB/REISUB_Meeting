import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/l10n/localized_error.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:v_meeting/settings/microphone_input.dart';

/// Recovers from an unavailable Windows default capture device without
/// retrying signaling/publishing failures or changing mobile capture options.
class MeetingMedia {
  MeetingMedia({
    bool? isWindows,
    this.microphoneId,
    this.cameraId,
    MicrophoneInput? microphoneInput,
    Future<List<rtc.MediaDeviceInfo>> Function()? enumerateDevices,
  }) : _isWindows =
           isWindows ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows),
       _enumerateDevices =
           enumerateDevices ?? rtc.navigator.mediaDevices.enumerateDevices,
       _microphoneInput =
           microphoneInput ?? MicrophoneInput(isWindows: isWindows);

  final bool _isWindows;
  String? microphoneId;
  String? cameraId;
  final Future<List<rtc.MediaDeviceInfo>> Function() _enumerateDevices;
  final MicrophoneInput _microphoneInput;

  Future<void> releaseDevice(
    LocalParticipant participant, {
    required bool camera,
  }) async {
    final publication = participant.getTrackPublicationBySource(
      camera ? TrackSource.camera : TrackSource.microphone,
    );
    if (publication != null) {
      // Unmute reuses the old publication's capture options. Removing only this
      // source releases the hardware and makes the next enable use the new ID.
      await participant.removePublishedTrack(publication.sid);
    }
  }

  Future<void> setCameraEnabled(LocalParticipant participant, bool enabled) =>
      _setEnabled(
        enabled: enabled,
        kind: 'videoinput',
        preferredDeviceId: cameraId,
        start: (deviceId) async {
          await participant.setCameraEnabled(
            enabled,
            cameraCaptureOptions: deviceId == null
                ? null
                : CameraCaptureOptions(
                    deviceId: deviceId,
                    // Common webcam mode; some Windows cameras cannot open
                    // the meeting's preferred 960x540 capture mode.
                    params: VideoParametersPresets.h480_43,
                  ),
          );
        },
      );

  Future<void> setMicrophoneEnabled(
    LocalParticipant participant,
    bool enabled,
  ) async {
    final initialDeviceId = enabled
        ? await _microphoneInput.resolve(microphoneId)
        : microphoneId;
    String? openedDeviceId;
    await _setEnabled(
      enabled: enabled,
      kind: 'audioinput',
      preferredDeviceId: microphoneId,
      initialDeviceId: initialDeviceId,
      start: (deviceId) async {
        await participant.setMicrophoneEnabled(
          enabled,
          audioCaptureOptions: deviceId == null
              ? null
              : AudioCaptureOptions(deviceId: deviceId),
        );
        openedDeviceId = deviceId;
      },
    );
    if (!enabled) return;
    try {
      await _microphoneInput.select(openedDeviceId);
    } catch (error, stack) {
      // Do not report an enabled microphone when routing the requested input
      // failed (for example, a saved USB microphone was unplugged).
      try {
        await participant.setMicrophoneEnabled(false);
      } catch (_) {
        // Preserve the routing error.
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<void> _setEnabled({
    required bool enabled,
    required String kind,
    String? preferredDeviceId,
    String? initialDeviceId,
    required Future<void> Function(String?) start,
  }) async {
    try {
      await start(preferredDeviceId ?? initialDeviceId);
      return;
    } catch (captureError, captureStack) {
      // Honor explicit choices instead of silently opening another microphone.
      if (!_isWindows ||
          !enabled ||
          preferredDeviceId != null ||
          !_isCaptureFailure(captureError)) {
        rethrow;
      }
      // Preserve the original capture error if device enumeration also fails.
      final List<rtc.MediaDeviceInfo> devices;
      try {
        devices = await _enumerateDevices();
      } catch (_) {
        Error.throwWithStackTrace(captureError, captureStack);
      }
      final tried = <String>{?initialDeviceId};
      for (final device in devices) {
        if (device.kind != kind ||
            device.deviceId.isEmpty ||
            !tried.add(device.deviceId)) {
          continue;
        }
        try {
          await start(device.deviceId);
          return;
        } catch (error) {
          if (!_isCaptureFailure(error)) rethrow;
          // A stale/virtual device may be listed before the physical device.
          continue;
        }
      }
      rethrow;
    }
  }
}

bool _isCaptureFailure(Object error) {
  if (error is TrackCreateException) return true;
  if (error is! PlatformException) return false;
  final message = '${error.code} ${error.message}'.toLowerCase();
  // Permission denial applies to all inputs; publishing/transport errors must
  // not cause a different microphone to be opened either.
  if ([
    'permission',
    'denied',
    'notallowed',
    '0x80070005',
  ].any(message.contains)) {
    return false;
  }
  return [
    'getusermedia',
    'notfound',
    'notreadable',
    'trackstarterror',
  ].any(message.contains);
}

String mediaCaptureError(
  Object error, {
  required bool camera,
  required AppLocalizations l10n,
}) {
  final device = camera ? l10n.cameraName : l10n.microphoneName;
  if (error is PlatformException &&
      (error.code == 'WindowsAudioRestartRequired' ||
          error.code == 'WindowsMicrophoneNotFound')) {
    return localizeError(error, l10n);
  }
  final message = error.toString().toLowerCase();
  final captureFailure =
      error is TrackCreateException ||
      [
        'getusermedia',
        'notallowed',
        'permission',
        'denied',
        '0x80070005',
      ].any(message.contains);
  if (!captureFailure) {
    return l10n.captureFailed(device, localizeError(error, l10n));
  }
  final windows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  final accessHint = windows
      ? l10n.windowsCaptureAccessHint(device)
      : l10n.appCaptureAccessHint(device.toLowerCase());
  return '${l10n.captureUnavailable(device, camera ? l10n.captureVideo : l10n.captureAudio)} '
      '$accessHint ${l10n.captureRetryHint(device.toLowerCase())}';
}
