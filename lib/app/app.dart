import 'package:flutter/material.dart';
import 'package:v_meeting/app/orientation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/app_startup.dart';
import 'package:v_meeting/app/deep_links.dart';
import 'package:v_meeting/app/invite.dart';
import 'package:v_meeting/app/locale.dart';
import 'package:v_meeting/app/theme.dart';
import 'package:v_meeting/auth/host_screen.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/join_screen.dart';
import 'package:v_meeting/meeting/meeting_screen.dart';

class VMeetingApp extends ConsumerStatefulWidget {
  const VMeetingApp({super.key});

  @override
  ConsumerState<VMeetingApp> createState() => _VMeetingAppState();
}

class _VMeetingAppState extends ConsumerState<VMeetingApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    DeepLinks.listen(_openInvite);
  }

  /// An invite opened while the app is already running.
  void _openInvite(InviteLink invite) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    if (MeetingScreen.isOpen) {
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.inviteFinishMeetingFirst),
        ),
      );
      return;
    }
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => JoinScreen(
          initialRoomId: invite.roomId,
          inviteServerUrl: invite.serverUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'REISUB Meeting',
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      locale: ref.watch(localeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildAppTheme(),
      navigatorObservers: [appRouteObserver],
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
