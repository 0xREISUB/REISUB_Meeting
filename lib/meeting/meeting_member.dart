import 'package:livekit_client/livekit_client.dart';

/// A participant's role in a meeting, as granted by the server.
enum MeetingRole {
  /// Full admin: everything an admin can do, plus changing roles.
  owner,

  /// Admin: microphone moderation, screen-share policy, ending the meeting.
  moderator,
  participant;

  /// Reads the server's role name; unknown or empty means participant.
  static MeetingRole parse(String? value) => switch (value) {
    'owner' => owner,
    'moderator' => moderator,
    _ => participant,
  };

  bool get canModerate => this != participant;
}

/// Whether [viewer] may lock, unmute-request or stop the share of [target].
/// The server protects owners from everyone and admins from other admins.
bool canModerateMember(MeetingRole viewer, MemberEntry target) =>
    viewer.canModerate &&
    !target.isLocal &&
    target.identity.isNotEmpty &&
    target.role != MeetingRole.owner &&
    !(viewer == MeetingRole.moderator && target.role == MeetingRole.moderator);

/// A participant as shown in the meeting UI.
class MemberEntry {
  final String id;
  final String name;
  final String identity;
  final bool isMicrophoneLocked;
  final bool isLocal;
  final bool isMicEnabled;
  final bool isSpeaking;
  final VideoTrack? videoTrack;
  final VideoTrack? screenShareTrack;
  final bool isScreenSharing;
  final bool isScreenShare;
  final bool mirrorCamera;
  final MeetingRole role;

  const MemberEntry({
    required this.id,
    required this.name,
    this.identity = '',
    this.isMicrophoneLocked = false,
    required this.isLocal,
    required this.isMicEnabled,
    this.isSpeaking = false,
    this.videoTrack,
    this.screenShareTrack,
    this.isScreenSharing = false,
    this.isScreenShare = false,
    this.mirrorCamera = true,
    this.role = MeetingRole.participant,
  });
}

MemberEntry selectMainMember(
  List<MemberEntry> members, {
  required List<String> activeSpeakerIds,
  String? previousSpeakerId,
}) {
  assert(members.isNotEmpty);
  for (final member in members) {
    if (member.isScreenSharing) {
      return MemberEntry(
        id: member.id,
        name: member.name,
        identity: member.identity,
        isLocal: member.isLocal,
        isMicEnabled: member.isMicEnabled,
        videoTrack: member.screenShareTrack,
        isScreenShare: true,
      );
    }
  }

  if (members.length == 1) return members.first;
  if (members.length == 2) {
    return members.firstWhere((member) => !member.isLocal);
  }
  for (final id in activeSpeakerIds) {
    for (final member in members) {
      if (member.id == id) return member;
    }
  }
  return members.firstWhere(
    (member) => member.id == previousSpeakerId,
    orElse: () => members.firstWhere((member) => !member.isLocal),
  );
}
