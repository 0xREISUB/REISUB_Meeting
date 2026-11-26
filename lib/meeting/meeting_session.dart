import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
// LiveKit has its own TimeoutException; the one used here is dart:async's.
import 'package:livekit_client/livekit_client.dart' hide TimeoutException;
import 'package:v_meeting/app/invite.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'package:v_meeting/l10n/localized_error.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/meeting/meeting_chat.dart';
import 'package:v_meeting/meeting/meeting_connection.dart';
import 'package:v_meeting/meeting/meeting_deadline.dart';
import 'package:v_meeting/meeting/meeting_entry_gate.dart';
import 'package:v_meeting/meeting/meeting_media.dart';
import 'package:v_meeting/meeting/meeting_member.dart';
import 'package:v_meeting/meeting/meeting_platform.dart';
import 'package:v_meeting/meeting/meeting_sharing.dart';
import 'package:v_meeting/meeting/room_realtime.dart';
import 'package:v_meeting/social/realtime.dart' show RealtimeConnector;
import 'package:v_meeting/settings/device_test_screen.dart';
import 'package:v_meeting/settings/media_preferences.dart';
import 'package:v_meeting/settings/meeting_preferences.dart';

part 'meeting_session_joining.dart';
part 'meeting_session_media.dart';
part 'meeting_session_moderation.dart';
part 'meeting_session_participants.dart';

enum MeetingExitReason {
  /// The user left.
  left,

  /// The host ended the meeting for everyone.
  endedByYou,

  /// The server closed the meeting or removed this participant.
  disconnected,
}

/// What the meeting logic needs from the screen: navigation, dialogs and
/// messages.
abstract interface class MeetingUi {
  void exitMeeting(MeetingExitReason reason);
  Future<bool> confirmUnmute();

  /// Shows an error or notice; [message] is localized with localizeError.
  void showMessage(Object message);

  /// Lets a desktop user choose a screen or window. Null means cancelled.
  Future<ScreenShareChoice?> pickDesktopScreen();
  NotificationText screenShareNotification();
  NotificationText meetingNotification();
}

/// A running in-meeting device test; see [MeetingSession.beginDeviceTest].
class MeetingDeviceTest {
  MeetingDeviceTest._({
    required this.camera,
    required this.wasEnabled,
    required this.participant,
  });

  final bool camera;
  final bool wasEnabled;
  final LocalParticipant participant;
  final controller = DeviceTestController();
}

