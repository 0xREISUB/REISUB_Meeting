import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/l10n/localized_error.dart';
import 'package:v_meeting/meeting/meeting_member.dart';

typedef MicrophoneModerationCallback =
    Future<void> Function(MemberEntry member, bool locked, bool requestUnmute);
typedef RoleChangeCallback =
    Future<void> Function(MemberEntry member, MeetingRole role);
typedef MemberCallback = Future<void> Function(MemberEntry member);

enum _MemberAction {
  lock,
  unlock,
  requestUnmute,
  makeOwner,
  makeModerator,
  makeParticipant,
  transferOwnership,
}

/// Live participants with their roles. Admins get microphone controls for
/// the people they may moderate; full admins can also change roles.
class MembersScreen extends StatefulWidget {
  final List<String> names;
  final List<MemberEntry>? members;
  final MeetingRole viewerRole;
  final MicrophoneModerationCallback? onMicrophoneChange;
  final RoleChangeCallback? onRoleChange;
  final MemberCallback? onTransferOwnership;

  const MembersScreen({
    super.key,
    this.names = const [],
    this.members,
    this.viewerRole = MeetingRole.participant,
    this.onMicrophoneChange,
    this.onRoleChange,
    this.onTransferOwnership,
  });

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final Set<String> _busy = {};
  Object? _error;

  bool _canModerateMicrophone(MemberEntry member) =>
      widget.onMicrophoneChange != null &&
      canModerateMember(widget.viewerRole, member);

  bool _canManageRole(MemberEntry member) =>
      widget.viewerRole == MeetingRole.owner &&
      !member.isLocal &&
      member.identity.isNotEmpty &&
      widget.onRoleChange != null;

  Future<void> _run(MemberEntry member, _MemberAction action) async {
    if (_busy.contains(member.identity)) return;
    if (action == _MemberAction.transferOwnership &&
        !await _confirmTransfer(member)) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy.add(member.identity);
      _error = null;
    });
    try {
      await switch (action) {
        _MemberAction.lock => widget.onMicrophoneChange!(member, true, false),
        _MemberAction.unlock => widget.onMicrophoneChange!(
          member,
          false,
          false,
        ),
        _MemberAction.requestUnmute => widget.onMicrophoneChange!(
          member,
          false,
          true,
        ),
        _MemberAction.makeOwner => widget.onRoleChange!(
          member,
          MeetingRole.owner,
        ),
        _MemberAction.makeModerator => widget.onRoleChange!(
          member,
          MeetingRole.moderator,
        ),
        _MemberAction.makeParticipant => widget.onRoleChange!(
          member,
          MeetingRole.participant,
        ),
        _MemberAction.transferOwnership =>
          widget.onTransferOwnership?.call(member) ?? Future<void>.value(),
      };
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy.remove(member.identity));
    }
  }

  Future<bool> _confirmTransfer(MemberEntry member) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.transferOwnershipTitle),
        content: Text(l10n.transferOwnershipBody(member.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirm-transfer'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.transfer),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  List<PopupMenuEntry<_MemberAction>> _menuItems(
    MemberEntry member,
    AppLocalizations l10n,
  ) {
    PopupMenuItem<_MemberAction> item(_MemberAction value, String text) =>
        PopupMenuItem(
          value: value,
          child: Text(text, style: const TextStyle(color: Colors.white)),
        );
    final microphone = _canModerateMicrophone(member);
    final roles = _canManageRole(member);
    return [
      if (microphone) ...[
        if (member.isMicrophoneLocked)
          item(_MemberAction.unlock, l10n.unlockMicrophone)
        else
          item(_MemberAction.lock, l10n.lockMicrophone),
        item(
          _MemberAction.requestUnmute,
          member.isMicrophoneLocked
              ? l10n.unlockAndRequestMicrophone
              : l10n.requestMicrophone,
        ),
      ],
      if (microphone && roles) const PopupMenuDivider(),
      if (roles) ...[
        if (member.role != MeetingRole.owner)
          item(_MemberAction.makeOwner, l10n.makeOwner),
        if (member.role != MeetingRole.moderator)
          item(_MemberAction.makeModerator, l10n.makeModerator),
        if (member.role != MeetingRole.participant)
          item(_MemberAction.makeParticipant, l10n.removeAdminRole),
        if (widget.onTransferOwnership != null)
          item(_MemberAction.transferOwnership, l10n.transferOwnership),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final members = widget.members;
    final names =
        members?.map((member) => member.name).toList() ?? widget.names;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.membersTitle} (${names.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const CloseButton(color: Colors.white70),
              ],
            ),
          ),
          const Divider(height: 24, color: Colors.white12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                localizeError(_error!, l10n),
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: names.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Colors.white12),
              itemBuilder: (context, index) {
                final member = members?[index];
                final hasActions =
                    member != null &&
                    (_canModerateMicrophone(member) || _canManageRole(member));
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      if (member != null) ...[
                        Icon(
                          member.isMicrophoneLocked
                              ? Icons.lock_rounded
                              : member.isMicEnabled
                              ? Icons.mic_rounded
                              : Icons.mic_off_rounded,
                          size: 18,
                          color: member.isMicrophoneLocked
                              ? Colors.orangeAccent
                              : Colors.white54,
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          names[index],
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (member != null && member.role.canModerate)
                        _RoleBadge(role: member.role),
                      if (hasActions)
                        if (_busy.contains(member.identity))
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else
                          PopupMenuButton<_MemberAction>(
                            key: ValueKey('moderate-${member.identity}'),
                            tooltip: l10n.participantActions,
                            color: const Color(0xFF2C2C2E),
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: Colors.white70,
                            ),
                            onSelected: (action) => _run(member, action),
                            itemBuilder: (_) => _menuItems(member, l10n),
                          ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final MeetingRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final owner = role == MeetingRole.owner;
    final color = owner ? const Color(0xFFFFC857) : const Color(0xFFB69BFF);
    return Container(
      key: ValueKey('role-badge-${role.name}'),
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            owner ? Icons.star_rounded : Icons.shield_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            owner ? l10n.roleOwner : l10n.roleModerator,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
