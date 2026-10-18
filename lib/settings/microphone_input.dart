import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

/// Windows WebRTC otherwise opens recording device 0, which need not be the
/// microphone selected as the default communications input in Windows.
class MicrophoneInput {
  MicrophoneInput({
    bool? isWindows,
    Future<String?> Function()? defaultDeviceId,
    Future<void> Function(String)? selectInput,
  }) : _isWindows =
           isWindows ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows),
       _defaultDeviceId = defaultDeviceId ?? _windowsDefaultDeviceId,
       _selectInput = selectInput ?? rtc.Helper.selectAudioInput;

  final bool _isWindows;
  final Future<String?> Function() _defaultDeviceId;
  final Future<void> Function(String) _selectInput;

  static Future<String?> _windowsDefaultDeviceId() async {
    try {
      return await const MethodChannel(
        'reisub_meeting/audio',
      ).invokeMethod<String>('getDefaultMicrophoneId');
    } on MissingPluginException {
      throw PlatformException(
        code: 'WindowsAudioRestartRequired',
        message:
            'Windows ses bileşeni güncel değil. Uygulamayı yeniden '
            'derleyip tamamen kapatarak yeniden başlatın.',
      );
    }
  }

  Future<String?> resolve(String? preferredDeviceId) async {
    if (preferredDeviceId != null && preferredDeviceId.isNotEmpty) {
      return preferredDeviceId;
    }
    if (!_isWindows) return null;
    final id = await _defaultDeviceId();
    return id == null || id.isEmpty ? null : id;
  }

  Future<void> select(String? deviceId) async {
    if (_isWindows && deviceId != null && deviceId.isNotEmpty) {
      // Also route existing publications: LiveKit's unmute ignores new capture
      // options once a microphone publication already exists.
      await _selectInput(deviceId);
    }
  }
}
