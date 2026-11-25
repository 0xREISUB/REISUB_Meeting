import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/social/chat_pane.dart';
import 'package:v_meeting/social/friends_list.dart';
import 'package:v_meeting/social/presence_avatar.dart';
import 'package:v_meeting/social/profile_screen.dart';
import 'package:v_meeting/social/social_models.dart';
import 'package:v_meeting/social/teams_list.dart';
import 'package:v_meeting/widgets/glass.dart';

/// The social tab for a logged-in user: the profile on top, then friends or
/// teams.
class SocialHome extends ConsumerStatefulWidget {
  const SocialHome({super.key});

  @override
  ConsumerState<SocialHome> createState() => _SocialHomeState();
}

class _SocialHomeState extends ConsumerState<SocialHome> {
  static const _friends = 0;

  /// Wider than this, the social tab is two panes, as a chat app.
  static const _wideWidth = 840.0;

  var _section = _friends;

  /// The conversation open in the right pane, on a computer.
  ChatTarget? _open;

  void _openChat(ChatTarget target, bool wide) {
    if (wide) {
      setState(() => _open = target);
      return;
    }
    final messages = ref.read(socialOverviewProvider).conversations;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(target: target, messages: messages[target.id] ?? []),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideWidth;
        final list = _list(context, wide);
        if (!wide) {
          return SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: list,
              ),
            ),
          );
        }
        final open = _open;
        final messages = ref.watch(socialOverviewProvider).conversations;
        return SafeArea(
          bottom: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 400, child: list),
              Expanded(
                child: Padding(
                  // Clear of the bottom bar, which floats over the list.
                  padding: EdgeInsets.fromLTRB(
                    4,
                    16,
                    20,
                    16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: GlassSurface(
                    key: const ValueKey('social-chat-pane'),
                    radius: 16,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: open == null
                          ? const ChatPlaceholder()
                          : ChatPane(
                              key: ValueKey('pane-${open.id}'),
                              target: open,
                              messages: messages[open.id] ?? const [],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The profile, then friends or teams.
  Widget _list(BuildContext context, bool wide) {
    final l10n = AppLocalizations.of(context)!;
    final overview = ref.watch(socialOverviewProvider);
    return ListView(
      key: const ValueKey('social-list'),
      padding: EdgeInsets.fromLTRB(
        wide ? 20 : 16,
        12,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  l10n.social,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            GlassIconButton(
              key: const ValueKey('social-add'),
              size: 44,
              iconSize: 22,
              tooltip: _section == _friends ? l10n.addFriend : l10n.createTeam,
              icon: _section == _friends
                  ? Icons.person_add_alt_1_rounded
                  : Icons.group_add_rounded,
              onPressed: () => showSocialComingSoon(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ProfileCard(profile: overview.profile),
        if (overview.isPreview) ...[
          const SizedBox(height: 10),
          Row(
            key: const ValueKey('social-preview-note'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.visibility_outlined,
                size: 14,
                color: glassMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.socialPreviewNote,
                  style: const TextStyle(color: glassMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        GlassSegmented(
          labels: [l10n.friends, l10n.teams],
          selectedIndex: _section,
          badges: {_friends: overview.requests.length},
          onSelected: (section) => setState(() => _section = section),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, ?current],
          ),
          child: _section == _friends
              ? FriendsList(
                  key: const ValueKey('friends'),
                  friends: overview.friends,
                  requests: overview.requests,
                  openId: _open?.id,
                  onOpen: (target) => _openChat(target, wide),
                )
              : TeamsList(
                  key: const ValueKey('teams'),
                  teams: overview.teams,
                  openId: _open?.id,
                  onOpen: (target) => _openChat(target, wide),
                ),
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final SocialProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GlassSurface(
      key: const ValueKey('social-profile'),
      radius: 14,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => showProfile(context, profile),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                PresenceAvatar(
                  name: profile.displayName,
                  seed: profile.nick,
                  presence: profile.presence,
                  size: 56,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${profile.nick} · ${profile.presence.label(l10n)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: glassMuted, fontSize: 13),
                      ),
                      if (profile.statusMessage.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          profile.statusMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: glassMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
