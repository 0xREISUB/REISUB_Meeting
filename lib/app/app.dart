import 'package:flutter/material.dart';
import 'package:v_meeting/app/orientation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/app_startup.dart';
import 'package:v_meeting/app/auto_hide_title_bar.dart';
import 'package:v_meeting/app/window_controls.dart';
import 'package:v_meeting/app/deep_links.dart';
import 'package:v_meeting/app/invite.dart';
import 'package:v_meeting/app/locale.dart';
import 'package:v_meeting/app/rounded_window.dart';
import 'package:v_meeting/app/theme.dart';
import 'package:v_meeting/auth/host_screen.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/join_screen.dart';
import 'package:v_meeting/meeting/meeting_screen.dart';
import 'package:v_meeting/social/in_app_notifications.dart';
import 'package:v_meeting/widgets/brand_loader.dart';
import 'package:v_meeting/widgets/glass.dart';

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
      // On a computer the app draws its own title bar, hidden until the
      // pointer rests at the top.
      builder: (context, child) {
        // New messages show over every screen.
        final app = InAppNotifications(
          navigatorKey: _navigatorKey,
          child: child!,
        );
        if (!DesktopWindowControls.supported) return app;
        final framed = AutoHideTitleBar(
          controls: const DesktopWindowControls(),
          child: app,
        );
        return RoundedWindow.supported ? RoundedWindow(child: framed) : framed;
      },
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
      // The app's own loading sign while it finds where to start.
      _ => const Scaffold(
        body: GlassBackground(child: Center(child: BrandLoader())),
      ),
    };
  }
}
