import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'package:v_meeting/social/realtime.dart';

/// What changed in a meeting, as the server says it.
enum RoomChange {
  /// A new chat message.
  chat,

  /// The screen share, the waiting room or someone's rights.
  state,
}

/// A realtime connection watching one meeting, for guests too. The server
/// says the moment something there changes; what changed is then read as
/// before, so the polls only run slowly beside it, in case an event is
/// missed. [connected] is true while it is open.
///
/// It tries again after a dropped connection, waiting longer each time up
/// to [maxRetryDelay], and gives up once the meeting is over or the session
/// is not valid.
class RoomRealtime extends ChangeNotifier {
  RoomRealtime({
    required this.roomId,
    RealtimeConnector? connector,
    Future<String?> Function()? readToken,
    Future<String?> Function()? readServer,
  }) : _connector = connector ?? connectRealtime,
       _readToken = readToken ?? _sessionToken,
       _readServer = readServer ?? ServerConfig.readUrl;

  static const maxRetryDelay = Duration(seconds: 30);

  /// Close codes after which trying again is no use: the session is not
  /// valid, or there is no meeting by that code the user is in (ended,
  /// removed from it, or never let in). Too many refused codes from this
  /// address (4429) is tried again later like a dropped connection.
  static const _closeInvalidToken = 4401;
  static const _closeRoomGone = 4404;

  final String roomId;
  final RealtimeConnector _connector;
  final Future<String?> Function() _readToken;
  final Future<String?> Function() _readServer;
  final _changes = StreamController<RoomChange>.broadcast();

  RealtimeSocket? _socket;
  StreamSubscription<dynamic>? _listening;
  Timer? _retry;
  int _failures = 0;
  bool _running = false;
  bool _connecting = false;
  bool _connected = false;

  bool get connected => _connected;

  /// What changed, as it happens. Right after (re)connecting it says both
  /// changed, to catch up on what came while away.
  Stream<RoomChange> get changes => _changes.stream;

  static Future<String?> _sessionToken() async {
    return await ServerConfig.readToken() ??
        await ServerConfig.readGuestToken();
  }

  void start() {
    if (_running) return;
    _running = true;
    unawaited(_connect());
  }

  Future<void> _connect() async {
    if (!_running || _connecting || _socket != null) return;
    _connecting = true;
    try {
      final token = await _readToken();
      final server = await _readServer();
      if (token == null || server == null || !_running) return;
      final socket = await _connector(realtimeUri(server));
      if (!_running) {
        await socket.close();
        return;
      }
      _socket = socket;
      _listening = socket.messages.listen(
        _receive,
        onDone: () => _dropped(socket),
        onError: (_) => _dropped(socket),
        cancelOnError: true,
      );
      // Who it is goes in a message, never in the URL.
      socket.send(jsonEncode({'type': 'auth', 'token': token, 'room': roomId}));
    } catch (_) {
      _scheduleRetry();
    } finally {
      _connecting = false;
    }
  }

  void _receive(dynamic data) {
    if (data is! String) return;
    final Object? event;
    try {
      event = jsonDecode(data);
    } on FormatException {
      return;
    }
    if (event is! Map) return;
    switch (event['type']) {
      case 'ready':
        _failures = 0;
        _setConnected(true);
        _changes
          ..add(RoomChange.state)
          ..add(RoomChange.chat);
      case 'room' when event['room'] == roomId:
        switch (event['what']) {
          case 'chat':
            _changes.add(RoomChange.chat);
          case 'state':
            _changes.add(RoomChange.state);
        }
    }
  }

  void _dropped(RealtimeSocket socket) {
    if (_socket != socket) return;
    _listening?.cancel();
    _listening = null;
    _socket = null;
    _setConnected(false);
    final code = socket.closeCode;
    if (code == _closeInvalidToken || code == _closeRoomGone) return;
    _scheduleRetry();
  }

  void _setConnected(bool value) {
    if (_connected == value || !_running) return;
    _connected = value;
    notifyListeners();
  }

  void _scheduleRetry() {
    if (!_running) return;
    _retry?.cancel();
    final seconds = math.min(
      maxRetryDelay.inSeconds,
      math.pow(2, _failures).toInt(),
    );
    _failures++;
    _retry = Timer(Duration(seconds: seconds), _connect);
  }

  @override
  void dispose() {
    _running = false;
    _retry?.cancel();
    _listening?.cancel();
    unawaited(_socket?.close());
    _socket = null;
    unawaited(_changes.close());
    super.dispose();
  }
}

/// Paces a poll that runs beside a [RoomRealtime]: on every tick (every
/// [tick]) while the connection is down, and only every [slow] while it is
/// up. It counts ticks rather than reading the clock.
class PollPace {
  PollPace(this.realtime, {required Duration tick, required Duration slow})
    : _ticksPerPoll = math.max(1, slow.inMilliseconds ~/ tick.inMilliseconds);

  final RoomRealtime? realtime;
  final int _ticksPerPoll;
  int _quietTicks = 0;

  /// Whether this tick should poll; it then counts as polled.
  bool due() {
    if (realtime?.connected == true && ++_quietTicks < _ticksPerPoll) {
      return false;
    }
    _quietTicks = 0;
    return true;
  }

  /// A read made for another reason (an event) counts as a poll.
  void polled() => _quietTicks = 0;
}
