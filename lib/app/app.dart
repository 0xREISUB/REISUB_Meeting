import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/app_startup.dart';
import 'package:v_meeting/app/invite.dart';
import 'package:v_meeting/app/locale.dart';
import 'package:v_meeting/app/theme.dart';
import 'package:v_meeting/auth/host_screen.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

class VMeetingApp extends ConsumerWidget {
  const VMeetingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'REISUB Meeting',
      debugShowCheckedModeBanner: false,
      locale: ref.watch(localeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(),
      home: const StartupScreen(),
    );
  }
}

class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(appStartupProvider)) {
      AsyncData(value: StartDestination.home) => startHome(ref),
      AsyncData(value: StartDestination.serverSetup) ||
      AsyncError() => const HostScreen(),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}
