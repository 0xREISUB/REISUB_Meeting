import 'package:material_ui/material_ui.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/meeting_member.dart';
import 'package:v_meeting/meeting/widgets/permissions_colors.dart';
import 'package:v_meeting/social/user_avatar.dart';

class PermissionsMemberList extends StatelessWidget {
  const PermissionsMemberList({
    super.key,
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
                color: permissionsAccent,
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
              fillColor: permissionsSurface,
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
        color: selected
            ? permissionsAccent.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('permissions-member-${member.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                UserAvatar(
                  name: member.name,
                  seed: member.identity.isEmpty ? member.name : member.identity,
                  avatarUrl: member.avatarUrl,
                  size: 38,
                  fitTile: true,
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
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: permissionsAccent,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PermissionsNothingSelected extends StatelessWidget {
  const PermissionsNothingSelected({super.key});

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
