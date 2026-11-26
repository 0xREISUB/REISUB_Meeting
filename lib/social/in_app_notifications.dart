import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/meeting_screen.dart';
import 'package:v_meeting/social/notifications.dart';
import 'package:v_meeting/social/realtime.dart';
import 'package:v_meeting/social/social_actions.dart';
import 'package:v_meeting/social/social_models.dart';
import 'package:v_meeting/social/user_avatar.dart';
import 'package:v_meeting/widgets/glass.dart';

/// Shows new messages over the whole app, wherever the user is: at the top
/// right on a computer, at the top on a phone. Tapping one opens its chat;
/// a meeting invitation can be joined from it.
class InAppNotifications extends ConsumerWidget {
  const InAppNotifications({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  /// The app's navigator, which the notifications sit above.
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  /// Wider than this, notifications sit at the top right.
  static const _wideWidth = 600.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    // Keeps the realtime connection up for the whole app.
    ref.listen(realtimeProvider, (_, _) {});
    final media = MediaQuery.of(context);
    final wide = media.size.width >= _wideWidth;
    return Stack(
      children: [
        child,
        if (notifications.isNotEmpty)
          Positioned(
            top: media.padding.top + (wide ? 16 : 8),
            right: wide ? 16 : 12,
            left: wide ? null : 12,
            width: wide ? 360 : null,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                key: const ValueKey('in-app-notifications'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  for (final notification in notifications.reversed)
                    _DropIn(
                      key: ValueKey('notification-${notification.message.id}'),
                      child: _NotificationCard(
                        notification: notification,
                        navigatorKey: navigatorKey,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({
    required this.notification,
    required this.navigatorKey,
  });

  final SocialNotification notification;
  final GlobalKey<NavigatorState> navigatorKey;

  void _dismiss(WidgetRef ref) =>
      ref.read(notificationsProvider.notifier).dismiss(notification);

  /// Opens the chat it came from, unless that would leave a meeting.
  void _open(WidgetRef ref) {
    _dismiss(ref);
    if (MeetingScreen.isOpen) return;
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    ref.read(socialOpenRequestProvider.notifier).open(notification.target);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final message = notification.message;
    final invite = message.roomId;
    final String body;
    if (invite != null) {
      body = l10n.meetingInviteFrom(message.sender);
    } else if (notification.fromTeam) {
      body = '${message.sender}: ${message.text}';
    } else {
      body = message.text;
    }
    return Dismissible(
      key: ValueKey('dismiss-${message.id}'),
      direction: DismissDirection.up,
      onDismissed: (_) => _dismiss(ref),
      child: GlassSurface(
        radius: 14,
        // Over any screen, video too: smoked and frosted to stay readable.
        blur: true,
        tint: glassSmoke,
        child: InkWell(
          key: ValueKey('open-notification-${message.id}'),
          onTap: () => _open(ref),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                UserAvatar(
                  name: message.sender,
                  seed: message.sender,
                  avatarUrl: message.senderAvatarUrl,
                  size: 38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (notification.fromTeam) ...[
                            const Icon(
                              Icons.groups_rounded,
                              size: 15,
                              color: glassAccent,
                            ),
                            const SizedBox(width: 5),
                          ],
                          Flexible(
                            child: Text(
                              notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: glassMuted, height: 1.3),
                      ),
                    ],
                  ),
                ),
                if (invite != null && !MeetingScreen.isOpen)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: FilledButton(
                      key: ValueKey('notification-join-${message.id}'),
                      onPressed: () {
                        _dismiss(ref);
                        final navigator = navigatorKey.currentContext;
                        if (navigator != null) {
                          joinSocialMeeting(navigator, ref, invite);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.withValues(alpha: 0.85),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(l10n.joinTeamMeeting),
                    ),
                  ),
                // A label, not a tooltip: notifications sit above the app's
                // overlay.
                Semantics(
                  button: true,
                  label: l10n.close,
                  child: IconButton(
                    key: ValueKey('close-notification-${message.id}'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _dismiss(ref),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: glassMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Slides down from above and fades in once, when it first appears.
class _DropIn extends StatelessWidget {
  const _DropIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, -20 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
