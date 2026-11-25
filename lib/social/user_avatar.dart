import 'dart:math' as math;

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
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    required this.seed,
    required this.avatarUrl,
    required this.size,
    this.fitTile = false,
  });

  final String name;
  final String seed;

  /// The picture's path on the server; empty without one.
  final String avatarUrl;
  final double size;

  /// Keeps it to half the space it is given, as in a small video tile.
  final bool fitTile;

  @override
  Widget build(BuildContext context) {
    if (!fitTile) return _avatar(size);
    return LayoutBuilder(
      builder: (context, constraints) =>
          _avatar(math.min(size, constraints.biggest.shortestSide * 0.5)),
    );
  }

  Widget _avatar(double size) {
    final initials = MemberAvatar(
      name: name,
      seed: seed,
      size: size,
      fitTile: false,
    );
    // Without a picture there is no server to ask, nor anything to read.
    if (avatarUrl.isEmpty) return initials;
    return _Picture(avatarUrl: avatarUrl, size: size, initials: initials);
  }
}

/// The picture itself, from the server; the initials while it loads, or
/// if it cannot be had.
class _Picture extends ConsumerWidget {
  const _Picture({
    required this.avatarUrl,
    required this.size,
    required this.initials,
  });

  final String avatarUrl;
  final double size;
  final Widget initials;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(serverUrlProvider).value;
    if (base == null) return initials;
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
