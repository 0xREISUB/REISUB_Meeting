/// When a time-limited meeting ends, kept from the server's seconds left
/// rather than its clock, so a wrong device clock does not matter.
class MeetingDeadline {
  MeetingDeadline({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// When the server will end the meeting, on this device's clock; null
  /// without a time limit.
  DateTime? _end;

  /// Takes a new count from the server. A missing count keeps the last one
  /// unless [clear], which means the server lifted the limit.
  void setSecondsLeft(int? seconds, {bool clear = false}) {
    if (seconds == null) {
      if (clear) _end = null;
      return;
    }
    _end = _clock().add(Duration(seconds: seconds));
  }

  /// How long until the server ends the meeting; null without a limit.
  Duration? get timeLeft {
    final end = _end;
    if (end == null) return null;
    final left = end.difference(_clock());
    return left.isNegative ? Duration.zero : left;
  }

  /// Whether the meeting has reached its limit, with a few seconds' leeway
  /// for the server closing it a little early.
  bool get reached {
    final left = timeLeft;
    return left != null && left <= const Duration(seconds: 5);
  }
}
