import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/app/app.dart';
import 'package:v_meeting/app/app_startup.dart';
import 'package:v_meeting/app/http.dart';
import 'package:v_meeting/social/notifications.dart';

import 'social_tab_test.dart' show FakeSocialServer, settle;

/// The whole app, logged in to the fake social server, on the home tab.
Future<FakeSocialServer> showApp(
  WidgetTester tester, {
  Size size = const Size(1280, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  FlutterSecureStorage.setMockInitialValues({'auth_token': 'account-1'});
  SharedPreferences.setMockInitialValues({
    'server_url': 'https://meeting.test:443',
  });
  final server = FakeSocialServer();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(server.dio()),
        appStartupProvider.overrideWith((ref) async => StartDestination.home),
      ],
      child: const VMeetingApp(),
    ),
  );
  await settle(tester);
  return server;
}

/// Lets the next notifications poll run.
Future<void> poll(WidgetTester tester) async {
  await tester.pump(NotificationsController.interval);
  await settle(tester);
}

Finder card(int id) => find.byKey(ValueKey('notification-$id'));

void main() {
  testWidgets('a message from anywhere shows wherever the user is', (
    tester,
  ) async {
    final server = await showApp(tester);
    // Old messages are not announced: the first poll only finds where to
    // start.
    await poll(tester);
    expect(find.byKey(const ValueKey('in-app-notifications')), findsNothing);

    server.notify(
      kind: 'friend',
      targetId: 2,
      title: 'Elif',
      sender: 'Elif',
      content: 'Akşam müsait misin?',
    );
    await poll(tester);
    expect(card(101), findsOneWidget);
    expect(find.text('Akşam müsait misin?'), findsOneWidget);

    // It goes by itself after a while.
    await tester.pump(NotificationsController.shownFor);
    await settle(tester);
    expect(card(101), findsNothing);
  });

  testWidgets('tapping a notification opens its chat', (tester) async {
    final server = await showApp(tester);
    await poll(tester);
    server.notify(
      kind: 'team',
      targetId: 11,
      title: 'Core',
      sender: 'Burak',
      content: '5 dakikaya oradayım',
    );
    await poll(tester);
    // A team's message says who wrote it.
    expect(find.text('Burak: 5 dakikaya oradayım'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-notification-101')));
    await settle(tester);
    expect(find.byKey(const ValueKey('chat-team-11')), findsOneWidget);
    expect(card(101), findsNothing);
  });

  testWidgets('a chat on screen is not announced on top of itself', (
    tester,
  ) async {
    final server = await showApp(tester);
    await poll(tester);
    await tester.tap(find.byIcon(Icons.people_alt_outlined));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('friend-2')));
    await settle(tester);

    server.notify(kind: 'friend', targetId: 2, title: 'Elif', sender: 'Elif');
    server.notify(kind: 'friend', targetId: 3, title: 'Burak', sender: 'Burak');
    await poll(tester);
    // Elif's chat shows; Burak's does not.
    expect(card(101), findsNothing);
    expect(card(102), findsOneWidget);
    // Elif's chat catches up at once.
    expect(
      server.calls.where((call) => call.startsWith('GET /chats/friend/2')),
      hasLength(greaterThan(1)),
    );

    // Away to settings, her chat no longer shows.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await settle(tester);
    server.notify(kind: 'friend', targetId: 2, title: 'Elif', sender: 'Elif');
    await poll(tester);
    expect(card(103), findsOneWidget);
  });

  testWidgets('a meeting invitation rings as a call, not as a message', (
    tester,
  ) async {
    final server = await showApp(tester);
    await poll(tester);
    server.notify(
      kind: 'team',
      targetId: 11,
      title: 'Core',
      sender: 'Burak',
      roomId: '777-888-999',
    );
    await poll(tester);
    // The call card shows it (see calls_test.dart); no message notice on
    // top of it.
    expect(card(101), findsNothing);
  });

  testWidgets('waiting messages show as badges and are read when opened', (
    tester,
  ) async {
    final server = await showApp(tester);
    // One request, two from Elif, one in Core.
    expect(
      find.byKey(const ValueKey('unread-2'), skipOffstage: false),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.people_alt_outlined));
    await settle(tester);
    expect(find.text('4'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('friend-2')));
    await settle(tester);
    expect(server.bodies['POST /chats/friend/2/read'], {'last_id': 2});
  });
}
