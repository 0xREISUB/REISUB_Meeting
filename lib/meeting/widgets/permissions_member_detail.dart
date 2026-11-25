import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/l10n/localized_error.dart';
import 'package:v_meeting/meeting/meeting_member.dart';
import 'package:v_meeting/meeting/widgets/meeting_participant.dart';
import 'package:v_meeting/meeting/widgets/permissions_dialog.dart';
import 'package:v_meeting/meeting/widgets/permissions_colors.dart';

class MemberPermissionsDetail extends StatelessWidget {
  const MemberPermissionsDetail({
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
              color: permissionsSurface,
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
          color: permissionsSurface,
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
