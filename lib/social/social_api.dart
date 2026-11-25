import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/auth/account.dart';
import 'package:v_meeting/l10n/localized_error.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/social/social_models.dart';

/// The server's social API: the profile, friends, teams and their chats.
/// It shares the meeting API's session and error handling.
class SocialApi {
  SocialApi(this._api);

  final MeetingApi _api;

  Future<SocialOverview> overview() async =>
      _decode(await _api.send('GET', '/social'), SocialOverview.fromJson);

  Future<void> updateProfile({
    String? displayName,
    String? statusMessage,
    Presence? presence,
  }) => _api.send(
    'PATCH',
    '/me',
    data: {
      'display_name': ?displayName,
      'status_message': ?statusMessage,
      if (presence != null) 'presence': presenceChoice(presence),
    },
  );

  Future<void> sendFriendRequest(String nick) =>
      _api.send('POST', '/friends/requests', data: {'nick': nick.trim()});

  Future<void> answerFriendRequest(String id, {required bool accept}) => _api
      .send('POST', '/friends/requests/$id/${accept ? 'accept' : 'decline'}');

  /// Ends a friendship, or takes back a request the user sent.
  Future<void> removeFriend(String userId) =>
      _api.send('DELETE', '/friends/$userId');

  Future<Team> createTeam(String name) async => _decode(
    await _api.send('POST', '/teams', data: {'name': name.trim()}),
    Team.fromJson,
  );

  Future<List<TeamMemberInfo>> teamMembers(String teamId) async {
    final json = await _api.send('GET', '/teams/$teamId');
    return _decode(
      json,
      (json) => [
        for (final member in json['members'] as List? ?? const [])
          TeamMemberInfo.fromJson(Map<String, dynamic>.from(member as Map)),
      ],
    );
  }

  Future<void> addTeamMember(String teamId, String userId) => _api.send(
    'POST',
    '/teams/$teamId/members',
    data: {'user_id': int.parse(userId)},
  );

  /// Takes someone out of the team; the user's own id leaves it.
  Future<void> removeTeamMember(String teamId, String userId) =>
      _api.send('DELETE', '/teams/$teamId/members/$userId');

  Future<void> deleteTeam(String teamId) =>
      _api.send('DELETE', '/teams/$teamId');

  /// The room of the team's meeting: the one going on or a new one.
  Future<String> startTeamMeeting(String teamId) async => _decode(
    await _api.send('POST', '/teams/$teamId/meeting'),
    (json) => json['room_id'] as String,
  );

  /// Opens a room and invites the friend to it in their chat.
  Future<String> callFriend(String userId) async => _decode(
    await _api.send('POST', '/chats/friend/$userId/call'),
    (json) => json['room_id'] as String,
  );

  /// The latest messages, or with [after] only newer ones.
  Future<List<SocialMessage>> messages(ChatTarget target, {int? after}) async {
    final data = await _api.send(
      'GET',
      '${target.path}/messages${after == null ? '' : '?after=$after'}',
    );
    if (data is! List) {
      throw const MeetingApiException.localized(AppError.invalidMessageData);
    }
    return [
      for (final item in data)
        SocialMessage.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  Future<SocialMessage> sendMessage(ChatTarget target, String text) async =>
      _decode(
        await _api.send(
          'POST',
          '${target.path}/messages',
          data: {'content': text.trim()},
        ),
        SocialMessage.fromJson,
      );

  static T _decode<T>(Object? data, T Function(Map<String, dynamic>) read) {
    if (data is! Map) {
      throw const MeetingApiException.localized(AppError.invalidServerResponse);
    }
    try {
      return read(Map<String, dynamic>.from(data));
    } on TypeError {
      throw const MeetingApiException.localized(AppError.invalidServerResponse);
    }
  }
}

final socialApiProvider = Provider<SocialApi>(
  (ref) => SocialApi(ref.watch(meetingApiProvider)),
);

/// The social tab's data, refreshed while the user is logged in: often
/// while the tab shows, now and then otherwise, which also keeps the user
/// online for their friends. Null without an account.
final socialOverviewProvider =
    AsyncNotifierProvider.autoDispose<
      SocialOverviewController,
      SocialOverview?
    >(SocialOverviewController.new);

class SocialOverviewController extends AsyncNotifier<SocialOverview?> {
  static const visibleInterval = Duration(seconds: 4);
  static const backgroundInterval = Duration(seconds: 20);

  Timer? _timer;
  int _viewers = 0;

  @override
  Future<SocialOverview?> build() async {
    final signedIn = ref.watch(signedInProvider).value ?? false;
    ref.onDispose(() => _timer?.cancel());
    if (!signedIn) return null;
    _schedule();
    return ref.read(socialApiProvider).overview();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(
      _viewers > 0 ? visibleInterval : backgroundInterval,
      (_) => refresh(),
    );
  }

  /// The social tab shows; refresh often while it does.
  void show() {
    _viewers++;
    if (_viewers == 1 && state.value != null) {
      _schedule();
      refresh();
    }
  }

  void hide() {
    if (_viewers == 0) return;
    _viewers--;
    if (_viewers == 0 && state.value != null) _schedule();
  }

  /// Reads the overview again, keeping what is shown if that fails.
  Future<void> refresh() async {
    if (!(ref.read(signedInProvider).value ?? false)) return;
    try {
      final overview = await ref.read(socialApiProvider).overview();
      state = AsyncData(overview);
    } on MeetingApiException catch (error) {
      if (error.sessionExpired) ref.read(signedInProvider.notifier).refresh();
    } catch (_) {
      // A missed refresh is made up by the next one.
    }
  }
}

/// A conversation's messages, oldest first, with newer ones fetched every
/// few seconds while it is open.
final conversationProvider = AsyncNotifierProvider.autoDispose
    .family<ConversationController, List<SocialMessage>, ChatTarget>(
      ConversationController.new,
    );

class ConversationController extends AsyncNotifier<List<SocialMessage>> {
  ConversationController(this.target);

  final ChatTarget target;
  static const interval = Duration(seconds: 3);

  @override
  Future<List<SocialMessage>> build() async {
    final timer = Timer.periodic(interval, (_) => _fetchNewer());
    ref.onDispose(timer.cancel);
    return ref.read(socialApiProvider).messages(target);
  }

  Future<void> _fetchNewer() async {
    final current = state.value;
    if (current == null) return;
    try {
      final newer = await ref
          .read(socialApiProvider)
          .messages(target, after: current.isEmpty ? null : current.last.id);
      _add(newer);
    } catch (_) {
      // The next poll tries again.
    }
  }

  void _add(List<SocialMessage> messages) {
    final current = state.value ?? const [];
    final known = {for (final message in current) message.id};
    final fresh = [
      for (final message in messages)
        if (!known.contains(message.id)) message,
    ];
    if (fresh.isEmpty) return;
    state = AsyncData([...current, ...fresh]..sort((a, b) => a.id - b.id));
  }

  Future<void> send(String text) async {
    final message = await ref.read(socialApiProvider).sendMessage(target, text);
    _add([message]);
  }

  /// Picks up a message the server just added, such as a call invitation.
  Future<void> refresh() => _fetchNewer();
}
