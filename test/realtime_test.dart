import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/app/app.dart';
import 'package:v_meeting/app/app_startup.dart';
import 'package:v_meeting/app/http.dart';
import 'package:v_meeting/social/realtime.dart';

import 'social_tab_test.dart' show FakeSocialServer, settle;

/// A realtime connection the test speaks for the server.
class FakeSocket implements RealtimeSocket {
  final _incoming = StreamController<dynamic>();
  final sent = <Map<String, dynamic>>[];

  @override
  int? closeCode;

  @override
  Stream<dynamic> get messages => _incoming.stream;

  @override
  void send(String text) =>
      sent.add(Map<String, dynamic>.from(jsonDecode(text) as Map));

  /// The server sends [event].
  void push(Map<String, Object?> event) => _incoming.add(jsonEncode(event));

  /// The server closes the connection with [code].
  Future<void> drop([int code = 1006]) async {
    closeCode = code;
    await _incoming.close();
  }

  @override
  Future<void> close() async {
    if (!_incoming.isClosed) await _incoming.close();
  }
}

class Harness {
  final server = FakeSocialServer();
  final sockets = <FakeSocket>[];
  final uris = <Uri>[];

  FakeSocket get socket => sockets.last;

  Future<RealtimeSocket> connect(Uri uri) async {
    uris.add(uri);
    final socket = FakeSocket();
    sockets.add(socket);
    return socket;
  }
}

Future<Harness> showApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  FlutterSecureStorage.setMockInitialValues({'auth_token': 'account-1'});
  SharedPreferences.setMockInitialValues({
    'server_url': 'https://meeting.test:443',
  });
  final harness = Harness();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(harness.server.dio()),
        appStartupProvider.overrideWith((ref) async => StartDestination.home),
        realtimeConnectorProvider.overrideWithValue(harness.connect),
      ],
      child: const VMeetingApp(),
    ),
  );
  await settle(tester);
  return harness;
}

Map<String, Object?> messageEvent({
  required int id,
  required String content,
  int targetId = 2,
  String sender = 'Elif',
}) => {
  'type': 'message',
  'message': {
    'id': id,
    'sender_id': 2,
    'sender': sender,
    'content': content,
    'created_at': '2026-11-25T18:40:00Z',
    'is_mine': false,
    'kind': 'friend',
    'target_id': targetId,
    'title': sender,
  },
};

void main() {
  test('the realtime address follows the server', () {
    // 443 is wss's own port, so the address leaves it out.
    expect(
      realtimeUri('https://meeting.test:443').toString(),
      'wss://meeting.test/ws',
    );
    expect(
      realtimeUri('http://192.168.1.10:8080/').toString(),
      'ws://192.168.1.10:8080/ws',
    );
  });

  testWidgets('it says who it is, then messages show at once', (tester) async {
    final harness = await showApp(tester);
    expect(harness.uris.single.toString(), 'wss://meeting.test/ws');
    // Who it is goes in the first message, not the address.
    expect(harness.socket.sent.single, {'type': 'auth', 'token': 'account-1'});

    harness.socket.push({'type': 'ready'});
    await settle(tester);
    harness.socket.push(messageEvent(id: 201, content: 'Şimdi geldi'));
    // No waiting for a poll.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Şimdi geldi'), findsOneWidget);
    // Nor anything asked of the server for it, past the catch-up.
    expect(
      harness.server.calls.where((call) => call.startsWith('GET /chats')),
      isEmpty,
    );
  });

  testWidgets('an open chat takes the message in without asking', (
    tester,
  ) async {
    final harness = await showApp(tester);
    harness.socket.push({'type': 'ready'});
    await settle(tester);
    await tester.tap(find.byIcon(Icons.people_alt_outlined));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('friend-2')));
    await settle(tester);
    final asked = harness.server.calls.length;

    harness.socket.push(messageEvent(id: 202, content: 'Sohbete düştü'));
    await settle(tester);
    expect(find.text('Sohbete düştü'), findsOneWidget);
    // Not announced on top of the open chat, and not fetched again.
    expect(find.byKey(const ValueKey('notification-202')), findsNothing);
    expect(
      harness.server.calls
          .skip(asked)
          .where((call) => call.startsWith('GET /chats/friend/2/messages')),
      isEmpty,
    );
  });

  testWidgets('a social change reads the overview again', (tester) async {
    final harness = await showApp(tester);
    harness.socket.push({'type': 'ready'});
    await settle(tester);
    final before = harness.server.calls.where((c) => c == 'GET /social').length;
    // A burst of changes is read once.
    harness.socket.push({'type': 'social'});
    harness.socket.push({'type': 'social'});
    harness.socket.push({'type': 'social'});
    await settle(tester);
    expect(
      harness.server.calls.where((c) => c == 'GET /social').length,
      before + 1,
    );
  });

  testWidgets('a dropped connection comes back, a dead session does not', (
    tester,
  ) async {
    final harness = await showApp(tester);
    harness.socket.push({'type': 'ready'});
    await settle(tester);

    await harness.socket.drop();
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    expect(harness.sockets, hasLength(2));

    // The server no longer knows the session: it is forgotten, and the
    // dead token is not tried again.
    await harness.socket.drop(4401);
    await tester.pump(const Duration(minutes: 1));
    await settle(tester);
    expect(harness.sockets, hasLength(2));
    expect(await FlutterSecureStorage().read(key: 'auth_token'), isNull);
  });
}
