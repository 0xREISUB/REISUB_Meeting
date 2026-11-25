import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/meeting_member.dart';
import 'package:v_meeting/meeting/widgets/permissions_member_list.dart';
import 'package:v_meeting/meeting/widgets/permissions_member_detail.dart';
import 'package:v_meeting/widgets/glass.dart';
import 'package:v_meeting/meeting/widgets/meeting_dialog.dart';

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

/// Smoked glass; the page behind is blurred by [showGlassDialog].
const _dialogColor = Color(0xE01C1A22);

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
  return showMeetingDialog<void>(
    context: context,
    builder: (context) => narrow
        ? Dialog.fullscreen(backgroundColor: _dialogColor, child: dialog)
        : Dialog(
            backgroundColor: _dialogColor,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
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
    final confirmed = await showMeetingDialog<bool>(
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
        final list = PermissionsMemberList(
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
        Widget detail(MemberEntry member) => MemberPermissionsDetail(
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
                  ? const PermissionsNothingSelected()
                  : detail(selected),
            ),
          ],
        );
      },
    );
  }
}
