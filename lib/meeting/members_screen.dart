import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/l10n/localized_error.dart';
import 'package:v_meeting/meeting/meeting_member.dart';

typedef MicrophoneModerationCallback =
    Future<void> Function(MemberEntry member, bool locked, bool requestUnmute);
typedef MemberCallback = Future<void> Function(MemberEntry member);

enum _MemberAction { lock, unlock, requestUnmute, remove }

/// Live participants, with the full admin marked. People who may mute
/// others or ask them to unmute get those controls; permissions themselves
/// are managed in the permissions window.
class MembersScreen extends StatefulWidget {
  final List<String> names;
  final List<MemberEntry>? members;

  /// What the viewer may do; decides which controls appear.
  final Set<MeetingPermission> viewerPermissions;
  final MicrophoneModerationCallback? onMicrophoneChange;

  /// Removes someone from the meeting for good.
  final MemberCallback? onRemove;

  const MembersScreen({
    super.key,
    this.names = const [],
    this.members,
    this.viewerPermissions = const {},
    this.onMicrophoneChange,
    this.onRemove,
  });

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final Set<String> _busy = {};
  Object? _error;

  bool get _canMute =>
      widget.viewerPermissions.contains(MeetingPermission.muteOthers);
  bool get _canRequestUnmute =>
      widget.viewerPermissions.contains(MeetingPermission.requestUnmute);
  bool get _canRemove =>
      widget.onRemove != null &&
      widget.viewerPermissions.contains(MeetingPermission.removeMembers);

  bool _canModerateMicrophone(MemberEntry member) =>
      widget.onMicrophoneChange != null &&
      canModerateMember(widget.viewerPermissions, member);

  Future<bool> _confirmRemove(MemberEntry member) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeMemberTitle(member.name)),
        content: Text(l10n.removeMemberBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('confirm-remove'),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _run(MemberEntry member, _MemberAction action) async {
    if (_busy.contains(member.identity)) return;
    if (action == _MemberAction.remove && !await _confirmRemove(member)) {
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
        _MemberAction.remove => widget.onRemove!(member),
      };
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy.remove(member.identity));
    }
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
    if (!canModerateMember(widget.viewerPermissions, member)) return [];
    final microphone = _canModerateMicrophone(member);
    return [
      if (microphone && _canMute)
        if (member.isMicrophoneLocked)
          item(_MemberAction.unlock, l10n.unlockMicrophone)
        else
          item(_MemberAction.lock, l10n.lockMicrophone),
      // Asking a locked person to unmute also unlocks them.
      if (microphone &&
          _canRequestUnmute &&
          (_canMute || !member.isMicrophoneLocked))
        item(
          _MemberAction.requestUnmute,
          member.isMicrophoneLocked
              ? l10n.unlockAndRequestMicrophone
              : l10n.requestMicrophone,
        ),
      if (_canRemove) ...[
        if (microphone && (_canMute || _canRequestUnmute))
          const PopupMenuDivider(),
        PopupMenuItem(
          value: _MemberAction.remove,
          child: Row(
            children: [
              const Icon(
                Icons.person_remove_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  l10n.removeFromMeeting,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ),
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
                    member != null && _menuItems(member, l10n).isNotEmpty;
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
                      if (member != null && member.role == MeetingRole.owner)
                        const _OwnerBadge(),
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

class _OwnerBadge extends StatelessWidget {
  const _OwnerBadge();

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFFFC857);
    return Container(
      key: const ValueKey('role-badge-owner'),
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context)!.roleOwner,
            style: const TextStyle(
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
