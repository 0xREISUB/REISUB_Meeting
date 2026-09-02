import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'home/home_screen.dart'; // HomeScreen import edildi

// GLOBAL DÄ°L DURUMU: VarsayÄ±lan olarak TÃ¼rkÃ§e baÅŸlatÄ±yoruz
final localeProvider = StateProvider<Locale>((ref) => const Locale('tr'));

void main() {
  runApp(
    // Riverpod'u projeye dahil etmek iÃ§in en dÄ±ÅŸtan ProviderScope ile sarÄ±yoruz
    const ProviderScope(child: VMeetingApp()),
  );
}

class VMeetingApp extends ConsumerWidget {
  const VMeetingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Riverpod'daki anlÄ±k dil durumunu dinliyoruz
    final currentLocale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'REISUB Meeting',
      debugShowCheckedModeBanner: false,
      locale: currentLocale, // Dili buraya baÄŸlÄ±yoruz
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // ArtÄ±k uygulamayÄ± doÄŸrudan Ana MenÃ¼ ile baÅŸlatÄ±yoruz
      home: const HomeScreen(),
    );
  }
}
