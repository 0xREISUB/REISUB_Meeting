import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/meeting/widgets/meeting_countdown.dart';
import 'package:v_meeting/meeting/widgets/meeting_waiting.dart';

/// What the top of the meeting screen announces: people starting to wait
/// to be let in, and the meeting's time limit coming up.
class MeetingNotices extends ChangeNotifier {
  static const arrivalNoticeTime = Duration(seconds: 20);
  static const timeNoticeTime = Duration(seconds: 8);

  /// Waiting people already seen, so each one is announced once.
  final _seenWaiting = <String>{};

  /// Newcomers announced at the top, newest last.
  final arrivals = <WaitingPerson>[];
  final _arrivalTimers = <String, Timer>{};

  /// Minutes left when the time limit was last announced, while it shows.
  int? minutesLeft;
  Timer? _timeTimer;
  bool _warnedTenMinutes = false;
  bool _warnedOneMinute = false;
  bool _disposed = false;

  /// Takes the waiting room's people. [notify] is whether to announce
  /// newcomers; null while the preference is still loading, so they wait
  /// for the next update instead of being announced by mistake.
  void updateWaiting(List<WaitingPerson> waiting, {required bool? notify}) {
    final present = {for (final person in waiting) person.requestId};
    var changed = false;
    // Let in or turned away, by anyone: their notice goes.
    for (final person in [...arrivals]) {
      if (!present.contains(person.requestId)) changed |= _drop(person);
    }
    if (notify != null) {
      for (final person in waiting) {
        if (_seenWaiting.add(person.requestId) && notify) {
          arrivals.add(person);
          _arrivalTimers[person.requestId] = Timer(
            arrivalNoticeTime,
            () => dismiss(person),
          );
          changed = true;
        }
      }
    }
    if (changed) notifyListeners();
  }

  /// Takes [person]'s notice away.
  void dismiss(WaitingPerson person) {
    if (_drop(person)) notifyListeners();
  }

  bool _drop(WaitingPerson person) {
    _arrivalTimers.remove(person.requestId)?.cancel();
    final before = arrivals.length;
    arrivals.removeWhere((other) => other.requestId == person.requestId);
    return arrivals.length != before;
  }

  /// Tells everyone once when ten minutes are left, or fewer on joining
  /// late, and once more at one minute. A limit the server extends arms
  /// the warnings again.
  void updateTimeLeft(Duration left) {
    if (left > MeetingCountdown.window) _warnedTenMinutes = false;
    if (left > const Duration(minutes: 1)) _warnedOneMinute = false;
    if (left <= const Duration(minutes: 1)) {
      if (_warnedOneMinute) return;
      _warnedOneMinute = _warnedTenMinutes = true;
      _showTime(1);
    } else if (left <= MeetingCountdown.window && !_warnedTenMinutes) {
      _warnedTenMinutes = true;
      _showTime((left.inSeconds / 60).ceil());
    }
  }

  void _showTime(int minutes) {
    _timeTimer?.cancel();
    minutesLeft = minutes;
    notifyListeners();
    _timeTimer = Timer(timeNoticeTime, () {
      minutesLeft = null;
      if (!_disposed) notifyListeners();
    });
  }

  bool get isEmpty => arrivals.isEmpty && minutesLeft == null;

  @override
  void dispose() {
    _disposed = true;
    _timeTimer?.cancel();
    for (final timer in _arrivalTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}

/// The notices at the top of the meeting, newest first: the time limit,
/// then up to [maxArrivals] people waiting, each with ✓ and ✗.
class MeetingNoticeStack extends StatelessWidget {
  const MeetingNoticeStack({
    super.key,
    required this.notices,
    required this.onAnswer,
    this.maxArrivals = 3,
  });

  final MeetingNotices notices;
  final WaitingAnswer onAnswer;
  final int maxArrivals;

  @override
  Widget build(BuildContext context) {
    final minutes = notices.minutesLeft;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            if (minutes != null)
              _DropIn(
                key: ValueKey('time-$minutes'),
                child: MeetingTimeNotice(
                  text: AppLocalizations.of(context)!
                      .minutesLeftNotice(minutes),
                ),
              ),
            for (final person in notices.arrivals.reversed.take(maxArrivals))
              _DropIn(
                key: ValueKey('drop-${person.requestId}'),
                child: ArrivalNotice(
                  person: person,
                  onAdmit: () => onAnswer(person, admit: true),
                  onReject: () => onAnswer(person, admit: false),
                  onDismiss: () => notices.dismiss(person),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Slides [child] down from above and fades it in once, when it first
/// appears.
class _DropIn extends StatelessWidget {
  const _DropIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, -24 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
