import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/main.dart';

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.language),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _LanguageCard(
              flag: "🇹🇷",
              title: "Türkçe",
              subtitle: "Turkish",
              selected: currentLocale.languageCode == "tr",
              colorScheme: colorScheme,
              onTap: () {
                ref.read(localeProvider.notifier).state = const Locale("tr");
              },
            ),

            const SizedBox(height: 16),

            _LanguageCard(
              flag: "🇺🇸",
              title: "English",
              subtitle: "English",
              selected: currentLocale.languageCode == "en",
              colorScheme: colorScheme,
              onTap: () {
                ref.read(localeProvider.notifier).state = const Locale("en");
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final String flag;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _LanguageCard({
    required this.flag,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.colorScheme,
  });

  @override
@override
Widget build(BuildContext context) {
  return Material(
    color: Colors.transparent,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 8,
        ),
        leading: Text(
          flag,
          style: const TextStyle(fontSize: 34),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: selected
              ? Icon(
                  Icons.check_circle,
                  key: const ValueKey(true),
                  color: colorScheme.primary,
                )
              : const SizedBox(
                  width: 28,
                  key: ValueKey(false),
                ),
        ),
      ),
    ),
  );
  }
}