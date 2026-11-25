import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/auth/account.dart';
import 'package:v_meeting/auth/login_screen.dart';
import 'package:v_meeting/auth/register_screen.dart';
import 'package:v_meeting/social/chat_pane.dart';
import 'package:v_meeting/social/profile_screen.dart';
import 'package:v_meeting/social/social_tab.dart';

import 'home_shell_test.dart' show showHome;

Future<void> openSocial(
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
  await showHome(tester);
  await tester.tap(find.byIcon(Icons.people_alt_outlined));
  await tester.pumpAndSettle();
  expect(find.byType(SocialTab), findsOneWidget);
}

void main() {
  testWidgets('without an account the tab asks to log in', (tester) async {
    await openSocial(tester, signedIn: false);
    expect(find.byKey(const ValueKey('social-home')), findsNothing);
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
    expect(find.byKey(const ValueKey('social-profile')), findsOneWidget);
    // Example data, and it says so.
    expect(find.byKey(const ValueKey('social-preview-note')), findsOneWidget);
    expect(find.byKey(const ValueKey('request-r1')), findsOneWidget);
    expect(find.byKey(const ValueKey('friend-f2')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('segment-1')));
    // The live team's dot keeps pulsing, so the screen never settles.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('friend-f2')), findsNothing);
    expect(find.byKey(const ValueKey('team-t1')), findsOneWidget);
    // A team with a meeting going on comes first.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('team-t1'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('team-t2'))).dy),
    );

    await tester.tap(find.byKey(const ValueKey('segment-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('friend-f2')), findsOneWidget);
  });

  testWidgets('the profile card opens the profile', (tester) async {
    await openSocial(tester, signedIn: true);
    await tester.tap(find.byKey(const ValueKey('social-profile')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('@reisub'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('presence-busy')));
    await tester.pump();
    final busy = tester.widget<ListTile>(
      find.byKey(const ValueKey('presence-busy')),
    );
    expect(busy.trailing, isNotNull);
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
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('social-profile')), findsNothing);
    expect(find.byKey(const ValueKey('social-login')), findsOneWidget);
  });

  testWidgets('on a phone a conversation opens as its own screen', (
    tester,
  ) async {
    await openSocial(tester, signedIn: true, size: const Size(390, 844));
    expect(find.byKey(const ValueKey('social-chat-pane')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('friend-f2')));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('Selam! Akşam müsait misin?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-back')));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsNothing);
  });

  testWidgets('on a computer conversations open in the right pane', (
    tester,
  ) async {
    await openSocial(tester, signedIn: true, size: const Size(1280, 800));
    expect(find.byKey(const ValueKey('chat-placeholder')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('friend-f2')));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsNothing);
    expect(find.byKey(const ValueKey('chat-friend-f2')), findsOneWidget);
    expect(find.text('Selam! Akşam müsait misin?'), findsOneWidget);
    // The list stays beside it, with the open friend marked.
    expect(
      tester.widget<ListTile>(find.byKey(const ValueKey('friend-f2'))).selected,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('segment-1')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('team-t1')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('chat-team-t1')), findsOneWidget);
    expect(find.text('5 dakikaya oradayım'), findsOneWidget);
  });

  testWidgets('on a computer the profile opens as a window', (tester) async {
    await openSocial(tester, signedIn: true, size: const Size(1280, 800));
    await tester.tap(find.byKey(const ValueKey('social-profile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-dialog')), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('profile-dialog')), findsNothing);
  });
}
