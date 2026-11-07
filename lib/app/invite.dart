import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/home/home_screen.dart';
import 'package:v_meeting/meeting/join_screen.dart';

/// A nine-digit room code, as shown to users: 123-456-789.
final roomCodePattern = RegExp(r'^\d{3}-\d{3}-\d{3}$');

/// Room code from an invite link (`…/?room=123-456-789`), until the user has
/// been taken to the join screen with it.
final inviteRoomProvider = NotifierProvider<InviteRoomController, String?>(
  InviteRoomController.new,
);

class InviteRoomController extends Notifier<String?> {
  @override
  String? build() => kIsWeb ? parseInviteRoom(Uri.base) : null;

  void clear() => state = null;
}

String? parseInviteRoom(Uri uri) {
  final room = uri.queryParameters['room']?.trim();
  return room != null && roomCodePattern.hasMatch(room) ? room : null;
}

/// Where a signed-in user lands: the join screen for a pending invite,
/// otherwise the home screen.
Widget signedInHome(WidgetRef ref) {
  final invite = ref.read(inviteRoomProvider);
  return invite == null
      ? const HomeScreen()
      : JoinScreen(initialRoomId: invite);
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
