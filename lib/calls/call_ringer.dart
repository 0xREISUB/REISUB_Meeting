import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reisub_calls/reisub_calls.dart';
import 'package:v_meeting/calls/ringing_call.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

/// Rings calls on this device. On Android the system's call service does
/// it; on a computer the app rings itself (see CallController).
abstract class CallRinger {
  /// Whether this ringer shows its own screen, with Answer and Decline, so
  /// the app shows none.
  bool get ownScreen;

  Future<void> ring(RingingCall call, AppLocalizations l10n, String server);

  /// Stops ringing; [missed] leaves a missed call behind.
  Future<void> stop(RingingCall call, AppLocalizations l10n, {bool missed});

  /// What the user did on the ringer's own screen.
  Stream<CallAction> get actions;

  /// Something done while the app was not running.
  Future<CallAction?> takePending();
}

/// Labels for the Android call screen and its notifications.
CallLabels callLabels(AppLocalizations l10n, RingingCall call) => CallLabels(
  incoming: call.subtitle(l10n),
  answer: l10n.callAnswer,
  decline: l10n.callDecline,
  channel: l10n.callChannel,
  missedChannel: l10n.callMissedChannel,
  missed: l10n.callMissed,
);

IncomingCall incomingCall(RingingCall call, String server) => IncomingCall(
  id: call.id,
  roomId: call.roomId,
  caller: call.caller,
  title: call.title,
  kind: call.kind,
  targetId: call.targetId,
  secret: call.secret,
  server: server,
  endsAt: call.endsAt,
);

final callRingerProvider = Provider<CallRinger?>((ref) {
  if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return null;
  if (Platform.isAndroid) return AndroidCallRinger();
  if (Platform.isLinux) return DesktopCallRinger();
  return null;
});

/// Through the reisub_calls plugin: Telecom, the phone's own ringtone, a
/// full screen call on the lock screen, and a volume key to silence it.
class AndroidCallRinger implements CallRinger {
  @override
  bool get ownScreen => true;

  @override
  Future<void> ring(RingingCall call, AppLocalizations l10n, String server) =>
      ReisubCalls.show(incomingCall(call, server), callLabels(l10n, call));

  @override
  Future<void> stop(
    RingingCall call,
    AppLocalizations l10n, {
    bool missed = false,
  }) => ReisubCalls.end(
    call.id,
    missed: missed,
    missedText: call.missedText(),
    labels: callLabels(l10n, call),
  );

  @override
  Stream<CallAction> get actions => ReisubCalls.actions;

  @override
  Future<CallAction?> takePending() => ReisubCalls.takePendingAction();
}

/// On a computer: the desktop's "phone-incoming-call" sound every few
/// seconds while it rings. What it looks like is the app's own call card
/// and the system notification (see CallController).
class DesktopCallRinger implements CallRinger {
  static const repeat = Duration(seconds: 3);
  final _timers = <String, Timer>{};

  @override
  bool get ownScreen => false;

  @override
  Future<void> ring(
    RingingCall call,
    AppLocalizations l10n,
    String server,
  ) async {
    if (_timers.containsKey(call.id)) return;
    _play();
    _timers[call.id] = Timer.periodic(repeat, (timer) {
      if (DateTime.now().isAfter(call.endsAt)) {
        timer.cancel();
        _timers.remove(call.id);
        return;
      }
      _play();
    });
  }

  void _play() {
    // The sound theme's ring, as the desktop plays it; a plain player if
    // that tool is missing.
    Process.run('canberra-gtk-play', [
          '-i',
          'phone-incoming-call',
          '-d',
          'REISUB Meeting',
        ])
        .catchError(
          (Object _) => Process.run('paplay', [
            '/usr/share/sounds/freedesktop/stereo/phone-incoming-call.oga',
          ]),
        )
        .catchError((Object _) => ProcessResult(0, 1, '', ''));
  }

  @override
  Future<void> stop(
    RingingCall call,
    AppLocalizations l10n, {
    bool missed = false,
  }) async {
    _timers.remove(call.id)?.cancel();
  }

  @override
  Stream<CallAction> get actions => const Stream.empty();

  @override
  Future<CallAction?> takePending() async => null;
}
