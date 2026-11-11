import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/l10n/localized_error.dart';
import 'package:v_meeting/meeting/meeting_member.dart';
import 'package:v_meeting/meeting/widgets/meeting_participant.dart';

/// How a permission looks in the permissions window.
extension MeetingPermissionText on MeetingPermission {
  IconData get icon => switch (this) {
    MeetingPermission.shareScreen => Icons.screen_share_rounded,
    MeetingPermission.muteOthers => Icons.mic_off_rounded,
    MeetingPermission.requestUnmute => Icons.record_voice_over_rounded,
    MeetingPermission.admitMembers => Icons.how_to_reg_rounded,
    MeetingPermission.removeMembers => Icons.person_remove_rounded,
    MeetingPermission.endMeeting => Icons.call_end_rounded,
    MeetingPermission.grantPermissions => Icons.admin_panel_settings_rounded,
  };

  String title(AppLocalizations l10n) => switch (this) {
    MeetingPermission.shareScreen => l10n.permissionShareScreen,
    MeetingPermission.muteOthers => l10n.permissionMuteOthers,
    MeetingPermission.requestUnmute => l10n.permissionRequestUnmute,
    MeetingPermission.admitMembers => l10n.permissionAdmitMembers,
    MeetingPermission.removeMembers => l10n.permissionRemoveMembers,
    MeetingPermission.endMeeting => l10n.permissionEndMeeting,
    MeetingPermission.grantPermissions => l10n.permissionGrant,
  };

  String hint(AppLocalizations l10n) => switch (this) {
    MeetingPermission.shareScreen => l10n.permissionShareScreenHint,
    MeetingPermission.muteOthers => l10n.permissionMuteOthersHint,
    MeetingPermission.requestUnmute => l10n.permissionRequestUnmuteHint,
    MeetingPermission.admitMembers => l10n.permissionAdmitMembersHint,
    MeetingPermission.removeMembers => l10n.permissionRemoveMembersHint,
    MeetingPermission.endMeeting => l10n.permissionEndMeetingHint,
    MeetingPermission.grantPermissions => l10n.permissionGrantHint,
  };
}

const _dialogColor = Color(0xFF1C1C1E);
const _surface = Color(0xFF2C2C2E);
const _accent = Color(0xFFB69BFF);

/// Gives or takes back one permission; throws the server's error.
typedef PermissionChange =
    Future<void> Function(
      MemberEntry member,
      MeetingPermission permission,
      bool on,
    );

/// Opens the permissions window from the meeting's menu. [members] is read
/// again whenever [listenable] changes, so the window follows the meeting.
Future<void> showPermissionsDialog(
  BuildContext context, {
  required Listenable listenable,
  required List<MemberEntry> Function() members,
  required bool Function(MemberEntry member) canChange,
  required PermissionChange onChanged,
  Future<void> Function(MemberEntry member)? onTransferOwnership,
}) {
  final narrow = MediaQuery.sizeOf(context).width < 640;
  final dialog = ListenableBuilder(
    listenable: listenable,
    builder: (context, _) => PermissionsDialog(
      members: members(),
      canChange: canChange,
      onChanged: onChanged,
      onTransferOwnership: onTransferOwnership,
    ),
  );
  return showDialog<void>(
    context: context,
    builder: (context) => narrow
        ? Dialog.fullscreen(backgroundColor: _dialogColor, child: dialog)
        : Dialog(
            backgroundColor: _dialogColor,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: SizedBox(width: 820, height: 560, child: dialog),
          ),
  );
}

/// The permissions window: members on the left with a search box, the
/// chosen member's permissions on the right. On a phone the two sides are
/// separate steps.
class PermissionsDialog extends StatefulWidget {
  const PermissionsDialog({
    super.key,
    required this.members,
    required this.canChange,
    required this.onChanged,
    this.onTransferOwnership,
    this.initialSelectionId,
  });

  final List<MemberEntry> members;

  /// Whether the viewer may change [member]'s permissions.
  final bool Function(MemberEntry member) canChange;
  final PermissionChange onChanged;

  /// Only for the full admin, who can hand the role to someone else.
  final Future<void> Function(MemberEntry member)? onTransferOwnership;
  final String? initialSelectionId;

