import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/app/http.dart';
import 'package:v_meeting/auth/account.dart';
import 'package:v_meeting/auth/login_screen.dart';
import 'package:v_meeting/auth/register_screen.dart';
import 'package:v_meeting/home/home_screen.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/social/chat_pane.dart';
import 'package:v_meeting/social/profile_screen.dart';
import 'package:v_meeting/social/social_tab.dart';

/// The server's social API with one user, alice, who has friends, a
/// request and teams. It records what the app asks of it.
class FakeSocialServer {
  final calls = <String>[];
  final bodies = <String, Object?>{};

  /// Messages the next notifications poll brings.
  final pendingNotifications = <Map<String, Object?>>[];
  var latestId = 100;

  /// Queues a message from [sender] in [kind] [targetId]'s chat.
  void notify({
    required String kind,
    required int targetId,
    required String title,
    required String sender,
    String content = '',
    String? roomId,
  }) => pendingNotifications.add({
    'id': ++latestId,
    'sender_id': 99,
    'sender': sender,
    'content': content,
    'room_id': ?roomId,
    'created_at': '2026-11-25T18:30:00Z',
    'is_mine': false,
    'kind': kind,
    'target_id': targetId,
    'title': title,
  });

  Map<String, Object?> person(int id, String nick, String presence) => {
    'id': id,
    'nick': nick,
    'display_name': nick[0].toUpperCase() + nick.substring(1),
    'status_message': '',
    'presence': presence,
    if (presence == 'offline') 'last_seen_seconds': 7200,
  };

  Map<String, Object?> get overview => {
    'profile': {
      'id': 1,
      'nick': 'alice',
      'display_name': 'Alice',
      'status_message': 'coding',
      'presence': 'online',
    },
    'friends': [
      {...person(2, 'elif', 'online'), 'unread': 2},
      person(3, 'burak', 'busy'),
      person(4, 'can', 'offline'),
    ],
    'requests': [
      {'id': 7, 'user': person(5, 'zeynep', 'online')},
    ],
    'outgoing': [
      {'id': 8, 'user': person(6, 'mert', 'offline')},
    ],
    'teams': [
      {
        'id': 11,
        'name': 'Core',
        'color': '#7C4DFF',
        'role': 'owner',
        'member_count': 3,
        'online_count': 2,
        'meeting_live': true,
        'room_id': '111-222-333',
        'unread': 1,
      },
      {
        'id': 12,
        'name': 'Thesis',
        'color': '#009688',
        'role': 'member',
        'member_count': 4,
        'online_count': 1,
        'meeting_live': false,
      },
    ],
  };

  Object? answer(String method, String path, Object? data) {
    calls.add('$method $path');
    bodies['$method $path'] = data;
    final route = Uri.parse(path).path;
    return switch ((method, route)) {
      ('GET', '/social') => overview,
      ('GET', '/notifications') => _notifications(path),
      ('GET', '/chats/friend/2/messages') => [
        {
          'id': 1,
          'sender_id': 2,
          'sender': 'Elif',
          'content': 'Akşam müsait misin?',
          'created_at': '2026-11-25T18:02:00Z',
          'is_mine': false,
        },
        {
          'id': 2,
          'sender_id': 1,
          'sender': 'Alice',
          'content': '',
          'room_id': '444-555-666',
          'created_at': '2026-11-25T18:03:00Z',
          'is_mine': true,
        },
      ],
      ('GET', '/chats/team/11/messages') => [
        {
          'id': 5,
          'sender_id': 3,
          'sender': 'Burak',
          'content': '5 dakikaya oradayım',
          'created_at': '2026-11-25T10:17:00Z',
          'is_mine': false,
        },
      ],
      ('GET', _) when route.startsWith('/chats/') => <Object?>[],
      ('POST', '/chats/friend/2/messages') => {
        'id': 3,
        'sender_id': 1,
        'sender': 'Alice',
        'content': (data as Map)['content'],
        'created_at': '2026-11-25T18:10:00Z',
        'is_mine': true,
      },
      ('POST', '/teams/11/meeting') => {'room_id': '111-222-333'},
      _ => <String, Object?>{},
    };
  }

  Map<String, Object?> _notifications(String path) {
    if (Uri.parse(path).queryParameters['after'] == null) {
      return {'latest_id': latestId, 'messages': <Object?>[]};
    }
    final messages = [...pendingNotifications];
    pendingNotifications.clear();
    return {'latest_id': latestId, 'messages': messages};
  }

  Dio dio() {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final path =
                options.uri.path +
                (options.uri.query.isEmpty ? '' : '?${options.uri.query}');
            if (options.uri.path == '/rooms/join') {
              calls.add('POST /rooms/join');
              bodies['POST /rooms/join'] = options.data;
              // A stand-in failure: joining is the meeting's own business.
              return handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 404,
                    data: {'error': 'Oda bulunamadı', 'code': 'room_not_found'},
                  ),
                ),
              );
            }
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                data: options.uri.path == '/policy'
                    ? {'guests_allowed': true}
                    : answer(options.method, path, options.data),
              ),
            );
          },
        ),
      );
    addTearDown(dio.close);
    return dio;
  }
}

Future<FakeSocialServer> openSocial(
  WidgetTester tester, {
  required bool signedIn,
  Size? size,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  FlutterSecureStorage.setMockInitialValues(
    signedIn ? {'auth_token': 'account-1'} : {},
  );
  SharedPreferences.setMockInitialValues({
    'server_url': 'https://meeting.test:443',
  });
  final server = FakeSocialServer();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dioProvider.overrideWithValue(server.dio())],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.people_alt_outlined));
  await settle(tester);
  expect(find.byType(SocialTab), findsOneWidget);
  return server;
}

