import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/meeting/meeting_chat.dart';

class _ChatApi extends MeetingApi {
  final reads = <Completer<List<MeetingChatMessage>>>[];
  late final sentMessage = MeetingChatMessage(
    id: 7,
    roomId: '123-456-789',
    sender: 'Me',
    content: 'hello',
    createdAt: DateTime.utc(2026),
    isMine: true,
  );

  @override
  Future<List<MeetingChatMessage>> getRoomMessages(String roomId) {
    final read = Completer<List<MeetingChatMessage>>();
    reads.add(read);
    return read.future;
  }

  @override
  Future<MeetingChatMessage> sendRoomMessage(
    String roomId,
    String content,
  ) async => sentMessage;
}

void main() {
  test('an older chat poll preserves a newly sent message', () async {
    final api = _ChatApi();
    final chat = MeetingChatController(roomId: '123-456-789', api: api);
    final firstRead = chat.refreshMessages();
    expect(api.reads, hasLength(1));

    expect(await chat.sendMessage('hello'), isTrue);
    api.reads.first.complete([]);
    await firstRead;
    expect(chat.messages.map((message) => message.id), [7]);

    final secondRead = chat.refreshMessages();
    api.reads.last.complete([api.sentMessage]);
    await secondRead;
    expect(chat.messages.map((message) => message.id), [7]);
    chat.dispose();
  });
}
