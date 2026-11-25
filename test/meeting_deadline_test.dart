import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/meeting/meeting_deadline.dart';

void main() {
  test('counts down from the server\'s seconds on this device\'s clock', () {
    var now = DateTime(2026, 1, 1, 12);
    final deadline = MeetingDeadline(clock: () => now);
    expect(deadline.timeLeft, isNull);
    expect(deadline.reached, isFalse);

    deadline.setSecondsLeft(600);
    now = now.add(const Duration(minutes: 4));
    expect(deadline.timeLeft, const Duration(minutes: 6));

    // A newer count replaces the old one; a missing one keeps it.
    deadline.setSecondsLeft(30);
    deadline.setSecondsLeft(null);
    expect(deadline.timeLeft, const Duration(seconds: 30));
    expect(deadline.reached, isFalse);

    // A few seconds early counts as reached; it never goes below zero.
    now = now.add(const Duration(seconds: 26));
    expect(deadline.reached, isTrue);
    now = now.add(const Duration(minutes: 1));
    expect(deadline.timeLeft, Duration.zero);

    // The server lifted the limit.
    deadline.setSecondsLeft(null, clear: true);
    expect(deadline.timeLeft, isNull);
    expect(deadline.reached, isFalse);
  });
}
