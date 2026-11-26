import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/app.dart';
import 'package:v_meeting/app/deep_links.dart';
import 'package:v_meeting/app/smooth_wheel.dart';
import 'package:v_meeting/app/window_controls.dart';
import 'package:v_meeting/app/invite.dart';
import 'package:v_meeting/notifications/push.dart';

Future<void> main(List<String> args) async {
  SmoothWheelBinding();
  try {
    await DesktopWindowControls.hideSystemTitleBar();
  } catch (_) {
    // The system's title bar stays; the app works the same.
  }
  // Push notifications, on Android builds with the Firebase project.
  await startPush();
  final invite = await DeepLinks.launchInvite(args);
  runApp(
    ProviderScope(
      overrides: [launchInviteProvider.overrideWithValue(invite)],
      child: const VMeetingApp(),
    ),
  );
}
