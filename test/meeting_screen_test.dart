import 'dart:collection';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/home/home_screen.dart';
import 'package:v_meeting/meeting/widgets/meeting_controls_bar.dart';
import 'package:v_meeting/meeting/meeting_api.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/members_screen.dart';
import 'package:v_meeting/meeting/meeting_member.dart';
import 'package:v_meeting/meeting/meeting_platform.dart';
import 'package:v_meeting/meeting/meeting_screen.dart';
import 'package:v_meeting/settings/device_test_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/meeting/widgets/meeting_participant.dart';

class _TestRoom extends ChangeNotifier implements Room {
  _TestRoom({this.local, this.connectSuccessfully = false, this.connectResult});
  final LocalParticipant? local;
  final bool connectSuccessfully;
  final Completer<void>? connectResult;
  int connectCalls = 0;
  void changed() => notifyListeners();
  @override
  final events = EventsEmitter<RoomEvent>();

  @override
  EventsListener<RoomEvent> createListener({bool synchronized = false}) =>
      EventsListener<RoomEvent>(events, synchronized: synchronized);
  @override
  LocalParticipant? get localParticipant => local;

  @override
  UnmodifiableListView<Participant> get activeSpeakers =>
      UnmodifiableListView([]);

  @override
  UnmodifiableMapView<String, RemoteParticipant> get remoteParticipants =>
      UnmodifiableMapView({});

  @override
  Future<void> connect(
    String url,
    String token, {
    ConnectOptions? connectOptions,
    RoomOptions? roomOptions,
    FastConnectOptions? fastConnectOptions,
  }) async {
    connectCalls++;
    if (connectResult != null) return connectResult!.future;
    if (!connectSuccessfully) throw StateError('Test connection failed');
  }

  int disconnects = 0;
  @override
  Future<void> disconnect() async {
    disconnects++;
  }

