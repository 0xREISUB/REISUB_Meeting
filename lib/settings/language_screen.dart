import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/app/locale.dart';
import 'package:v_meeting/app/theme.dart';
import 'package:v_meeting/widgets/glass.dart';

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(l10n.language), centerTitle: true),
      body: GlassBackground(
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _LanguageCard(
                  flag: "🇹🇷",
                  title: "Türkçe",
                  subtitle: l10n.turkishLanguage,
                  selected: currentLocale.languageCode == "tr",
                  colorScheme: colorScheme,
                  onTap: () {
                    ref
                        .read(localeProvider.notifier)
                        .select(const Locale("tr"));
                  },
                ),

                const SizedBox(height: 16),

                _LanguageCard(
                  flag: "🇺🇸",
                  title: "English",
                  subtitle: l10n.englishLanguage,
                  selected: currentLocale.languageCode == "en",
                  colorScheme: colorScheme,
                  onTap: () {
                    ref
                        .read(localeProvider.notifier)
                        .select(const Locale("en"));
                  },
                ),
              ],
            ),
          ),
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
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? brandColor.withValues(alpha: 0.30) : glassFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? glassAccent : glassStroke,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            onTap: onTap,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Text(flag, style: const TextStyle(fontSize: 34)),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            subtitle: Text(subtitle),
            trailing: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: selected
                  ? Icon(
                      Icons.check_circle,
                      key: const ValueKey(true),
                      color: glassAccent,
                    )
                  : const SizedBox(width: 28, key: ValueKey(false)),
            ),
          ),
        ),
      ),
    );
  }
}
