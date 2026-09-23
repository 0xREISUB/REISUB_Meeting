import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'widgets/meeting_components.dart';

class MemberEntry {
  final String name;
  final bool isLocal;
  final bool isMicEnabled;
  final VideoTrack? videoTrack;

  const MemberEntry({
    required this.name,
    required this.isLocal,
    required this.isMicEnabled,
    this.videoTrack,
  });
}

class MembersScreen extends StatefulWidget {
  final int totalMembers;
  final List<MemberEntry>? members;

  const MembersScreen({
    super.key,
    required this.totalMembers,
    this.members,
  });

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  static const int _perPage = 12;
  static const int _columns = 4;
  late int _totalMembers = widget.totalMembers.clamp(1, 100);
  int _currentPage = 0;

  bool get _hasLiveMembers => widget.members != null;

  int get _memberCount => widget.members?.length ?? _totalMembers;

  int get _totalPages => (_memberCount / _perPage).ceil().clamp(1, 100);

  List<MemberEntry> _entries(AppLocalizations l10n) {
    final liveMembers = widget.members;
    if (liveMembers != null && liveMembers.isNotEmpty) return liveMembers;

    return List.generate(
      _totalMembers,
      (index) => MemberEntry(
        name: l10n.userName(index + 1),
        isLocal: index == 0,
        isMicEnabled: index == 0,
      ),
    );
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _totalPages) return;
    setState(() => _currentPage = page);
  }

  void _setTotalMembers(int value) {
    if (_hasLiveMembers) return;
    setState(() {
      _totalMembers = value.clamp(1, 100);
      if (_currentPage >= _totalPages) {
        _currentPage = _totalPages - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = _entries(l10n);
    final totalPages = _totalPages;
    final page = _currentPage.clamp(0, totalPages - 1);
    final start = page * _perPage;
    final end = (start + _perPage).clamp(0, entries.length);
    final visibleEntries = entries.sublist(start, end);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RoundIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.membersTitle,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          l10n.membersHeader(
                            entries.length,
                            page + 1,
                            totalPages,
                          ),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_hasLiveMembers)
                _LiveMemberSummary(count: entries.length)
              else
                _DemoMemberSlider(
                  totalMembers: _totalMembers,
                  totalPages: totalPages,
                  onChanged: _setTotalMembers,
                ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: visibleEntries.isEmpty
                          ? const Center(
                              child: Text(
                                'Henüz katılımcı yok',
                                style: TextStyle(color: Colors.white54),
                              ),
                            )
                          : GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _columns,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 10,
                                childAspectRatio: 16 / 10,
                              ),
                              itemCount: visibleEntries.length,
                              itemBuilder: (context, index) => _LiveMemberTile(
                                member: visibleEntries[index],
                                memberNumber: start + index + 1,
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 76,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RoundIconButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: page > 0
                                ? () => _goToPage(page - 1)
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var index = 0;
                                      index < totalPages;
                                      index++)
                                    PageDot(active: index == page),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          RoundIconButton(
                            icon: Icons.arrow_forward_ios_rounded,
                            onTap: page < totalPages - 1
                                ? () => _goToPage(page + 1)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveMemberSummary extends StatelessWidget {
  final int count;

  const _LiveMemberSummary({required this.count});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_alt_rounded, color: Colors.white38, size: 20),
          const SizedBox(width: 8),
          Text(
            l10n.memberCountLabel(count),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const Icon(Icons.wifi_tethering, color: Colors.greenAccent, size: 16),
          const SizedBox(width: 6),
          const Text(
            'Canlı bağlantı',
            style: TextStyle(color: Colors.greenAccent, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DemoMemberSlider extends StatelessWidget {
  final int totalMembers;
  final int totalPages;
  final ValueChanged<int> onChanged;

  const _DemoMemberSlider({
    required this.totalMembers,
    required this.totalPages,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_alt_rounded, color: Colors.white38, size: 20),
          const SizedBox(width: 8),
          Text(
            l10n.memberCountLabel(totalMembers),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Slider(
              value: totalMembers.toDouble(),
              min: 1,
              max: 100,
              divisions: 99,
              activeColor: const Color(0xFF8A5CFF),
              inactiveColor: const Color(0xFF2C2C2E),
              onChanged: (value) => onChanged(value.round()),
            ),
          ),
          Text(
            l10n.screenCountLabel(totalPages),
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LiveMemberTile extends StatelessWidget {
  final MemberEntry member;
  final int memberNumber;

  const _LiveMemberTile({
    required this.member,
    required this.memberNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: member.isLocal ? const Color(0xFF8A5CFF) : Colors.white12,
          width: member.isLocal ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          if (member.videoTrack != null)
            Positioned.fill(
              child: VideoTrackRenderer(
                member.videoTrack!,
                fit: VideoViewFit.cover,
                mirrorMode: member.isLocal
                    ? VideoViewMirrorMode.mirror
                    : VideoViewMirrorMode.auto,
              ),
            )
          else
            const Center(
              child: Icon(Icons.person, size: 44, color: Colors.white24),
            ),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: member.isLocal
                    ? const Color(0xFF8A5CFF)
                    : const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                memberNumber.toString().padLeft(2, '0'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Icon(
              member.isMicEnabled ? Icons.mic : Icons.mic_off,
              size: 16,
              color: member.isMicEnabled ? Colors.white : Colors.redAccent,
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                member.isLocal ? '${member.name} (Sen)' : member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
