import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:v_meeting/meeting/meeting_connection.dart';

class _EventRoom implements Room {
  @override
  final events = EventsEmitter<RoomEvent>();

  @override
  EventsListener<RoomEvent> createListener({bool synchronized = false}) =>
      EventsListener<RoomEvent>(events, synchronized: synchronized);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _EventRoom room;
  late MeetingConnection connection;

  setUp(() {
    room = _EventRoom();
    connection = MeetingConnection(room);
  });

  tearDown(() async {
    connection.dispose();
    await room.events.dispose();
  });

  Future<void> emit(RoomEvent event) async {
    room.events.streamCtrl.add(event);
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'media reconnect and signal resume are never shown as connected',
    () async {
      connection.markConnected();
      expect(connection.isConnected, isTrue);
      await emit(const RoomReconnectingEvent());
      expect(connection.phase, MeetingConnectionPhase.reconnecting);
      expect(connection.isConnected, isFalse);
      expect(connection.message, contains('Yeniden bağlanılıyor'));
      await emit(const RoomReconnectedEvent());
      expect(connection.isConnected, isTrue);
      expect(connection.message, isNull);
      await emit(const RoomResumingEvent());
      expect(connection.isConnected, isFalse);
    },
  );

  test(
    'final disconnect reports actual reason and reconnect clears it',
    () async {
      connection.markConnected();
      await emit(
        RoomDisconnectedEvent(reason: DisconnectReason.duplicateIdentity),
      );
      expect(connection.phase, MeetingConnectionPhase.disconnected);
      expect(connection.message, contains('başka bir cihazda'));
      connection.startConnecting();
      expect(connection.disconnectReason, isNull);
      expect(connection.phase, MeetingConnectionPhase.connecting);
      await emit(RoomConnectedEvent(room: room, metadata: null));
      expect(connection.isConnected, isTrue);
      expect(connection.message, isNull);
    },
  );

  test(
    'exhausted retries stay disconnected until a new connection succeeds',
    () async {
      await emit(
        RoomDisconnectedEvent(
          reason: DisconnectReason.reconnectAttemptsExceeded,
        ),
      );
      expect(connection.isConnected, isFalse);
      expect(connection.message, contains('geri kurulamadı'));
      connection.startConnecting();
      connection.fail('Oda bulunamadı');
      expect(connection.isConnected, isFalse);
      expect(connection.message, contains('Oda bulunamadı'));
    },
  );

  test(
    'subscription failures remain visible while signaling is connected',
    () async {
      connection.markConnected();
      await emit(
        const TrackSubscriptionExceptionEvent(
          reason: TrackSubscribeFailReason.noParticipantFound,
        ),
      );
      expect(connection.isConnected, isTrue);
      expect(connection.message, contains('medya akışı alınamadı'));
    },
  );
  test(
    'closed rooms and removed participants are not offered a rejoin',
    () async {
      for (final reason in [
        DisconnectReason.roomDeleted,
        DisconnectReason.roomClosed,
        DisconnectReason.participantRemoved,
      ]) {
        await emit(RoomDisconnectedEvent(reason: reason));
        expect(connection.canRejoin, isFalse);
      }
      connection.startConnecting();
      expect(connection.canRejoin, isTrue);
    },
  );
}
