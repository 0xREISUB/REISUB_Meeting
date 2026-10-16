import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'widgets/meeting_participant.dart';

typedef MicrophoneModerationCallback =
    Future<void> Function(MemberEntry member, bool locked, bool requestUnmute);

/// Live participant names, with owner-only microphone controls.
class MembersScreen extends StatefulWidget {
  final List<String> names;
  final List<MemberEntry>? members;
  final bool isHost;
  final MicrophoneModerationCallback? onMicrophoneChange;

  const MembersScreen({
    super.key,
    this.names = const [],
    this.members,
    this.isHost = false,
    this.onMicrophoneChange,
  });

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final Set<String> _busy = {};
  String? _error;

  Future<void> _moderate(MemberEntry member, String action) async {
    if (_busy.contains(member.identity)) return;
    setState(() {
      _busy.add(member.identity);
      _error = null;
    });
    try {
      await widget.onMicrophoneChange?.call(
        member,
        action == 'lock',
        action == 'request',
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy.remove(member.identity));
    }
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
                _error!,
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
                final canModerate =
                    widget.isHost &&
                    widget.onMicrophoneChange != null &&
                    member != null &&
                    !member.isLocal &&
                    member.identity.isNotEmpty;
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (canModerate)
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
                          PopupMenuButton<String>(
                            key: ValueKey('moderate-${member.identity}'),
                            tooltip: 'Mikrofon yönetimi',
                            color: const Color(0xFF2C2C2E),
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: Colors.white70,
                            ),
                            onSelected: (action) => _moderate(member, action),
                            itemBuilder: (_) => [
                              if (member.isMicrophoneLocked)
                                const PopupMenuItem(
                                  value: 'unlock',
                                  child: Text(
                                    'Mikrofon kilidini kaldır',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                )
                              else
                                const PopupMenuItem(
                                  value: 'lock',
                                  child: Text(
                                    'Mikrofonu kapat ve kilitle',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              PopupMenuItem(
                                value: 'request',
                                child: Text(
                                  member.isMicrophoneLocked
                                      ? 'Kilidi kaldır ve açmasını iste'
                                      : 'Mikrofonu açmasını iste',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
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
