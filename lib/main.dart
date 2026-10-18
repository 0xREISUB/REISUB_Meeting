import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/home/home_screen.dart';
import 'auth/host_screen.dart';
import 'auth/login_screen.dart';
import 'auth/server_config.dart';

final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));

void main() {
  runApp(const ProviderScope(child: VMeetingApp()));
}

class VMeetingApp extends ConsumerWidget {
  const VMeetingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);

    return MaterialApp(
      title: 'REISUB Meeting',
      debugShowCheckedModeBanner: false,
      locale: currentLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const _StartupScreen(),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  Future<Widget> _resolveStartScreen() async {
    final serverUrl = await ServerConfig.readUrl();
    if (serverUrl == null) {
      return const HostScreen();
    }

    final token = await ServerConfig.readToken();
    return token == null ? const LoginScreen() : const HomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _resolveStartScreen(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return snapshot.data!;
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
