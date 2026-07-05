import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'features/auth/home_screen.dart'; // HomeScreen import edildi

// GLOBAL DİL DURUMU: Varsayılan olarak Türkçe başlatıyoruz
final localeProvider = StateProvider<Locale>((ref) => const Locale('tr'));

void main() {
  runApp(
    // Riverpod'u projeye dahil etmek için en dıştan ProviderScope ile sarıyoruz
    const ProviderScope(child: VMeetingApp()),
  );
}

class VMeetingApp extends ConsumerWidget {
  const VMeetingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Riverpod'daki anlık dil durumunu dinliyoruz
    final currentLocale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'REISUB Meeting',
      debugShowCheckedModeBanner: false,
      locale: currentLocale, // Dili buraya bağlıyoruz
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // Artık uygulamayı doğrudan Ana Menü ile başlatıyoruz
      home: const HomeScreen(),
    );
  }
}
