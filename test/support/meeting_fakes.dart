/// Fakes and helpers shared by the meeting screen tests.
library;

import 'dart:collection';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/meeting_member.dart';
import 'package:v_meeting/meeting/meeting_platform.dart';
import 'package:v_meeting/meeting/meeting_screen.dart';
import 'package:v_meeting/meeting/widgets/meeting_participant.dart';

class TestRoom extends ChangeNotifier implements Room {
  TestRoom({this.local, this.connectSuccessfully = false, this.connectResult});
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

class TestLocal implements LocalParticipant {
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

class TestPublication extends Fake implements LocalTrackPublication {
  TestPublication(this.sid);
  @override
  final String sid;
  @override
  LocalTrack? get track => null;
  @override
  bool get muted => false;
}

class ModerationApi extends MeetingApi {
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
class WaitingApi extends ModerationApi {
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

class BusySharingApi extends ModerationApi {
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

const guestCredentials = RoomCredentials(
  roomId: '123-456-789',
  liveKitUrl: 'wss://example.test',
  token: 'test',
  participant: 'Test',
  isHost: false,
);

/// Avoids the real Bluetooth permission prompt, which never answers in tests.
/// Records background-support calls and avoids the real Bluetooth
/// permission prompt, which never answers in tests.
class TestPlatform extends MeetingPlatform {
  TestPlatform({this.connectCalls});

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
    meetingApiProvider.overrideWithValue(api ?? ModerationApi()),
    meetingPlatformProvider.overrideWithValue(platform ?? TestPlatform()),
  ],
  child: localized(
    MeetingScreen(
      credentials: credentials,
      skipJoiningScreen: skipJoiningScreen,
    ),
  ),
);

Future<void> openExitTest(
  WidgetTester tester,
  TestRoom room, {
  bool host = false,
  ModerationApi? api,
  TestPlatform? platform,
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
