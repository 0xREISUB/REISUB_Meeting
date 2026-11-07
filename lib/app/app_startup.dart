import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/invite.dart';
import 'package:v_meeting/app/locale.dart';
import 'package:v_meeting/auth/server_config.dart';

enum StartDestination { serverSetup, login, home }

/// Meeting server for the web app: `--dart-define=REISUB_SERVER_URL=…` when
/// the API lives elsewhere, otherwise the server that served the page.
@visibleForTesting
String? webServerUrl({Uri? page}) {
  const configured = String.fromEnvironment('REISUB_SERVER_URL');
  if (configured.isNotEmpty) return configured;
  final origin = (page ?? Uri.base).origin;
  return ServerConfig.parseUrl(origin) == null ? null : origin;
}

/// Decides the first screen once saved settings have been read.
final appStartupProvider = FutureProvider<StartDestination>((ref) async {
  await ref.read(localeProvider.notifier).restore();

  var serverUrl = await ServerConfig.readUrl();
  if (kIsWeb) {
    serverUrl = await _useWebServer(
      saved: serverUrl,
      // An invite belongs to the server that hosts the web app.
      forInvite: ref.read(inviteRoomProvider) != null,
    );
  }
  if (serverUrl == null) return StartDestination.serverSetup;

  try {
    final token = await ServerConfig.readToken();
    return token == null ? StartDestination.login : StartDestination.home;
  } catch (_) {
    // A locked or unavailable platform key store requires a new login.
    return StartDestination.login;
  }
});

Future<String?> _useWebServer({
  required String? saved,
  required bool forInvite,
}) async {
  final server = webServerUrl();
  if (server == null || (saved != null && !forInvite)) return saved;
  final normalized = ServerConfig.normalizeUrl(server);
  if (saved == normalized) return saved;
  // A session from another server is not valid here.
  if (saved != null) await ServerConfig.clearToken();
  await ServerConfig.saveUrl(normalized);
  return normalized;
}
