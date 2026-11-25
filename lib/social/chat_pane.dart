import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/theme.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/social/notifications.dart';
import 'package:v_meeting/social/presence_avatar.dart';
import 'package:v_meeting/social/social_actions.dart';
import 'package:v_meeting/social/social_api.dart';
import 'package:v_meeting/social/social_models.dart';
import 'package:v_meeting/social/team_members_dialog.dart';
import 'package:v_meeting/social/teams_list.dart';
import 'package:v_meeting/social/user_avatar.dart';
import 'package:v_meeting/widgets/glass.dart';

/// A conversation with a friend or a team: who it is with on top, the
/// messages, and a box to write. On a computer it is the right pane of the
/// social tab; on a phone a screen of its own, with [onBack].
/// [onClosed] is called once the conversation is gone, such as after
/// unfriending or leaving the team.
class ChatPane extends ConsumerStatefulWidget {
  const ChatPane({super.key, required this.target, this.onBack, this.onClosed});

  final ChatTarget target;
  final VoidCallback? onBack;
  final VoidCallback? onClosed;

  @override
  ConsumerState<ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends ConsumerState<ChatPane> {
  final _draft = TextEditingController();
  bool _sending = false;
  late final ChatVisibility _visibility;
  late final String _id = widget.target.id;

  /// The last message marked read, and the last one there when it opened.
  int _readTo = 0;
  int? _openedAt;

  @override
  void initState() {
    super.initState();
    // Its new messages are not announced while it shows.
    _visibility = ref.read(chatVisibilityProvider)..add(_id, _shows);
  }

  @override
  void dispose() {
    _visibility.remove(_id, _shows);
    _draft.dispose();
    super.dispose();
  }

  /// Whether it is on screen: nothing in front of it, and, beside the
  /// social list on a computer, the social tab in front.
  bool _shows() {
    if (!mounted) return false;
    if (!(ModalRoute.isCurrentOf(context) ?? true)) return false;
    return widget.onBack != null || ref.read(socialTabShownProvider);
  }

  /// Marks what shows as read, when there is something new to mark.
  void _markRead(List<SocialMessage> messages) {
    if (messages.isEmpty || !_shows()) return;
    final last = messages.last.id;
    if (last <= _readTo) return;
    _openedAt ??= last;
    final unread =
        widget.target.friend?.unread ?? widget.target.team?.unread ?? 0;
    _readTo = last;
    // Nothing unread when it opened, and nothing new since.
    if (unread == 0 && last == _openedAt) return;
    ref
        .read(socialApiProvider)
        .markRead(widget.target, last)
        .then(
          (_) => ref.read(socialOverviewProvider.notifier).refresh(),
          onError: (_) => _readTo = 0,
        );
  }

  Future<void> _send() async {
    final text = _draft.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final sent = await runSocialAction(
      context,
      ref,
      () => ref.read(conversationProvider(widget.target).notifier).send(text),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (sent) _draft.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final conversation = ref.watch(conversationProvider(widget.target));
    final messages = conversation.value;
    // Read again when the social tab comes to the front.
    ref.watch(socialTabShownProvider);
    if (messages != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _markRead(messages);
      });
    }
    final now = DateTime.now();
    return Column(
      key: ValueKey('chat-${widget.target.id}'),
      children: [
        _ChatHeader(
          target: widget.target,
          onBack: widget.onBack,
          onClosed: widget.onClosed,
        ),
        const Divider(height: 1, color: Color(0x14FFFFFF)),
        Expanded(
          child: messages == null
              ? Center(
                  child: conversation.hasError
                      ? Text(
                          l10n.socialLoadFailed,
                          style: const TextStyle(color: glassMuted),
                        )
                      : const CircularProgressIndicator(),
                )
              : messages.isEmpty
              ? Center(
                  child: Text(
                    l10n.noMessagesYet,
                    style: const TextStyle(color: glassMuted),
                  ),
                )
              : ListView.builder(
                  key: const ValueKey('chat-messages'),
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    final previous = index + 1 < messages.length
                        ? messages[messages.length - 2 - index]
                        : null;
                    if (message.roomId != null) {
                      return _InviteBubble(message: message, now: now);
                    }
                    return _Bubble(
                      message: message,
                      now: now,
                      // A team's messages say who wrote them, once per run.
                      showSender:
                          widget.target.team != null &&
                          !message.mine &&
                          (previous == null ||
                              previous.sender != message.sender ||
                              previous.roomId != null),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('chat-input'),
                  controller: _draft,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: l10n.messageHint,
                    isDense: true,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: glassStroke),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: glassStroke),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: brandColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GlassIconButton(
                key: const ValueKey('chat-send'),
                size: 46,
                iconSize: 20,
                tint: brandColor,
                icon: Icons.send_rounded,
                onPressed: _sending ? null : _send,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatHeader extends ConsumerWidget {
  const _ChatHeader({required this.target, this.onBack, this.onClosed});

  final ChatTarget target;
  final VoidCallback? onBack;
  final VoidCallback? onClosed;

  /// Calls the friend: opens a room, invites them in the chat, and joins.
  Future<void> _call(BuildContext context, WidgetRef ref, Friend friend) async {
    String? roomId;
    final opened = await runSocialAction(context, ref, () async {
      roomId = await ref.read(socialApiProvider).callFriend(friend.id);
    });
    if (!opened || !context.mounted) return;
    ref.read(conversationProvider(target).notifier).refresh();
    await joinSocialMeeting(context, ref, roomId!);
  }

  Future<void> _startTeamMeeting(
    BuildContext context,
    WidgetRef ref,
    Team team,
  ) async {
    String? roomId;
    final started = await runSocialAction(context, ref, () async {
      roomId = await ref.read(socialApiProvider).startTeamMeeting(team.id);
    });
    if (!started || !context.mounted) return;
    ref.read(conversationProvider(target).notifier).refresh();
    await joinSocialMeeting(context, ref, roomId!);
  }

  Future<void> _removeFriend(
    BuildContext context,
    WidgetRef ref,
    Friend friend,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await confirmSocial(
      context,
      title: l10n.removeFriend,
      body: l10n.removeFriendBody(friend.displayName),
      action: l10n.remove,
    );
    if (!confirmed || !context.mounted) return;
    final removed = await runSocialAction(
      context,
      ref,
      () => ref.read(socialApiProvider).removeFriend(friend.id),
    );
    if (removed) _close();
  }

  void _close() => (onClosed ?? onBack)?.call();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final friend = target.friend;
    final team = target.team;
    final String subtitle;
    final Color subtitleColor;
    if (friend != null) {
      final offlineFor = friend.offlineFor;
      subtitle = friend.presence == Presence.offline && offlineFor != null
          ? lastSeenText(offlineFor, l10n)
          : friend.presence.label(l10n);
      subtitleColor = friend.presence == Presence.offline
          ? glassMuted
          : friend.presence.color;
    } else {
      subtitle = team!.meetingLive
          ? l10n.teamLive
          : '${l10n.teamMembers(team.memberCount)} · '
                '${l10n.onlineCount(team.onlineCount)}';
      subtitleColor = team.meetingLive ? Colors.greenAccent : glassMuted;
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(onBack == null ? 16 : 4, 10, 6, 10),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              key: const ValueKey('chat-back'),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          if (friend != null)
            PresenceAvatar(
              name: friend.displayName,
              seed: friend.nick,
              avatarUrl: friend.avatarUrl,
              presence: friend.presence,
              size: 42,
            )
          else
            TeamBadge(team: team!, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: subtitleColor, fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (team != null) ...[
            FilledButton.icon(
              key: const ValueKey('chat-team-meeting'),
              onPressed: () => _startTeamMeeting(context, ref, team),
              style: FilledButton.styleFrom(
                backgroundColor: team.meetingLive
                    ? Colors.green.withValues(alpha: 0.85)
                    : brandColor.withValues(alpha: 0.85),
              ),
              icon: const Icon(Icons.videocam_rounded, size: 18),
              label: Text(
                team.meetingLive ? l10n.joinTeamMeeting : l10n.startTeamMeeting,
              ),
            ),
            IconButton(
              key: const ValueKey('chat-team-members'),
              tooltip: l10n.teamMembersTitle,
              onPressed: () async {
                final left = await showTeamMembers(context, team);
                if (left) _close();
              },
              icon: const Icon(Icons.group_rounded),
            ),
          ] else ...[
            IconButton(
              key: const ValueKey('chat-call'),
              tooltip: l10n.videoCall,
              onPressed: () => _call(context, ref, friend!),
              icon: const Icon(Icons.videocam_rounded),
            ),
            PopupMenuButton<void>(
              key: const ValueKey('chat-friend-menu'),
              icon: const Icon(Icons.more_vert_rounded),
              itemBuilder: (_) => [
                PopupMenuItem<void>(
                  key: const ValueKey('chat-remove-friend'),
                  onTap: () => _removeFriend(context, ref, friend!),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_remove_rounded,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 10),
                      Text(l10n.removeFriend),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A call: someone started a meeting here, with a button to join it.
class _InviteBubble extends ConsumerWidget {
  const _InviteBubble({required this.message, required this.now});

  final SocialMessage message;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          // Flat, as the other messages.
          child: Container(
            key: ValueKey('invite-${message.id}'),
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: BoxDecoration(
              color: glassFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: glassStroke),
            ),
            child: Row(
              children: [
                const Icon(Icons.videocam_rounded, color: Colors.greenAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.mine
                            ? l10n.meetingInviteMine
                            : l10n.meetingInviteFrom(message.sender),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        message.timeLabel(now),
                        style: const TextStyle(color: glassMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  key: ValueKey('invite-join-${message.id}'),
                  onPressed: () =>
                      joinSocialMeeting(context, ref, message.roomId!),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.withValues(alpha: 0.85),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(l10n.joinTeamMeeting),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.now,
    required this.showSender,
  });

  final SocialMessage message;
  final DateTime now;
  final bool showSender;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final sender = message.sender;
    return Padding(
      padding: EdgeInsets.only(top: showSender ? 10 : 4),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: mine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (showSender)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          UserAvatar(
                            name: sender,
                            seed: sender,
                            avatarUrl: message.senderAvatarUrl,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            sender,
                            style: const TextStyle(
                              color: glassAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
                    decoration: BoxDecoration(
                      color: mine
                          ? brandColor.withValues(alpha: 0.75)
                          : glassFill,
                      border: Border.all(color: glassStroke),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: Radius.circular(mine ? 12 : 4),
                        bottomRight: Radius.circular(mine ? 4 : 12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SelectableText(
                          message.text,
                          style: const TextStyle(height: 1.3),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message.timeLabel(now),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The chat's even, opaque tone, on a computer's pane and a phone's
/// screen alike: nothing of the page's glow shows through.
const chatPaneColor = Color(0xFF1A1820);

/// Nothing chosen yet: shown in the right pane on a computer.
class ChatPlaceholder extends StatelessWidget {
  const ChatPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      key: const ValueKey('chat-placeholder'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 76,
              child: GlassSurface(
                shape: BoxShape.circle,
                tint: brandColor,
                child: Icon(Icons.forum_rounded, size: 36, color: Colors.white),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.chooseConversation,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.chooseConversationHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: glassMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// A conversation as a screen of its own, on a phone. It follows the
/// friend or team as the overview refreshes, and closes once they are gone.
class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key, required this.target});

  final ChatTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(socialOverviewProvider).value;
    final current = overview == null ? target : overview.current(target);
    void back() => Navigator.maybePop(context);
    if (current == null) {
      // Unfriended, or out of the team: nothing left to show.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) back();
      });
    }
    return Scaffold(
      // Flat, as the chat pane on a computer.
      backgroundColor: pageBackground,
      body: ColoredBox(
        color: chatPaneColor,
        child: SafeArea(
          child: current == null
              ? const SizedBox.shrink()
              : ChatPane(target: current, onBack: back),
        ),
      ),
    );
  }
}
