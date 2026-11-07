import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/invite.dart';
import 'package:v_meeting/app/locale.dart';
import 'package:v_meeting/auth/server_config.dart';

/// Logging in is optional, so a configured server leads straight home.
enum StartDestination { serverSetup, home }

/// Meeting server for the web app: `--dart-define=REISUB_WEB_SERVER_URL=…`
/// (from app.env via tool/build_web.py) when the API lives on another origin,
/// otherwise the server that served the page.
@visibleForTesting
String? webServerUrl({Uri? page}) {
  const configured = String.fromEnvironment('REISUB_WEB_SERVER_URL');
  if (configured.isNotEmpty) return configured;
  final origin = (page ?? Uri.base).origin;
  return ServerConfig.parseUrl(origin) == null ? null : origin;
}

/// Decides the first screen once saved settings have been read.
final appStartupProvider = FutureProvider<StartDestination>((ref) async {
  await ref.read(localeProvider.notifier).restore();

  var serverUrl = await ServerConfig.readUrl();
  final invite = ref.read(pendingInviteProvider);
  if (kIsWeb) {
    serverUrl = await _useWebServer(
      saved: serverUrl,
      // An invite belongs to the server that hosts the web app.
      forInvite: invite != null,
    );
  } else if (serverUrl == null && invite?.serverUrl != null) {
    // First launch from an invite: nothing to replace, so use its server.
    // Switching from a saved server is confirmed on the join screen.
    serverUrl = invite!.serverUrl;
    await ServerConfig.saveUrl(serverUrl!);
  }
  return serverUrl == null
      ? StartDestination.serverSetup
      : StartDestination.home;
});

Future<String?> _useWebServer({
  required String? saved,
  required bool forInvite,
}) async {
  final server = webServerUrl();
  if (server == null || (saved != null && !forInvite)) return saved;
  final normalized = ServerConfig.normalizeUrl(server);
  if (ServerConfig.sameServer(saved, normalized)) return saved;
  // A session from another server is not valid here.
  if (saved != null) await ServerConfig.clearSessions();
  await ServerConfig.saveUrl(normalized);
  return normalized;
}
