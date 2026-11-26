part of 'meeting_session.dart';

/// Who is in the meeting, and whom the main view shows.
extension MeetingSessionParticipants on MeetingSession {
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
        grantedPermissions: permissions,
        mirrorCamera: mirrorCamera,
        avatarUrl: local?.attributes[MeetingSession.avatarAttribute] ?? '',
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
                participant.attributes[MeetingSession.micLockAttribute] ==
                'true',
            name: participant.name.isEmpty
                ? participant.identity
                : participant.name,
            isLocal: false,
            role: MeetingRole.parse(
              participant.attributes[MeetingSession.roleAttribute],
            ),
            grantedPermissions: MeetingPermission.parseList(
              participant.attributes[MeetingSession.permissionsAttribute],
            ),
            avatarUrl:
                participant.attributes[MeetingSession.avatarAttribute] ?? '',
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

  MemberEntry mainMember(List<MemberEntry> members) =>
      selectMainMember(members, speakerId: _speakerFocus.focusId);

  RemoteParticipant? _mainRemoteParticipant() {
    final participants = room.remoteParticipants.values;
    if (participants.isEmpty) return null;
    final main = mainMember(members());
    for (final participant in participants) {
      if (participant.sid == main.id) return participant;
    }
    return participants.first;
  }

  Future<void> moderateMicrophone(
    MemberEntry member,
    bool locked,
    bool requestUnmute,
  ) async {
    final credentials = _credentials;
    if (credentials == null || !canModerateMember(permissions, member)) return;
    // Locking and unlocking need one permission, asking to unmute another.
    if ((locked || member.isMicrophoneLocked) &&
        !can(MeetingPermission.muteOthers)) {
      return;
    }
    if (requestUnmute && !can(MeetingPermission.requestUnmute)) return;
    await api.setParticipantMicrophone(
      roomId: credentials.roomId,
      identity: member.identity,
      locked: locked,
      requestUnmute: requestUnmute,
    );
  }

  /// Whether this user may change [member]'s permissions: never the full
  /// admin's or their own.
  bool canChangePermissions(MemberEntry member) =>
      can(MeetingPermission.grantPermissions) &&
      !member.isLocal &&
      member.identity.isNotEmpty &&
      member.role != MeetingRole.owner;

  /// Gives or takes back one of [member]'s permissions. Throws the server's
  /// error so the caller can show it.
  Future<void> setPermission(
    MemberEntry member,
    MeetingPermission permission,
    bool on,
  ) async {
    final credentials = _credentials;
    if (credentials == null || !canChangePermissions(member)) return;
    final next = {...member.grantedPermissions};
    on ? next.add(permission) : next.remove(permission);
    await api.setParticipantPermissions(
      roomId: credentials.roomId,
      identity: member.identity,
      permissions: next,
    );
  }

  /// Removes [member] from the meeting; the server keeps them from joining
  /// again. Throws the server's error so the caller can show it.
  Future<void> removeMember(MemberEntry member) async {
    final credentials = _credentials;
    if (credentials == null ||
        !can(MeetingPermission.removeMembers) ||
        !canModerateMember(permissions, member)) {
      return;
    }
    await api.removeParticipant(credentials.roomId, member.identity);
  }

  /// Full admin only: [member] becomes the full admin and this user keeps
  /// every permission.
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
  bool get isLastOwner => isOwner && room.remoteParticipants.isNotEmpty;

  /// Tells the user when the server makes them the full admin, e.g. after
  /// the previous one left.
  void _announceRoleChange() {
    if (room.localParticipant?.attributes[MeetingSession.roleAttribute] ==
        null) {
      return;
    }
    final current = role;
    final previous = _announcedRole;
    _announcedRole = current;
    if (previous == null || previous == current) return;
    if (current == MeetingRole.owner) {
      _ui.showMessage(const AppException.localized(AppError.nowOwner));
    }
  }
}
