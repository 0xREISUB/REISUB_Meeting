import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/calls/call_controller.dart';
import 'package:v_meeting/calls/ringing_call.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/social/user_avatar.dart';
import 'package:v_meeting/widgets/glass.dart';

/// A ringing call over every screen, with Decline and Join, where the app
/// rings calls itself (on a computer).
class IncomingCalls extends ConsumerWidget {
  const IncomingCalls({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calls = ref.watch(callControllerProvider);
    final media = MediaQuery.of(context);
    return Stack(
      children: [
        child,
        if (calls.isNotEmpty)
          Positioned(
            top: media.padding.top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8,
                      children: [
                        for (final call in calls) _CallCard(call: call),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CallCard extends ConsumerWidget {
  const _CallCard({required this.call});

  final RingingCall call;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final calls = ref.read(callControllerProvider.notifier);
    return GlassSurface(
      key: ValueKey('call-${call.id}'),
      radius: 18,
      blur: true,
      tint: glassSmoke,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            UserAvatar(
              name: call.title,
              seed: call.title,
              avatarUrl: '',
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    call.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    call.subtitle(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            _RoundButton(
              key: ValueKey('call-decline-${call.id}'),
              icon: Icons.call_end_rounded,
              color: const Color(0xFFE53935),
              label: l10n.callDecline,
              onTap: () => calls.decline(call),
            ),
            const SizedBox(width: 10),
            _RoundButton(
              key: ValueKey('call-join-${call.id}'),
              icon: Icons.videocam_rounded,
              color: const Color(0xFF43A047),
              label: l10n.callAnswer,
              onTap: () => calls.answer(call),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
