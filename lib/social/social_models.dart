import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

/// Whether someone can be reached right now, as their friends see it.
enum Presence {
  online,
  busy,
  inMeeting,
  offline;

  static Presence parse(Object? value) => switch (value) {
    'online' => Presence.online,
    'busy' => Presence.busy,
    'in_meeting' => Presence.inMeeting,
    _ => Presence.offline,
  };

  Color get color => switch (this) {
    Presence.online => Colors.greenAccent,
    Presence.busy => Colors.redAccent,
    Presence.inMeeting => Colors.amberAccent,
    Presence.offline => Colors.white38,
  };

  String label(AppLocalizations l10n) => switch (this) {
    Presence.online => l10n.presenceOnline,
    Presence.busy => l10n.presenceBusy,
    Presence.inMeeting => l10n.presenceInMeeting,
    Presence.offline => l10n.presenceOffline,
  };
}

/// "5 min ago", for someone offline since [since].
String lastSeenText(Duration since, AppLocalizations l10n) {
  if (since.inHours < 1) return l10n.lastSeenMinutes(since.inMinutes);
  if (since.inDays < 1) return l10n.lastSeenHours(since.inHours);
  return l10n.lastSeenDays(since.inDays);
}

/// The user's own profile. [presence] is what they chose to show: online,
/// busy, or offline for hidden.
class SocialProfile {
  const SocialProfile({
    required this.displayName,
    required this.nick,
    required this.presence,
    this.statusMessage = '',
  });

  factory SocialProfile.fromJson(Map<String, dynamic> json) => SocialProfile(
    displayName: json['display_name'] as String? ?? json['nick'] as String,
    nick: json['nick'] as String,
    statusMessage: json['status_message'] as String? ?? '',
    // Hiding shows as offline to friends.
    presence: json['presence'] == 'invisible'
        ? Presence.offline
        : Presence.parse(json['presence']),
  );

  final String displayName;
  final String nick;
  final Presence presence;
  final String statusMessage;
}

/// The server's word for a presence the user picks.
String presenceChoice(Presence presence) => switch (presence) {
  Presence.busy => 'busy',
  Presence.offline => 'invisible',
  _ => 'online',
};

class Friend {
  const Friend({
    required this.id,
    required this.displayName,
    required this.nick,
    required this.presence,
    this.statusMessage = '',
    this.offlineFor,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    final lastSeen = (json['last_seen_seconds'] as num?)?.toInt();
    return Friend(
      id: '${json['id']}',
      displayName: json['display_name'] as String? ?? json['nick'] as String,
      nick: json['nick'] as String,
      statusMessage: json['status_message'] as String? ?? '',
      presence: Presence.parse(json['presence']),
      offlineFor: lastSeen == null ? null : Duration(seconds: lastSeen),
    );
  }

  final String id;
  final String displayName;
  final String nick;
  final Presence presence;
  final String statusMessage;

  /// How long ago an offline friend was last seen.
  final Duration? offlineFor;
}

/// A friend request: incoming, to answer, or outgoing, waiting.
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.nick,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    final user = Map<String, dynamic>.from(json['user'] as Map);
    return FriendRequest(
      id: '${json['id']}',
      userId: '${user['id']}',
      displayName: user['display_name'] as String? ?? user['nick'] as String,
      nick: user['nick'] as String,
    );
  }

  final String id;
  final String userId;
  final String displayName;
  final String nick;
}

enum TeamRole {
  owner,
  admin,
  member;

  static TeamRole parse(Object? value) => switch (value) {
    'owner' => TeamRole.owner,
    'admin' => TeamRole.admin,
    _ => TeamRole.member,
  };

  bool get manages => this != TeamRole.member;
}

class Team {
  const Team({
    required this.id,
    required this.name,
    required this.color,
    required this.memberCount,
    required this.onlineCount,
    required this.role,
    this.meetingLive = false,
    this.roomId,
  });

  factory Team.fromJson(Map<String, dynamic> json) => Team(
    id: '${json['id']}',
    name: json['name'] as String,
    color: parseColor(json['color']) ?? Colors.deepPurpleAccent,
    memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
    onlineCount: (json['online_count'] as num?)?.toInt() ?? 0,
    role: TeamRole.parse(json['role']),
    meetingLive: json['meeting_live'] as bool? ?? false,
    roomId: json['room_id'] as String?,
  );

