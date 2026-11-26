import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/theme.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/social/social_actions.dart';
import 'package:v_meeting/social/social_api.dart';
import 'package:v_meeting/social/social_models.dart';
import 'package:v_meeting/widgets/glass.dart';

/// The user's teams, each a glass card with its own room: a team with a
/// meeting going on can be joined, the others started.
class TeamsList extends StatelessWidget {
  const TeamsList({
    super.key,
    required this.teams,
    required this.onOpen,
    this.openId,
  });

  final List<Team> teams;

  /// Opens the team's conversation.
  final ValueChanged<ChatTarget> onOpen;

  /// The [ChatTarget.id] of the open conversation, to mark it.
  final String? openId;

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) {
      return Padding(
        key: const ValueKey('no-teams'),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Text(
          AppLocalizations.of(context)!.noTeamsYet,
          textAlign: TextAlign.center,
          style: const TextStyle(color: glassMuted, height: 1.4),
        ),
      );
    }
    final sorted = [...teams]
      ..sort((a, b) {
        if (a.meetingLive != b.meetingLive) return a.meetingLive ? -1 : 1;
        return b.onlineCount.compareTo(a.onlineCount);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        for (final team in sorted)
          _TeamCard(
            team: team,
            open: openId == ChatTarget.team(team).id,
            onOpen: () => onOpen(ChatTarget.team(team)),
          ),
      ],
    );
  }
}

class _TeamCard extends ConsumerWidget {
  const _TeamCard({
    required this.team,
    required this.open,
    required this.onOpen,
  });

  final Team team;
  final bool open;
  final VoidCallback onOpen;

  /// Joins the team's meeting, starting it when nobody is in it.
  Future<void> _startMeeting(BuildContext context, WidgetRef ref) async {
    String? roomId;
    final started = await runSocialAction(context, ref, () async {
      roomId = await ref.read(socialApiProvider).startTeamMeeting(team.id);
    });
    if (started && context.mounted) {
      await joinSocialMeeting(context, ref, roomId!);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final role = switch (team.role) {
      TeamRole.owner => l10n.teamRoleOwner,
      TeamRole.admin => l10n.teamRoleAdmin,
      TeamRole.member => null,
    };
    return GlassSurface(
      key: ValueKey('team-${team.id}'),
      radius: 12,
      shadow: false,
      tint: open ? brandColor.withValues(alpha: 0.5) : null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                TeamBadge(team: team, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              team.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15.5,
                              ),
                            ),
                          ),
                          if (role != null) ...[
                            const SizedBox(width: 8),
                            _RoleChip(label: role),
                          ],
                          if (team.unread > 0) ...[
                            const SizedBox(width: 8),
                            GlassCountBadge(
                              key: ValueKey('unread-team-${team.id}'),
                              count: team.unread,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (team.meetingLive)
                        Row(
                          children: [
                            const _LiveDot(),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                l10n.teamLive,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          '${l10n.teamMembers(team.memberCount)} · '
                          '${l10n.onlineCount(team.onlineCount)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: glassMuted,
                            fontSize: 12.5,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: ValueKey('team-meeting-${team.id}'),
                  onPressed: () => _startMeeting(context, ref),
                  style: FilledButton.styleFrom(
                    backgroundColor: team.meetingLive
                        ? Colors.green.withValues(alpha: 0.85)
                        : brandColor.withValues(alpha: 0.85),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    team.meetingLive
                        ? l10n.joinTeamMeeting
                        : l10n.startTeamMeeting,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: glassFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: glassStroke),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: glassAccent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A green dot that pulses, for a meeting going on now.
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Its own layer: the pulse repaints the dot alone, not the list.
    return RepaintBoundary(
      child: FadeTransition(
        opacity: Tween(begin: 0.35, end: 1.0).animate(_pulse),
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.greenAccent,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// A team's coloured glass square with its initials.
class TeamBadge extends StatelessWidget {
  const TeamBadge({super.key, required this.team, this.size = 52});

  final Team team;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: GlassSurface(
        radius: size * 0.22,
        tint: team.color,
        shadow: false,
        child: Center(
          child: Text(
            _initials(team.name),
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.34,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    return words
        .take(2)
        .map((word) => word.isEmpty ? '' : word.characters.first)
        .join()
        .toUpperCase();
  }
}
