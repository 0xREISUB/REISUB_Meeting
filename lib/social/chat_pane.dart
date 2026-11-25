import 'package:flutter/material.dart';
import 'package:v_meeting/app/theme.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/widgets/participant_tile.dart';
import 'package:v_meeting/social/presence_avatar.dart';
import 'package:v_meeting/social/social_models.dart';
import 'package:v_meeting/social/teams_list.dart';
import 'package:v_meeting/widgets/glass.dart';

/// A conversation with a friend or a team: who it is with on top, the
/// messages, and a box to write. On a computer it is the right pane of the
/// social tab; on a phone a screen of its own, with [onBack].
class ChatPane extends StatefulWidget {
  const ChatPane({
    super.key,
    required this.target,
    required this.messages,
    this.onBack,
  });

  final ChatTarget target;
  final List<SocialMessage> messages;
  final VoidCallback? onBack;

  @override
  State<ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<ChatPane> {
  final _draft = TextEditingController();

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final messages = widget.messages;
    return Column(
      key: ValueKey('chat-${widget.target.id}'),
      children: [
        _ChatHeader(target: widget.target, onBack: widget.onBack),
        const Divider(height: 1, color: Color(0x14FFFFFF)),
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Text(
                    l10n.noMessagesYet,
                    style: const TextStyle(color: glassMuted),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    final previous = index + 1 < messages.length
                        ? messages[messages.length - 2 - index]
                        : null;
                    return _Bubble(
                      message: message,
                      // A team's messages say who wrote them, once per run.
                      showSender:
                          widget.target.team != null &&
                          !message.mine &&
                          previous?.sender != message.sender,
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
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => showSocialComingSoon(context),
                  decoration: InputDecoration(
                    hintText: l10n.messageHint,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: glassStroke),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: glassStroke),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
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
                onPressed: () => showSocialComingSoon(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.target, this.onBack});

  final ChatTarget target;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
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
      padding: EdgeInsets.fromLTRB(onBack == null ? 16 : 4, 10, 10, 10),
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
          if (team != null)
            FilledButton.icon(
              onPressed: () => showSocialComingSoon(context),
              style: FilledButton.styleFrom(
                backgroundColor: team.meetingLive
                    ? Colors.green.withValues(alpha: 0.85)
                    : brandColor.withValues(alpha: 0.85),
              ),
              icon: const Icon(Icons.videocam_rounded, size: 18),
              label: Text(
                team.meetingLive ? l10n.joinTeamMeeting : l10n.startTeamMeeting,
              ),
            )
          else ...[
            IconButton(
              tooltip: l10n.callFriend,
              onPressed: () => showSocialComingSoon(context),
              icon: const Icon(Icons.call_rounded),
            ),
            IconButton(
              tooltip: l10n.videoCall,
              onPressed: () => showSocialComingSoon(context),
              icon: const Icon(Icons.videocam_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.showSender});

  final SocialMessage message;
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
                  if (showSender && sender != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MemberAvatar(
                            name: sender,
                            seed: sender,
                            size: 18,
                            fitTile: false,
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
                        bottomLeft: Radius.circular(mine ? 18 : 4),
                        bottomRight: Radius.circular(mine ? 4 : 18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(message.text, style: const TextStyle(height: 1.3)),
                        const SizedBox(height: 2),
                        Text(
                          message.time,
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

/// A conversation as a screen of its own, on a phone.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, required this.target, required this.messages});

  final ChatTarget target;
  final List<SocialMessage> messages;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GlassBackground(
        child: SafeArea(
          child: ChatPane(
            target: target,
            messages: messages,
            onBack: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }
}