  @override
  Future<bool> dispose() async {
    super.dispose();
    await events.dispose();
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestLocal implements LocalParticipant {
  final values = <String, String>{};
  final microphoneChanges = <bool>[];
  bool microphone = false;
  final cameraChanges = <bool>[];
  final microphoneDevices = <String?>[];
  final cameraDevices = <String?>[];
  final publications = <TrackSource, LocalTrackPublication>{};
  final removed = <String>[];
  @override
  UnmodifiableMapView<String, String> get attributes =>
      UnmodifiableMapView(values);
  @override
  String get identity => 'test-local';
  @override
  String get sid => 'local';
  @override
  bool get isSpeaking => false;
  @override
  bool isMicrophoneEnabled() => microphone;
  @override
  LocalTrackPublication? getTrackPublicationBySource(TrackSource source) =>
      publications[source];
  @override
  Future<void> removePublishedTrack(String sid, {bool notify = true}) async {
    removed.add(sid);
    publications.removeWhere((source, publication) {
      if (publication.sid != sid) return false;
      if (source == TrackSource.microphone) microphone = false;
      return true;
    });
  }

  @override
  Future<LocalTrackPublication?> setMicrophoneEnabled(
    bool enabled, {
    AudioCaptureOptions? audioCaptureOptions,
  }) async {
    microphoneChanges.add(enabled);
    microphoneDevices.add(audioCaptureOptions?.deviceId);
    microphone = enabled;
    return null;
  }

  @override
  Future<LocalTrackPublication?> setCameraEnabled(
    bool enabled, {
    CameraCaptureOptions? cameraCaptureOptions,
  }) async {
    cameraChanges.add(enabled);
    cameraDevices.add(cameraCaptureOptions?.deviceId);
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestPublication extends Fake implements LocalTrackPublication {
  _TestPublication(this.sid);
  @override
  final String sid;
  @override
  LocalTrack? get track => null;
  @override
  bool get muted => false;
}

class _ModerationApi extends MeetingApi {
  int closes = 0;
  int joins = 0;
  @override
  Future<RoomCredentials> joinRoom({
    required String roomId,
    required String name,
  }) async {
    joins++;
    return RoomCredentials(
      roomId: roomId,
      liveKitUrl: 'wss://example.test',
      token: 'test',
      participant: name,
      isHost: false,
    );
  }

  @override
  Future<MeetingState> getMeetingState(String roomId) async =>
      const MeetingState();
  VoidCallback? onClose;
  @override
  Future<List<MeetingChatMessage>> getRoomMessages(String roomId) async => [];
  int leaves = 0;
  @override
  Future<void> leaveRoom(String roomId) async => leaves++;

  @override
  Future<void> closeRoom(String roomId) async {
    closes++;
    onClose?.call();
    await Future<void>.delayed(Duration.zero);
  }
}

class _BusySharingApi extends _ModerationApi {
  @override
  Future<MeetingState> getMeetingState(String roomId) async =>
      const MeetingState(
        allowParticipantScreenShare: true,
        screenShareIdentity: 'someone-else',
      );
}

const local = MemberEntry(
  id: 'local',
  name: 'Ali',
  isLocal: true,
  isMicEnabled: true,
);
const remote = MemberEntry(
  id: 'remote',
  name: 'Ayşe',
  isLocal: false,
  isMicEnabled: true,
);
const third = MemberEntry(
  id: 'third',
  name: 'Can',
  isLocal: false,
  isMicEnabled: false,
);
const fourth = MemberEntry(
  id: 'fourth',
  name: 'Deniz',
  isLocal: false,
  isMicEnabled: true,
);

Widget localized(Widget child) => MaterialApp(
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

const _guestCredentials = RoomCredentials(
  roomId: '123-456-789',
  liveKitUrl: 'wss://example.test',
  token: 'test',
  participant: 'Test',
  isHost: false,
);

/// Avoids the real Bluetooth permission prompt, which never answers in tests.
/// Records background-support calls and avoids the real Bluetooth
/// permission prompt, which never answers in tests.
class _TestPlatform extends MeetingPlatform {
  _TestPlatform({this.connectCalls});

  final calls = <String>[];

  /// How often the room had connected when permissions were asked for.
  final int Function()? connectCalls;

  @override
  Future<void> requestMeetingPermissions({required bool camera}) async =>
      calls.add('permissions:camera=$camera,connects=${connectCalls?.call()}');

  @override
  Future<void> setKeepScreenOn(bool enabled) async =>
      calls.add('keepScreenOn:$enabled');

  @override
  Future<void> startMeetingService(NotificationText text) async =>
      calls.add('startService:${text.title}');

  @override
  Future<void> stopMeetingService() async => calls.add('stopService');

  @override
  Future<void> moveToBackground() async => calls.add('moveToBackground');
}

Widget meetingApp(
  Room room, {
  MeetingApi? api,
  RoomCredentials? credentials,
  bool skipJoiningScreen = false,
  MeetingPlatform? platform,
}) => ProviderScope(
  overrides: [
    meetingRoomFactoryProvider.overrideWithValue(() => room),
    meetingApiProvider.overrideWithValue(api ?? _ModerationApi()),
    meetingPlatformProvider.overrideWithValue(platform ?? _TestPlatform()),
  ],
  child: localized(
    MeetingScreen(
      credentials: credentials,
      skipJoiningScreen: skipJoiningScreen,
    ),
  ),
);

void main() {
  Future<void> openExitTest(
    WidgetTester tester,
    _TestRoom room, {
    bool host = false,
    _ModerationApi? api,
    _TestPlatform? platform,
  }) async {
    await tester.pumpWidget(
      meetingApp(
        room,
        api: api,
        platform: platform,
        skipJoiningScreen: true,
        credentials: RoomCredentials(
          roomId: '123-456-789',
          liveKitUrl: 'wss://example.test',
          token: 'test',
          participant: 'Test',
          isHost: host,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('joining screen stays until connection and media setup finish', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final room = _TestRoom(connectSuccessfully: true);
    await tester.pumpWidget(
      meetingApp(room, api: _ModerationApi(), credentials: _guestCredentials),
    );
    expect(
      find.byKey(const ValueKey('meeting-joining-overlay')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('meeting-joining-overlay')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byKey(const ValueKey('meeting-joining-overlay')), findsNothing);
    expect(room.connectCalls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed join shows retry and retries the connection', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final room = _TestRoom();
    final api = _ModerationApi();
    await tester.pumpWidget(
      meetingApp(room, api: api, credentials: _guestCredentials),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byKey(const ValueKey('meeting-joining-retry')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('meeting-joining-retry')));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(api.joins, 1);
    expect(room.connectCalls, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('joining screen times out when signaling never finishes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final room = _TestRoom(connectResult: Completer<void>());
    await tester.pumpWidget(
      meetingApp(room, api: _ModerationApi(), credentials: _guestCredentials),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
    expect(find.byKey(const ValueKey('meeting-joining-retry')), findsOneWidget);
    expect(room.disconnects, greaterThanOrEqualTo(1));
    await tester.pumpWidget(const SizedBox());
  });

  for (final deviceCase in [
    (camera: false, enabled: true, locked: false),
    (camera: true, enabled: true, locked: false),
    (camera: false, enabled: false, locked: false),
    (camera: false, enabled: true, locked: true),
  ]) {
    final camera = deviceCase.camera;
    testWidgets(
      'meeting device selection camera=$camera enabled=${deviceCase.enabled} lockDuringTest=${deviceCase.locked}',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const channel = MethodChannel('FlutterWebRTC.Method');
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getSources') {
            return {
              'sources': [
                {
                  'deviceId': 'new-mic',
                  'label': 'USB mikrofon',
                  'kind': 'audioinput',
                },
                {
                  'deviceId': 'new-camera',
                  'label': 'USB kamera',
                  'kind': 'videoinput',
                },
              ],
            };
          }
          if (call.method == 'createVideoRenderer') return {'textureId': 42};
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final source = camera ? TrackSource.camera : TrackSource.microphone;
        final local = _TestLocal()..microphone = deviceCase.enabled;
        local.publications[source] = _TestPublication('old-device');
        local.publications[TrackSource.screenShareAudio] = _TestPublication(
          'screen-audio',
        );
        final room = _TestRoom(local: local);
        await openExitTest(tester, room);
        room.events.streamCtrl.add(
          RoomConnectedEvent(room: room, metadata: null),
        );
        room.changed();
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.more_horiz_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Toplantı ayarları'));
        await tester.pumpAndSettle();
        expect(find.byType(SwitchListTile), findsNothing);
        await tester.tap(
          find.text(
            camera ? 'Kamera seçimi ve testi' : 'Mikrofon seçimi ve testi',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DeviceTestScreen), findsOneWidget);
        expect(find.byType(MeetingScreen), findsOneWidget);
        expect(local.removed, ['old-device']);
        expect(
          local.publications.containsKey(TrackSource.screenShareAudio),
          isTrue,
        );
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(camera ? 'USB kamera' : 'USB mikrofon').last,
        );
        await tester.pumpAndSettle();
        if (deviceCase.locked) {
          local.values['meeting.microphone_locked'] = 'true';
          room.changed();
          await tester.pump();
        }
        await tester.tap(find.byType(CloseButton));
        await tester.pumpAndSettle();
        expect(find.byType(DeviceTestScreen), findsNothing);
        expect(
          camera ? local.cameraChanges.last : local.microphoneChanges.last,
          deviceCase.enabled && !deviceCase.locked,
        );
        expect(
          camera ? local.cameraDevices.last : local.microphoneDevices.last,
          camera ? 'new-camera' : 'new-mic',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  }

  for (final reason in [
    DisconnectReason.roomDeleted,
    DisconnectReason.roomClosed,
  ]) {
    testWidgets('server $reason returns home even with a sheet open', (
      tester,
    ) async {
      final room = _TestRoom();
      await openExitTest(tester, room);
      await tester.tap(find.byIcon(Icons.people_rounded));
      await tester.pumpAndSettle();
      room.events.streamCtrl.add(RoomDisconnectedEvent(reason: reason));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(MeetingScreen), findsNothing);
      expect(find.byType(MembersScreen), findsNothing);
      expect(
        find.text('Toplantı sunucu tarafından kapatıldı.'),
        findsOneWidget,
      );
      expect(room.disconnects, 1);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  }

  testWidgets('network failure keeps the meeting and rejoin action', (
    tester,
  ) async {
    final room = _TestRoom();
    await openExitTest(tester, room);
    room.events.streamCtrl.add(
      RoomDisconnectedEvent(reason: DisconnectReason.reconnectAttemptsExceeded),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MeetingScreen), findsOneWidget);
    expect(find.text('Tekrar katıl'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  for (final host in [false, true]) {
    testWidgets('screen share is unavailable while someone else shares '
        '(host=$host)', (tester) async {
      final room = _TestRoom(local: _TestLocal());
      await openExitTest(tester, room, host: host, api: _BusySharingApi());
      room.events.streamCtrl.add(
        RoomConnectedEvent(room: room, metadata: null),
      );
      await tester.pumpAndSettle();
      final button = find.byTooltip('Şu anda başka biri ekranını paylaşıyor');
      expect(button, findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(of: button, matching: find.byType(IconButton)),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  }

  testWidgets('host exit offers end and leave; leave does not close the room', (
    tester,
  ) async {
    final room = _TestRoom();
    final api = _ModerationApi();
    await openExitTest(tester, room, host: true, api: api);
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Toplantıyı herkes için bitir'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.call_end_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Toplantıyı bitir'), findsOneWidget);
    expect(find.text('Ayrıl'), findsOneWidget);
    await tester.tap(find.text('Ayrıl'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(api.closes, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('host end tolerates server disconnect before API returns', (
    tester,
  ) async {
    final room = _TestRoom();
    final api = _ModerationApi()
      ..onClose = () {
        room.events.streamCtrl.add(
          RoomDisconnectedEvent(reason: DisconnectReason.roomDeleted),
        );
      };
    await openExitTest(tester, room, host: true, api: api);
    await tester.tap(find.byIcon(Icons.call_end_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toplantıyı bitir'));
    await tester.pumpAndSettle();
    expect(api.closes, 1);
    expect(room.disconnects, 1);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Toplantıyı bitirdiniz.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  test('alone shows self; two participants always show the other person', () {
    expect(selectMainMember([local], activeSpeakerIds: []).id, local.id);
    expect(
      selectMainMember([local, remote], activeSpeakerIds: [local.id]).id,
      remote.id,
    );
  });

  test(
    'group follows the loudest speaker, including self and camera-off users',
    () {
      const members = [local, remote, third];
      for (final speaker in members) {
        expect(
          selectMainMember(
            members,
            activeSpeakerIds: [speaker.id, fourth.id],
            previousSpeakerId: remote.id,
          ).id,
          speaker.id,
        );
      }
    },
  );

  test(
    'silence keeps last speaker and a departed speaker falls back safely',
    () {
      expect(
        selectMainMember(
          [local, remote, third],
          activeSpeakerIds: [],
          previousSpeakerId: third.id,
        ).id,
        third.id,
      );
      expect(
        selectMainMember(
          [local, remote, fourth],
          activeSpeakerIds: [third.id],
          previousSpeakerId: third.id,
        ).id,
        remote.id,
      );
      expect(
        selectMainMember(
          [local],
          activeSpeakerIds: [third.id],
          previousSpeakerId: third.id,
        ).id,
        local.id,
      );
    },
  );

  testWidgets(
    'members panel lists names and rebuilds when membership changes',
    (tester) async {
      final names = ValueNotifier<List<String>>(['Ali', 'Ayşe']);
      addTearDown(names.dispose);
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: ValueListenableBuilder<List<String>>(
              valueListenable: names,
              builder: (context, value, _) => MembersScreen(names: value),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ali'), findsOneWidget);
      expect(find.text('Ayşe'), findsOneWidget);
      expect(find.byType(MeetingParticipantTile), findsNothing);
      names.value = ['Ali', 'Can'];
      await tester.pump();
      expect(find.text('Ayşe'), findsNothing);
      expect(find.text('Can'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  final members = [
    local,
    ...List.generate(
      30,
      (index) => MemberEntry(
        id: 'remote-$index',
        name: 'Katılımcı $index',
        isLocal: false,
        isMicEnabled: false,
      ),
    ),
  ];

  Future<void> showMeeting(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: MeetingVideoLayout(members: members, mainMember: members[1]),
        ),
      ),
    );
  }

  const shared = MemberEntry(
    id: 'sharing',
    name: 'Ayşe',
    isLocal: false,
    isMicEnabled: false,
    isScreenSharing: true,
  );

  test(
    'screen sharing takes precedence over self, speakers and the last speaker',
    () {
      for (final entries in [
        [shared],
        [local, shared],
        [local, remote, shared],
      ]) {
        final main = selectMainMember(
          entries,
          activeSpeakerIds: [local.id, remote.id],
          previousSpeakerId: remote.id,
        );
        expect(main.id, shared.id);
        expect(main.isScreenShare, isTrue);
        expect(
          main.videoTrack,
          isNull,
        ); // Wait for the screen instead of showing a camera.
      }
    },
  );

  testWidgets('fullscreen hides the desktop sidebar and restores it', (
    tester,
  ) async {
    await showMeeting(tester, const Size(1280, 800));
    expect(find.byKey(const ValueKey('meeting-sidebar')), findsOneWidget);
    final before = tester.getSize(find.byKey(const ValueKey('main-remote-0')));
    await tester.tap(find.byKey(const ValueKey('main-fullscreen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('meeting-sidebar')), findsNothing);
    expect(find.byKey(const ValueKey('meeting-next-page')), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('main-remote-0'))).width,
      greaterThan(before.width),
    );
    await tester.tap(find.byKey(const ValueKey('main-fullscreen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('meeting-sidebar')), findsOneWidget);
  });

  testWidgets('shared screen zooms with the mouse wheel and resets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: MeetingVideoLayout(
            members: const [local, shared],
            mainMember: selectMainMember([local, shared], activeSpeakerIds: []),
          ),
        ),
      ),
    );
    final zoom = find.byKey(const ValueKey('main-video-zoom'));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(zoom),
        scrollDelta: const Offset(0, -200),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InteractiveViewer>(zoom)
          .transformationController!
          .value
          .getMaxScaleOnAxis(),
      greaterThan(1),
    );
    await tester.tap(find.byKey(const ValueKey('reset-video-zoom')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InteractiveViewer>(zoom)
          .transformationController!
          .value
          .getMaxScaleOnAxis(),
      closeTo(1, .001),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'phone screen pinch zooms; one-finger swipes still change pages at 1x',
    (tester) async {
      tester.view.physicalSize = const Size(920, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: MeetingVideoLayout(
              members: const [local, shared],
              mainMember: selectMainMember([
                local,
                shared,
              ], activeSpeakerIds: []),
            ),
          ),
        ),
      );
      final zoom = find.byKey(const ValueKey('main-video-zoom'));
      final center = tester.getCenter(zoom);
      final first = await tester.startGesture(
        center - const Offset(40, 0),
        pointer: 1,
      );
      final second = await tester.startGesture(
        center + const Offset(40, 0),
        pointer: 2,
      );
      await tester.pump();
      await first.moveTo(center - const Offset(120, 0));
      await second.moveTo(center + const Offset(120, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<InteractiveViewer>(zoom)
            .transformationController!
            .value
            .getMaxScaleOnAxis(),
        greaterThan(1),
      );
      await tester.tap(find.byKey(const ValueKey('reset-video-zoom')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('meeting-pages')),
        const Offset(-850, 0),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('gallery-page-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('phone pinch works when one finger lands and moves first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(920, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: MeetingVideoLayout(
            members: const [local, shared],
            mainMember: selectMainMember([local, shared], activeSpeakerIds: []),
          ),
        ),
      ),
    );
    final zoom = find.byKey(const ValueKey('main-video-zoom'));
    final center = tester.getCenter(zoom);
    // Real fingers rarely land together: the first one has already slid
    // sideways a little when the second touches the screen.
    final first = await tester.startGesture(
      center - const Offset(40, 0),
      pointer: 1,
    );
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 4; i++) {
      await first.moveBy(const Offset(-6, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final second = await tester.startGesture(
      center + const Offset(40, 0),
      pointer: 2,
    );
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 10; i++) {
      await first.moveBy(const Offset(-10, 0));
      await second.moveBy(const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InteractiveViewer>(zoom)
          .transformationController!
          .value
          .getMaxScaleOnAxis(),
      greaterThan(1.5),
    );
    expect(find.byKey(const ValueKey('gallery-page-1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ending a zoomed share restores phone paging', (tester) async {
    tester.view.physicalSize = const Size(920, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entries = ValueNotifier<List<MemberEntry>>([local, shared]);
    addTearDown(entries.dispose);
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: ValueListenableBuilder<List<MemberEntry>>(
            valueListenable: entries,
            builder: (context, value, _) => MeetingVideoLayout(
              members: value,
              mainMember: selectMainMember(value, activeSpeakerIds: []),
            ),
          ),
        ),
      ),
    );
    final zoom = find.byKey(const ValueKey('main-video-zoom'));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(zoom),
        scrollDelta: const Offset(0, -200),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reset-video-zoom')), findsOneWidget);
    entries.value = [local, remote];
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('meeting-pages')),
      const Offset(-850, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('gallery-page-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop has five previews and arrows page through the gallery', (
    tester,
  ) async {
    await showMeeting(tester, const Size(1280, 800));
    final sidebar = find.byKey(const ValueKey('meeting-sidebar'));
    expect(
      find.descendant(
        of: sidebar,
        matching: find.byType(MeetingParticipantTile),
      ),
      findsNWidgets(5),
    );
    expect(find.byKey(const ValueKey('preview-remote-0')), findsNothing);
    expect(find.byKey(const ValueKey('main-remote-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('meeting-next-page')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-remote-0')), findsNothing);
    expect(find.byType(MeetingParticipantTile), findsNWidgets(16));
    expect(find.byKey(const ValueKey('local')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('meeting-next-page')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('remote-29')), findsOneWidget);
    expect(find.byKey(const ValueKey('meeting-next-page')), findsNothing);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('meeting-previous-page')));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('main-remote-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop previews keep their shape and size as people join', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entries = ValueNotifier<List<MemberEntry>>([local, remote]);
    addTearDown(entries.dispose);
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: ValueListenableBuilder<List<MemberEntry>>(
            valueListenable: entries,
            builder: (context, value, _) =>
                MeetingVideoLayout(members: value, mainMember: remote),
          ),
        ),
      ),
    );
    final preview = find.byKey(const ValueKey('preview-local'));
    final before = tester.getSize(preview);
    expect(before.width / before.height, closeTo(16 / 9, 0.001));
    expect(before.height, lessThan(170));
    entries.value = [local, remote, third, fourth, ...members.skip(3).take(2)];
    await tester.pumpAndSettle();
    expect(tester.getSize(preview), before);
    final sidebar = find.byKey(const ValueKey('meeting-sidebar'));
    final tiles = find.descendant(
      of: sidebar,
      matching: find.byType(MeetingParticipantTile),
    );
    expect(tiles, findsNWidgets(5));
    for (var i = 0; i < 5; i++) {
      expect(tester.getSize(tiles.at(i)), before);
    }
    tester.view.physicalSize = const Size(1280, 600);
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      final rect = tester.getRect(tiles.at(i));
      expect(rect.width / rect.height, closeTo(16 / 9, 0.001));
      expect(rect.bottom, lessThanOrEqualTo(600.001));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile main video fills page and galleries use swipes only', (
    tester,
  ) async {
    await showMeeting(tester, const Size(360, 720));
    final pager = find.byKey(const ValueKey('meeting-pages'));
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(MeetingParticipantTile), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('main-remote-0'))),
      const Size(360, 720),
    );
    await tester.drag(pager, const Offset(-320, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-remote-0')), findsNothing);
    expect(find.byType(MeetingParticipantTile), findsNWidgets(4));
    expect(find.byKey(const ValueKey('local')), findsOneWidget);
    for (var i = 0; i < 7; i++) {
      await tester.drag(pager, const Offset(-320, 0));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('remote-29')), findsOneWidget);
    for (var i = 0; i < 8; i++) {
      await tester.drag(pager, const Offset(320, 0));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('main-remote-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery returns safely when participants leave', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entries = ValueNotifier(members);
    addTearDown(entries.dispose);
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: ValueListenableBuilder<List<MemberEntry>>(
            valueListenable: entries,
            builder: (context, value, _) =>
                MeetingVideoLayout(members: value, mainMember: value.first),
          ),
        ),
      ),
    );
    final pager = find.byKey(const ValueKey('meeting-pages'));
    for (var i = 0; i < 3; i++) {
      await tester.drag(pager, const Offset(-320, 0));
      await tester.pumpAndSettle();
    }
    entries.value = [local];
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-local')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape phone stays swipeable and taps reveal controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(920, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: MeetingVideoLayout(
            members: const [local, remote, third, fourth],
            mainMember: remote,
            onMainPageTap: () => taps++,
          ),
        ),
      ),
    );
    expect(find.byType(IconButton), findsNothing);
    expect(find.byKey(const ValueKey('meeting-sidebar')), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('main-remote'))),
      const Size(920, 400),
    );
    await tester.tapAt(const Offset(5, 200));
    expect(taps, 1);
    final pager = find.byKey(const ValueKey('meeting-pages'));
    await tester.drag(pager, const Offset(-850, 0));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.byType(MeetingParticipantTile), findsNWidgets(4));
    // The participant gallery reveals the controls too.
    await tester.tapAt(const Offset(100, 100));
    expect(taps, 2);
    await tester.drag(pager, const Offset(850, 0));
    await tester.pumpAndSettle();
    expect(taps, 2);
    await tester.tapAt(const Offset(915, 200));
    expect(taps, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('taps reach the controls even where the video claims them', (
    tester,
  ) async {
    var taps = 0;
    var innerTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MeetingTapListener(
          onTap: () => taps++,
          // Like the phone's local camera renderer, which takes taps for
          // focus and pinches for zoom.
          child: GestureDetector(
            onTap: () => innerTaps++,
            onScaleUpdate: (_) {},
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(200, 300));
    expect(innerTaps, 1);
    expect(taps, 1);

    // A pinch is not a tap.
    final first = await tester.startGesture(const Offset(150, 300));
    final second = await tester.startGesture(const Offset(250, 300));
    await first.up();
    await second.up();
    expect(taps, 1);

    // Neither is a drag.
    await tester.dragFrom(const Offset(200, 300), const Offset(-120, 0));
    expect(taps, 1);
  });

  testWidgets(
    'phone enters fullscreen, controls overlay video, exit restores UI',
    (tester) async {
      tester.view.physicalSize = const Size(920, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <MethodCall>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
      const display = MethodChannel('reisub_meeting/display');
      messenger.setMockMethodCallHandler(display, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        messenger.setMockMethodCallHandler(display, null);
      });
      await tester.pumpWidget(meetingApp(_TestRoom()));
      await tester.pumpAndSettle();
      expect(
        calls.any(
          (call) => call.method == 'setFullscreen' && call.arguments == true,
        ),
        isTrue,
      );
      expect(
        calls
            .where(
              (call) => call.method == 'SystemChrome.setPreferredOrientations',
            )
            .last
            .arguments,
        ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight'],
      );
      final video = find.byKey(const ValueKey('main-local'));
      final before = tester.getRect(video);
      expect(before.size, const Size(920, 400));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.mic_rounded).hitTestable(), findsNothing);
      expect(tester.getRect(video), before);
      await tester.tapAt(const Offset(5, 200));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.mic_rounded).hitTestable(), findsOneWidget);
      expect(tester.getRect(video), before);
      // A second tap on the video hides the controls again.
      await tester.tapAt(const Offset(915, 200));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.mic_rounded).hitTestable(), findsNothing);
      expect(tester.getRect(video), before);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'setFullscreen').last.arguments,
        false,
      );
      expect(
        calls
            .where(
              (call) => call.method == 'SystemChrome.setPreferredOrientations',
            )
            .last
            .arguments,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  testWidgets('only owners can moderate remote participants', (tester) async {
    const guest = MemberEntry(
      id: 'guest',
      identity: 'guest',
      name: 'Konuk',
      isLocal: false,
      isMicEnabled: true,
    );
    final actions = <(bool, bool)>[];
    Future<void> render(bool host, MemberEntry entry) async {
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: MembersScreen(
              members: [local, entry],
              viewerRole: host ? MeetingRole.owner : MeetingRole.participant,
              onMicrophoneChange: (_, locked, request) async =>
                  actions.add((locked, request)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await render(false, guest);
    expect(find.byTooltip('Katılımcı işlemleri'), findsNothing);
    await render(true, guest);
    expect(find.byTooltip('Katılımcı işlemleri'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('moderate-guest')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mikrofonu kapat ve kilitle'));
    await tester.pumpAndSettle();
    expect(actions, [(true, false)]);
    const lockedGuest = MemberEntry(
      id: 'guest',
      identity: 'guest',
      name: 'Konuk',
      isLocal: false,
      isMicEnabled: false,
      isMicrophoneLocked: true,
    );
    await render(true, lockedGuest);
    await tester.tap(find.byKey(const ValueKey('moderate-guest')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kilidi kaldır ve açmasını iste'));
    await tester.pumpAndSettle();
    expect(actions.last, (false, true));
    expect(tester.takeException(), isNull);
  });

  group('roles in the members panel', () {
    const guest = MemberEntry(
      id: 'guest',
      identity: 'guest',
      name: 'Konuk',
      isLocal: false,
      isMicEnabled: true,
    );
    const admin = MemberEntry(
      id: 'admin',
      identity: 'admin',
      name: 'Yönetici Ayşe',
      isLocal: false,
      isMicEnabled: true,
      role: MeetingRole.moderator,
    );
    const fullAdmin = MemberEntry(
      id: 'owner',
      identity: 'owner',
      name: 'Sahip Can',
      isLocal: false,
      isMicEnabled: true,
      role: MeetingRole.owner,
    );
    final roleChanges = <(String, MeetingRole)>[];
    final transfers = <String>[];

    Future<void> render(WidgetTester tester, MeetingRole viewer) async {
      roleChanges.clear();
      transfers.clear();
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: MembersScreen(
              members: const [local, guest, admin, fullAdmin],
              viewerRole: viewer,
              onMicrophoneChange: (_, _, _) async {},
              onRoleChange: (member, role) async =>
                  roleChanges.add((member.identity, role)),
              onTransferOwnership: (member) async =>
                  transfers.add(member.identity),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('admins moderate participants but not other admins', (
      tester,
    ) async {
      await render(tester, MeetingRole.moderator);
      expect(find.byKey(const ValueKey('moderate-guest')), findsOneWidget);
      expect(find.byKey(const ValueKey('moderate-admin')), findsNothing);
      expect(find.byKey(const ValueKey('moderate-owner')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('moderate-guest')));
      await tester.pumpAndSettle();
      expect(find.text('Mikrofonu kapat ve kilitle'), findsOneWidget);
      expect(find.text('Yönetici yap'), findsNothing);
      expect(find.text('Tam yöneticiliği devret'), findsNothing);
      expect(find.byKey(const ValueKey('role-badge-owner')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('role-badge-moderator')),
        findsOneWidget,
      );
    });

    testWidgets('full admins change roles but cannot mute a full admin', (
      tester,
    ) async {
      await render(tester, MeetingRole.owner);
      await tester.tap(find.byKey(const ValueKey('moderate-owner')));
      await tester.pumpAndSettle();
      expect(find.text('Mikrofonu kapat ve kilitle'), findsNothing);
      expect(find.text('Tam yönetici yap'), findsNothing);
      await tester.tap(find.text('Yönetici yap'));
      await tester.pumpAndSettle();
      expect(roleChanges, [('owner', MeetingRole.moderator)]);

      await tester.tap(find.byKey(const ValueKey('moderate-admin')));
      await tester.pumpAndSettle();
      expect(find.text('Mikrofonu kapat ve kilitle'), findsOneWidget);
      await tester.tap(find.text('Yöneticiliği kaldır'));
      await tester.pumpAndSettle();
      expect(roleChanges.last, ('admin', MeetingRole.participant));
    });

    testWidgets('transferring full admin asks for confirmation', (
      tester,
    ) async {
      await render(tester, MeetingRole.owner);
      await tester.tap(find.byKey(const ValueKey('moderate-guest')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tam yöneticiliği devret'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Konuk tam yönetici olur'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-transfer')));
      await tester.pumpAndSettle();
      expect(transfers, ['guest']);
    });
  });

  testWidgets('an admin role from the server unlocks ending the meeting', (
    tester,
  ) async {
    final participant = _TestLocal();
    participant.values['meeting.role'] = 'moderator';
    final room = _TestRoom(local: participant);
    final api = _ModerationApi();
    await openExitTest(tester, room, api: api);
    await tester.tap(find.byIcon(Icons.call_end_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Toplantıyı bitir'), findsOneWidget);
    await tester.tap(find.text('Ayrıl'));
    await tester.pumpAndSettle();
    expect(api.leaves, 1);
    expect(api.closes, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a tap on the video toggles the controls, not one on them', (
    tester,
  ) async {
    await openExitTest(tester, _TestRoom());
    final bar = find.byType(MeetingControlsBar);
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    bool shown() => tester.getRect(bar).top < screenHeight;
    expect(shown(), isTrue);

    await tester.tapAt(const Offset(200, 150));
    await tester.pumpAndSettle();
    expect(shown(), isFalse);

    await tester.tapAt(const Offset(200, 150));
    await tester.pumpAndSettle();
    expect(shown(), isTrue);

    // The bar's own background, between its buttons' edges.
    await tester.tapAt(tester.getRect(bar).topLeft + const Offset(12, 30));
    await tester.pumpAndSettle();
    expect(shown(), isTrue);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a participant leaves at once and tells the server', (
    tester,
  ) async {
    final room = _TestRoom(local: _TestLocal());
    final api = _ModerationApi();
    await openExitTest(tester, room, api: api);
    await tester.tap(find.byIcon(Icons.call_end_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(api.leaves, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  group('background', () {
    testWidgets('a meeting keeps the screen awake and runs in the background', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final room = _TestRoom();
      final platform = _TestPlatform(connectCalls: () => room.connectCalls);
      await openExitTest(tester, room, platform: platform);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      // Permissions come first, before connecting and before the service,
      // so no prompt opens while the meeting connects.
      expect(platform.calls, [
        'keepScreenOn:true',
        'permissions:camera=true,connects=0',
        'startService:Toplantı sürüyor',
      ]);
      expect(room.connectCalls, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(
        platform.calls,
        containsAll(['keepScreenOn:false', 'stopService']),
      );
    });

    testWidgets('Android back keeps the meeting and leaves the app running', (
      tester,
    ) async {
      final platform = _TestPlatform();
      final api = _ModerationApi();
      await openExitTest(tester, _TestRoom(), platform: platform, api: api);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(platform.calls.last, 'moveToBackground');
      expect(find.byType(MeetingScreen), findsOneWidget);
      expect(api.leaves, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('desktop back leaves the meeting properly', (tester) async {
      final api = _ModerationApi();
      await openExitTest(tester, _TestRoom(), api: api);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(api.leaves, 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('the camera pauses in the background and comes back', (
      tester,
    ) async {
      final local = _TestLocal();
      final room = _TestRoom(local: local);
      await openExitTest(tester, room);
      room.events.streamCtrl.add(
        RoomConnectedEvent(room: room, metadata: null),
      );
      await tester.pumpAndSettle();
      local.cameraChanges.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(local.cameraChanges, [false]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(local.cameraChanges, [false, true]);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });

  testWidgets('locked microphone stops capture and cannot be opened locally', (
    tester,
  ) async {
    final participant = _TestLocal()..microphone = true;
    participant.values['meeting.microphone_locked'] = 'true';
    final room = _TestRoom(local: participant);
    await tester.pumpWidget(meetingApp(room));
    await tester.pumpAndSettle();
    room.changed();
    await tester.pumpAndSettle();
    expect(participant.microphoneChanges, [false]);
    await tester.tap(find.byIcon(Icons.lock_rounded));
    await tester.pumpAndSettle();
    expect(participant.microphoneChanges, [false]);
    expect(
      find.text('Mikrofonunuz yönetici tarafından kilitlendi.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'microphone requests require consent and a new lock overrides consent',
    (tester) async {
      final participant = _TestLocal();
      final room = _TestRoom(local: participant);
      await tester.pumpWidget(meetingApp(room));
      await tester.pumpAndSettle();
      participant.values['meeting.microphone_request'] = 'request-1';
      room.changed();
      await tester.pumpAndSettle();
      expect(find.text('Mikrofon açma isteği'), findsOneWidget);
      expect(participant.microphoneChanges, isEmpty);
      await tester.tap(find.text('Şimdi değil'));
      await tester.pumpAndSettle();
      expect(participant.microphoneChanges, isEmpty);
      participant.values['meeting.microphone_request'] = 'request-2';
      room.changed();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mikrofonu aç'));
      await tester.pumpAndSettle();
      expect(participant.microphoneChanges, [true]);
      participant.microphone = false;
      participant.values['meeting.microphone_request'] = 'request-3';
      room.changed();
      await tester.pumpAndSettle();
      participant.values['meeting.microphone_locked'] = 'true';
      room.changed();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mikrofonu aç'));
      await tester.pumpAndSettle();
      expect(participant.microphoneChanges, [true]);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
