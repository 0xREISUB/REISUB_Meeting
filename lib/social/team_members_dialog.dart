import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/social/presence_avatar.dart';
import 'package:v_meeting/social/social_actions.dart';
import 'package:v_meeting/social/social_api.dart';
import 'package:v_meeting/social/social_models.dart';
import 'package:v_meeting/widgets/glass.dart';

/// Shows the team's members, to add friends, remove members, leave or
/// delete the team, as the user's role allows. Answers whether the user is
/// no longer in the team.
Future<bool> showTeamMembers(BuildContext context, Team team) async {
  final gone = await showGlassDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      key: const ValueKey('team-members-dialog'),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(width: 440, height: 560, child: _TeamMembers(team: team)),
    ),
  );
  return gone ?? false;
}

class _TeamMembers extends ConsumerStatefulWidget {
  const _TeamMembers({required this.team});

  final Team team;

  @override
  ConsumerState<_TeamMembers> createState() => _TeamMembersState();
}

class _TeamMembersState extends ConsumerState<_TeamMembers> {
  late Future<List<TeamMemberInfo>> _members = _load();

  Future<List<TeamMemberInfo>> _load() =>
      ref.read(socialApiProvider).teamMembers(widget.team.id);

  void _reload() => setState(() => _members = _load());

  Future<void> _add(List<TeamMemberInfo> members) async {
    final l10n = AppLocalizations.of(context)!;
    final inTeam = {for (final member in members) member.person.nick};
    final friends = [
      for (final friend
          in ref.read(socialOverviewProvider).value?.friends ??
              const <Friend>[])
        if (!inTeam.contains(friend.nick)) friend,
    ];
    final friend = await showDialog<Friend>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.addTeamMember),
        children: [
          if (friends.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Text(
                l10n.noFriendsToAdd,
                style: const TextStyle(color: glassMuted),
              ),
            ),
          for (final friend in friends)
            SimpleDialogOption(
              key: ValueKey('add-member-${friend.id}'),
              onPressed: () => Navigator.pop(context, friend),
              child: Row(
                children: [
                  PresenceAvatar(
                    name: friend.displayName,
                    seed: friend.nick,
                    avatarUrl: friend.avatarUrl,
                    presence: friend.presence,
                    size: 34,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(friend.displayName)),
                ],
              ),
            ),
        ],
      ),
    );
    if (friend == null || !mounted) return;
    await runSocialAction(
      context,
      ref,
      () =>
          ref.read(socialApiProvider).addTeamMember(widget.team.id, friend.id),
    );
    _reload();
  }

  Future<void> _remove(TeamMemberInfo member) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await confirmSocial(
      context,
      title: l10n.removeFromTeam,
      body: member.person.displayName,
      action: l10n.remove,
    );
    if (!confirmed || !mounted) return;
    await runSocialAction(
      context,
      ref,
      () => ref
          .read(socialApiProvider)
          .removeTeamMember(widget.team.id, member.person.id),
    );
    _reload();
  }

  Future<void> _leave(TeamMemberInfo me) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await confirmSocial(
      context,
      title: l10n.leaveTeam,
      body: l10n.leaveTeamBody(widget.team.name),
      action: l10n.leave,
    );
    if (!confirmed || !mounted) return;
    final navigator = Navigator.of(context);
    final left = await runSocialAction(
      context,
      ref,
      () => ref
          .read(socialApiProvider)
          .removeTeamMember(widget.team.id, me.person.id),
    );
    if (left) navigator.pop(true);
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await confirmSocial(
      context,
      title: l10n.deleteTeam,
      body: l10n.deleteTeamBody(widget.team.name),
      action: l10n.deleteTeam,
    );
    if (!confirmed || !mounted) return;
    final navigator = Navigator.of(context);
    final deleted = await runSocialAction(
      context,
      ref,
      () => ref.read(socialApiProvider).deleteTeam(widget.team.id),
    );
    if (deleted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final myNick = ref.watch(socialOverviewProvider).value?.profile.nick;
    return FutureBuilder<List<TeamMemberInfo>>(
      future: _members,
      builder: (context, snapshot) {
        final members = snapshot.data;
        TeamMemberInfo? me;
        for (final member in members ?? const <TeamMemberInfo>[]) {
          if (member.person.nick == myNick) me = member;
        }
        final myRole = me?.role ?? widget.team.role;
        bool mayRemove(TeamMemberInfo member) =>
            member != me &&
            (myRole == TeamRole.owner ||
                (myRole == TeamRole.admin && member.role == TeamRole.member));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.team.name} · ${l10n.teamMembersTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const CloseButton(),
                ],
              ),
            ),
            Expanded(
              child: members == null
                  ? Center(
                      child: snapshot.hasError
                          ? Text(
                              l10n.socialLoadFailed,
                              style: const TextStyle(color: glassMuted),
                            )
                          : const CircularProgressIndicator(),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: [
                        if (myRole.manages)
                          ListTile(
                            key: const ValueKey('team-add-member'),
                            leading: const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: glassAccent,
                            ),
                            title: Text(l10n.addTeamMember),
                            onTap: () => _add(members),
                          ),
                        for (final member in members)
                          ListTile(
                            key: ValueKey('team-member-${member.person.id}'),
                            leading: PresenceAvatar(
                              name: member.person.displayName,
                              seed: member.person.nick,
                              avatarUrl: member.person.avatarUrl,
                              presence: member.person.presence,
                              size: 38,
                            ),
                            title: Text(
                              member == me
                                  ? '${member.person.displayName} (${l10n.you})'
                                  : member.person.displayName,
                            ),
                            subtitle: Text(switch (member.role) {
                              TeamRole.owner => l10n.teamRoleOwner,
                              TeamRole.admin => l10n.teamRoleAdmin,
                              TeamRole.member => '@${member.person.nick}',
                            }, style: const TextStyle(color: glassMuted)),
                            trailing: mayRemove(member)
                                ? IconButton(
                                    tooltip: l10n.removeFromTeam,
                                    onPressed: () => _remove(member),
                                    icon: const Icon(
                                      Icons.person_remove_rounded,
                                      color: Colors.redAccent,
                                    ),
                                  )
                                : null,
                          ),
                      ],
                    ),
            ),
            if (me != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('team-leave'),
                        onPressed: () => _leave(me!),
                        icon: const Icon(Icons.logout_rounded),
                        label: Text(l10n.leaveTeam),
                      ),
                    ),
                    if (myRole == TeamRole.owner) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          key: const ValueKey('team-delete'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _delete,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: Text(l10n.deleteTeam),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
