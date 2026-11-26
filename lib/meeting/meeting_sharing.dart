import 'dart:async';

import 'package:flutter/foundation.dart';

import 'meeting_api.dart';
import 'room_realtime.dart';

/// The room's shared state, read from the server: the single screen share,
/// and the waiting room with the people in it. It is read again when
/// [realtime] says it changed; the poll runs every [pollInterval] while that
/// connection is down and every [slowPoll] while it is up.
class MeetingSharing extends ChangeNotifier {
  MeetingSharing({required this.roomId, required this.api, this.realtime})
    : _pace = PollPace(realtime, tick: pollInterval, slow: slowPoll);

  static const pollInterval = Duration(seconds: 2);
  static const slowPoll = Duration(seconds: 15);

  final String roomId;
  final MeetingApi api;
  final RoomRealtime? realtime;
  final PollPace _pace;
  StreamSubscription<RoomChange>? _changes;
  MeetingState state = const MeetingState();
  Object? error;
  bool loaded = false;
  bool updating = false;
  bool _refreshing = false;
  bool _disposed = false;
  Timer? _timer;

  void start() {
    _pace.polled();
    unawaited(refresh());
    _timer = Timer.periodic(pollInterval, (_) {
      if (_pace.due()) unawaited(refresh());
    });
    _changes = realtime?.changes.listen((change) {
      if (change != RoomChange.state) return;
      _pace.polled();
      unawaited(refresh());
    });
  }

  void _accept(MeetingState value) {
    if (_disposed) return;
    state = value;
    loaded = true;
    error = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_refreshing || updating || _disposed) return;
    _refreshing = true;
    final revision = _revision;
    try {
      final value = await api.getMeetingState(roomId);
      // An older poll must not overwrite a just-completed mutation.
      if (!updating && revision == _revision) _accept(value);
    } catch (e) {
      if (!_disposed) {
        error = e;
        notifyListeners();
      }
    } finally {
      _refreshing = false;
    }
  }

  int _revision = 0;
  Future<void> _update(Future<MeetingState> Function() request) async {
    updating = true;
    _revision++;
    if (!_disposed) notifyListeners();
    try {
      _accept(await request());
    } finally {
      updating = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> acquire(String identity) =>
      _update(() => api.startScreenShare(roomId, identity));
  Future<void> release(String identity) =>
      _update(() => api.stopScreenShare(roomId, identity));
  Future<void> setWaitingRoom(bool on) =>
      _update(() => api.setWaitingRoom(roomId, on));
  Future<void> answer(String requestId, {required bool admit}) =>
      _update(() => api.answerWaiting(roomId, requestId, admit: admit));

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_changes?.cancel());
    super.dispose();
  }
}
