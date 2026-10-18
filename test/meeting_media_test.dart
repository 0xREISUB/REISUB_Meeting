import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:v_meeting/meeting/meeting_media.dart';
import 'package:v_meeting/settings/microphone_input.dart';

class _Participant implements LocalParticipant {
  final cameras = <CameraCaptureOptions?>[];
  final microphones = <AudioCaptureOptions?>[];
  final enabledValues = <bool>[];
  final microphoneEnabledValues = <bool>[];
  final microphoneErrors = <Object>[];
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
    microphoneEnabledValues.add(enabled);
    if (microphoneErrors.isNotEmpty) throw microphoneErrors.removeAt(0);
    if (publishError != null) throw publishError!;
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

MeetingMedia _media({
  required bool isWindows,
  String? microphoneId,
  String? cameraId,
  Future<List<rtc.MediaDeviceInfo>> Function()? enumerateDevices,
}) => MeetingMedia(
  isWindows: isWindows,
  microphoneId: microphoneId,
  cameraId: cameraId,
  enumerateDevices: enumerateDevices,
  microphoneInput: MicrophoneInput(
    isWindows: isWindows,
    defaultDeviceId: () async => null,
    selectInput: (_) async {},
  ),
);

void main() {
  test(
    'explicit saved choices are used and never replaced by another input',
    () async {
      final participant = _Participant()
        ..workingMicrophone = 'chosen-mic'
        ..workingCamera = 'chosen-camera';
      final media = _media(
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
      final media = _media(
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
    final media = _media(
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
    final media = _media(
      isWindows: true,
      enumerateDevices: () async => throw StateError('unexpected enumeration'),
    );
    await media.setCameraEnabled(participant, true);
    await media.setCameraEnabled(participant, false);
    expect(participant.enabledValues, [true, false]);
  });

  test('mobile capture failures do not try Windows fallbacks', () async {
    final media = _media(
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
      final media = _media(
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
      final media = _media(
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

  test(
    'Windows uses the system communications microphone before capture succeeds',
    () async {
      final routed = <String>[];
      final participant = _Participant()
        ..workingMicrophone = 'communications-mic';
      final media = MeetingMedia(
        isWindows: true,
        microphoneInput: MicrophoneInput(
          isWindows: true,
          defaultDeviceId: () async => 'communications-mic',
          selectInput: (id) async => routed.add(id),
        ),
        enumerateDevices: () async => throw StateError('no fallback expected'),
      );
      await media.setMicrophoneEnabled(participant, true);
      expect(participant.microphones.single!.deviceId, 'communications-mic');
      expect(routed, ['communications-mic']);
    },
  );

  test(
    'unmuting reroutes an existing publication and resolves the current default',
    () async {
      final routed = <String>[];
      var defaultId = 'built-in';
      final participant = _Participant()..workingMicrophone = defaultId;
      final media = MeetingMedia(
        isWindows: true,
        enumerateDevices: () async =>
            throw StateError('unexpected enumeration'),
        microphoneInput: MicrophoneInput(
          isWindows: true,
          defaultDeviceId: () async => defaultId,
          selectInput: (id) async => routed.add(id),
        ),
      );
      await media.setMicrophoneEnabled(participant, true);
      await media.setMicrophoneEnabled(participant, false);
      defaultId = 'headset';
      participant.workingMicrophone = defaultId;
      await media.setMicrophoneEnabled(participant, true);
      expect(routed, ['built-in', 'headset']);
      expect(participant.microphoneEnabledValues, [true, false, true]);
    },
  );

  test('a saved microphone is used instead of the Windows default', () async {
    final routed = <String>[];
    final participant = _Participant()..workingMicrophone = 'saved';
    final media = MeetingMedia(
      isWindows: true,
      microphoneId: 'saved',
      enumerateDevices: () async => throw StateError('unexpected enumeration'),
      microphoneInput: MicrophoneInput(
        isWindows: true,
        defaultDeviceId: () async => throw StateError('must honor saved input'),
        selectInput: (id) async => routed.add(id),
      ),
    );
    await media.setMicrophoneEnabled(participant, true);
    expect(routed, ['saved']);
  });

  test(
    'a routing failure disables the microphone and preserves the error',
    () async {
      final error = PlatformException(
        code: 'Bad Arguments',
        message: 'Input missing',
      );
      final participant = _Participant()..workingMicrophone = 'unplugged';
      final media = MeetingMedia(
        isWindows: true,
        microphoneId: 'unplugged',
        enumerateDevices: () async =>
            throw StateError('unexpected enumeration'),
        microphoneInput: MicrophoneInput(
          isWindows: true,
          selectInput: (_) async => throw error,
        ),
      );
      await expectLater(
        media.setMicrophoneEnabled(participant, true),
        throwsA(same(error)),
      );
      expect(participant.microphoneEnabledValues, [true, false]);
    },
  );

  test(
    'native capture errors retry audio inputs, skipping the failed system default',
    () async {
      final routed = <String>[];
      final participant = _Participant()
        ..workingMicrophone = 'usb'
        ..microphoneErrors.add(
          PlatformException(code: 'getUserMedia', message: 'NotReadableError'),
        );
      final media = MeetingMedia(
        isWindows: true,
        microphoneInput: MicrophoneInput(
          isWindows: true,
          defaultDeviceId: () async => 'broken-default',
          selectInput: (id) async => routed.add(id),
        ),
        enumerateDevices: () async => [
          device('audioinput', 'broken-default'),
          device('audiooutput', 'speaker'),
          device('audioinput', 'usb'),
        ],
      );
      await media.setMicrophoneEnabled(participant, true);
      expect(participant.microphones.map((options) => options?.deviceId), [
        'broken-default',
        'usb',
      ]);
      expect(routed, ['usb']);
    },
  );

  test(
    'permission and publish failures never open a different microphone',
    () async {
      for (final error in [
        PlatformException(code: 'getUserMedia', message: 'Permission denied'),
        StateError('publish failed'),
      ]) {
        final participant = _Participant()..microphoneErrors.add(error);
        final media = _media(
          isWindows: true,
          enumerateDevices: () async => throw StateError('unexpected fallback'),
        );
        await expectLater(
          media.setMicrophoneEnabled(participant, true),
          throwsA(same(error)),
        );
        expect(participant.microphones.length, 1);
      }
    },
  );
}
