import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reisub_calls/reisub_calls.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/app/app_keys.dart';
import 'package:v_meeting/app/locale.dart';
import 'package:v_meeting/auth/account.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'package:v_meeting/calls/call_ringer.dart';
import 'package:v_meeting/calls/ringing_call.dart';
import 'package:v_meeting/desktop/desktop_background.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/l10n/localized_error.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/meeting/meeting_screen.dart';
import 'package:v_meeting/meeting/waiting_room_screen.dart';
import 'package:v_meeting/notifications/app_focus.dart';
import 'package:v_meeting/notifications/notification_text.dart';
import 'package:v_meeting/notifications/system_notifications.dart';
import 'package:v_meeting/social/social_api.dart';

/// Calls that ring on this device, from the realtime connection and from
/// pushes. On a phone the system's call service rings them, with its own
/// screen; on a computer the app shows a call card (this state) and the
/// system notification, and plays the ring.
final callControllerProvider =
    NotifierProvider<CallController, List<RingingCall>>(CallController.new);

class CallController extends Notifier<List<RingingCall>> {
  /// Calls already rung, so one that comes twice (realtime and push) rings
  /// once.
  final _seen = <String>{};
  final _ringing = <String, RingingCall>{};
  final _timeouts = <String, Timer>{};
  StreamSubscription<CallAction>? _actions;

  CallRinger? get _ringer => ref.read(callRingerProvider);

  AppLocalizations get _l10n =>
      lookupAppLocalizations(ref.read(localeProvider));

  @override
  List<RingingCall> build() {
    ref.onDispose(() {
      _actions?.cancel();
      for (final timer in _timeouts.values) {
        timer.cancel();
      }
    });
    final signedIn = ref.watch(signedInProvider).value ?? false;
    final ringer = ref.watch(callRingerProvider);
    if (signedIn && ringer != null) {
      _actions = ringer.actions.listen(_onAction);
      if (ringer.ownScreen) {
        Future.delayed(const Duration(seconds: 3), _askFullScreen);
      }
      // Answered from the lock screen while the app was not running.
      Future.microtask(() async {
        try {
          final pending = await ringer.takePending();
          if (pending != null) _onAction(pending);
        } catch (_) {}
      });
    }
    return const [];
  }

  static const _askedFullScreenKey = 'calls.asked_full_screen';

  /// Android 14 lets a call fill the lock screen only with the user's
  /// leave: asked once, with the way to the setting.
  Future<void> _askFullScreen() async {
    try {
      if (await ReisubCalls.canUseFullScreen()) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedFullScreenKey) ?? false) return;
      await prefs.setBool(_askedFullScreenKey, true);
      final context = appNavigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      final l10n = _l10n;
      final allow = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.callFullScreenTitle),
          content: Text(l10n.callFullScreenBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.callFullScreenLater),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.callFullScreenAllow),
            ),
          ],
        ),
      );
      if (allow ?? false) await ReisubCalls.openFullScreenSettings();
    } catch (_) {
      // Asked another time.
    }
  }

  /// A call rings for this user.
  Future<void> incoming(RingingCall call) async {
    if (!_seen.add(call.id)) return;
    if (_seen.length > 200) _seen.remove(_seen.first);
    final left = call.endsAt.difference(DateTime.now());
    if (left <= Duration.zero) return;
    _ringing[call.id] = call;
    _timeouts[call.id] = Timer(left, () => ended(call.id, missed: true));
    final l10n = _l10n;
    final ringer = _ringer;
    try {
      await ringer?.ring(call, l10n, await ServerConfig.readUrl() ?? '');
    } catch (_) {
      // No ring here; the card and notification still show.
    }
    if (ringer?.ownScreen ?? false) return;
    state = [...state, call];
    if (!ref.read(appInFrontProvider)) {
      final notifier = ref.read(systemNotifierProvider);
      if (notifier is LocalSystemNotifier && desktopBackgroundSupported) {
        notifier.onCallTapped = () => unawaited(DesktopBackground.showWindow());
      }
      unawaited(
        notifier
            .showCall(
              id: call.id,
              title: call.title,
              body: call.subtitle(l10n),
              join: l10n.callAnswer,
              decline: l10n.callDecline,
              onAction: (join) => join ? answer(call) : decline(call),
            )
            .catchError((Object _) {}),
      );
    }
  }

  /// The call stopped ringing here: answered on another device, given up
  /// by the caller, or unanswered ([missed]). [info] describes it when this
  /// device never rang it (a phone woken by the push alone).
  Future<void> ended(
    String id, {
    bool missed = false,
    RingingCall? info,
  }) async {
    _timeouts.remove(id)?.cancel();
    final call = _ringing.remove(id) ?? info;
    _seen.add(id);
    if (call == null) return;
    final l10n = _l10n;
    try {
      await _ringer?.stop(call, l10n, missed: missed);
    } catch (_) {}
    if (state.any((c) => c.id == id)) {
      state = [
        for (final c in state)
          if (c.id != id) c,
      ];
    }
    final notifier = ref.read(systemNotifierProvider);
    unawaited(notifier.hideCall(id).catchError((Object _) {}));
    // The phone's call service leaves its own missed call notice.
    if (missed && !(_ringer?.ownScreen ?? false)) {
      unawaited(
        notifier
            .show(
              SystemNotice(
                id: SystemNotice.idFor(0x3000000 + (int.tryParse(id) ?? 0)),
                title: l10n.callMissed,
                body: call.missedText(),
                target: call.target,
              ),
            )
            .catchError((Object _) {}),
      );
    }
  }

  /// Joins the call's meeting.
  Future<void> answer(RingingCall call) async {
    await ended(call.id);
    unawaited(_tell(call.id, 'answer'));
    await _join(call.roomId);
  }

  Future<void> decline(RingingCall call) async {
    await ended(call.id);
    await _tell(call.id, 'decline');
  }

  Future<void> _tell(String id, String what) async {
    try {
      await ref.read(meetingApiProvider).send('POST', '/calls/$id/$what');
    } catch (_) {
      // The call ends on the server by itself.
    }
  }

  /// Answered or declined on the phone's call screen. A decline was sent
  /// by the phone itself.
  void _onAction(CallAction action) {
    _timeouts.remove(action.id)?.cancel();
    _ringing.remove(action.id);
    _seen.add(action.id);
    if (!action.answered) return;
    unawaited(_tell(action.id, 'answer'));
    unawaited(_join(action.roomId));
  }

  Future<void> _join(String roomId) async {
    if (desktopBackgroundSupported) unawaited(DesktopBackground.showWindow());
    final navigator = appNavigatorKey.currentState;
    if (navigator == null || MeetingScreen.isOpen) return;
    final name =
        ref.read(socialOverviewProvider).value?.profile.displayName ?? '';
    try {
      final result = await ref
          .read(meetingApiProvider)
          .joinRoom(roomId: roomId, name: name);
      switch (result) {
        case JoinAdmitted(:final credentials):
          unawaited(
            navigator.push(
              MaterialPageRoute<void>(
                builder: (_) => MeetingScreen(credentials: credentials),
              ),
            ),
          );
        case JoinWaiting(:final requestId):
          unawaited(
            navigator.push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    WaitingRoomScreen(roomId: roomId, requestId: requestId),
              ),
            ),
          );
      }
    } catch (error) {
      _say(localizeError(error, _l10n));
    }
  }

  /// The caller hears what became of a friend's call.
  void declinedBy(String name) => _say(_l10n.callDeclinedBy(name));

  void unanswered() => _say(_l10n.callUnanswered);

  void _say(String text) =>
      appMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(text)));
}
