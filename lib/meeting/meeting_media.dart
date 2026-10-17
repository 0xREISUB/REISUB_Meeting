import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';

/// Recovers from an unavailable Windows default capture device without
/// retrying signaling/publishing failures or changing mobile capture options.
class MeetingMedia {
  MeetingMedia({
    bool? isWindows,
    this.microphoneId,
    this.cameraId,
    Future<List<rtc.MediaDeviceInfo>> Function()? enumerateDevices,
  }) : _isWindows =
           isWindows ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows),
       _enumerateDevices =
           enumerateDevices ?? rtc.navigator.mediaDevices.enumerateDevices;

  final bool _isWindows;
  String? microphoneId;
  String? cameraId;
  final Future<List<rtc.MediaDeviceInfo>> Function() _enumerateDevices;

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
  ) => _setEnabled(
    enabled: enabled,
    kind: 'audioinput',
    preferredDeviceId: microphoneId,
    start: (deviceId) async {
      await participant.setMicrophoneEnabled(
        enabled,
        audioCaptureOptions: deviceId == null
            ? null
            : AudioCaptureOptions(deviceId: deviceId),
      );
    },
  );

  Future<void> _setEnabled({
    required bool enabled,
    required String kind,
    String? preferredDeviceId,
    required Future<void> Function(String?) start,
  }) async {
    try {
      await start(preferredDeviceId);
      return;
    } on TrackCreateException catch (captureError, captureStack) {
      // Honor explicit choices instead of silently opening another microphone.
      if (!_isWindows || !enabled || preferredDeviceId != null) rethrow;
      // Preserve the original capture error if device enumeration also fails.
      final List<rtc.MediaDeviceInfo> devices;
      try {
        devices = await _enumerateDevices();
      } catch (_) {
        Error.throwWithStackTrace(captureError, captureStack);
      }
      final tried = <String>{};
      for (final device in devices) {
        if (device.kind != kind ||
            device.deviceId.isEmpty ||
            !tried.add(device.deviceId)) {
          continue;
        }
        try {
          await start(device.deviceId);
          return;
        } on TrackCreateException {
          // A stale/virtual device may be listed before the physical device.
          continue;
        }
      }
      rethrow;
    }
  }
}

String mediaCaptureError(Object error, {required bool camera}) {
  final device = camera ? 'Kamera' : 'Mikrofon';
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
  if (!captureFailure) return '$device açılamadı: $error';
  final windows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  return '$device açılamadı; cihazdan ${camera ? 'görüntü' : 'ses'} alınamadı. '
      'Cihazın bağlı olduğunu ve başka bir uygulama tarafından kullanılmadığını kontrol edin. '
      '${windows ? 'Windows ayarlarında $device erişimini ve masaüstü uygulamalarının erişimini açın.' : 'Uygulamanın ${camera ? 'kamera' : 'mikrofon'} iznini kontrol edin.'} '
      'Ardından ${camera ? 'kamera' : 'mikrofon'} düğmesiyle tekrar deneyin.';
}
