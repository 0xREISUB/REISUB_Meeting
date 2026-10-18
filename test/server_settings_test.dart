import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/auth/host_screen.dart';
import 'package:v_meeting/auth/login_screen.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/settings/settings_screen.dart';

Widget app(Widget child) => ProviderScope(
  child: MaterialApp(
    key: UniqueKey(),
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);

String fieldText(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(EditableText),
      ),
    )
    .controller
    .text;

Future<void> showSettings(WidgetTester tester, {Dio? dio}) async {
  await tester.pumpWidget(app(SettingsScreen(dio: dio)));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.byKey(const Key('server-host')), 250);
  await tester.pumpAndSettle();
}

Dio pingClient(List<RequestOptions> requests, {bool success = true}) {
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'message': success ? 'pong' : 'unexpected',
                'status': 'active',
              },
            ),
          );
        },
      ),
    );
  addTearDown(dio.close);
  return dio;
}

Future<void> saveSettings(WidgetTester tester) async {
  final button = find.text('Sunucu Ayarlarını Kaydet');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('address and port share one builder, including HTTPS and IPv6', () {
    for (final entry in {
      '192.168.1.20': 'http://192.168.1.20:9000',
      'https://meeting.test:8443/': 'https://meeting.test:9000',
      'HTTPS://meeting.test/': 'https://meeting.test:9000',
      '[::1]': 'http://[::1]:9000',
    }.entries) {
      expect(
        ServerConfig.buildUrl(address: entry.key, port: '9000'),
        entry.value,
      );
    }
    for (final port in ['', '0', '-1', '65536', 'abc']) {
      expect(ServerConfig.buildUrl(address: 'localhost', port: port), isNull);
    }
    expect(ServerConfig.buildUrl(address: '', port: '8080'), isNull);
  });

  for (final url in [
    'http://192.168.1.20:4567',
    'https://meeting.test:8443',
    'http://meeting.test:80',
    'https://meeting.test:443',
  ]) {
    testWidgets('startup and settings show the same saved endpoint: $url', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'server_url': url});
      await tester.pumpWidget(app(const HostScreen()));
      await tester.pumpAndSettle();
      final host = fieldText(tester, 'server-host');
      final port = fieldText(tester, 'server-port');
      expect(port, Uri.parse(url).port.toString());
      expect(
        ServerConfig.buildUrl(address: host, port: port),
        Uri.parse(url).toString(),
      );
      await showSettings(tester);
      expect(fieldText(tester, 'server-host'), host);
      expect(fieldText(tester, 'server-port'), port);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('both forms default to port 8080 without a saved server', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app(const HostScreen()));
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'server-port'), '8080');
    await showSettings(tester);
    expect(fieldText(tester, 'server-host'), isEmpty);
    expect(fieldText(tester, 'server-port'), '8080');
  });

  testWidgets('startup persists the entered port for the settings form', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final requests = <RequestOptions>[];
    final dio = pingClient(requests);
    await tester.pumpWidget(app(HostScreen(dio: dio)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('server-host')),
      'https://meeting.test',
    );
    await tester.enterText(find.byKey(const Key('server-port')), '9443');
    await saveSettings(tester);
    expect(requests.single.uri.toString(), 'https://meeting.test:9443/ping');
    expect(await ServerConfig.readUrl(), 'https://meeting.test:9443');
    expect(find.byType(LoginScreen), findsOneWidget);
    await showSettings(tester);
    expect(fieldText(tester, 'server-host'), 'https://meeting.test');
    expect(fieldText(tester, 'server-port'), '9443');
  });

  testWidgets(
    'changing only the settings port preserves HTTPS and persists after reopening',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'server_url': 'https://meeting.test:443',
        'auth_token': 'old-session',
      });
      final requests = <RequestOptions>[];
      await showSettings(tester, dio: pingClient(requests));
      await tester.ensureVisible(find.byKey(const Key('server-port')));
      await tester.enterText(find.byKey(const Key('server-port')), '8443');
      await saveSettings(tester);
      expect(requests.single.uri.toString(), 'https://meeting.test:8443/ping');
      expect(await ServerConfig.readUrl(), 'https://meeting.test:8443');
      expect(await ServerConfig.readToken(), isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.pumpWidget(app(const HostScreen()));
      await tester.pumpAndSettle();
      expect(fieldText(tester, 'server-port'), '8443');
      expect(fieldText(tester, 'server-host'), 'https://meeting.test');
    },
  );

  testWidgets(
    'saving an unchanged HTTPS endpoint keeps the session and standard port',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'server_url': 'https://meeting.test:443',
        'auth_token': 'keep-session',
      });
      final requests = <RequestOptions>[];
      await showSettings(tester, dio: pingClient(requests));
      await saveSettings(tester);
      expect(requests.single.uri.scheme, 'https');
      expect(requests.single.uri.port, 443);
      expect(await ServerConfig.readToken(), 'keep-session');
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(fieldText(tester, 'server-port'), '443');
    },
  );

  testWidgets(
    'failed server validation leaves the saved endpoint and session intact',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'server_url': 'http://localhost:8080',
        'auth_token': 'keep-session',
      });
      final requests = <RequestOptions>[];
      await showSettings(tester, dio: pingClient(requests, success: false));
      await tester.ensureVisible(find.byKey(const Key('server-port')));
      await tester.enterText(find.byKey(const Key('server-port')), '9090');
      await saveSettings(tester);
      expect(requests.single.uri.port, 9090);
      expect(await ServerConfig.readUrl(), 'http://localhost:8080');
      expect(await ServerConfig.readToken(), 'keep-session');
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
