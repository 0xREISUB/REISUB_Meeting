import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/auth/account.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'package:v_meeting/meeting/widgets/participant_tile.dart';

/// The server's address, which profile picture paths are relative to.
/// Read again when the user logs in or out, as the server may have changed.
final serverUrlProvider = FutureProvider<String?>((ref) async {
  ref.watch(signedInProvider);
  try {
    return await ServerConfig.readUrl();
  } catch (_) {
    return null;
  }
});

/// Someone's profile picture, or their initials on their colour when they
/// have none or it cannot be loaded.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    required this.name,
    required this.seed,
    required this.avatarUrl,
    required this.size,
  });

  final String name;
  final String seed;

  /// The picture's path on the server; empty without one.
  final String avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = MemberAvatar(
      name: name,
      seed: seed,
      size: size,
      fitTile: false,
    );
    final base = ref.watch(serverUrlProvider).value;
    if (avatarUrl.isEmpty || base == null) return initials;
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: Image.network(
          '$base$avatarUrl',
          key: ValueKey('avatar-$avatarUrl'),
          fit: BoxFit.cover,
          // Pictures are at most 256 px; decode no larger than shown.
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
          frameBuilder: (context, child, frame, synchronous) =>
              frame == null && !synchronous ? initials : child,
          errorBuilder: (_, _, _) => initials,
        ),
      ),
    );
  }
}
