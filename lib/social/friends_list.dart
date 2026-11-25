import 'package:flutter/material.dart';
import 'package:v_meeting/app/theme.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/widgets/participant_tile.dart';
import 'package:v_meeting/social/presence_avatar.dart';
import 'package:v_meeting/social/social_models.dart';
import 'package:v_meeting/widgets/glass.dart';

/// Friend requests waiting for an answer, then the friends: those who can
/// be reached first.
class FriendsList extends StatelessWidget {
  const FriendsList({
    super.key,
    required this.friends,
    required this.requests,
    required this.onOpen,
    this.openId,
  });

  final List<Friend> friends;
  final List<FriendRequest> requests;

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
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.friend,
    required this.open,
    required this.onOpen,
  });

  final Friend friend;
  final bool open;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
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
              tooltip: l10n.callFriend,
              onPressed: () => showSocialComingSoon(context),
              icon: Icon(
                Icons.call_rounded,
                color: reachable ? Colors.greenAccent : glassMuted,
              ),
            ),
      onTap: onOpen,
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request});

  final FriendRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      key: ValueKey('request-${request.id}'),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          MemberAvatar(name: request.displayName, seed: request.nick, size: 42),
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
          IconButton.filled(
            tooltip: l10n.declineRequest,
            onPressed: () => showSocialComingSoon(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
              foregroundColor: Colors.redAccent,
            ),
            icon: const Icon(Icons.close_rounded),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            tooltip: l10n.acceptRequest,
            onPressed: () => showSocialComingSoon(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.greenAccent.withValues(alpha: 0.2),
              foregroundColor: Colors.greenAccent,
            ),
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
    );
  }
}