  final String id;
  final String name;
  final Color color;
  final int memberCount;
  final int onlineCount;
  final TeamRole role;

  /// Whether someone is in the team's meeting now.
  final bool meetingLive;
  final String? roomId;
}

/// "#7C4DFF" as a colour.
Color? parseColor(Object? value) {
  if (value is! String || value.length != 7 || !value.startsWith('#')) {
    return null;
  }
  final rgb = int.tryParse(value.substring(1), radix: 16);
  return rgb == null ? null : Color(0xFF000000 | rgb);
}

/// Someone in a team, with their role in it.
class TeamMemberInfo {
  const TeamMemberInfo({required this.person, required this.role});

  factory TeamMemberInfo.fromJson(Map<String, dynamic> json) => TeamMemberInfo(
    person: Friend.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
    role: TeamRole.parse(json['role']),
  );

  final Friend person;
  final TeamRole role;
}

/// One message in a conversation with a friend or a team.
class SocialMessage {
  const SocialMessage({
    required this.id,
    required this.text,
    required this.sentAt,
    required this.sender,
    required this.mine,
    this.roomId,
  });

  factory SocialMessage.fromJson(Map<String, dynamic> json) {
    final roomId = json['room_id'] as String?;
    return SocialMessage(
      id: (json['id'] as num).toInt(),
      text: json['content'] as String? ?? '',
      sentAt: DateTime.parse(json['created_at'] as String).toLocal(),
      sender: json['sender'] as String? ?? '',
      mine: json['is_mine'] as bool? ?? false,
      roomId: roomId == null || roomId.isEmpty ? null : roomId,
    );
  }

  final int id;
  final String text;
  final DateTime sentAt;
  final String sender;
  final bool mine;

  /// Set when the message invites to a meeting.
  final String? roomId;

  /// "14:05", or with the date for an older message.
  String timeLabel(DateTime now) {
    String two(int value) => value.toString().padLeft(2, '0');
    final time = '${two(sentAt.hour)}:${two(sentAt.minute)}';
    final sameDay =
        sentAt.year == now.year &&
        sentAt.month == now.month &&
        sentAt.day == now.day;
    return sameDay ? time : '${two(sentAt.day)}.${two(sentAt.month)} $time';
  }
}

/// Whom a conversation is with: a friend or a team.
class ChatTarget {
  const ChatTarget.friend(Friend this.friend) : team = null;
  const ChatTarget.team(Team this.team) : friend = null;

  final Friend? friend;
  final Team? team;

  String get id => friend != null ? 'friend-${friend!.id}' : 'team-${team!.id}';
  String get name => friend?.displayName ?? team!.name;

  /// The server's path for this conversation.
  String get path => friend != null
      ? '/chats/friend/${friend!.id}'
      : '/chats/team/${team!.id}';

  @override
  bool operator ==(Object other) => other is ChatTarget && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Everything the social tab shows.
class SocialOverview {
  const SocialOverview({
    required this.profile,
    required this.friends,
    required this.requests,
    required this.teams,
    this.outgoing = const [],
  });

  factory SocialOverview.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) read) => [
      for (final item in json[key] as List? ?? const [])
        read(Map<String, dynamic>.from(item as Map)),
    ];
    return SocialOverview(
      profile: SocialProfile.fromJson(
        Map<String, dynamic>.from(json['profile'] as Map),
      ),
      friends: list('friends', Friend.fromJson),
      requests: list('requests', FriendRequest.fromJson),
      outgoing: list('outgoing', FriendRequest.fromJson),
      teams: list('teams', Team.fromJson),
    );
  }

  final SocialProfile profile;
  final List<Friend> friends;

  /// Requests to the user, to answer.
  final List<FriendRequest> requests;

  /// Requests the user sent that wait for an answer.
  final List<FriendRequest> outgoing;
  final List<Team> teams;

  /// The friend or team behind a conversation, as it is now; null once
  /// they are gone.
  ChatTarget? current(ChatTarget target) {
    if (target.friend != null) {
      for (final friend in friends) {
        if (friend.id == target.friend!.id) return ChatTarget.friend(friend);
      }
    } else {
      for (final team in teams) {
        if (team.id == target.team!.id) return ChatTarget.team(team);
      }
    }
    return null;
  }
}
