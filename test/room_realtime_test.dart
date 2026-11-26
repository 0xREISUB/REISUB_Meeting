import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/meeting/meeting_chat.dart';
import 'package:v_meeting/meeting/meeting_sharing.dart';
import 'package:v_meeting/meeting/room_realtime.dart';
import 'package:v_meeting/social/realtime.dart';

import 'realtime_test.dart' show FakeSocket;

const room = '123-456-789';

class _CountingApi extends MeetingApi {
  int stateReads = 0;
  int messageReads = 0;

  @override
  Future<MeetingState> getMeetingState(String roomId) async {
    stateReads++;
    return const MeetingState();
  }

  @override
  Future<List<MeetingChatMessage>> getRoomMessages(String roomId) async {
    messageReads++;
    return const [];
  }
}

class _Server {
  final sockets = <FakeSocket>[];
  final uris = <Uri>[];
  FakeSocket get socket => sockets.last;

  Future<RealtimeSocket> connect(Uri uri) async {
    uris.add(uri);
    final socket = FakeSocket();
    sockets.add(socket);
    return socket;
  }

  RoomRealtime watch() => RoomRealtime(
    roomId: room,
    connector: connect,
    readToken: () async => 'guest-7',
    readServer: () async => 'https://meeting.test:443',
  )..start();
}

void main() {
  testWidgets('it watches the meeting and says what changed', (tester) async {
    final server = _Server();
    final realtime = server.watch();
    final changes = <RoomChange>[];
    final listening = realtime.changes.listen(changes.add);
    await tester.pump();

    expect(server.uris.single.toString(), 'wss://meeting.test/ws');
    expect(server.socket.sent.single, {
      'type': 'auth',
      'token': 'guest-7',
      'room': room,
    });
    expect(realtime.connected, isFalse);

    // Ready: catch up on both.
    server.socket.push({'type': 'ready'});
    await tester.pump();
    expect(realtime.connected, isTrue);
    expect(changes, [RoomChange.state, RoomChange.chat]);

    changes.clear();
    server.socket
      ..push({'type': 'room', 'room': room, 'what': 'chat'})
      ..push({'type': 'room', 'room': '999-999-999', 'what': 'state'})
      ..push({'type': 'room', 'room': room, 'what': 'state'});
    await tester.pump();
    expect(changes, [RoomChange.chat, RoomChange.state]);

    // Dropped: tried again, later.
    unawaited(server.socket.drop());
    await tester.pump();
    expect(realtime.connected, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(server.sockets, hasLength(2));

    // The meeting is over: no more tries.
    unawaited(server.socket.drop(4404));
    await tester.pump(RoomRealtime.maxRetryDelay);
    expect(server.sockets, hasLength(2));

    unawaited(listening.cancel());
    realtime.dispose();
  });

  testWidgets('connected, the meeting is read on news and polled slowly', (
    tester,
  ) async {
    final server = _Server();
    final realtime = server.watch();
    final api = _CountingApi();
    final sharing = MeetingSharing(roomId: room, api: api, realtime: realtime)
      ..start();
    final chat = MeetingChatController(
      roomId: room,
      api: api,
      realtime: realtime,
    )..start();
    await tester.pump();
    expect((api.stateReads, api.messageReads), (1, 1));

    // Not connected yet: polled every two seconds.
    await tester.pump(MeetingSharing.pollInterval);
    expect((api.stateReads, api.messageReads), (2, 2));

    server.socket.push({'type': 'ready'});
    await tester.pump();
    expect((api.stateReads, api.messageReads), (3, 3));

    // Connected: quiet until something happens…
    await tester.pump(const Duration(seconds: 10));
    expect((api.stateReads, api.messageReads), (3, 3));
    server.socket.push({'type': 'room', 'room': room, 'what': 'chat'});
    await tester.pump();
    expect((api.stateReads, api.messageReads), (3, 4));
    server.socket.push({'type': 'room', 'room': room, 'what': 'state'});
    await tester.pump();
    expect((api.stateReads, api.messageReads), (4, 4));

    // …but still asked now and then, in case news was missed.
    await tester.pump(MeetingSharing.slowPoll);
    expect((api.stateReads, api.messageReads), (5, 5));

    // Without the connection, back to every two seconds.
    unawaited(server.socket.drop(4404));
    await tester.pump();
    await tester.pump(MeetingSharing.pollInterval);
    expect((api.stateReads, api.messageReads), (6, 6));

    sharing.dispose();
    chat.dispose();
    realtime.dispose();
  });
}
