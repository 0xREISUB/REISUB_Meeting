import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'widgets/meeting_components.dart';

class MembersScreen extends StatefulWidget {
  final int totalMembers;
  const MembersScreen({
    super.key,
    required this.totalMembers
    });

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  static const int _perPage = 12;
  static const int _columns = 4;
  late int _totalMembers = widget.totalMembers;
  late int _currentPage = 0;

  int get _totalPages => (_totalMembers / _perPage).ceil();

  void _goToPage(int page) {
    if (page < 0 || page >= _totalPages) return;
    setState(() => _currentPage = page);
  }

  void _setTotalMembers(int value) {
    setState(() {
      _totalMembers = value.clamp(1, 100);
      if (_currentPage >= _totalPages) {
        _currentPage = (_totalPages - 1).clamp(0, _totalPages - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final start = _currentPage * _perPage;
    final end = (start + _perPage).clamp(0, _totalMembers);
    final members = List.generate(_totalMembers, (i) => i).sublist(start, end);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RoundIconButton(icon: Icons.close_rounded, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.membersTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(l10n.membersHeader(_totalMembers, _currentPage + 1, _totalPages), style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
                child: Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, color: Colors.white38, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.memberCountLabel(_totalMembers), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    Expanded(
                      child: Slider(
                        value: _totalMembers.toDouble(), min: 1, max: 100, divisions: 99,
                        activeColor: const Color(0xFF8A5CFF), inactiveColor: const Color(0xFF2C2C2E),
                        onChanged: (value) => _setTotalMembers(value.round()),
                      ),
                    ),
                    Text(l10n.screenCountLabel(_totalPages), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _columns, mainAxisSpacing: 12, crossAxisSpacing: 10, childAspectRatio: 16 / 10,
                        ),
                        itemCount: members.length,
                        itemBuilder: (context, index) => MemberTile(memberNumber: members[index] + 1),
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
                            onTap: _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
                          ),
                          const SizedBox(height: 16),
                          Flexible(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [for (var i = 0; i < _totalPages; i++) PageDot(active: i == _currentPage)],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          RoundIconButton(
                            icon: Icons.arrow_forward_ios_rounded,
                            onTap: _currentPage < _totalPages - 1 ? () => _goToPage(_currentPage + 1) : null,
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