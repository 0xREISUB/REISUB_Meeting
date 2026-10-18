import 'package:v_meeting/l10n/app_localizations.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/settings/device_test_screen.dart';
import 'package:v_meeting/settings/device_test_session.dart';
import 'package:v_meeting/settings/media_preferences.dart';
import 'package:v_meeting/settings/media_privacy.dart';
import 'package:v_meeting/settings/microphone_input.dart';

class _Track extends Fake implements rtc.MediaStreamTrack {
  int stops = 0;
  @override
  Future<void> stop() async {
    stops++;
  }
}

class _Stream extends Fake implements rtc.MediaStream {
  _Stream({this.camera = false, this.empty = false});
  final bool camera;
  final bool empty;
  final track = _Track();
  int disposals = 0;
  @override
  List<rtc.MediaStreamTrack> getTracks() => [track];
  @override
  List<rtc.MediaStreamTrack> getVideoTracks() =>
      camera && !empty ? [track] : [];
  @override
  List<rtc.MediaStreamTrack> getAudioTracks() =>
      !camera && !empty ? [track] : [];
  @override
  Future<void> dispose() async {
    disposals++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const webRtcChannel = MethodChannel('FlutterWebRTC.Method');
  const privacyChannel = MethodChannel('reisub_meeting/privacy');
  const audioChannel = MethodChannel('reisub_meeting/audio');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(webRtcChannel, null)
      ..setMockMethodCallHandler(audioChannel, null)
      ..setMockMethodCallHandler(privacyChannel, null);
  });

  test(
    'Windows microphone resolves the native default and routes the same input',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final routed = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(audioChannel, (call) async {
            expect(call.method, 'getDefaultMicrophoneId');
            return 'communications-microphone';
          });
      final input = MicrophoneInput(selectInput: (id) async => routed.add(id));
      final id = await input.resolve(null);
      expect(id, 'communications-microphone');
      await input.select(id);
      expect(routed, ['communications-microphone']);
    },
  );

  test('non-Windows capture never invokes native Windows routing', () async {
    final input = MicrophoneInput(
      isWindows: false,
      defaultDeviceId: () async =>
          throw StateError('unexpected Windows lookup'),
      selectInput: (_) async => throw StateError('unexpected Windows routing'),
    );
    expect(await input.resolve(null), isNull);
    expect(await input.resolve('saved'), 'saved');
    await input.select('saved');
  });

  test(
    'an older Windows runner requests a rebuild instead of a silent input',
    () async {
      await expectLater(
        MicrophoneInput(isWindows: true).resolve(null),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'WindowsAudioRestartRequired',
          ),
        ),
      );
    },
  );

  test(
    'microphone meter uses the meeting input before starting audio peers',
    () async {
      final events = <String>[];
      final stream = _Stream();
      await expectLater(
        DeviceTestSession.start(
          camera: false,
          microphoneInput: MicrophoneInput(
            isWindows: true,
            defaultDeviceId: () async => 'system-input',
            selectInput: (id) async => events.add('select:$id'),
          ),
          getUserMedia: (constraints) async {
            final audio = constraints['audio'] as Map;
            expect(
              audio['optional'],
              contains(equals({'sourceId': 'system-input'})),
            );
            expect(constraints['video'], false);
            events.add('capture');
            return stream;
          },
          createPeer: (_) async {
            events.add('peer');
            throw StateError('end test after routing');
          },
        ),
        throwsStateError,
      );
      expect(events, ['capture', 'select:system-input', 'peer']);
      expect(stream.track.stops, 1);
      expect(stream.disposals, 1);
    },
  );

  test(
    'camera and microphone preferences persist independently and reset',
    () async {
      await MediaPreferences.select(camera: false, deviceId: 'usb-mic');
      await MediaPreferences.select(camera: true, deviceId: 'webcam');
      var preferences = await MediaPreferences.load();
      expect(preferences.microphoneId, 'usb-mic');
      expect(preferences.cameraId, 'webcam');
      await MediaPreferences.select(camera: false);
      preferences = await MediaPreferences.load();
      expect(preferences.microphoneId, isNull);
      expect(preferences.cameraId, 'webcam');
    },
  );

  test(
    'preview uses only selected camera and stops capture exactly once',
    () async {
      final stream = _Stream(camera: true);
      Map<String, dynamic>? constraints;
      final session = await DeviceTestSession.start(
        camera: true,
        deviceId: 'usb-camera',
        getUserMedia: (value) async {
          constraints = value;
          return stream;
        },
      );
      expect(constraints!['audio'], false);
      expect((constraints!['video'] as Map)['optional'], [
        {'sourceId': 'usb-camera'},
      ]);
      await session.stop();
      await session.stop();
      expect(stream.track.stops, 1);
      expect(stream.disposals, 1);
    },
  );

  test(
    'empty capture and microphone meter startup failure release hardware',
    () async {
      final empty = _Stream(camera: true, empty: true);
      await expectLater(
        DeviceTestSession.start(camera: true, getUserMedia: (_) async => empty),
        throwsA(isA<TrackCreateException>()),
      );
      expect(empty.track.stops, 1);
      expect(empty.disposals, 1);
      final microphone = _Stream();
      await expectLater(
        DeviceTestSession.start(
          camera: false,
          getUserMedia: (_) async => microphone,
          createPeer: (_) async => throw StateError('meter failed'),
        ),
        throwsStateError,
      );
      expect(microphone.track.stops, 1);
      expect(microphone.disposals, 1);
    },
  );

  test(
    'Windows opens separate privacy pages and tolerates unavailable channel',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(privacyChannel, (call) async {
            calls.add(call.method);
            return true;
          });
      expect(await openMediaPrivacy(camera: true), isTrue);
      expect(await openMediaPrivacy(camera: false), isTrue);
      expect(calls, ['openCameraSettings', 'openMicrophoneSettings']);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            privacyChannel,
            (_) async => throw PlatformException(code: 'blocked'),
          );
      expect(await openMediaPrivacy(camera: true), isFalse);
    },
  );

  testWidgets('microphone selection saves and denied test remains retryable', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(webRtcChannel, (call) async {
          if (call.method == 'initialize') return null;
          if (call.method == 'getSources') {
            return {
              'sources': [
                {
                  'deviceId': 'usb',
                  'label': 'USB mikrofon',
                  'kind': 'audioinput',
                },
                {'deviceId': 'cam', 'label': 'Webcam', 'kind': 'videoinput'},
              ],
            };
          }
          if (call.method == 'getUserMedia') {
            throw PlatformException(
              code: 'NotAllowedError',
              message: 'Permission denied',
            );
          }
          return null;
        });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DeviceTestScreen(camera: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Webcam'), findsNothing);
    await tester.tap(find.text('USB mikrofon').last);
    await tester.pumpAndSettle();
    expect((await MediaPreferences.load()).microphoneId, 'usb');
    await tester.tap(find.text('Testi başlat'));
    await tester.pumpAndSettle();
    expect(find.textContaining('iznini kontrol edin'), findsOneWidget);
    expect(find.text('Testi başlat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing while capture is opening releases the eventual stream', (
    tester,
  ) async {
    final capture = Completer<Map<String, dynamic>>();
    final controller = DeviceTestController();
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(webRtcChannel, (call) async {
          calls.add(call.method);
          if (call.method == 'getSources') return {'sources': []};
          if (call.method == 'getUserMedia') return capture.future;
          return null;
        });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DeviceTestScreen(camera: false, controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Testi başlat'));
    await tester.pump();
    expect(calls, contains('getUserMedia'));
    await tester.pumpWidget(const SizedBox());
    var released = false;
    controller.close().then((_) => released = true);
    await tester.pump();
    expect(released, isFalse);
    capture.complete({
      'streamId': 'test-stream',
      'audioTracks': [],
      'videoTracks': [],
    });
    await tester.pumpAndSettle();
    expect(calls, contains('streamDispose'));
    expect(released, isTrue);
    expect(tester.takeException(), isNull);
  });
}