/// Lets the screen settle; the live team's dot keeps pulsing, so it never
/// settles fully.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('without an account the tab asks to log in', (tester) async {
    final server = await openSocial(tester, signedIn: false);
    expect(find.byKey(const ValueKey('social-home')), findsNothing);
    // Nobody to be online for: the server is not asked.
    expect(server.calls.where((call) => call == 'GET /social'), isEmpty);
    await tester.tap(find.byKey(const ValueKey('social-login')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    // The login screen has no back button of its own.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('social-register')));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
  });

  testWidgets('logged in shows the profile, friends and teams', (tester) async {
    await openSocial(tester, signedIn: true);
    expect(find.byKey(const ValueKey('social-signed-out-body')), findsNothing);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.byKey(const ValueKey('request-7')), findsOneWidget);
    expect(find.byKey(const ValueKey('friend-2')), findsOneWidget);
    // The request alice sent waits in its own section.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('cancel-request-8')),
      200,
      scrollable: find.byType(Scrollable).at(1),
    );

    await tester.tap(find.byKey(const ValueKey('segment-1')));
    await settle(tester);
    expect(find.byKey(const ValueKey('friend-2')), findsNothing);
    // A team with a meeting going on comes first.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('team-11'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('team-12'))).dy),
    );
  });

  testWidgets('friend requests are answered and sent', (tester) async {
    final server = await openSocial(tester, signedIn: true);
    await tester.tap(find.byKey(const ValueKey('accept-7')));
    await settle(tester);
    expect(server.calls, contains('POST /friends/requests/7/accept'));

    await tester.tap(find.byKey(const ValueKey('social-add')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('social-text-input')),
      ' deniz ',
    );
    await tester.tap(find.byKey(const ValueKey('social-text-submit')));
    await settle(tester);
    expect(server.calls, contains('POST /friends/requests'));
    expect(server.bodies['POST /friends/requests'], {'nick': 'deniz'});
    expect(find.text('Arkadaşlık isteği gönderildi.'), findsOneWidget);
  });

  testWidgets('the profile is saved to the server', (tester) async {
    final server = await openSocial(tester, signedIn: true);
    await tester.tap(find.byKey(const ValueKey('social-profile')));
    await settle(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('@alice'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('profile-display-name')),
      'Alice A',
    );
    await tester.tap(find.byKey(const ValueKey('presence-busy')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('profile-save')),
      200,
      // The profile's list, not a text field's own scrolling.
      scrollable: find
          .descendant(
            of: find.byType(ProfileView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await settle(tester);
    expect(server.bodies['PATCH /me'], {
      'display_name': 'Alice A',
      'status_message': 'coding',
      'presence': 'busy',
    });
    expect(find.byType(ProfileScreen), findsNothing);
  });

  testWidgets('logging out takes the social tab back to the login card', (
    tester,
  ) async {
    await openSocial(tester, signedIn: true);
    expect(find.byKey(const ValueKey('social-profile')), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SocialTab)),
    );
    await container.read(signedInProvider.notifier).signOut();
    await settle(tester);
    expect(find.byKey(const ValueKey('social-profile')), findsNothing);
    expect(find.byKey(const ValueKey('social-login')), findsOneWidget);
  });

  testWidgets('on a phone a conversation opens as its own screen', (
    tester,
  ) async {
    final server = await openSocial(
      tester,
      signedIn: true,
      size: const Size(390, 844),
    );
    expect(find.byKey(const ValueKey('social-chat-pane')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('friend-2')));
    await settle(tester);
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('Akşam müsait misin?'), findsOneWidget);
    // The call alice started shows as an invitation to join.
    expect(find.byKey(const ValueKey('invite-2')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('chat-input')), 'Olur');
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await settle(tester);
    expect(server.bodies['POST /chats/friend/2/messages'], {'content': 'Olur'});
    expect(find.text('Olur'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-back')));
    await settle(tester);
    expect(find.byType(ChatScreen), findsNothing);
  });

  testWidgets('on a computer conversations open in the right pane', (
    tester,
  ) async {
    await openSocial(tester, signedIn: true, size: const Size(1280, 800));
    expect(find.byKey(const ValueKey('chat-placeholder')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('friend-2')));
    await settle(tester);
    expect(find.byType(ChatScreen), findsNothing);
    expect(find.byKey(const ValueKey('chat-friend-2')), findsOneWidget);
    expect(find.text('Akşam müsait misin?'), findsOneWidget);
    // The list stays beside it, with the open friend marked.
    expect(
      tester.widget<ListTile>(find.byKey(const ValueKey('friend-2'))).selected,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('segment-1')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('team-11')));
    await settle(tester);
    expect(find.byKey(const ValueKey('chat-team-11')), findsOneWidget);
    expect(find.text('5 dakikaya oradayım'), findsOneWidget);
  });

  testWidgets('joining a team meeting goes to its room', (tester) async {
    final server = await openSocial(
      tester,
      signedIn: true,
      size: const Size(1280, 800),
    );
    await tester.tap(find.byKey(const ValueKey('segment-1')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('team-meeting-11')));
    await settle(tester);
    expect(server.calls, contains('POST /teams/11/meeting'));
    // It joins as the display name.
    expect(server.bodies['POST /rooms/join'], {
      'room_id': '111-222-333',
      'name': 'Alice',
    });
  });

  testWidgets('on a computer the profile opens as a window', (tester) async {
    await openSocial(tester, signedIn: true, size: const Size(1280, 800));
    await tester.tap(find.byKey(const ValueKey('social-profile')));
    await settle(tester);
    expect(find.byKey(const ValueKey('profile-dialog')), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);
    await tester.tap(find.byType(CloseButton));
    await settle(tester);
    expect(find.byKey(const ValueKey('profile-dialog')), findsNothing);
  });
}
