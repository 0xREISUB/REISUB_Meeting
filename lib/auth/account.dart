import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'package:v_meeting/meeting/meeting_api.dart';

/// Whether the user is logged in. Logging in is optional: without an account
/// the app uses a guest session.
final signedInProvider = AsyncNotifierProvider<SignedInController, bool>(
  SignedInController.new,
);

class SignedInController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    try {
      return await ServerConfig.readToken() != null;
    } catch (_) {
      return false;
    }
  }

  /// Call after a successful login has stored the token.
  void markSignedIn() => state = const AsyncData(true);

  /// Signs this device out, on the server too: its session ends there, and
  /// with it this device's push notifications. The user's other devices
  /// stay signed in.
  Future<void> signOut() async {
    try {
      await ref.read(meetingApiProvider).send('POST', '/logout');
    } catch (_) {
      // Unreachable, or already over; signed out here all the same.
    }
    await ServerConfig.clearToken();
    state = const AsyncData(false);
  }

  /// Re-reads storage, e.g. after the server changed or a session expired.
  void refresh() => ref.invalidateSelf();
}
