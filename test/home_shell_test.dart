import 'package:v_meeting/l10n/delegates.dart';
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/app/http.dart';
import 'package:v_meeting/auth/login_screen.dart';
import 'package:v_meeting/home/home_screen.dart';
import 'package:v_meeting/home/home_tab.dart';
import 'package:v_meeting/social/social_tab.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/settings/about_screen.dart';
import 'package:v_meeting/settings/language_screen.dart';
import 'package:v_meeting/settings/server_terms_screen.dart';
import 'package:v_meeting/settings/settings_view.dart';

/// A server answering /policy; others get the ping reply.
Dio server({bool guests = true}) {
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 200,
            data: options.uri.path == '/policy'
                ? {'guests_allowed': guests}
                : {'message': 'pong', 'status': 'active'},
          ),
        ),
      ),
    );
  addTearDown(dio.close);
  return dio;
}

Future<void> showHome(WidgetTester tester, {bool guests = true}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [dioProvider.overrideWithValue(server(guests: guests))],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls the settings tab until [key]'s row is built.
Future<void> scrollSettingsTo(WidgetTester tester, String key) async {
  // The settings list itself; its text fields scroll too.
  final list = find
      .descendant(
        of: find.byType(SettingsView),
        matching: find.byType(Scrollable),
      )
      .first;
  for (var i = 0; i < 20; i++) {
    if (find.byKey(ValueKey(key)).evaluate().isNotEmpty) break;
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'server_url': 'https://meeting.test:443',
    });
  });

  testWidgets('home opens in front, between social and settings', (
    tester,
  ) async {
    await showHome(tester);
    expect(find.byType(HomeTab), findsOneWidget);
    expect(find.text('Sosyal'), findsOneWidget);
    expect(find.text('Ana sayfa'), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);
    // The meeting buttons are on the home tab.
    expect(find.text('Toplantıya Katıl'), findsOneWidget);
  });

  testWidgets('a tab slides in when it is chosen', (tester) async {
    await showHome(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    // Halfway through the slide both are on screen.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(HomeTab), findsOneWidget);
    expect(find.byType(SettingsView), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(HomeTab), findsNothing);
    expect(find.byType(SettingsView), findsOneWidget);

    // From settings, social is two tabs to the left.
    await tester.tap(find.byIcon(Icons.people_alt_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(SocialTab), findsOneWidget);
    expect(
      find.byKey(const ValueKey('social-signed-out-body')),
      findsOneWidget,
    );
  });

  testWidgets('tabs stay built, so sliding to one builds nothing', (
    tester,
  ) async {
    await showHome(tester);
    // Settings is built ahead of time, before it is ever shown.
    final settings = find.byType(SettingsView, skipOffstage: false);
    expect(settings, findsOneWidget);
    final state = tester.state(settings);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SettingsView), const Offset(0, -300));
    await tester.pumpAndSettle();
    final scrolled = tester
        .state<ScrollableState>(
          find
              .descendant(of: settings, matching: find.byType(Scrollable))
              .first,
        )
        .position
        .pixels;
    expect(scrolled, greaterThan(0));

    // Away to social and back: the same page, where it was left.
    await tester.tap(find.byIcon(Icons.people_alt_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(tester.state(settings), same(state));
    expect(
      tester
          .state<ScrollableState>(
            find
                .descendant(of: settings, matching: find.byType(Scrollable))
                .first,
          )
          .position
          .pixels,
      scrolled,
    );
  });

  testWidgets('tabs can be swiped', (tester) async {
    await showHome(tester);
    final tabs = find.byKey(const ValueKey('home-tabs'));
    await tester.fling(tabs, const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsView), findsOneWidget);
    // The bar follows the swipe.
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    await tester.fling(tabs, const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    await tester.fling(tabs, const Offset(400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.byType(SocialTab), findsOneWidget);
  });

  testWidgets('settings open language, server terms and about', (tester) async {
    await showHome(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    for (final (key, screen) in [
      ('settings-language', LanguageScreen),
      ('settings-server-terms', ServerTermsScreen),
      ('settings-about', AboutScreen),
    ]) {
      await scrollSettingsTo(tester, key);
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      expect(find.byType(screen), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('logging out where guests are refused asks to log in', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'account-1'});
    await showHome(tester, guests: false);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await scrollSettingsTo(tester, 'settings-logout');
    await tester.tap(find.byKey(const ValueKey('settings-logout')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byKey(const Key('login-guests-refused')), findsOneWidget);
  });
}
