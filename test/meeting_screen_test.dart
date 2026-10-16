import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/home/home_screen.dart';
import 'package:v_meeting/meeting/meeting_api.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/members_screen.dart';
import 'package:v_meeting/meeting/meeting_screen.dart';
import 'package:v_meeting/meeting/widgets/meeting_participant.dart';

class _TestRoom extends ChangeNotifier implements Room {
  _TestRoom({this.local});
  final LocalParticipant? local;
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
      null;
  @override
  Future<LocalTrackPublication?> setMicrophoneEnabled(
    bool enabled, {
    AudioCaptureOptions? audioCaptureOptions,
  }) async {
    microphoneChanges.add(enabled);
    microphone = enabled;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ModerationApi extends MeetingApi {
  int closes = 0;
  VoidCallback? onClose;
  @override
  Future<List<MeetingChatMessage>> getRoomMessages(String roomId) async => [];
  @override
  Future<void> closeRoom(String roomId) async {
    closes++;
    onClose?.call();
    await Future<void>.delayed(Duration.zero);
  }
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

void main() {
  Future<void> openExitTest(
    WidgetTester tester,
    _TestRoom room, {
    bool host = false,
    _ModerationApi? api,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: localized(
          MeetingScreen(
            room: room,
            api: api ?? _ModerationApi(),
            credentials: RoomCredentials(
              roomId: '123-456-789',
              liveKitUrl: 'wss://example.test',
              token: 'test',
              participant: 'Test',
              isHost: host,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
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

  testWidgets('landscape phone stays swipeable and only taps reveal controls', (
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
    await tester.tapAt(const Offset(100, 100));
    expect(taps, 1);
    await tester.drag(pager, const Offset(850, 0));
    await tester.pumpAndSettle();
    expect(taps, 1);
    await tester.tapAt(const Offset(915, 200));
    expect(taps, 2);
    expect(tester.takeException(), isNull);
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
      await tester.pumpWidget(localized(MeetingScreen(room: _TestRoom())));
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
      await tester.tapAt(const Offset(915, 200));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.mic_rounded).hitTestable(), findsOneWidget);
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
              isHost: host,
              onMicrophoneChange: (_, locked, request) async =>
                  actions.add((locked, request)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await render(false, guest);
    expect(find.byTooltip('Mikrofon yönetimi'), findsNothing);
    await render(true, guest);
    expect(find.byTooltip('Mikrofon yönetimi'), findsOneWidget);
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

  testWidgets('locked microphone stops capture and cannot be opened locally', (
    tester,
  ) async {
    final participant = _TestLocal()..microphone = true;
    participant.values['meeting.microphone_locked'] = 'true';
    final room = _TestRoom(local: participant);
    await tester.pumpWidget(localized(MeetingScreen(room: room)));
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
      await tester.pumpWidget(localized(MeetingScreen(room: room)));
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
