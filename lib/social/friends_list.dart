import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/theme.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/social/presence_avatar.dart';
import 'package:v_meeting/social/social_actions.dart';
import 'package:v_meeting/social/social_api.dart';
import 'package:v_meeting/social/social_models.dart';
import 'package:v_meeting/social/user_avatar.dart';
import 'package:v_meeting/widgets/glass.dart';

/// Friend requests waiting for an answer, then the friends: those who can
/// be reached first, and the requests the user sent.
class FriendsList extends StatelessWidget {
  const FriendsList({
    super.key,
    required this.friends,
    required this.requests,
    this.outgoing = const [],
    required this.onOpen,
    this.openId,
  });

  final List<Friend> friends;
  final List<FriendRequest> requests;

  /// Requests the user sent, waiting for an answer.
  final List<FriendRequest> outgoing;

  /// Opens the conversation with a friend.
  final ValueChanged<ChatTarget> onOpen;

  /// The [ChatTarget.id] of the open conversation, to mark it.
  final String? openId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sorted = [...friends]
      ..sort((a, b) => a.presence.index.compareTo(b.presence.index));
    final online = friends
        .where((friend) => friend.presence != Presence.offline)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (requests.isNotEmpty)
          GlassSection(
            radius: 14,
            title: l10n.friendRequests(requests.length),
            children: [
              for (final request in requests) _RequestRow(request: request),
            ],
          ),
        if (friends.isEmpty && requests.isEmpty && outgoing.isEmpty)
          Padding(
            key: const ValueKey('no-friends'),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(
              l10n.noFriendsYet,
              textAlign: TextAlign.center,
              style: const TextStyle(color: glassMuted, height: 1.4),
            ),
          ),
        if (friends.isNotEmpty)
          GlassSection(
            radius: 14,
            title: '${l10n.friends} · ${l10n.onlineCount(online)}',
            children: [
              for (final friend in sorted)
                _FriendRow(
                  friend: friend,
                  open: openId == ChatTarget.friend(friend).id,
                  onOpen: () => onOpen(ChatTarget.friend(friend)),
                ),
            ],
          ),
        if (outgoing.isNotEmpty)
          GlassSection(
            radius: 14,
            title: l10n.outgoingRequests(outgoing.length),
            children: [
              for (final request in outgoing)
                _RequestRow(request: request, outgoing: true),
            ],
          ),
      ],
    );
  }
}

class _FriendRow extends ConsumerWidget {
  const _FriendRow({
    required this.friend,
    required this.open,
    required this.onOpen,
  });

  final Friend friend;
  final bool open;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final offlineFor = friend.offlineFor;
    final status = friend.presence == Presence.offline && offlineFor != null
        ? lastSeenText(offlineFor, l10n)
        : friend.presence.label(l10n);
    final reachable = friend.presence == Presence.online;
    return ListTile(
      key: ValueKey('friend-${friend.id}'),
      selected: open,
      selectedTileColor: brandColor.withValues(alpha: 0.22),
      selectedColor: Colors.white,
      contentPadding: const EdgeInsets.fromLTRB(14, 2, 8, 2),
      leading: PresenceAvatar(
        name: friend.displayName,
        seed: friend.nick,
        avatarUrl: friend.avatarUrl,
        presence: friend.presence,
        size: 42,
      ),
      title: Text(
        friend.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '@${friend.nick} · $status',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: friend.presence == Presence.offline
              ? glassMuted
              : friend.presence.color.withValues(alpha: 0.9),
          fontSize: 12.5,
        ),
      ),
      trailing: friend.presence == Presence.offline
          ? null
          : IconButton(
              key: ValueKey('call-${friend.id}'),
              tooltip: l10n.callFriend,
              onPressed: () => _call(context, ref),
              icon: Icon(
                Icons.call_rounded,
                color: reachable ? Colors.greenAccent : glassMuted,
              ),
            ),
      onTap: onOpen,
    );
  }

  /// Opens a room, invites the friend to it in their chat, and joins.
  Future<void> _call(BuildContext context, WidgetRef ref) async {
    String? roomId;
    final opened = await runSocialAction(context, ref, () async {
      roomId = await ref.read(socialApiProvider).callFriend(friend.id);
    });
    if (opened && context.mounted) {
      await joinSocialMeeting(context, ref, roomId!);
    }
  }
}

class _RequestRow extends ConsumerWidget {
  const _RequestRow({required this.request, this.outgoing = false});

  final FriendRequest request;

  /// Sent by the user: it can only be taken back.
  final bool outgoing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final api = ref.read(socialApiProvider);
    void answer({required bool accept}) => runSocialAction(
      context,
      ref,
      () => api.answerFriendRequest(request.id, accept: accept),
    );
    return Padding(
      key: ValueKey('request-${request.id}'),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          UserAvatar(
            name: request.displayName,
            seed: request.nick,
            avatarUrl: request.avatarUrl,
            size: 42,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '@${request.nick}',
                  style: const TextStyle(color: glassMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (outgoing)
            TextButton(
              key: ValueKey('cancel-request-${request.id}'),
              onPressed: () => runSocialAction(
                context,
                ref,
                () => api.removeFriend(request.userId),
              ),
              child: Text(l10n.cancelFriendRequest),
            )
          else ...[
            IconButton.filled(
              key: ValueKey('decline-${request.id}'),
              tooltip: l10n.declineRequest,
              onPressed: () => answer(accept: false),
              style: IconButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                foregroundColor: Colors.redAccent,
              ),
              icon: const Icon(Icons.close_rounded),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              key: ValueKey('accept-${request.id}'),
              tooltip: l10n.acceptRequest,
              onPressed: () => answer(accept: true),
              style: IconButton.styleFrom(
                backgroundColor: Colors.greenAccent.withValues(alpha: 0.2),
                foregroundColor: Colors.greenAccent,
              ),
              icon: const Icon(Icons.check_rounded),
            ),
          ],
        ],
      ),
    );
  }
}
