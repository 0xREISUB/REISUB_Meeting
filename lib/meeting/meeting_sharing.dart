import 'dart:async';

import 'package:flutter/foundation.dart';
import 'meeting_api.dart';

class MeetingSharing extends ChangeNotifier {
  MeetingSharing({required this.roomId, required this.api});

  final String roomId;
  final MeetingApi api;
  MeetingState state = const MeetingState();
  Object? error;
  bool loaded = false;
  bool updating = false;
  bool _refreshing = false;
  bool _disposed = false;
  Timer? _timer;

  void start() {
    unawaited(refresh());
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
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

  Future<void> setAllowed(bool value) =>
      _update(() => api.updateMeetingSettings(roomId, allowScreenShare: value));
  Future<void> acquire(String identity) =>
      _update(() => api.startScreenShare(roomId, identity));
  Future<void> release(String identity) =>
      _update(() => api.stopScreenShare(roomId, identity));

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
