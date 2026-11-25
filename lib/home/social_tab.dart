import 'package:flutter/material.dart';
import 'package:v_meeting/app/theme.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/widgets/glass.dart';

/// The social tab. A placeholder until the social features arrive.
class SocialTab extends StatelessWidget {
  const SocialTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      bottom: false,
      child: Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            28,
            28,
            28,
            28 + MediaQuery.paddingOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: GlassSurface(
              radius: 28,
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 88,
                    child: GlassSurface(
                      shape: BoxShape.circle,
                      tint: brandColor,
                      child: const Icon(
                        Icons.people_alt_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.social,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.socialComingSoon,
                    key: const ValueKey('social-coming-soon'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: glassMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
