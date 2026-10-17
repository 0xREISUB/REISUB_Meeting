import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:v_meeting/meeting/meeting_media.dart';

class _Participant implements LocalParticipant {
  final cameras = <CameraCaptureOptions?>[];
  final microphones = <AudioCaptureOptions?>[];
  final enabledValues = <bool>[];
  String? workingCamera;
  String? workingMicrophone;
  Object? publishError;

  @override
  Future<LocalTrackPublication?> setCameraEnabled(
    bool enabled, {
    CameraCaptureOptions? cameraCaptureOptions,
  }) async {
    cameras.add(cameraCaptureOptions);
    enabledValues.add(enabled);
    if (publishError != null) throw publishError!;
    if (enabled && cameraCaptureOptions?.deviceId != workingCamera) {
      throw TrackCreateException();
    }
    return null;
  }

  @override
  Future<LocalTrackPublication?> setMicrophoneEnabled(
    bool enabled, {
    AudioCaptureOptions? audioCaptureOptions,
  }) async {
    microphones.add(audioCaptureOptions);
    if (enabled && audioCaptureOptions?.deviceId != workingMicrophone) {
      throw TrackCreateException();
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

rtc.MediaDeviceInfo device(String kind, String id) =>
    rtc.MediaDeviceInfo(kind: kind, label: id, deviceId: id);

void main() {
  test(
    'explicit saved choices are used and never replaced by another input',
    () async {
      final participant = _Participant()
        ..workingMicrophone = 'chosen-mic'
        ..workingCamera = 'chosen-camera';
      final media = MeetingMedia(
        isWindows: true,
        microphoneId: 'chosen-mic',
        cameraId: 'chosen-camera',
        enumerateDevices: () async => throw StateError('unexpected fallback'),
      );
      await media.setMicrophoneEnabled(participant, true);
      await media.setCameraEnabled(participant, true);
      expect(participant.microphones.single!.deviceId, 'chosen-mic');
      expect(participant.cameras.single!.deviceId, 'chosen-camera');
      participant.workingMicrophone = 'other';
      await expectLater(
        media.setMicrophoneEnabled(participant, true),
        throwsA(isA<TrackCreateException>()),
      );
    },
  );

  test(
    'Windows retries physical camera after default and virtual camera fail',
    () async {
      final participant = _Participant()..workingCamera = 'usb';
      final media = MeetingMedia(
        isWindows: true,
        enumerateDevices: () async => [
          device('audioinput', 'mic'),
          device('videoinput', 'virtual'),
          device('videoinput', 'virtual'),
          device('videoinput', 'usb'),
        ],
      );
      await media.setCameraEnabled(participant, true);
      expect(participant.cameras.map((o) => o?.deviceId), [
        null,
        'virtual',
        'usb',
      ]);
      expect(participant.cameras.last!.params, VideoParametersPresets.h480_43);
    },
  );

  test('microphone retries audio inputs independently of camera', () async {
    final participant = _Participant()..workingMicrophone = 'usb-mic';
    final media = MeetingMedia(
      isWindows: true,
      enumerateDevices: () async => [
        device('videoinput', 'cam'),
        device('audiooutput', 'speaker'),
        device('audioinput', 'usb-mic'),
      ],
    );
    await media.setMicrophoneEnabled(participant, true);
    expect(participant.microphones.map((o) => o?.deviceId), [null, 'usb-mic']);
    expect(participant.cameras, isEmpty);
  });

  test('successful default and disabling never enumerate devices', () async {
    final participant = _Participant();
    final media = MeetingMedia(
      isWindows: true,
      enumerateDevices: () async => throw StateError('unexpected enumeration'),
    );
    await media.setCameraEnabled(participant, true);
    await media.setCameraEnabled(participant, false);
    expect(participant.enabledValues, [true, false]);
  });

  test('mobile capture failures do not try Windows fallbacks', () async {
    final media = MeetingMedia(
      isWindows: false,
      enumerateDevices: () async => throw StateError('unexpected enumeration'),
    );
    await expectLater(
      media.setCameraEnabled(_Participant()..workingCamera = 'missing', true),
      throwsA(isA<TrackCreateException>()),
    );
  });

  test(
    'publishing failures are propagated without opening other cameras',
    () async {
      final error = StateError('publish failed');
      final media = MeetingMedia(
        isWindows: true,
        enumerateDevices: () async =>
            throw StateError('unexpected enumeration'),
      );
      await expectLater(
        media.setCameraEnabled(_Participant()..publishError = error, true),
        throwsA(same(error)),
      );
    },
  );

  test('missing devices and failed enumeration retain capture error', () async {
    for (final failEnumeration in [false, true]) {
      final media = MeetingMedia(
        isWindows: true,
        enumerateDevices: () async {
          if (failEnumeration) throw StateError('enumeration failed');
          return [];
        },
      );
      await expectLater(
        media.setCameraEnabled(_Participant()..workingCamera = 'missing', true),
        throwsA(isA<TrackCreateException>()),
      );
    }
  });
}
