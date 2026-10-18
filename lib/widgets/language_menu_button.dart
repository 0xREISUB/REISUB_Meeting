import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/main.dart';

class LanguageMenuButton extends ConsumerWidget {
  const LanguageMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(localeProvider).languageCode;

    return PopupMenuButton<String>(
      tooltip: AppLocalizations.of(context)!.language,
      icon: const Icon(Icons.language),
      onSelected: (value) {
        ref.read(localeProvider.notifier).state = Locale(value);
      },
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: 'en',
          checked: language == 'en',
          child: const Text('English'),
        ),
        CheckedPopupMenuItem(
          value: 'tr',
          checked: language == 'tr',
          child: const Text('Türkçe'),
        ),
      ],
    );
  }
}
