import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

/// Covers the meeting while it connects; after a timeout offers to retry or
/// leave.
class MeetingJoiningOverlay extends StatelessWidget {
  const MeetingJoiningOverlay({
    super.key,
    required this.timedOut,
    required this.onRetry,
    required this.onLeave,
  });

  final bool timedOut;

  /// Null disables the retry button while a join is already running.
  final VoidCallback? onRetry;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ColoredBox(
      key: const ValueKey('meeting-joining-overlay'),
      color: const Color(0xF5141418),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!timedOut)
                  const CircularProgressIndicator(
                    key: ValueKey('meeting-joining-progress'),
                  ),
                const SizedBox(height: 24),
                Text(
                  timedOut ? l10n.meetingMediaTimeout : l10n.joiningMeeting,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!timedOut) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.preparingMeetingMedia,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const ValueKey('meeting-joining-retry'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.rejoinMeeting),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: onLeave, child: Text(l10n.leave)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
