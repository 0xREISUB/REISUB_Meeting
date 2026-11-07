import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/app.dart';
import 'package:v_meeting/app/deep_links.dart';
import 'package:v_meeting/app/invite.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final invite = await DeepLinks.launchInvite(args);
  runApp(
    ProviderScope(
      overrides: [launchInviteProvider.overrideWithValue(invite)],
      child: const VMeetingApp(),
    ),
  );
}
