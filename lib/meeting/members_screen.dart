import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

/// Shown inside the meeting's bottom sheet, with live names supplied by the room.
class MembersScreen extends StatelessWidget {
  final List<String> names;

  const MembersScreen({super.key, required this.names});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                CloseButton(color: Colors.white70),
              ],
            ),
          ),
          const Divider(height: 24, color: Colors.white12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: names.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Colors.white12),
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  names[index],
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
