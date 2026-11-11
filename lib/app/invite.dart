import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/auth/account.dart';
import 'package:v_meeting/auth/login_screen.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'package:v_meeting/auth/server_policy.dart';
import 'package:v_meeting/home/home_screen.dart';
import 'package:v_meeting/meeting/join_screen.dart';

/// A nine-digit room code, as shown to users: 123-456-789.
final roomCodePattern = RegExp(r'^\d{3}-\d{3}-\d{3}$');

/// URL scheme that opens invites in the installed app:
/// `reisub-meeting://join/123-456-789?server=https://meeting.example`.
const inviteScheme = 'reisub-meeting';

/// An invite to a room, optionally on a specific meeting server.
@immutable
class InviteLink {
  const InviteLink({required this.roomId, this.serverUrl});

  final String roomId;

  /// Normalized server address named by the link, or null to use the
  /// current server.
  final String? serverUrl;

  @override
  bool operator ==(Object other) =>
      other is InviteLink &&
      other.roomId == roomId &&
      other.serverUrl == serverUrl;

  @override
  int get hashCode => Object.hash(roomId, serverUrl);
}

/// Reads an invite from the app scheme, a short link (`…/j/<code>`) or an
/// invite page (`…/invite/?room=<code>`). For https links the server is the
/// link's own origin unless `server` is given. [webPage] marks the address
/// the web app was loaded from; the web app picks its server itself.
InviteLink? parseInviteLink(Uri uri, {bool webPage = false}) {
  String? room;
  if (uri.scheme == inviteScheme) {
    if (uri.host != 'join' || uri.pathSegments.isEmpty) return null;
    room = uri.pathSegments.first;
  } else if (uri.scheme == 'http' || uri.scheme == 'https') {
    room = uri.queryParameters['room'];
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (room == null &&
        segments.length >= 2 &&
        segments[segments.length - 2] == 'j') {
      room = segments.last;
    }
  } else {
    return null;
  }
  room = room?.trim();
  if (room == null || !roomCodePattern.hasMatch(room)) return null;

  var server = uri.queryParameters['server'];
  if (server == null && uri.scheme != inviteScheme && !webPage) {
    server = uri.origin;
  }
  final valid = server != null && ServerConfig.parseUrl(server) != null;
  return InviteLink(
    roomId: room,
    serverUrl: valid ? ServerConfig.normalizeUrl(server) : null,
  );
}

/// The invite the app was opened with on Android, Windows or Linux. main()
/// overrides it before the app starts.
final launchInviteProvider = Provider<InviteLink?>((ref) => null);

/// An invite the user has not yet been taken to the join screen for.
final pendingInviteProvider =
    NotifierProvider<PendingInviteController, InviteLink?>(
      PendingInviteController.new,
    );

class PendingInviteController extends Notifier<InviteLink?> {
  @override
  InviteLink? build() => kIsWeb
      ? parseInviteLink(Uri.base, webPage: true)
      : ref.watch(launchInviteProvider);

  void clear() => state = null;
}

/// The first screen once a server is set; see [StartGate].
Widget startHome(WidgetRef ref) => const StartGate();

/// Decides the first screen once a server is set: login when the server
/// takes no guests and nobody is signed in, otherwise the join screen for a
/// pending invite, otherwise home. The invite waits through the login.
class StartGate extends ConsumerWidget {
  const StartGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(serverPolicyProvider);
    final signedIn = ref.watch(signedInProvider);
    if (!policy.hasValue || !signedIn.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (policy.value?.guestsAllowed == false && signedIn.value != true) {
      return const LoginScreen(guestsRefused: true);
    }
    final invite = ref.read(pendingInviteProvider);
    return invite == null
        ? const HomeScreen()
        : JoinScreen(
            initialRoomId: invite.roomId,
            inviteServerUrl: invite.serverUrl,
          );
  }
}

/// The landing page for an invite to [roomId], served next to the web app.
///
/// [serverUrl] is used on native platforms, where the app has no web address
/// of its own; it assumes the web app is served by the meeting server.
String fallbackInviteLink(String roomId, {String? serverUrl}) {
  final base = kIsWeb
      ? Uri.base.resolve('invite/')
      : Uri.parse('${serverUrl ?? ''}/invite/');
  return base.replace(queryParameters: {'room': roomId}).toString();
}
