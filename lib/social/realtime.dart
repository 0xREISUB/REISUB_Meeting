import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/auth/account.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'package:v_meeting/calls/call_controller.dart';
import 'package:v_meeting/calls/ringing_call.dart';
import 'package:v_meeting/social/notifications.dart';
import 'package:v_meeting/social/social_api.dart';
import 'package:v_meeting/social/social_models.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// An open realtime connection to the server.
abstract class RealtimeSocket {
  /// What the server sends: text frames.
  Stream<dynamic> get messages;

  void send(String text);

  /// The server's close code once it has closed; null before.
  int? get closeCode;

  Future<void> close();
}

/// Opens a realtime connection; tests put a fake one in its place.
typedef RealtimeConnector = Future<RealtimeSocket> Function(Uri uri);

final realtimeConnectorProvider = Provider<RealtimeConnector>(
  (ref) => connectRealtime,
);

/// Opens a real WebSocket to [uri].
Future<RealtimeSocket> connectRealtime(Uri uri) async {
  // Tests reach no network; those about the connection bring a fake one.
  if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
    throw StateError('No realtime connection in tests');
  }
  final channel = WebSocketChannel.connect(uri);
  await channel.ready;
  return _ChannelSocket(channel);
}

class _ChannelSocket implements RealtimeSocket {
  _ChannelSocket(this._channel);

  final WebSocketChannel _channel;

  @override
  Stream<dynamic> get messages => _channel.stream;

  @override
  void send(String text) => _channel.sink.add(text);

  @override
  int? get closeCode => _channel.closeCode;

  @override
  Future<void> close() => _channel.sink.close();
}

/// The server's close codes after which trying again is no use.
const _closeInvalidToken = 4401;
const _closeAccountRequired = 4403;

/// The realtime connection, kept open while the user is logged in: new
/// messages and changes arrive the moment they happen, and nothing needs to
/// be asked for every few seconds. True while connected.
///
/// After every (re)connection it catches up on what it missed; when the
/// connection drops it tries again, waiting longer each time up to
/// [maxRetryDelay], and at once when the app comes back to the front.
final realtimeProvider = NotifierProvider<RealtimeController, bool>(
  RealtimeController.new,
);

class RealtimeController extends Notifier<bool> {
  static const maxRetryDelay = Duration(seconds: 30);

  /// Social changes come in bursts; they are read once they settle.
  static const socialSettle = Duration(milliseconds: 250);

  RealtimeSocket? _socket;
  StreamSubscription<dynamic>? _listening;
  Timer? _retry;
  Timer? _socialRefresh;
  AppLifecycleListener? _lifecycle;
  int _failures = 0;
  bool _running = false;
  bool _connecting = false;

  @override
  bool build() {
    final signedIn = ref.watch(signedInProvider).value ?? false;
    ref.onDispose(_stop);
    if (!signedIn) return false;
    _running = true;
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (!state) _connectNow();
      },
    );
    Future.microtask(_connect);
    return false;
  }

  void _stop() {
    _running = false;
    _retry?.cancel();
    _retry = null;
    _socialRefresh?.cancel();
    _socialRefresh = null;
    _lifecycle?.dispose();
    _lifecycle = null;
    _listening?.cancel();
    _listening = null;
    _socket?.close();
    _socket = null;
  }

  void _connectNow() {
    _retry?.cancel();
    _failures = 0;
    _connect();
  }

  Future<void> _connect() async {
    if (!_running || _connecting || _socket != null) return;
    _connecting = true;
    try {
      final token = await ServerConfig.readToken();
      final server = await ServerConfig.readUrl();
      if (token == null || server == null || !_running) return;
      final uri = realtimeUri(server);
      final socket = await ref.read(realtimeConnectorProvider)(uri);
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
      socket.send(jsonEncode({'type': 'auth', 'token': token}));
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
        state = true;
        // Catch up on what came while away.
        ref.read(notificationsProvider.notifier).check();
        ref.read(socialOverviewProvider.notifier).refresh();
      case 'message':
        final message = event['message'];
        if (message is Map) {
          ref.read(notificationsProvider.notifier).deliver([
            SocialNotification.fromJson(Map<String, dynamic>.from(message)),
          ]);
        }
      case 'call':
        final call = RingingCall.fromJson(event['call']);
        if (call != null) {
          ref.read(callControllerProvider.notifier).incoming(call);
        }
      case 'call_end':
        final info = event['call'];
        if (info is Map) {
          ref
              .read(callControllerProvider.notifier)
              .ended(
                '${info['id']}',
                missed: info['missed'] == true,
                info: endedCall(info),
              );
        }
      case 'call_declined':
        final info = event['call'];
        if (info is Map) {
          ref
              .read(callControllerProvider.notifier)
              .declinedBy('${info['by'] ?? ''}');
        }
      case 'call_unanswered':
        ref.read(callControllerProvider.notifier).unanswered();
      case 'social':
        _socialRefresh?.cancel();
        _socialRefresh = Timer(
          socialSettle,
          () => ref.read(socialOverviewProvider.notifier).refresh(),
        );
    }
  }

  void _dropped(RealtimeSocket socket) {
    if (_socket != socket) return;
    _listening?.cancel();
    _listening = null;
    _socket = null;
    if (state) state = false;
    final code = socket.closeCode;
    if (code == _closeInvalidToken) {
      // The session ended, as on a 401 from the API: forget it, so the app
      // is logged out rather than trying the dead token again and again.
      _forgetSession();
      return;
    }
    if (code == _closeAccountRequired) return;
    _scheduleRetry();
  }

  Future<void> _forgetSession() async {
    try {
      await ServerConfig.clearToken();
    } catch (_) {
      // Unreadable storage: logged out all the same below.
    }
    ref.read(signedInProvider.notifier).refresh();
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
}

/// The realtime address of a server: https://host:443 becomes
/// wss://host:443/ws.
Uri realtimeUri(String server) {
  final base = Uri.parse(server);
  return base.replace(
    scheme: base.scheme == 'https' ? 'wss' : 'ws',
    path: '${base.path.replaceAll(RegExp(r'/+$'), '')}/ws',
  );
}
