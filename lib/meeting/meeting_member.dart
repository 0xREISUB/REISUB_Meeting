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

/// The main video: a shared screen first, then [speakerId] or another
/// participant; yourself only when nobody else is there.
MemberEntry selectMainMember(List<MemberEntry> members, {String? speakerId}) {
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
  // You never fill the main video while someone else is there.
  final others = members.where((member) => !member.isLocal).toList();
  if (others.isEmpty) return members.first;
  return others.firstWhere(
    (member) => member.id == speakerId,
    orElse: () => others.first,
  );
}

/// Decides whose camera the main video shows in a group, without jumping at
/// every short sound. Another person takes over only after speaking for
/// [switchAfter] without a break, and whoever is shown stays for at least
/// [minimumHold]. Silence keeps the last speaker.
class SpeakerFocus {
  SpeakerFocus({
    this.switchAfter = const Duration(milliseconds: 1500),
    this.minimumHold = const Duration(seconds: 4),
  });

  final Duration switchAfter;
  final Duration minimumHold;

  /// The participant the main video shows, or null before anyone else joins.
  String? get focusId => _focusId;
  String? _focusId;
  DateTime _focusSince = DateTime.fromMillisecondsSinceEpoch(0);

  String? _candidateId;
  DateTime _candidateSince = DateTime.fromMillisecondsSinceEpoch(0);

  /// Updates the focus from the other participants in the room and those of
  /// them speaking now, loudest first. Returns how long to wait before
  /// calling again when someone is about to take over, otherwise null.
  Duration? update({
    required List<String> participantIds,
    required List<String> speakingIds,
    required DateTime now,
  }) {
    if (!participantIds.contains(_focusId)) {
      // The shown person left, or nobody was shown yet: take the current
      // speaker, or anyone, at once.
      final next = speakingIds.firstOrNull ?? participantIds.firstOrNull;
      _setFocus(next, now);
      return null;
    }
    final loudest = speakingIds.firstOrNull;
    if (loudest == null || speakingIds.contains(_focusId)) {
      // Silence, or the shown person is still talking.
      _candidateId = null;
      return null;
    }
    if (_candidateId != loudest) {
      _candidateId = loudest;
      _candidateSince = now;
    }
    final heardEnough = _candidateSince.add(switchAfter);
    final shownEnough = _focusSince.add(minimumHold);
    final switchAt = heardEnough.isAfter(shownEnough)
        ? heardEnough
        : shownEnough;
    if (now.isBefore(switchAt)) return switchAt.difference(now);
    _setFocus(loudest, now);
    return null;
  }

  void reset() => _setFocus(null, DateTime.fromMillisecondsSinceEpoch(0));

  void _setFocus(String? id, DateTime now) {
    if (id != _focusId) _focusSince = now;
    _focusId = id;
    _candidateId = null;
  }
}
