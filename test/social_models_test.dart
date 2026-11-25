import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/social/social_models.dart';

void main() {
  // Answers of the real server, as recorded from it.
  test('the overview reads as the server sends it', () {
    final overview = SocialOverview.fromJson({
      'profile': {
        'id': 1,
        'nick': 'alice',
        'display_name': 'alice',
        'status_message': '',
        'presence': 'invisible',
      },
      'friends': [
        {
          'id': 2,
          'nick': 'bob',
          'display_name': 'Bob B',
          'status_message': 'hi',
          'presence': 'busy',
        },
        {
          'id': 3,
          'nick': 'can',
          'display_name': 'can',
          'status_message': '',
          'presence': 'offline',
          'last_seen_seconds': 7200,
        },
        {
          'id': 4,
          'nick': 'dan',
          'display_name': 'dan',
          'status_message': '',
          'presence': 'in_meeting',
        },
      ],
      'requests': [
        {
          'id': 9,
          'user': {
            'id': 5,
            'nick': 'eve',
            'display_name': 'Eve',
            'status_message': '',
            'presence': 'online',
          },
        },
      ],
      'outgoing': [],
      'teams': [
        {
          'id': 1,
          'name': 'Core',
          'color': '#009688',
          'role': 'owner',
          'member_count': 2,
          'online_count': 2,
          'meeting_live': true,
          'room_id': '111-222-333',
        },
      ],
    });
    // Hiding shows as offline.
    expect(overview.profile.presence, Presence.offline);
    expect(presenceChoice(overview.profile.presence), 'invisible');
    expect(overview.friends.map((f) => f.presence), [
      Presence.busy,
      Presence.offline,
      Presence.inMeeting,
    ]);
    expect(overview.friends[1].offlineFor, const Duration(hours: 2));
    expect(overview.requests.single.userId, '5');
    final team = overview.teams.single;
    expect(team.role, TeamRole.owner);
    expect(team.color.toARGB32(), 0xFF009688);
    expect(team.meetingLive, isTrue);
    expect(team.roomId, '111-222-333');
    // The open conversation follows the friend as they are now.
    const stale = ChatTarget.friend(
      Friend(
        id: '2',
        displayName: 'Bob',
        nick: 'bob',
        presence: Presence.online,
      ),
    );
    expect(overview.current(stale)!.friend!.presence, Presence.busy);
  });

  test('messages read as the server sends them', () {
    final text = SocialMessage.fromJson({
      'id': 1,
      'sender_id': 1,
      'sender': 'alice',
      'content': 'selam',
      'created_at': '2026-11-25T15:56:56.167Z',
      'is_mine': true,
    });
    expect(text.mine, isTrue);
    expect(text.roomId, isNull);
    expect(text.sentAt.isUtc, isFalse);
    final call = SocialMessage.fromJson({
      'id': 2,
      'sender_id': 2,
      'sender': 'Bob B',
      'content': '',
      'room_id': '444-555-666',
      'created_at': '2026-11-25T16:00:00Z',
      'is_mine': false,
    });
    expect(call.roomId, '444-555-666');
    // An older message shows its date.
    expect(call.timeLabel(DateTime(2026, 11, 27, 9)), startsWith('25.11 '));
  });
}
