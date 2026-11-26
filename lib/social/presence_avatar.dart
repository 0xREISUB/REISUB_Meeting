import 'package:material_ui/material_ui.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/social/social_models.dart';
import 'package:v_meeting/social/user_avatar.dart';

/// Someone's avatar with a dot for whether they can be reached.
class PresenceAvatar extends StatelessWidget {
  const PresenceAvatar({
    super.key,
    required this.name,
    required this.seed,
    required this.presence,
    this.avatarUrl = '',
    this.size = 44,
  });

  final String name;
  final String seed;
  final Presence presence;

  /// The profile picture's path on the server; empty without one.
  final String avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = size * 0.3;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          UserAvatar(name: name, seed: seed, avatarUrl: avatarUrl, size: size),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: presence.color,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1C1A22), width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tells that an action of the social preview is not there yet.
void showSocialComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.comingSoon)),
    );
}
