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
import 'package:v_meeting/meeting/meeting_entry_gate.dart';
import 'package:v_meeting/meeting/meeting_media.dart';
import 'package:v_meeting/meeting/meeting_member.dart';
import 'package:v_meeting/meeting/meeting_platform.dart';
import 'package:v_meeting/meeting/meeting_sharing.dart';
import 'package:v_meeting/settings/device_test_screen.dart';
import 'package:v_meeting/settings/media_preferences.dart';
import 'package:v_meeting/settings/meeting_preferences.dart';

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
  }) : _credentials = credentials,
       connection = MeetingConnection(room) {
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
      sharing = MeetingSharing(roomId: roomId, api: api)
        ..addListener(_onSharingChanged)
        ..start();
      chat = MeetingChatController(roomId: roomId, api: api)
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
  late final EventsListener<RoomEvent> _roomEvents;
  late final MeetingEntryGate entryGate;
  MeetingSharing? sharing;
  MeetingChatController? chat;
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

  bool get canModerate => role.canModerate;
  bool get isOwner => role == MeetingRole.owner;
  MeetingRole? _announcedRole;

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

  bool get microphoneLocked =>
      room.localParticipant?.attributes[micLockAttribute] == 'true';

  // ---------------------------------------------------------------------------
  // Joining

  Future<void> connect() async {
    if (_isJoining || _inactive) return;
    final credentials = _credentials;
    if (credentials == null) {
      isConnecting = false;
      connectionError = const AppException.localized(
        AppError.missingMeetingDetails,
      );
      notifyListeners();
      connection.fail(
        const AppException.localized(AppError.missingMeetingDetails),
      );
      return;
    }

    if (kIsWeb &&
        Uri.base.scheme != 'https' &&
        Uri.base.host != 'localhost' &&
        Uri.base.host != '127.0.0.1') {
      isConnecting = false;
      connectionError = const AppException.localized(
        AppError.mediaRequiresHttps,
      );
      notifyListeners();
      return;
    }

    _isJoining = true;
    connection.startConnecting();
    try {
      final mediaPreferences = await MediaPreferences.load();
      final meetingPreferences = await MeetingPreferences.load();
      media.microphoneId = mediaPreferences.microphoneId;
      media.cameraId = mediaPreferences.cameraId;
      if (!_initialPreferencesLoaded) {
        isMicEnabled = meetingPreferences.startWithMicrophone;
        isCameraEnabled = meetingPreferences.startWithCamera;
        _initialPreferencesLoaded = true;
      }
      mirrorCamera = meetingPreferences.mirrorCamera;
      if (_inactive) return;
      await platform.requestMeetingPermissions(camera: isCameraEnabled);
      if (_inactive) return;
      // After the permissions, so that Android lets the service keep the
      // microphone running in the background.
      if (!_backgroundServiceStarted) {
        _backgroundServiceStarted = true;
        await platform.startMeetingService(_ui.meetingNotification());
      }
      if (_inactive) return;
      await room
          .connect(credentials.liveKitUrl, credentials.token)
          .timeout(connectTimeout);
      if (_inactive) return;
      connection.markConnected();
      microphoneError = null;
      cameraError = null;
      // A microphone permission/device failure must not prevent video startup.
      try {
        final startMic = isMicEnabled && !microphoneLocked;
        final participant = room.localParticipant;
        if (participant != null) {
          await media.setMicrophoneEnabled(participant, startMic);
        }
        isMicEnabled = startMic;
      } catch (error) {
        isMicEnabled = false;
        microphoneError = error;
      }
      if (_inactive) return;
      try {
        final participant = room.localParticipant;
        if (participant != null) {
          await media.setCameraEnabled(participant, isCameraEnabled);
        }
      } catch (error) {
        isCameraEnabled = false;
        cameraError = error;
      }
      if (_inactive) return;
      isConnecting = false;
      connectionError = null;
      notifyListeners();
    } catch (error) {
      var failure = error;
      if (error is TimeoutException) {
        // Stop the attempt that is still running in the background.
        failure = const AppException.localized(
          AppError.meetingServerUnavailable,
        );
        try {
          await room.disconnect();
        } catch (_) {}
      }
      if (!_inactive) {
        isConnecting = false;
        notifyListeners();
        connection.fail(failure);
      }
    } finally {
      _isJoining = false;
      if (!_inactive) _handleMicrophonePolicy();
    }
  }

  /// Joins again with a fresh token, which also recovers expired credentials
  /// and stale server sessions.
  Future<void> rejoin() async {
    final previous = _credentials;
    if (previous == null || isRejoining || _isJoining) return;
    entryGate.begin();
    isRejoining = true;
    isConnecting = true;
    connectionError = null;
    notifyListeners();
    connection.startConnecting();
    try {
      await room.disconnect();
      if (_disposed) return;
      connection.startConnecting();
      _credentials = await api.joinRoom(
        roomId: previous.roomId,
        name: previous.participant,
      );
      if (_disposed) return;
      await connect();
    } catch (error) {
      // An expired account continues as a guest on the next attempt.
      if (!_disposed) connection.fail(error);
    } finally {
      if (!_disposed) {
        isRejoining = false;
        isConnecting = false;
        notifyListeners();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Leaving

  /// Releases meeting resources and asks the screen to navigate away.
  void leave(MeetingExitReason reason) {
    if (_inactive) return;
    _leaving = true;
    unawaited(_deviceTest?.controller.close());
    entryGate.stop();
    if (_ownsScreenShare) {
      final identity = room.localParticipant?.identity;
      if (identity != null) {
        unawaited(sharing?.release(identity).catchError((Object _) {}));
      }
      _ownsScreenShare = false;
    }
    unawaited(_stopScreenService());
    final roomId = _credentials?.roomId;
    if (reason == MeetingExitReason.left && roomId != null) {
      // Lets the server hand ownership on at once. If this fails, LiveKit's
      // disconnect webhook does the same a little later.
      unawaited(api.leaveRoom(roomId).catchError((Object _) {}));
    }
    unawaited(room.disconnect());
    _ui.exitMeeting(reason);
  }

  Future<void> closeRoomForEveryone() async {
    final credentials = _credentials;
    if (_inactive || credentials == null || !canModerate || endingRoom) {
      return;
    }
    endingRoom = true;
    notifyListeners();
    try {
      await api.closeRoom(credentials.roomId);
      if (!_inactive) leave(MeetingExitReason.endedByYou);
    } catch (error) {
      if (!_inactive) _ui.showMessage(error);
    } finally {
      if (!_inactive) {
        endingRoom = false;
        notifyListeners();
      }
    }
  }

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
    if (!connection.isConnected) mainMemberId = null;
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
    mainMemberId = mainMember(members()).id;
    notifyListeners();
  }

  void _onSharingChanged() {
    if (_inactive) return;
    final state = sharing!.state;
    if (_ownsScreenShare &&
        !changingScreenShare &&
        state.screenShareIdentity != room.localParticipant?.identity) {
      if (!canModerate && !state.allowParticipantScreenShare) {
        _stopRevokedScreenShare();
      } else {
        unawaited(stopScreenShare());
      }
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Participants

  /// Everyone in the meeting, starting with this device. [localName] is shown
  /// when the meeting has no participant name.
  List<MemberEntry> members({String localName = ''}) {
    final local = room.localParticipant;
    return [
      MemberEntry(
        id: local?.sid ?? 'local',
        name: _credentials?.participant ?? localName,
        identity: local?.identity ?? '',
        isMicrophoneLocked: microphoneLocked,
        isLocal: true,
        role: role,
        mirrorCamera: mirrorCamera,
        isMicEnabled: local?.isMicrophoneEnabled() ?? isMicEnabled,
        isSpeaking: local?.isSpeaking ?? false,
        videoTrack: local == null ? null : _videoTrack(local),
        isScreenSharing: local != null && _hasScreenShare(local),
        screenShareTrack: local == null
            ? null
            : _videoTrack(local, source: TrackSource.screenShareVideo),
      ),
      if (connection.isConnected)
        ...room.remoteParticipants.values.map(
          (participant) => MemberEntry(
            id: participant.sid,
            identity: participant.identity,
            isMicrophoneLocked:
                participant.attributes[micLockAttribute] == 'true',
            name: participant.name.isEmpty
                ? participant.identity
                : participant.name,
            isLocal: false,
            role: MeetingRole.parse(participant.attributes[roleAttribute]),
            isMicEnabled: participant.isMicrophoneEnabled(),
            isSpeaking: participant.isSpeaking,
            videoTrack: _videoTrack(participant),
            isScreenSharing: _hasScreenShare(participant),
            screenShareTrack: _videoTrack(
              participant,
              source: TrackSource.screenShareVideo,
            ),
          ),
        ),
    ];
  }

  MemberEntry mainMember(List<MemberEntry> members) => selectMainMember(
    members,
    activeSpeakerIds: room.activeSpeakers.map((p) => p.sid).toList(),
    previousSpeakerId: mainMemberId,
  );

  RemoteParticipant? _mainRemoteParticipant() {
    final participants = room.remoteParticipants.values;
    if (participants.isEmpty) return null;
    final main = mainMember(members());
    for (final participant in participants) {
      if (participant.sid == main.id) return participant;
    }
    return participants.first;
  }

  static VideoTrack? _videoTrack(
    Participant participant, {
    TrackSource source = TrackSource.camera,
  }) {
    final publication = participant.getTrackPublicationBySource(source);
    final track = publication?.track;
    return track is VideoTrack && !publication!.muted ? track : null;
  }

  static bool _hasScreenShare(Participant participant) {
    final publication = participant.getTrackPublicationBySource(
      TrackSource.screenShareVideo,
    );
    return publication != null && !publication.muted;
  }

  Future<void> moderateMicrophone(
    MemberEntry member,
    bool locked,
    bool requestUnmute,
  ) async {
    final credentials = _credentials;
    if (credentials == null || !canModerateMember(role, member)) return;
    await api.setParticipantMicrophone(
      roomId: credentials.roomId,
      identity: member.identity,
      locked: locked,
      requestUnmute: requestUnmute,
    );
  }

  /// Owners only. Throws the server's error so the caller can show it.
  Future<void> changeRole(MemberEntry member, MeetingRole newRole) async {
    final credentials = _credentials;
    if (credentials == null || !isOwner || member.identity.isEmpty) return;
    await api.setParticipantRole(
      roomId: credentials.roomId,
      identity: member.identity,
      role: newRole,
    );
  }

  /// Owners only: [member] becomes owner and this user becomes an admin.
  Future<void> transferOwnership(MemberEntry member) async {
    final credentials = _credentials;
    if (credentials == null || !isOwner || member.isLocal) return;
    await api.transferOwnership(credentials.roomId, member.identity);
  }

  /// A link that opens this meeting's invite page.
  Future<String?> inviteLink() async {
    final credentials = _credentials;
    if (credentials == null) return null;
    final fromServer = credentials.inviteUrl;
    if (fromServer != null && fromServer.isNotEmpty) return fromServer;
    return fallbackInviteLink(
      credentials.roomId,
      serverUrl: await ServerConfig.readUrl(),
    );
  }

  /// Whether leaving now hands full admin to someone else.
  bool get isLastOwner =>
      isOwner &&
      !room.remoteParticipants.values.any(
        (p) => p.attributes[roleAttribute] == MeetingRole.owner.name,
      );

  /// Tells the user when the server gives them a higher role, e.g. after the
  /// last full admin left.
  void _announceRoleChange() {
    if (room.localParticipant?.attributes[roleAttribute] == null) return;
    final current = role;
    final previous = _announcedRole;
    _announcedRole = current;
    if (previous == null || previous == current) return;
    if (current == MeetingRole.owner) {
      _ui.showMessage(const AppException.localized(AppError.nowOwner));
    } else if (current == MeetingRole.moderator &&
        previous == MeetingRole.participant) {
      _ui.showMessage(const AppException.localized(AppError.nowModerator));
    }
  }

  // ---------------------------------------------------------------------------
  // Microphone and camera

  /// Enforces a host lock and asks for consent when the host requests unmute.
  void _handleMicrophonePolicy() {
    if (_leaving) return;
    final local = room.localParticipant;
    if (local == null) return;
    if (microphoneLocked) {
      isMicEnabled = false;
      if (local.isMicrophoneEnabled() && !_applyingMicLock) {
        unawaited(_disableLockedMicrophone(local));
      }
      return;
    }
    if (!isConnecting) isMicEnabled = local.isMicrophoneEnabled();
    if (_deviceTest != null) return;
    final request = local.attributes[micRequestAttribute];
    if (isConnecting ||
        request == null ||
        request.isEmpty ||
        request == _lastUnmuteRequest ||
        _unmuteDialogOpen) {
      return;
    }
    _lastUnmuteRequest = request;
    _unmuteDialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_inactive || microphoneLocked) {
        _unmuteDialogOpen = false;
        return;
      }
      unawaited(_confirmUnmute());
    });
  }

  Future<void> _disableLockedMicrophone(LocalParticipant local) async {
    _applyingMicLock = true;
    try {
      await local.setMicrophoneEnabled(false);
    } catch (error) {
      if (!_disposed) {
        connectionError = AppException.localized(
          AppError.microphoneDisableFailed,
          details: error,
        );
        notifyListeners();
      }
    } finally {
      _applyingMicLock = false;
    }
  }

  Future<void> _confirmUnmute() async {
    try {
      final accepted = await _ui.confirmUnmute();
      if (!accepted || _inactive || microphoneLocked) return;
      final local = room.localParticipant;
      if (local == null) return;
      await media.setMicrophoneEnabled(local, true);
      if (microphoneLocked) {
        await local.setMicrophoneEnabled(false);
        return;
      }
      if (!_disposed) {
        isMicEnabled = true;
        microphoneError = null;
        notifyListeners();
      }
    } catch (error) {
      if (!_disposed) {
        microphoneError = error;
        notifyListeners();
      }
    } finally {
      _unmuteDialogOpen = false;
    }
  }

  /// Does nothing while the host has locked the microphone.
  Future<void> toggleMicrophone() async {
    if (microphoneLocked) return;
    final enabled = !isMicEnabled;
    try {
      final participant = room.localParticipant;
      if (participant == null) return;
      await media.setMicrophoneEnabled(participant, enabled);
      if (enabled && microphoneLocked) {
        await participant.setMicrophoneEnabled(false);
        return;
      }
      if (!_disposed) {
        isMicEnabled = enabled;
        microphoneError = null;
        notifyListeners();
      }
    } catch (error) {
      if (!_disposed) {
        microphoneError = error;
        notifyListeners();
      }
    }
  }

  Future<void> toggleCamera() async {
    final enabled = !isCameraEnabled;
    try {
      final participant = room.localParticipant;
      if (participant == null) return;
      await media.setCameraEnabled(participant, enabled);
      if (!_disposed) {
        isCameraEnabled = enabled;
        cameraError = null;
        notifyListeners();
      }
    } catch (error) {
      if (!_disposed) {
        cameraError = error;
        notifyListeners();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Background

  bool _cameraPausedInBackground = false;

  /// Android blocks the camera in the background and the picture would
  /// freeze, so the camera is turned off until the app returns. Audio keeps
  /// running.
  Future<void> pauseCameraForBackground() async {
    final participant = room.localParticipant;
    if (_inactive ||
        !isCameraEnabled ||
        _cameraPausedInBackground ||
        participant == null ||
        !connection.isConnected) {
      return;
    }
    _cameraPausedInBackground = true;
    try {
      await media.setCameraEnabled(participant, false);
    } catch (_) {
      // The camera is released anyway when the app is in the background.
    }
  }

  Future<void> resumeCameraFromBackground() async {
    if (!_cameraPausedInBackground) return;
    _cameraPausedInBackground = false;
    final participant = room.localParticipant;
    if (_inactive || participant == null || !isCameraEnabled) return;
    try {
      await media.setCameraEnabled(participant, true);
    } catch (error) {
      if (!_disposed) {
        isCameraEnabled = false;
        cameraError = error;
        notifyListeners();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Device tests inside the meeting

  /// Starts a device test, or returns null when one cannot run now. Call
  /// [releaseDeviceForTest] next and always finish with [endDeviceTest].
  MeetingDeviceTest? beginDeviceTest({required bool camera}) {
    final participant = room.localParticipant;
    if (_deviceTest != null || participant == null || !connection.isConnected) {
      return null;
    }
    return _deviceTest = MeetingDeviceTest._(
      camera: camera,
      wasEnabled: camera ? isCameraEnabled : isMicEnabled,
      participant: participant,
    );
  }

  /// Frees the device so the test screen can open it.
  Future<void> releaseDeviceForTest(MeetingDeviceTest test) async {
    await media.releaseDevice(test.participant, camera: test.camera);
    if (_inactive) return;
    if (test.camera) {
      isCameraEnabled = false;
    } else {
      isMicEnabled = false;
    }
    notifyListeners();
  }

  /// Restores the device with the selection made during the test.
  Future<void> endDeviceTest(MeetingDeviceTest test) async {
    final participant = test.participant;
    try {
      await test.controller.close();
      if (_inactive || !identical(participant, room.localParticipant)) return;
      final preferences = await MediaPreferences.load();
      if (_inactive || !connection.isConnected) return;
      if (test.camera) {
        media.cameraId = preferences.cameraId;
        await media.setCameraEnabled(participant, test.wasEnabled);
        if (!_disposed) {
          isCameraEnabled = test.wasEnabled;
          cameraError = null;
          notifyListeners();
        }
      } else {
        media.microphoneId = preferences.microphoneId;
        final enable = test.wasEnabled && !microphoneLocked;
        await media.setMicrophoneEnabled(participant, enable);
        if (microphoneLocked && enable) {
          await participant.setMicrophoneEnabled(false);
        }
        if (!_disposed) {
          isMicEnabled = enable && !microphoneLocked;
          microphoneError = null;
          notifyListeners();
        }
      }
    } catch (error) {
      if (!_inactive) {
        if (test.camera) {
          isCameraEnabled = false;
          cameraError = error;
        } else {
          isMicEnabled = false;
          microphoneError = error;
        }
        notifyListeners();
      }
    } finally {
      _deviceTest = null;
      if (!_inactive) _handleMicrophonePolicy();
    }
  }

  // ---------------------------------------------------------------------------
  // Screen sharing

  bool get _localScreenSharing {
    final local = room.localParticipant;
    return local != null && _hasScreenShare(local);
  }

  bool get isSharingScreen => _localScreenSharing || _ownsScreenShare;

  /// Whether the host allows this participant to share at all.
  bool get screenSharingAllowed =>
      canModerate || (sharing?.state.allowParticipantScreenShare ?? false);

  bool get canToggleScreenShare {
    final state = sharing?.state;
    if (changingScreenShare || !connection.isConnected) return false;
    if (isSharingScreen) return true;
    // Only one person can share at a time, the host included.
    if (screenShareBusy) return false;
    return canModerate ||
        (sharing?.loaded == true && state!.allowParticipantScreenShare);
  }

  /// Another participant holds the room's single screen share.
  bool get screenShareBusy {
    final holder = sharing?.state.screenShareIdentity ?? '';
    if (holder.isNotEmpty && holder != room.localParticipant?.identity) {
      return true;
    }
    return connection.isConnected &&
        room.remoteParticipants.values.any(_hasScreenShare);
  }

  static bool _maySharescreen(ParticipantPermissions permissions) =>
      permissions.canPublish &&
      (permissions.canPublishSources.isEmpty ||
          permissions.canPublishSources.any((s) => s.name == 'SCREEN_SHARE'));

  /// The server revokes the permission when the host turns sharing off; stop
  /// at once instead of waiting for the next state poll.
  void _onLocalPermissionsChanged(ParticipantPermissions permissions) {
    if (_inactive || changingScreenShare || !isSharingScreen) return;
    if (_maySharescreen(permissions)) return;
    _stopRevokedScreenShare();
  }

  void _stopRevokedScreenShare() {
    _ui.showMessage(
      const AppException.localized(AppError.screenShareStoppedByHost),
    );
    unawaited(stopScreenShare());
  }

  Future<void> _stopScreenService() async {
    if (!_screenServiceRunning) return;
    _screenServiceRunning = false;
    await platform.stopScreenShareService();
  }

  Future<void> stopScreenShare() async {
    if (changingScreenShare) return;
    changingScreenShare = true;
    notifyListeners();
    final identity = room.localParticipant?.identity;
    try {
      await room.localParticipant?.setScreenShareEnabled(false);
      _ownsScreenShare = false;
      await _stopScreenService();
      if (identity != null) await sharing?.release(identity);
    } catch (error) {
      if (!_inactive) _ui.showMessage(error);
    } finally {
      if (!_disposed) {
        changingScreenShare = false;
        notifyListeners();
      }
    }
  }

  Future<void> toggleScreenShare() async {
    if (changingScreenShare || _leaving) return;
    if (isSharingScreen) {
      await stopScreenShare();
      return;
    }
    final local = room.localParticipant;
    final sharing = this.sharing;
    if (local == null || sharing == null || !connection.isConnected) return;
    changingScreenShare = true;
    notifyListeners();
    var reserved = false;
    try {
      ScreenShareChoice? choice;
      if (platform.isDesktop) {
        choice = await _ui.pickDesktopScreen();
        if (choice == null || _inactive) return;
      } else if (!await platform.requestScreenCapturePermission() ||
          _inactive) {
        return;
      }
      // The server grants one screen share at a time.
      await sharing.acquire(local.identity);
      reserved = true;
      if (_inactive) return;
      // Wait for the permission update on the signaling channel as well as HTTP.
      for (var i = 0; i < 30; i++) {
        if (_maySharescreen(local.permissions)) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (_inactive) return;
      }
      _screenServiceRunning = await platform.startScreenShareService(
        _ui.screenShareNotification(),
      );
      if (_inactive) return;
      // Browsers offer their own "share audio" choice.
      final shareAudio = choice?.shareAudio ?? kIsWeb;
      final publication = await local.setScreenShareEnabled(
        true,
        captureScreenAudio: shareAudio,
        screenShareCaptureOptions: ScreenShareCaptureOptions(
          sourceId: choice?.sourceId,
          maxFrameRate: 15,
          captureScreenAudio: shareAudio,
        ),
      );
      if (publication == null) {
        throw const MeetingApiException.localized(
          AppError.screenShareStartFailed,
        );
      }
      if (_inactive) {
        await local.setScreenShareEnabled(false);
        return;
      }
      _ownsScreenShare = true;
      reserved = false;
    } catch (error) {
      if (!_inactive) _ui.showMessage(error);
    } finally {
      if (reserved) {
        try {
          await local.setScreenShareEnabled(false);
        } catch (_) {}
        try {
          await sharing.release(local.identity);
        } catch (_) {}
      }
      if (!_ownsScreenShare) await _stopScreenService();
      if (!_disposed) {
        changingScreenShare = false;
        notifyListeners();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Diagnostics

  Future<void> _logVideoStats() async {
    if (!connection.isConnected || _readingVideoStats) return;
    _readingVideoStats = true;
    try {
      for (final participant in room.remoteParticipants.values.toList()) {
        final track = _videoTrack(participant);
        if (track is! RemoteVideoTrack) continue;
        final stats = await track.getReceiverStats();
        if (_disposed || stats == null) continue;
        // Never log access tokens or signaling URLs.
        developer.log(
          'room=${_credentials?.roomId} participantSid=${participant.sid} '
          'codec=${stats.mimeType} decoder=${stats.decoderImplementation} '
          'size=${stats.frameWidth}x${stats.frameHeight} fps=${stats.framesPerSecond} '
          'packets=${stats.packetsReceived} lost=${stats.packetsLost} '
          'bytes=${stats.bytesReceived} decoded=${stats.framesDecoded} '
          'dropped=${stats.framesDropped} jitter=${stats.jitter}',
          name: 'meeting.video',
        );
      }
    } catch (error) {
      developer.log(
        'Video statistics unavailable: ${error.runtimeType}',
        name: 'meeting.video',
      );
    } finally {
      _readingVideoStats = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
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
    unawaited(room.dispose());
    super.dispose();
  }
}
