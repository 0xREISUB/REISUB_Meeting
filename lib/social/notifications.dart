import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/auth/account.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/social/realtime.dart';
import 'package:v_meeting/social/social_api.dart';
import 'package:v_meeting/social/social_models.dart';

/// Which conversations are on screen now, so their new messages are not
/// announced on top of them. Each open chat says how to tell whether it
/// shows, as it may be behind another screen or on a tab out of sight.
class ChatVisibility {
  final _chats = <String, bool Function()>{};

  void add(String id, bool Function() shows) => _chats[id] = shows;

  void remove(String id, bool Function() shows) {
    if (_chats[id] == shows) _chats.remove(id);
  }

  bool shows(String id) => _chats[id]?.call() ?? false;
}

final chatVisibilityProvider = Provider<ChatVisibility>(
  (ref) => ChatVisibility(),
);

/// Whether the home screen's social tab is the one in front.
final socialTabShownProvider = NotifierProvider<SocialTabShown, bool>(
  SocialTabShown.new,
);

class SocialTabShown extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool shown) => state = shown;
}

/// A conversation to open, asked for from outside the social tab, such as
/// by tapping a notification. The social tab opens it and clears it.
final socialOpenRequestProvider =
    NotifierProvider<SocialOpenRequest, ChatTarget?>(SocialOpenRequest.new);

class SocialOpenRequest extends Notifier<ChatTarget?> {
  @override
  ChatTarget? build() => null;

  void open(ChatTarget target) => state = target;

  void clear() => state = null;
}

/// The messages announced on screen now, newest last. While the user is
/// logged in and the app is in front, the server is asked every few
/// seconds for messages sent anywhere; those of a chat on screen are not
/// announced.
final notificationsProvider =
    NotifierProvider<NotificationsController, List<SocialNotification>>(
      NotificationsController.new,
    );

class NotificationsController extends Notifier<List<SocialNotification>> {
  static const interval = Duration(seconds: 4);
  static const shownFor = Duration(seconds: 6);
  static const maxShown = 3;

  Timer? _poll;
  AppLifecycleListener? _lifecycle;
  final _dismissTimers = <int, Timer>{};

  /// The message id to ask from; null until the first answer.
  int? _after;
  bool _inFront = true;
  bool _asking = false;

  @override
  List<SocialNotification> build() {
    final signedIn = ref.watch(signedInProvider).value ?? false;
    ref.onDispose(_stop);
    _after = null;
    if (!signedIn) return const [];
    _lifecycle = AppLifecycleListener(
      onStateChange: (lifecycle) {
        // Minimised or in the background: no need to ask.
        _inFront =
            lifecycle == AppLifecycleState.resumed ||
            lifecycle == AppLifecycleState.inactive;
        if (_inFront) check();
      },
    );
    // Only while the realtime connection is down; it brings them at once.
    _poll = Timer.periodic(interval, (_) {
      if (!ref.read(realtimeProvider)) check();
    });
    Future.microtask(check);
    return const [];
  }

  /// Stops asking, when logging out or when the app closes; each only once.
  void _stop() {
    _poll?.cancel();
    _poll = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    for (final timer in _dismissTimers.values) {
      timer.cancel();
    }
    _dismissTimers.clear();
  }

  /// Asks the server for new messages and announces them.
  Future<void> check() async {
    if (!_inFront || _asking) return;
    if (!(ref.read(signedInProvider).value ?? false)) return;
    _asking = true;
    try {
      final api = ref.read(socialApiProvider);
      final answer = await api.notifications(after: _after);
      final first = _after == null;
      _after = answer.latestId > (_after ?? 0) ? answer.latestId : _after;
      if (first || answer.messages.isEmpty) return;
      deliver(answer.messages);
    } on MeetingApiException catch (error) {
      if (error.sessionExpired) ref.read(signedInProvider.notifier).refresh();
    } catch (_) {
      // The next check tries again.
    } finally {
      _asking = false;
    }
  }

  /// Messages already handled, so one that comes both over the realtime
  /// connection and in a catch-up is announced once.
  final _handled = <int>{};

  /// Takes new messages, from a check or the realtime connection: open
  /// chats show them, badges catch up, and those of chats not on screen,
  /// and not the user's own, are announced.
  void deliver(List<SocialNotification> messages) {
    final fresh = [
      for (final notification in messages)
        if (_handled.add(notification.message.id)) notification,
    ];
    if (_handled.length > 500) {
      _handled.removeAll(_handled.take(_handled.length - 200).toList());
    }
    if (fresh.isEmpty) return;
    for (final notification in fresh) {
      final id = notification.message.id;
      if (id > (_after ?? 0) && _after != null) _after = id;
    }
    ref.read(socialOverviewProvider.notifier).refresh();
    final visibility = ref.read(chatVisibilityProvider);
    for (final notification in fresh) {
      final conversation = conversationProvider(notification.target);
      if (ref.exists(conversation)) {
        ref.read(conversation.notifier).receive(notification.message);
      }
      if (!notification.message.mine &&
          !visibility.shows(notification.target.id)) {
        _announce(notification);
      }
    }
  }

  void _announce(SocialNotification notification) {
    final shown = [...state, notification];
    // Beyond the most there may be, the oldest go.
    final excess = shown.length - maxShown;
    if (excess > 0) {
      for (final old in shown.take(excess)) {
        _dismissTimers.remove(old.message.id)?.cancel();
      }
      shown.removeRange(0, excess);
    }
    state = shown;
    _dismissTimers[notification.message.id] = Timer(
      shownFor,
      () => dismiss(notification),
    );
  }

  void dismiss(SocialNotification notification) {
    _dismissTimers.remove(notification.message.id)?.cancel();
    if (!state.contains(notification)) return;
    state = [
      for (final shown in state)
        if (shown != notification) shown,
    ];
  }
}