  @override
  State<PermissionsDialog> createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<PermissionsDialog> {
  late String? _selectedId = widget.initialSelectionId;
  String _query = '';
  Object? _error;

  /// Switches flipped here and not yet confirmed by the server, by member.
  /// They show at once and give way to the server's value when it arrives.
  final _pending = <String, Map<MeetingPermission, bool>>{};

  @override
  void didUpdateWidget(PermissionsDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Drop guesses the server has confirmed.
    for (final member in widget.members) {
      _pending[member.id]?.removeWhere(
        (permission, on) =>
            member.grantedPermissions.contains(permission) == on,
      );
    }
    _pending.removeWhere((_, changes) => changes.isEmpty);
  }

  Set<MeetingPermission> _permissionsOf(MemberEntry member) {
    final changes = _pending[member.id];
    if (changes == null || member.role == MeetingRole.owner) {
      return member.permissions;
    }
    return {
      for (final permission in MeetingPermission.values)
        if (changes[permission] ??
            member.grantedPermissions.contains(permission))
          permission,
    };
  }

  Future<void> _change(
    MemberEntry member,
    MeetingPermission permission,
    bool on,
  ) async {
    setState(() {
      _error = null;
      (_pending[member.id] ??= {})[permission] = on;
    });
    try {
      await widget.onChanged(member, permission, on);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _pending[member.id]?.remove(permission);
      });
    }
  }

  Future<void> _transfer(MemberEntry member) async {
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
    if (confirmed != true || !mounted) return;
    setState(() => _error = null);
    try {
      await widget.onTransferOwnership!(member);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  MemberEntry? get _selected {
    for (final member in widget.members) {
      if (member.id == _selectedId) return member;
    }
    return null;
  }

  List<MemberEntry> get _visibleMembers {
    final query = _query.trim().toLowerCase();
    final members = [
      for (final member in widget.members)
        if (query.isEmpty || member.name.toLowerCase().contains(query)) member,
    ];
    // The full admin first, then you, then everyone else by name.
    int rank(MemberEntry member) => member.role == MeetingRole.owner
        ? 0
        : member.isLocal
        ? 1
        : 2;
    members.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0
          ? byRank
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return members;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final selected = _selected;
        final list = _MemberList(
          members: _visibleMembers,
          selectedId: wide ? _selectedId : null,
          permissionsOf: _permissionsOf,
          onSearch: (value) => setState(() => _query = value),
          onSelect: (member) => setState(() {
            _selectedId = member.id;
            _error = null;
          }),
          onClose: () => Navigator.of(context).pop(),
        );
        Widget detail(MemberEntry member) => _MemberPermissions(
          key: ValueKey('permissions-${member.id}'),
          member: member,
          isOwner: member.role == MeetingRole.owner,
          permissions: _permissionsOf(member),
          error: _error,
          onChanged: widget.canChange(member)
              ? (permission, on) => _change(member, permission, on)
              : null,
          onTransferOwnership:
              widget.onTransferOwnership == null ||
                  member.role == MeetingRole.owner ||
                  member.isLocal ||
                  member.identity.isEmpty
              ? null
              : () => _transfer(member),
          onBack: wide ? null : () => setState(() => _selectedId = null),
        );
        if (!wide) return selected == null ? list : detail(selected);
        return Row(
          children: [
            SizedBox(width: 300, child: list),
            const VerticalDivider(width: 1, color: Colors.white12),
            Expanded(
              child: selected == null
                  ? const _NothingSelected()
                  : detail(selected),
            ),
          ],
        );
      },
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({
    required this.members,
    required this.selectedId,
    required this.permissionsOf,
    required this.onSearch,
    required this.onSelect,
    required this.onClose,
  });

  final List<MemberEntry> members;
  final String? selectedId;
  final Set<MeetingPermission> Function(MemberEntry member) permissionsOf;
  final ValueChanged<String> onSearch;
  final ValueChanged<MemberEntry> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 8, 8),
          child: Row(
            children: [
              const Icon(
                Icons.admin_panel_settings_rounded,
                color: _accent,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.permissionsTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('permissions-close'),
                tooltip: l10n.close,
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            key: const ValueKey('permissions-search'),
            onChanged: onSearch,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: l10n.searchMembers,
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Colors.white54,
              ),
              filled: true,
              fillColor: _surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: members.isEmpty
              ? Center(
                  child: Text(
                    l10n.noMembersFound,
                    style: const TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final isOwner = member.role == MeetingRole.owner;
                    final count = permissionsOf(member).length;
                    return _MemberRow(
                      member: member,
                      selected: member.id == selectedId,
                      subtitle: isOwner
                          ? l10n.roleOwner
                          : l10n.permissionCount(count),
                      isOwner: isOwner,
                      hasDangerous:
                          !isOwner &&
                          permissionsOf(member).any((p) => p.isDangerous),
                      onTap: () => onSelect(member),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.selected,
    required this.subtitle,
    required this.isOwner,
    required this.hasDangerous,
    required this.onTap,
  });

  final MemberEntry member;
  final bool selected;
  final String subtitle;
  final bool isOwner;
  final bool hasDangerous;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? _accent.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('permissions-member-${member.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                MemberAvatar(
                  name: member.name,
                  seed: member.identity.isEmpty ? member.name : member.identity,
                  size: 38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.isLocal
                            ? '${member.name} (${l10n.you})'
                            : member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (isOwner) ...[
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                          ] else if (hasDangerous) ...[
                            const Icon(
                              Icons.circle,
                              size: 7,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isOwner ? Colors.amber : Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.chevron_right_rounded, color: _accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NothingSelected extends StatelessWidget {
  const _NothingSelected();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.admin_panel_settings_outlined,
            size: 56,
            color: Colors.white24,
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.selectMemberForPermissions,
            style: const TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _MemberPermissions extends StatelessWidget {
  const _MemberPermissions({
    super.key,
    required this.member,
    required this.isOwner,
    required this.permissions,
    required this.error,
    required this.onChanged,
    required this.onTransferOwnership,
    required this.onBack,
  });

  final MemberEntry member;
  final bool isOwner;
  final Set<MeetingPermission> permissions;

  /// The last failed change, shown above the switches.
  final Object? error;

  /// Null when the viewer may not change this member's permissions.
  final void Function(MeetingPermission permission, bool on)? onChanged;
  final VoidCallback? onTransferOwnership;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final editable = onChanged != null && !isOwner && !member.isLocal;
    final note = isOwner
        ? l10n.ownerHasAllPermissions
        : member.isLocal
        ? l10n.cannotChangeOwnPermissions
        : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        Row(
          children: [
            if (onBack != null) ...[
              IconButton(
                key: const ValueKey('permissions-back'),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              const SizedBox(width: 4),
            ],
            MemberAvatar(
              name: member.name,
              seed: member.identity.isEmpty ? member.name : member.identity,
              size: 52,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.isLocal
                        ? '${member.name} (${l10n.you})'
                        : member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isOwner) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.roleOwner,
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (note != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Colors.white54,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    note,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 16),
          Text(
            localizeError(error!, l10n),
            key: const ValueKey('permissions-error'),
            style: const TextStyle(color: Colors.redAccent),
          ),
        ],
        const SizedBox(height: 16),
        // A Material, so the switches' ink shows on it.
        Material(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final permission in MeetingPermission.values) ...[
                if (permission != MeetingPermission.values.first)
                  const Divider(height: 1, indent: 56, color: Colors.white10),
                _PermissionTile(
                  permission: permission,
                  value: isOwner || permissions.contains(permission),
                  onChanged: editable
                      ? (on) => onChanged!(permission, on)
                      : null,
                ),
              ],
            ],
          ),
        ),
        if (onTransferOwnership != null) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            key: const ValueKey('permissions-transfer'),
            onPressed: onTransferOwnership,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amber,
              side: const BorderSide(color: Colors.amber),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.star_rounded),
            label: Text(l10n.transferOwnership),
          ),
        ],
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.permission,
    required this.value,
    required this.onChanged,
  });

  final MeetingPermission permission;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final danger = permission.isDangerous;
    final color = danger ? Colors.redAccent : Colors.white;
    return SwitchListTile(
      key: ValueKey('permission-${permission.name}'),
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: Icon(permission.icon, color: danger ? color : Colors.white70),
      activeThumbColor: Colors.white,
      activeTrackColor: danger ? Colors.redAccent : const Color(0xFF8A5CFF),
      title: Text(
        permission.title(l10n),
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        permission.hint(l10n),
        style: TextStyle(
          color: danger
              ? Colors.redAccent.withValues(alpha: 0.75)
              : Colors.white54,
          fontSize: 12,
        ),
      ),
    );
  }
}
