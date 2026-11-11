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
import 'package:v_meeting/meeting/waiting_room_screen.dart';
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
  Future<JoinResult> joinRoom({
    required String roomId,
    required String name,
  }) async {
    joins++;
    return JoinAdmitted(
      RoomCredentials(
        roomId: roomId,
        liveKitUrl: 'wss://example.test',
        token: 'test',
        participant: name,
        isHost: false,
      ),
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

  final permissionChanges = <(String, Set<MeetingPermission>)>[];
  @override
  Future<void> setParticipantPermissions({
    required String roomId,
    required String identity,
    required Set<MeetingPermission> permissions,
  }) async => permissionChanges.add((identity, permissions));

  @override
  Future<void> closeRoom(String roomId) async {
    closes++;
    onClose?.call();
    await Future<void>.delayed(Duration.zero);
  }
}

/// A server whose room has a waiting room.
class _WaitingApi extends _ModerationApi {
  MeetingState state = const MeetingState(waitingRoom: true);
  final answers = <(String, bool)>[];
  final waitingRoomChanges = <bool>[];
  final cancels = <String>[];
  final statuses = <WaitingUpdate>[];

  @override
  Future<MeetingState> getMeetingState(String roomId) async => state;

  @override
  Future<MeetingState> setWaitingRoom(String roomId, bool on) async {
    waitingRoomChanges.add(on);
    return state = MeetingState(waitingRoom: on, waiting: state.waiting);
  }

  @override
  Future<MeetingState> answerWaiting(
    String roomId,
    String requestId, {
    required bool admit,
  }) async {
    answers.add((requestId, admit));
    return state = MeetingState(
      waitingRoom: state.waitingRoom,
      waiting: [
        for (final person in state.waiting)
          if (person.requestId != requestId) person,
      ],
    );
  }

  @override
  Future<WaitingUpdate> waitingStatus(String roomId, String requestId) async =>
      statuses.isEmpty
      ? const WaitingUpdate(WaitingStatus.waiting)
      : statuses.removeAt(0);

  @override
  Future<void> cancelWaiting(String roomId, String requestId) async =>
      cancels.add(requestId);
}

class _BusySharingApi extends _ModerationApi {
  @override
  Future<MeetingState> getMeetingState(String roomId) async =>
      const MeetingState(screenShareIdentity: 'someone-else');
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
        await tester.tap(find.text('Ses ve görüntü'));
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
      // A participant who may share, or the full admin.
      final local = _TestLocal()
        ..values['meeting.permissions'] = 'share_screen';
      final room = _TestRoom(local: local);
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

  test('you are on the main video only when alone', () {
    expect(selectMainMember([local]).id, local.id);
    expect(selectMainMember([local, remote]).id, remote.id);
    // Even when you are the one talking in a group.
    for (final speaker in [null, local.id]) {
      expect(
        selectMainMember([local, remote, third], speakerId: speaker).id,
        isNot(local.id),
      );
    }
  });

  test('the main video shows the focused speaker, else another person', () {
    const members = [local, remote, third];
    expect(selectMainMember(members, speakerId: third.id).id, third.id);
    expect(selectMainMember(members, speakerId: remote.id).id, remote.id);
    // A speaker who left.
    expect(selectMainMember(members, speakerId: fourth.id).id, remote.id);
  });

  group('speaker focus', () {
    final start = DateTime(2026);
    DateTime at(int milliseconds) =>
        start.add(Duration(milliseconds: milliseconds));
    const people = ['a', 'b', 'c'];

    test('starts on the first person and switches only after 1.5 s', () {
      final focus = SpeakerFocus();
      focus.update(participantIds: people, speakingIds: [], now: at(0));
      expect(focus.focusId, 'a');

      // b talks; a has been shown long enough, but b only just started.
      final wait = focus.update(
        participantIds: people,
        speakingIds: ['b'],
        now: at(5000),
      );
      expect(focus.focusId, 'a');
      expect(wait, const Duration(milliseconds: 1500));
      focus.update(participantIds: people, speakingIds: ['b'], now: at(6000));
      expect(focus.focusId, 'a');
      focus.update(participantIds: people, speakingIds: ['b'], now: at(6500));
      expect(focus.focusId, 'b');
    });

    test('a short sound or a break in speech does not switch', () {
      final focus = SpeakerFocus();
      focus.update(participantIds: people, speakingIds: [], now: at(0));
      focus.update(participantIds: people, speakingIds: ['b'], now: at(5000));
      focus.update(participantIds: people, speakingIds: [], now: at(5400));
      // b starts again: the 1.5 s count starts over.
      focus.update(participantIds: people, speakingIds: ['b'], now: at(5600));
      focus.update(participantIds: people, speakingIds: ['b'], now: at(6600));
      expect(focus.focusId, 'a');
      focus.update(participantIds: people, speakingIds: ['b'], now: at(7100));
      expect(focus.focusId, 'b');
    });

    test('the shown person stays while still talking and for 4 s', () {
      final focus = SpeakerFocus();
      focus.update(participantIds: people, speakingIds: ['a'], now: at(0));
      // a and b both talking, b louder: a stays.
      focus.update(
        participantIds: people,
        speakingIds: ['b', 'a'],
        now: at(1000),
      );
      focus.update(
        participantIds: people,
        speakingIds: ['b', 'a'],
        now: at(9000),
      );
      expect(focus.focusId, 'a');

      // After a switch to b, c must wait until b has been shown 4 s.
      focus.update(participantIds: people, speakingIds: ['b'], now: at(10000));
      focus.update(participantIds: people, speakingIds: ['b'], now: at(11500));
      expect(focus.focusId, 'b');
      final wait = focus.update(
        participantIds: people,
        speakingIds: ['c'],
        now: at(12000),
      );
      expect(wait, const Duration(milliseconds: 3500));
      focus.update(participantIds: people, speakingIds: ['c'], now: at(15500));
      expect(focus.focusId, 'c');
    });

    test('silence keeps the last speaker; one who leaves is replaced', () {
      final focus = SpeakerFocus();
      focus.update(participantIds: people, speakingIds: ['c'], now: at(0));
      focus.update(participantIds: people, speakingIds: [], now: at(60000));
      expect(focus.focusId, 'c');
      focus.update(participantIds: ['a', 'b'], speakingIds: [], now: at(61000));
      expect(focus.focusId, 'a');
    });
  });

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
        final main = selectMainMember(entries, speakerId: remote.id);
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
            mainMember: selectMainMember([local, shared]),
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
              mainMember: selectMainMember([local, shared]),
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
            mainMember: selectMainMember([local, shared]),
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
              mainMember: selectMainMember(value),
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

  testWidgets('desktop sidebar shows four people, the rest, and arrows page', (
    tester,
  ) async {
    await showMeeting(tester, const Size(1280, 800));
    final sidebar = find.byKey(const ValueKey('meeting-sidebar'));
    // Four previews and a fifth slot standing in for everyone else.
    expect(
      find.descendant(
        of: sidebar,
        matching: find.byType(MeetingParticipantTile),
      ),
      findsNWidgets(4),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('meeting-sidebar-count')))
          .data,
      '${members.length}',
    );
    final more = find.byKey(const ValueKey('meeting-sidebar-more'));
    expect(
      find.descendant(
        of: more,
        matching: find.text('+${members.length - 1 - 4} kişi daha'),
      ),
      findsOneWidget,
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
    // The extra slot opens the gallery.
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-remote-0')), findsNothing);
    expect(find.byType(MeetingParticipantTile), findsNWidgets(16));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop frame holds its buttons and a touchpad swipe pages', (
    tester,
  ) async {
    await showMeeting(tester, const Size(1280, 800));
    final main = find.byKey(const ValueKey('main-remote-0'));
    // The main tile; the floating panel's previews sit inside it too.
    final frame = tester.getRect(
      find
          .descendant(of: main, matching: find.byType(MeetingParticipantTile))
          .first,
    );
    final button = tester.getRect(
      find.byKey(const ValueKey('main-fullscreen')),
    );
    expect(frame.contains(button.topLeft), isTrue);
    expect(frame.contains(button.bottomRight), isTrue);
    expect(find.byKey(const ValueKey('meeting-page-dots')), findsOneWidget);

    final pager = find.byKey(const ValueKey('meeting-pages'));
    final swipe = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await swipe.panZoomStart(tester.getCenter(pager));
    await swipe.panZoomUpdate(
      tester.getCenter(pager),
      pan: const Offset(-600, 0),
    );
    await swipe.panZoomEnd();
    await tester.pumpAndSettle();
    expect(main, findsNothing);
    expect(find.byType(MeetingParticipantTile), findsNWidgets(16));
    expect(tester.takeException(), isNull);
  });

  testWidgets('people without video show their initials', (tester) async {
    await tester.pumpWidget(
      localized(
        const Scaffold(
          body: SizedBox(
            width: 320,
            height: 180,
            child: MeetingParticipantTile(member: fourth),
          ),
        ),
      ),
    );
    expect(find.text('D'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsNothing);
    expect(MemberAvatar.initials('Yusuf Enes Kaya'), 'YK');
    expect(MemberAvatar.initials('  '), '?');
  });

  testWidgets('the floating panel collapses, moves and keeps taps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: MeetingVideoLayout(
            // Five people besides the one on the main video.
            members: members.take(6).toList(),
            mainMember: members[1],
            onMainPageTap: () => taps++,
          ),
        ),
      ),
    );
    final panel = find.byKey(const ValueKey('meeting-sidebar'));
    final previews = find.descendant(
      of: panel,
      matching: find.byType(MeetingParticipantTile),
    );
    expect(previews, findsNWidgets(5));
    // It starts in the bottom-right corner.
    final start = tester.getRect(panel);
    expect(start.center.dx, greaterThan(640));
    expect(start.center.dy, greaterThan(400));

    // Collapse to one person and back; taps on it leave the controls alone.
    await tester.tap(find.byKey(const ValueKey('meeting-island-collapse')));
    await tester.pumpAndSettle();
    expect(previews, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('meeting-island-collapse')));
    await tester.pumpAndSettle();
    expect(previews, findsNWidgets(5));
    await tester.tap(previews.first);
    await tester.pumpAndSettle();
    expect(taps, 0);

    // Dragged most of the way to the top-left, it settles in that corner.
    await tester.drag(panel, const Offset(-900, -500));
    await tester.pumpAndSettle();
    final moved = tester.getRect(panel);
    expect(moved.center.dx, lessThan(640));
    expect(moved.center.dy, lessThan(400));
    expect(taps, 0);

    // The video beside it still toggles the controls.
    await tester.tapAt(const Offset(900, 600));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the floating panel resizes and keeps its 16:9 previews', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: MeetingVideoLayout(
            members: members.take(3).toList(),
            mainMember: members[1],
            onMainPageTap: () => taps++,
          ),
        ),
      ),
    );
    final preview = find.byKey(const ValueKey('preview-local'));
    final before = tester.getSize(preview);
    final handle = find.byKey(const ValueKey('meeting-island-resize'));
    // Anchored bottom-right, so the grip is top-left and grows outwards.
    await tester.drag(handle, const Offset(-120, -40));
    await tester.pumpAndSettle();
    final after = tester.getSize(preview);
    expect(after.width, greaterThan(before.width + 100));
    expect(after.width / after.height, closeTo(16 / 9, 0.01));
    expect(taps, 0);

    // The size outlives collapsing and expanding.
    await tester.tap(find.byKey(const ValueKey('meeting-island-collapse')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('meeting-island-collapse')));
    await tester.pumpAndSettle();
    expect(tester.getSize(preview), after);

    // It never grows past what fits in the frame.
    await tester.drag(handle, const Offset(-2000, -2000));
    await tester.pumpAndSettle();
    final panel = tester.getRect(find.byKey(const ValueKey('meeting-sidebar')));
    expect(panel.top, greaterThanOrEqualTo(0));
    expect(panel.left, greaterThanOrEqualTo(0));
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
    // The main video and the small floating one, showing you.
    expect(find.byType(MeetingParticipantTile), findsNWidgets(2));
    expect(find.byKey(const ValueKey('pip-local')), findsOneWidget);
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

  test('a single floating tile shows the sharer, else the last speaker', () {
    const sharing = MemberEntry(
      id: 'remote',
      name: 'Ayşe',
      isLocal: false,
      isMicEnabled: true,
      isScreenShare: true,
    );
    // During a screen share, the sharer's camera.
    expect(soloMember([local, remote, third], sharing)?.id, remote.id);
    // Otherwise whoever was on the main video before...
    expect(
      soloMember([local, remote, third], remote, previousMainId: third.id)?.id,
      third.id,
    );
    // ...else you, else anyone else.
    expect(soloMember([local, remote, third], remote)?.id, local.id);
    expect(soloMember([remote, third], remote)?.id, third.id);
    expect(soloMember([local], local), isNull);
  });

  testWidgets('the collapsed panel follows the previous main person', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final main = ValueNotifier<MemberEntry>(remote);
    addTearDown(main.dispose);
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: ValueListenableBuilder<MemberEntry>(
            valueListenable: main,
            builder: (context, value, _) => MeetingVideoLayout(
              members: const [local, remote, third, fourth],
              mainMember: value,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('meeting-island-collapse')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('preview-local')), findsOneWidget);
    main.value = third;
    await tester.pumpAndSettle();
    // Ayşe was on the main video before Can.
    expect(find.byKey(const ValueKey('preview-remote')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-local')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the phone video floats, resizes, goes away and comes back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    var taps = 0;
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: MeetingVideoLayout(
            members: const [local, remote, third],
            mainMember: remote,
            onMainPageTap: () => taps++,
          ),
        ),
      ),
    );
    final pip = find.byKey(const ValueKey('meeting-pip'));
    // One person, in the top-right corner, over the whole page.
    expect(
      find.descendant(of: pip, matching: find.byType(MeetingParticipantTile)),
      findsOneWidget,
    );
    final start = tester.getRect(pip);
    expect(start.center.dx, greaterThan(180));
    expect(start.center.dy, lessThan(360));
    await tester.tap(pip);
    expect(taps, 0);

    // Resizing keeps 16:9.
    await tester.drag(
      find.byKey(const ValueKey('meeting-island-resize')),
      const Offset(-60, 0),
    );
    await tester.pumpAndSettle();
    final bigger = tester.getSize(pip);
    expect(bigger.width, greaterThan(start.width + 40));
    expect(bigger.width / bigger.height, closeTo(16 / 9, 0.01));

    // Dragged to the top centre it fades, vibrates and goes away.
    final drag = await tester.startGesture(tester.getCenter(pip));
    // The first move starts the drag, the next one moves the video.
    await drag.moveBy(const Offset(-20, 0));
    await drag.moveBy(const Offset(-10, 0));
    await tester.pump();
    final target = find.byKey(const ValueKey('meeting-pip-dismiss-target'));
    expect(target, findsOneWidget);
    await drag.moveTo(Offset(180, tester.getSize(pip).height / 2 + 12));
    await tester.pump();
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
    await drag.up();
    await tester.pumpAndSettle();
    expect(pip, findsNothing);
    expect(target, findsNothing);

    // Pulling the tab high on the right edge brings it back, same size.
    final tab = find.byKey(const ValueKey('meeting-pip-restore'));
    expect(tester.getRect(tab).right, 360);
    expect(tester.getCenter(tab).dy, lessThan(720 * 0.3));
    await tester.drag(tab, const Offset(-60, 0));
    await tester.pumpAndSettle();
    expect(pip, findsOneWidget);
    expect(tester.getSize(pip), bigger);
    expect(find.byKey(const ValueKey('main-remote')), findsOneWidget);
    expect(taps, 0);
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
  testWidgets('microphone controls follow the viewer\'s permissions', (
    tester,
  ) async {
    const guest = MemberEntry(
      id: 'guest',
      identity: 'guest',
      name: 'Konuk',
      isLocal: false,
      isMicEnabled: true,
    );
    const lockedGuest = MemberEntry(
      id: 'guest',
      identity: 'guest',
      name: 'Konuk',
      isLocal: false,
      isMicEnabled: false,
      isMicrophoneLocked: true,
    );
    final actions = <(bool, bool)>[];
    Future<void> render(
      Set<MeetingPermission> viewer,
      MemberEntry entry,
    ) async {
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: MembersScreen(
              members: [local, entry],
              viewerPermissions: viewer,
              onMicrophoneChange: (_, locked, request) async =>
                  actions.add((locked, request)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openMenu() async {
      await tester.tap(find.byKey(const ValueKey('moderate-guest')));
      await tester.pumpAndSettle();
    }

    await render({}, guest);
    expect(find.byTooltip('Katılımcı işlemleri'), findsNothing);
    await render({MeetingPermission.shareScreen}, guest);
    expect(find.byTooltip('Katılımcı işlemleri'), findsNothing);

    // Muting alone: lock, but no unmute request.
    await render({MeetingPermission.muteOthers}, guest);
    await openMenu();
    expect(find.text('Mikrofonu açmasını iste'), findsNothing);
    await tester.tap(find.text('Mikrofonu kapat ve kilitle'));
    await tester.pumpAndSettle();
    expect(actions, [(true, false)]);

    // Asking alone: a request, but nothing for a locked microphone.
    await render({MeetingPermission.requestUnmute}, guest);
    await openMenu();
    expect(find.text('Mikrofonu kapat ve kilitle'), findsNothing);
    await tester.tap(find.text('Mikrofonu açmasını iste'));
    await tester.pumpAndSettle();
    expect(actions.last, (false, true));
    await render({MeetingPermission.requestUnmute}, lockedGuest);
    expect(find.byKey(const ValueKey('moderate-guest')), findsNothing);

    // Both: unlock and ask at once.
    await render({
      MeetingPermission.muteOthers,
      MeetingPermission.requestUnmute,
    }, lockedGuest);
    await openMenu();
    await tester.tap(find.text('Kilidi kaldır ve açmasını iste'));
    await tester.pumpAndSettle();
    expect(actions.last, (false, true));
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing someone asks first and spares the full admin', (
    tester,
  ) async {
    const guest = MemberEntry(
      id: 'guest',
      identity: 'guest',
      name: 'Konuk',
      isLocal: false,
      isMicEnabled: true,
    );
    const fullAdmin = MemberEntry(
      id: 'owner',
      identity: 'owner',
      name: 'Sahip Can',
      isLocal: false,
      isMicEnabled: true,
      role: MeetingRole.owner,
    );
    final removed = <String>[];
    Future<void> render(Set<MeetingPermission> viewer) async {
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: MembersScreen(
              members: const [local, guest, fullAdmin],
              viewerPermissions: viewer,
              onMicrophoneChange: (_, _, _) async {},
              onRemove: (member) async => removed.add(member.identity),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await render({MeetingPermission.muteOthers});
    await tester.tap(find.byKey(const ValueKey('moderate-guest')));
    await tester.pumpAndSettle();
    expect(find.text('Toplantıdan çıkar'), findsNothing);
    // Close that menu.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    // Removing alone is enough for the menu.
    await render({MeetingPermission.removeMembers});
    expect(find.byKey(const ValueKey('moderate-owner')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('moderate-guest')));
    await tester.pumpAndSettle();
    expect(find.text('Mikrofonu kapat ve kilitle'), findsNothing);
    await tester.tap(find.text('Toplantıdan çıkar'));
    await tester.pumpAndSettle();
    expect(find.text('Konuk toplantıdan çıkarılsın mı?'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(removed, isEmpty);

    await tester.tap(find.byKey(const ValueKey('moderate-guest')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toplantıdan çıkar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-remove')));
    await tester.pumpAndSettle();
    expect(removed, ['guest']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the members panel marks and protects the full admin', (
    tester,
  ) async {
    const fullAdmin = MemberEntry(
      id: 'owner',
      identity: 'owner',
      name: 'Sahip Can',
      isLocal: false,
      isMicEnabled: true,
      role: MeetingRole.owner,
    );
    const guest = MemberEntry(
      id: 'guest',
      identity: 'guest',
      name: 'Konuk',
      isLocal: false,
      isMicEnabled: true,
    );
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: MembersScreen(
            members: const [local, guest, fullAdmin],
            viewerPermissions: MeetingPermission.values.toSet(),
            onMicrophoneChange: (_, _, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('role-badge-owner')), findsOneWidget);
    expect(find.byKey(const ValueKey('moderate-owner')), findsNothing);
    expect(find.byKey(const ValueKey('moderate-guest')), findsOneWidget);
    // Roles and transfers live in the permissions window now.
    await tester.tap(find.byKey(const ValueKey('moderate-guest')));
    await tester.pumpAndSettle();
    expect(find.text('Tam yöneticiliği devret'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the end-meeting permission unlocks ending the meeting', (
    tester,
  ) async {
    final participant = _TestLocal();
    participant.values['meeting.permissions'] = 'end_meeting';
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

  testWidgets('only people who may give permissions see the menu entry', (
    tester,
  ) async {
    Future<void> openMenu() async {
      await tester.tap(find.byTooltip('Daha fazla'));
      await tester.pumpAndSettle();
    }

    final participant = _TestLocal()
      ..values['meeting.permissions'] = 'share_screen';
    await openExitTest(tester, _TestRoom(local: participant));
    await openMenu();
    expect(find.text('Yetkilendirmeler'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    final granter = _TestLocal()
      ..values['meeting.permissions'] = 'grant_permissions';
    await openExitTest(tester, _TestRoom(local: granter));
    await openMenu();
    await tester.tap(find.text('Yetkilendirmeler'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('permissions-search')), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  group('waiting room', () {
    const ece = WaitingPerson(requestId: 'r1', name: 'Ece');
    const can = WaitingPerson(requestId: 'r2', name: 'Can');
    final waitingButton = find.byKey(const ValueKey('waiting-room-button'));

    Future<void> poll(WidgetTester tester) async {
      // The room's state is fetched every two seconds.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    }

    /// Brings the dock back if it hid itself.
    Future<void> showControls(WidgetTester tester) async {
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final bar = find.byType(MeetingControlsBar);
      if (tester.getRect(bar).top >= screenHeight) {
        await tester.tapAt(const Offset(200, 150));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('newcomers are counted, announced and let in or turned away', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final api = _WaitingApi()
        ..state = const MeetingState(waitingRoom: true, waiting: [ece]);
      await openExitTest(tester, _TestRoom(), host: true, api: api);
      await poll(tester);
      expect(waitingButton, findsOneWidget);
      expect(
        find.descendant(of: waitingButton, matching: find.text('1')),
        findsOneWidget,
      );
      expect(find.text('Ece katılmak istiyor'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('arrival-r1-admit')));
      await tester.pumpAndSettle();
      expect(api.answers, [('r1', true)]);
      expect(find.text('Ece katılmak istiyor'), findsNothing);

      // Someone new arrives: one notice, and the list can turn them away.
      api.state = const MeetingState(waitingRoom: true, waiting: [can]);
      await poll(tester);
      expect(find.text('Can katılmak istiyor'), findsOneWidget);
      await showControls(tester);
      await tester.tap(waitingButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('r2-reject')));
      await tester.pumpAndSettle();
      expect(api.answers.last, ('r2', false));
      // Answered from the list, the notice goes too.
      expect(find.text('Can katılmak istiyor'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('notices can be switched off', (tester) async {
      SharedPreferences.setMockInitialValues({
        'meeting.notify_arrivals': false,
      });
      final api = _WaitingApi()
        ..state = const MeetingState(waitingRoom: true, waiting: [ece]);
      await openExitTest(tester, _TestRoom(), host: true, api: api);
      await poll(tester);
      expect(waitingButton, findsOneWidget);
      expect(find.text('Ece katılmak istiyor'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('people who may not let others in see none of it', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final api = _WaitingApi()
        ..state = const MeetingState(waitingRoom: true, waiting: [ece]);
      await openExitTest(tester, _TestRoom(), api: api);
      await poll(tester);
      expect(waitingButton, findsNothing);
      expect(find.text('Ece katılmak istiyor'), findsNothing);
      await showControls(tester);
      await tester.tap(find.byTooltip('Daha fazla'));
      await tester.pumpAndSettle();
      expect(find.text('Toplantı ayarları'), findsNothing);
      expect(find.text('Ses ve görüntü'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('the meeting settings turn the waiting room on and off', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final api = _WaitingApi()..state = const MeetingState();
      await openExitTest(tester, _TestRoom(), host: true, api: api);
      await poll(tester);
      expect(waitingButton, findsNothing);
      await showControls(tester);
      await tester.tap(find.byTooltip('Daha fazla'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toplantı ayarları'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('setting-waiting-room')));
      await tester.pumpAndSettle();
      expect(api.waitingRoomChanges, [true]);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('setting-waiting-room')),
            )
            .value,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('setting-notify-arrivals')));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('meeting.notify_arrivals'), isFalse);
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      expect(waitingButton, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    Future<_WaitingApi> openWaiting(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = _WaitingApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meetingRoomFactoryProvider.overrideWithValue(_TestRoom.new),
            meetingApiProvider.overrideWithValue(api),
            meetingPlatformProvider.overrideWithValue(_TestPlatform()),
          ],
          child: localized(
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const WaitingRoomScreen(
                        roomId: '123-456-789',
                        requestId: 'r9',
                        pollInterval: Duration(milliseconds: 100),
                      ),
                    ),
                  ),
                  child: const Text('join'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('join'));
      // The spinner never settles, so time is pumped instead: one frame to
      // start the route, then its transition.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('Yetkililerin sizi içeri alması bekleniyor'),
        findsOneWidget,
      );
      return api;
    }

    testWidgets('a turned-away guest goes back and is told', (tester) async {
      final api = await openWaiting(tester);
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        find.text('Yetkililerin sizi içeri alması bekleniyor'),
        findsOneWidget,
      );
      api.statuses.add(const WaitingUpdate(WaitingStatus.rejected));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.text('join'), findsOneWidget);
      expect(find.text('Toplantıya alınmadınız.'), findsOneWidget);
    });

    testWidgets('a guest can stop waiting', (tester) async {
      final api = await openWaiting(tester);
      await tester.tap(find.byKey(const ValueKey('waiting-room-cancel')));
      await tester.pumpAndSettle();
      expect(find.text('join'), findsOneWidget);
      expect(api.cancels, ['r9']);
    });

    testWidgets('a guest who is let in joins the meeting', (tester) async {
      final api = await openWaiting(tester);
      api.statuses.add(
        const WaitingUpdate(
          WaitingStatus.admitted,
          RoomCredentials(
            roomId: '123-456-789',
            liveKitUrl: 'wss://example.test',
            token: 'test',
            participant: 'Konuk',
            isHost: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.byType(MeetingScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });

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
