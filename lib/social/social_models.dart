import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

/// Whether someone can be reached right now.
enum Presence {
  online,
  busy,
  inMeeting,
  offline;

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

/// How the user shows to others.
class SocialProfile {
  const SocialProfile({
    required this.displayName,
    required this.nick,
    required this.presence,
    this.statusMessage = '',
  });

  final String displayName;
  final String nick;
  final Presence presence;
  final String statusMessage;
}

class Friend {
  const Friend({
    required this.id,
    required this.displayName,
    required this.nick,
    required this.presence,
    this.offlineFor,
  });

  final String id;
  final String displayName;
  final String nick;
  final Presence presence;

  /// How long ago an offline friend was last seen.
  final Duration? offlineFor;
}

/// Someone asking to be friends.
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.displayName,
    required this.nick,
  });

  final String id;
  final String displayName;
  final String nick;
}

enum TeamRole { owner, admin, member }

class Team {
  const Team({
    required this.id,
    required this.name,
    required this.color,
    required this.memberCount,
    required this.onlineCount,
    required this.role,
    this.meetingLive = false,
  });

  final String id;
  final String name;
  final Color color;
  final int memberCount;
  final int onlineCount;
  final TeamRole role;

  /// Whether the team's own room has a meeting going on.
  final bool meetingLive;
}

/// One message in a conversation with a friend or a team.
class SocialMessage {
  const SocialMessage({required this.text, required this.time, this.sender});

  final String text;

  /// When it was sent, as shown under it.
  final String time;

  /// Who sent it; null for the user's own messages.
  final String? sender;

  bool get mine => sender == null;
}

/// Whom a conversation is with: a friend or a team.
class ChatTarget {
  const ChatTarget.friend(Friend this.friend) : team = null;
  const ChatTarget.team(Team this.team) : friend = null;

  final Friend? friend;
  final Team? team;

  String get id => friend != null ? 'friend-${friend!.id}' : 'team-${team!.id}';
  String get name => friend?.displayName ?? team!.name;

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
    this.conversations = const {},
    this.isPreview = false,
  });

  final SocialProfile profile;
  final List<Friend> friends;
  final List<FriendRequest> requests;
  final List<Team> teams;

  /// Messages by [ChatTarget.id], oldest first.
  final Map<String, List<SocialMessage>> conversations;

  /// Example data, shown until the server offers the social features.
  final bool isPreview;
}

/// The social tab's data. Example data for now: the server has no profiles,
/// friends or teams yet. It will be read from the server once it does.
final socialOverviewProvider = Provider<SocialOverview>(
  (ref) => _previewOverview,
);

const _previewOverview = SocialOverview(
  isPreview: true,
  conversations: {
    'friend-f2': [
      SocialMessage(
        sender: 'Elif',
        text: 'Selam! Akşam müsait misin?',
        time: '18:02',
      ),
      SocialMessage(text: 'Selam, 9 gibi olur', time: '18:05'),
      SocialMessage(
        sender: 'Elif',
        text: 'Tamamdır, sunumu birlikte bir gözden geçirelim',
        time: '18:06',
      ),
      SocialMessage(text: 'Olur, ben toplantıyı kurarım', time: '18:07'),
    ],
    'friend-f1': [
      SocialMessage(
        sender: 'Ali Demir',
        text: 'Toplantıdayım, birazdan dönerim',
        time: '14:20',
      ),
    ],
    'team-t1': [
      SocialMessage(
        sender: 'Ali Demir',
        text: 'Yeni sürümü denedim, cam görünüm çok iyi olmuş',
        time: '10:12',
      ),
      SocialMessage(sender: 'Elif', text: 'Telefonda da akıcı', time: '10:15'),
      SocialMessage(
        text: 'Teşekkürler! Toplantı odasını açtım, gelin',
        time: '10:16',
      ),
      SocialMessage(
        sender: 'Burak Yılmaz',
        text: '5 dakikaya oradayım',
        time: '10:17',
      ),
    ],
    'team-t2': [
      SocialMessage(
        sender: 'Can',
        text: 'Rapor taslağını yükledim',
        time: 'Dün',
      ),
    ],
  },
  profile: SocialProfile(
    displayName: 'Yusuf',
    nick: 'reisub',
    presence: Presence.online,
    statusMessage: 'Kod yazıyorum, akşam müsaitim',
  ),
  requests: [
    FriendRequest(id: 'r1', displayName: 'Zeynep Kaya', nick: 'zeynepk'),
    FriendRequest(id: 'r2', displayName: 'Mert', nick: 'mert.dev'),
  ],
  friends: [
    Friend(
      id: 'f1',
      displayName: 'Ali Demir',
      nick: 'alid',
      presence: Presence.inMeeting,
    ),
    Friend(
      id: 'f2',
      displayName: 'Elif',
      nick: 'elif',
      presence: Presence.online,
    ),
    Friend(
      id: 'f3',
      displayName: 'Burak Yılmaz',
      nick: 'burak',
      presence: Presence.busy,
    ),
    Friend(
      id: 'f4',
      displayName: 'Can',
      nick: 'can42',
      presence: Presence.offline,
      offlineFor: Duration(hours: 2),
    ),
    Friend(
      id: 'f5',
      displayName: 'Deniz Arslan',
      nick: 'deniz',
      presence: Presence.offline,
      offlineFor: Duration(days: 3),
    ),
  ],
  teams: [
    Team(
      id: 't1',
      name: 'REISUB Çekirdek',
      color: Colors.deepPurpleAccent,
      memberCount: 6,
      onlineCount: 3,
      role: TeamRole.owner,
      meetingLive: true,
    ),
    Team(
      id: 't2',
      name: 'Bitirme Projesi',
      color: Colors.teal,
      memberCount: 4,
      onlineCount: 1,
      role: TeamRole.admin,
    ),
    Team(
      id: 't3',
      name: 'Oyun Gecesi',
      color: Colors.orange,
      memberCount: 9,
      onlineCount: 0,
      role: TeamRole.member,
    ),
  ],
);
