import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/theme.dart';
import 'package:v_meeting/auth/account.dart';
import 'package:v_meeting/auth/login_screen.dart';
import 'package:v_meeting/auth/register_screen.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/social/social_home.dart';
import 'package:v_meeting/widgets/glass.dart';

/// The social tab: friends, teams and the profile, for a logged-in user.
/// Others are asked to log in, as guests have no friends or teams.
class SocialTab extends ConsumerWidget {
  const SocialTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInProvider).value ?? false;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: signedIn
          ? const SocialHome(key: ValueKey('social-home'))
          : const SocialSignedOut(key: ValueKey('social-signed-out')),
    );
  }
}

class SocialSignedOut extends StatelessWidget {
  const SocialSignedOut({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      bottom: false,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            28,
            28,
            28,
            28 + MediaQuery.paddingOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: GlassSurface(
              radius: 16,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(
                    dimension: 88,
                    child: GlassSurface(
                      shape: BoxShape.circle,
                      tint: brandColor,
                      child: Icon(
                        Icons.people_alt_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.socialSignedOutTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.socialSignedOutBody,
                    key: const ValueKey('social-signed-out-body'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: glassMuted, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  GlassButton(
                    radius: 12,
                    key: const ValueKey('social-login'),
                    tint: brandColor,
                    icon: Icons.login_rounded,
                    label: l10n.login,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassButton(
                    radius: 12,
                    key: const ValueKey('social-register'),
                    icon: Icons.person_add_alt_1_rounded,
                    label: l10n.register,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
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
