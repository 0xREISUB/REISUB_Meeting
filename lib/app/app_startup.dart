import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/locale.dart';
import 'package:v_meeting/auth/server_config.dart';

enum StartDestination { serverSetup, login, home }

/// Decides the first screen once saved settings have been read.
final appStartupProvider = FutureProvider<StartDestination>((ref) async {
  await ref.read(localeProvider.notifier).restore();

  final serverUrl = await ServerConfig.readUrl();
  if (serverUrl == null) return StartDestination.serverSetup;

  try {
    final token = await ServerConfig.readToken();
    return token == null ? StartDestination.login : StartDestination.home;
  } catch (_) {
    // A locked or unavailable platform key store requires a new login.
    return StartDestination.login;
  }
});
