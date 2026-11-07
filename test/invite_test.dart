import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/app/app_startup.dart';
import 'package:v_meeting/app/invite.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/join_screen.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/meeting/widgets/meeting_banners.dart';

Widget localized(Widget child) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

/// Records clipboard writes.
List<String> mockClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

void main() {
  test('invite links carry a valid room code only', () {
    expect(
      parseInviteRoom(Uri.parse('https://m.test/?room=123-456-789')),
      '123-456-789',
    );
    expect(parseInviteRoom(Uri.parse('https://m.test/?room=12-3')), isNull);
    expect(parseInviteRoom(Uri.parse('https://m.test/')), isNull);
  });

  test('without a server link the invite page is on the meeting server', () {
    expect(
      fallbackInviteLink('123-456-789', serverUrl: 'https://meeting.test:8443'),
      'https://meeting.test:8443/invite/?room=123-456-789',
    );
  });

  test('the web app uses the server that served it', () {
    expect(
      webServerUrl(page: Uri.parse('https://meeting.test/?room=1#/')),
      'https://meeting.test',
    );
    // Public servers must use HTTPS.
    expect(webServerUrl(page: Uri.parse('http://meeting.test/')), isNull);
  });

  test('join responses carry the server invite link', () {
    final credentials = RoomCredentials.fromJson({
      'room_id': '123-456-789',
      'livekit_url': 'wss://m.test',
      'token': 't',
      'participant': 'Ali',
      'invite_url': 'https://m.test/j/123-456-789',
    });
    expect(credentials.inviteUrl, 'https://m.test/j/123-456-789');
  });

  testWidgets('an invite prefills the join screen', (tester) async {
    await tester.pumpWidget(
      localized(const JoinScreen(initialRoomId: '123-456-789')),
    );
    await tester.pumpAndSettle();
    expect(find.text('123-456-789'), findsOneWidget);
  });

  testWidgets('the room code is copied and the invite button copies a link', (
    tester,
  ) async {
    final copied = mockClipboard(tester);
    await tester.pumpWidget(
      localized(
        RoomCodeBanner(
          roomId: '123-456-789',
          onClose: () {},
          inviteLink: () async => 'https://m.test/j/123-456-789',
        ),
      ),
    );
    await tester.pump();
    expect(copied, ['123-456-789']);
    expect(find.text('Oda kodu kopyalandı'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('room-invite')));
    await tester.pump();
    expect(copied.last, 'https://m.test/j/123-456-789');
    expect(find.text('Davet bağlantısı kopyalandı'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
