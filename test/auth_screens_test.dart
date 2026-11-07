import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/app/http.dart';
import 'package:v_meeting/auth/login_screen.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'package:v_meeting/home/home_screen.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

/// Answers each login request when the test completes [pending].
Dio slowLoginClient(List<RequestOptions> requests, Completer<void> pending) {
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          requests.add(options);
          await pending.future;
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: {'token': 'new-session'},
            ),
          );
        },
      ),
    );
  addTearDown(dio.close);
  return dio;
}

Widget app(Widget child, Dio dio) => ProviderScope(
  overrides: [dioProvider.overrideWithValue(dio)],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'server_url': 'https://meeting.test:443',
    });
  });

  testWidgets('login ignores repeated taps while a request is running', (
    tester,
  ) async {
    final requests = <RequestOptions>[];
    final pending = Completer<void>();
    await tester.pumpWidget(
      app(const LoginScreen(), slowLoginClient(requests, pending)),
    );
    await tester.enterText(find.byKey(const Key('login-nick')), ' ali ');
    await tester.enterText(find.byKey(const Key('login-password')), 'secret');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(requests, hasLength(1));
    expect(requests.single.data, {'nick': 'ali', 'password': 'secret'});
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(await ServerConfig.readToken(), 'new-session');
  });

  testWidgets('login with empty fields sends nothing', (tester) async {
    final requests = <RequestOptions>[];
    await tester.pumpWidget(
      app(const LoginScreen(), slowLoginClient(requests, Completer())),
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    expect(requests, isEmpty);
    expect(find.text('Enter your username and password.'), findsOneWidget);
  });
}
