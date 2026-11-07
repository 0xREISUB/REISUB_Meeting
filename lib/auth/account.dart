import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/auth/server_config.dart';

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

  Future<void> signOut() async {
    await ServerConfig.clearToken();
    state = const AsyncData(false);
  }

  /// Re-reads storage, e.g. after the server changed or a session expired.
  void refresh() => ref.invalidateSelf();
}
