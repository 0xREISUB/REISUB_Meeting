import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/app/app.dart';
import 'package:v_meeting/app/deep_links.dart';
import 'package:v_meeting/auth/server_config.dart';
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
  group('invite links', () {
    InviteLink? parse(String link, {bool webPage = false}) =>
        parseInviteLink(Uri.parse(link), webPage: webPage);

    test('the app scheme carries the room and the server', () {
      expect(
        parse(
          'reisub-meeting://join/123-456-789'
          '?server=https%3A%2F%2Fmeeting.test',
        ),
        const InviteLink(
          roomId: '123-456-789',
          serverUrl: 'https://meeting.test',
        ),
      );
      expect(
        parse('reisub-meeting://join/123-456-789'),
        const InviteLink(roomId: '123-456-789'),
      );
    });

    test('https invites use their own origin as the server', () {
      const expected = InviteLink(
        roomId: '123-456-789',
        serverUrl: 'https://meeting.test',
      );
      expect(parse('https://meeting.test/j/123-456-789'), expected);
      expect(parse('https://meeting.test/invite/?room=123-456-789'), expected);
    });

    test('the web app leaves the server to its own logic', () {
      expect(
        parse('https://meeting.test/?room=123-456-789', webPage: true),
        const InviteLink(roomId: '123-456-789'),
      );
    });

    test('invalid codes, hosts and servers are rejected', () {
      expect(parse('https://meeting.test/?room=12-3'), isNull);
      expect(parse('https://meeting.test/'), isNull);
      expect(parse('reisub-meeting://settings/123-456-789'), isNull);
      expect(parse('ftp://meeting.test/j/123-456-789'), isNull);
      // Public servers must use HTTPS, so such a server is ignored.
      expect(
        parse('reisub-meeting://join/123-456-789?server=http://evil.test'),
        const InviteLink(roomId: '123-456-789'),
      );
    });
  });

  test('desktop apps read the invite from the command line', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(
      await DeepLinks.launchInvite([
        '--some-flag',
        'reisub-meeting://join/123-456-789?server=https://meeting.test',
      ]),
      const InviteLink(
        roomId: '123-456-789',
        serverUrl: 'https://meeting.test',
      ),
    );
    expect(await DeepLinks.launchInvite(['--some-flag']), isNull);
  });

  group('opening an invite for another server', () {
    Future<void> openInvite(WidgetTester tester) async {
      await tester.pumpWidget(
        localized(
          const JoinScreen(
            initialRoomId: '123-456-789',
            inviteServerUrl: 'https://other.test',
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('asks before switching servers', (tester) async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'account'});
      SharedPreferences.setMockInitialValues({
        'server_url': 'https://meeting.test',
      });
      await openInvite(tester);
      expect(find.text('Sunucu değiştirilsin mi?'), findsOneWidget);
      expect(find.textContaining('other.test'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('switch-invite-server')));
      await tester.pumpAndSettle();
      expect(await ServerConfig.readUrl(), 'https://other.test');
      expect(await ServerConfig.readToken(), isNull);
    });

    testWidgets('declining keeps the current server and session', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({'auth_token': 'account'});
      SharedPreferences.setMockInitialValues({
        'server_url': 'https://meeting.test',
      });
      await openInvite(tester);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(await ServerConfig.readUrl(), 'https://meeting.test');
      expect(await ServerConfig.readToken(), 'account');
    });

    testWidgets('a first launch from an invite uses its server', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            launchInviteProvider.overrideWithValue(
              const InviteLink(
                roomId: '123-456-789',
                serverUrl: 'https://meeting.test',
              ),
            ),
          ],
          child: const VMeetingApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(JoinScreen), findsOneWidget);
      expect(find.text('123-456-789'), findsOneWidget);
      expect(find.text('Server Settings'), findsNothing);
      expect(await ServerConfig.readUrl(), 'https://meeting.test');
    });
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
