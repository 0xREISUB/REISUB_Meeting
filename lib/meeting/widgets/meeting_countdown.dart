import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

/// The time left before a time-limited meeting ends, in its last ten
/// minutes: a red pie that shrinks from full to nothing, and minutes and
/// seconds beside it.
class MeetingCountdown extends StatelessWidget {
  const MeetingCountdown({super.key, required this.left});

  final Duration left;

  /// The countdown shows over this last stretch of the meeting.
  static const window = Duration(minutes: 10);

  static String format(Duration left) {
    final seconds = left.inSeconds.clamp(0, 99 * 60 + 59);
    final minutes = seconds ~/ 60;
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final fraction = (left.inMilliseconds / window.inMilliseconds).clamp(
      0.0,
      1.0,
    );
    final text = format(left);
    final lastMinute = left <= const Duration(minutes: 1);
    return Semantics(
      label: AppLocalizations.of(context)!.meetingTimeLeft(text),
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('meeting-countdown'),
        padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 24,
              child: CustomPaint(painter: CountdownPiePainter(fraction)),
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: lastMinute ? Colors.redAccent : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A red disc with a slice the size of [fraction] (0 to 1), starting at
/// twelve o'clock; the rest of the disc is faint.
class CountdownPiePainter extends CustomPainter {
  const CountdownPiePainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawOval(
      rect,
      Paint()..color = Colors.redAccent.withValues(alpha: 0.22),
    );
    if (fraction <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * fraction,
      true,
      Paint()..color = Colors.redAccent,
    );
  }

  @override
  bool shouldRepaint(CountdownPiePainter old) => old.fraction != fraction;
}

/// A notice at the top that the meeting is about to reach its time limit.
class MeetingTimeNotice extends StatelessWidget {
  const MeetingTimeNotice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('meeting-time-notice'),
      decoration: BoxDecoration(
        color: const Color(0xF22C2C2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_rounded, color: Colors.redAccent),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