/// The state and behaviour of one meeting, independent of widgets.
class MeetingSession extends ChangeNotifier {
  MeetingSession({
    required this.room,
    required this.api,
    required this.platform,
    required this._ui,
    RoomCredentials? credentials,
    bool showEntryGate = true,
    RealtimeConnector? realtimeConnector,
    DateTime Function()? clock,
  }) : _credentials = credentials,
       _deadline = MeetingDeadline(clock: clock),
       connection = MeetingConnection(room) {
    _deadline.setSecondsLeft(credentials?.secondsLeft);
    connection.addListener(_onConnectionChanged);
    room.addListener(_onRoomChanged);
    _roomEvents = room.createListener()
      ..on<ParticipantPermissionsUpdatedEvent>((event) {
        if (event.participant is LocalParticipant) {
          _onLocalPermissionsChanged(event.permissions);
        }
      });
    entryGate = MeetingEntryGate(
      enabled: showEntryGate && credentials != null,
      connection: connection,
      isConnecting: () => isConnecting,
      mainRemoteParticipant: _mainRemoteParticipant,
    )..addListener(notifyListeners);
    if (kDebugMode) {
      _videoStatsTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _logVideoStats(),
      );
    }
    final roomId = credentials?.roomId;
    if (roomId != null) {
      // Changes arrive over it the moment they happen; the polls only run
      // slowly beside it.
      final realtime = RoomRealtime(
        roomId: roomId,
        connector: realtimeConnector,
      )..start();
      this.realtime = realtime;
      sharing = MeetingSharing(roomId: roomId, api: api, realtime: realtime)
        ..addListener(_onSharingChanged)
        ..start();
      chat = MeetingChatController(roomId: roomId, api: api, realtime: realtime)
        ..addListener(notifyListeners)
        ..start();
    }
  }

  static const connectTimeout = Duration(seconds: 10);
  static const micLockAttribute = 'meeting.microphone_locked';
  static const micRequestAttribute = 'meeting.microphone_request';

  final Room room;
  final MeetingApi api;
  final MeetingPlatform platform;
  final MeetingConnection connection;
  final MeetingUi _ui;
  final MeetingDeadline _deadline;
  late final EventsListener<RoomEvent> _roomEvents;
  late final MeetingEntryGate entryGate;
  MeetingSharing? sharing;
  MeetingChatController? chat;
  RoomRealtime? realtime;
  final media = MeetingMedia();

  RoomCredentials? _credentials;
  RoomCredentials? get credentials => _credentials;
  static const roleAttribute = 'meeting.role';

  /// This participant's live role. The server updates the LiveKit attribute
  /// on every change; before joining, the role from the join response is used.
  MeetingRole get role {
    final value = room.localParticipant?.attributes[roleAttribute];
    return value == null
        ? (_credentials?.initialRole ?? MeetingRole.participant)
        : MeetingRole.parse(value);
  }

  bool get isOwner => role == MeetingRole.owner;
  MeetingRole? _announcedRole;

  static const permissionsAttribute = 'meeting.permissions';

  /// A participant's profile picture path, signed into their join token.
  static const avatarAttribute = 'meeting.avatar_url';

  /// What this participant may do. The full admin may do everything; for
  /// anyone else the server keeps a LiveKit attribute up to date, and the
  /// join response is used until it arrives.
  Set<MeetingPermission> get permissions {
    if (isOwner) return MeetingPermission.values.toSet();
    final value = room.localParticipant?.attributes[permissionsAttribute];
    return value == null
        ? (_credentials?.permissions ?? const {})
        : MeetingPermission.parseList(value);
  }

  bool can(MeetingPermission permission) => permissions.contains(permission);

  bool isConnecting = true;
  bool isRejoining = false;
  bool _isJoining = false;
  bool get isJoining => _isJoining;
  bool endingRoom = false;

  bool isMicEnabled = true;
  bool isCameraEnabled = true;
  bool mirrorCamera = true;
  bool _initialPreferencesLoaded = false;

  Object? connectionError;
  Object? microphoneError;
  Object? cameraError;

  String? mainMemberId;
  final _speakerFocus = SpeakerFocus();
  Timer? _speakerFocusTimer;

  bool changingScreenShare = false;
  bool _ownsScreenShare = false;
  bool _screenServiceRunning = false;

  MeetingDeviceTest? _deviceTest;
  bool _applyingMicLock = false;
  bool _unmuteDialogOpen = false;
  String? _lastUnmuteRequest;

  Timer? _videoStatsTimer;
  bool _readingVideoStats = false;

  bool _leaving = false;
  bool _disposed = false;

  /// True once the meeting is being left or the session was disposed; async
  /// work must not continue after that.
  bool get _inactive => _disposed || _leaving;
  bool _backgroundServiceStarted = false;
  bool _cameraPausedInBackground = false;

  /// Tells listeners the session changed; for its parts, which as
  /// extensions may not call notifyListeners themselves.
  void _changed() => notifyListeners();

  bool get microphoneLocked =>
      room.localParticipant?.attributes[micLockAttribute] == 'true';

  // ---------------------------------------------------------------------------
  // Room and connection events

  void _onConnectionChanged() {
    if (_inactive) return;
    if (connection.phase == MeetingConnectionPhase.disconnected &&
        !connection.canRejoin) {
      leave(
        endingRoom
            ? MeetingExitReason.endedByYou
            : MeetingExitReason.disconnected,
      );
      return;
    }
    if (!connection.isConnected) {
      mainMemberId = null;
      _speakerFocusTimer?.cancel();
      _speakerFocus.reset();
    }
    developer.log(
      'phase=${connection.phase.name} reason=${connection.disconnectReason?.name} '
      'quality=${connection.quality.name} room=${_credentials?.roomId}',
      name: 'meeting.connection',
    );
    notifyListeners();
  }

  void _onRoomChanged() {
    if (_inactive) return;
    _announceRoleChange();
    _handleMicrophonePolicy();
    if (_ownsScreenShare && !changingScreenShare && !_localScreenSharing) {
      unawaited(stopScreenShare());
    }
    _updateSpeakerFocus();
    mainMemberId = mainMember(members()).id;
    notifyListeners();
  }

  /// Moves the main video to whoever has been speaking, once they have
  /// spoken long enough; see [SpeakerFocus].
  void _updateSpeakerFocus() {
    _speakerFocusTimer?.cancel();
    final wait = _speakerFocus.update(
      participantIds: [for (final p in room.remoteParticipants.values) p.sid],
      speakingIds: [
        for (final p in room.activeSpeakers)
          if (p is! LocalParticipant) p.sid,
      ],
      now: DateTime.now(),
    );
    if (wait == null) return;
    // Nothing else may happen while they keep talking, so check again then.
    _speakerFocusTimer = Timer(wait, () {
      if (_inactive) return;
      _updateSpeakerFocus();
      mainMemberId = mainMember(members()).id;
      notifyListeners();
    });
  }

  void _onSharingChanged() {
    if (_inactive) return;
    final state = sharing!.state;
    // The server's count is the truth; it also lifts or adds a limit.
    if (sharing!.loaded) {
      _deadline.setSecondsLeft(state.secondsLeft, clear: true);
    }
    if (_ownsScreenShare &&
        !changingScreenShare &&
        state.screenShareIdentity != room.localParticipant?.identity) {
      if (!can(MeetingPermission.shareScreen)) {
        _stopRevokedScreenShare();
      } else {
        unawaited(stopScreenShare());
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _speakerFocusTimer?.cancel();
    unawaited(_deviceTest?.controller.close());
    _videoStatsTimer?.cancel();
    unawaited(_stopScreenService());
    entryGate
      ..removeListener(notifyListeners)
      ..dispose();
    sharing
      ?..removeListener(_onSharingChanged)
      ..dispose();
    connection
      ..removeListener(_onConnectionChanged)
      ..dispose();
    room.removeListener(_onRoomChanged);
    unawaited(_roomEvents.dispose());
    chat
      ?..removeListener(notifyListeners)
      ..dispose();
    realtime?.dispose();
    unawaited(room.dispose());
    super.dispose();
  }
}

/// The participant's track from [source], once it carries video.
VideoTrack? _videoTrack(
  Participant participant, {
  TrackSource source = TrackSource.camera,
}) {
  final publication = participant.getTrackPublicationBySource(source);
  final track = publication?.track;
  return track is VideoTrack && !publication!.muted ? track : null;
}

/// Whether the participant shares a screen now.
bool _hasScreenShare(Participant participant) {
  final publication = participant.getTrackPublicationBySource(
    TrackSource.screenShareVideo,
  );
  return publication != null && !publication.muted;
}
