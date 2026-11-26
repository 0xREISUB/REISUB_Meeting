import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/app/app.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'package:v_meeting/home/home_screen.dart';
import 'package:v_meeting/settings/settings_view.dart';
import 'package:v_meeting/l10n/localized_error.dart';
import 'package:v_meeting/meeting/meeting_api.dart';

/// Fake server: POST /guest hands out guest-1, guest-2, …; other routes
/// answer with [respond].
Dio fakeServer(
  List<RequestOptions> requests, {
  int guestStatus = 200,
  Response<dynamic> Function(RequestOptions options)? respond,
}) {
  var guests = 0;
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          requests.add(options);
          if (options.path.endsWith('/guest')) {
            if (guestStatus != 200) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response<dynamic>(
                    requestOptions: options,
                    statusCode: guestStatus,
                  ),
                ),
              );
            }
            guests++;
            return handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 201,
                data: {'token': 'guest-$guests'},
              ),
            );
          }
          final response =
              respond?.call(options) ??
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <dynamic>[],
              );
          if ((response.statusCode ?? 200) >= 400) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: response,
              ),
            );
          }
          handler.resolve(response);
        },
      ),
    );
  addTearDown(dio.close);
  return dio;
}

String? bearer(RequestOptions options) =>
    options.headers['Authorization'] as String?;

/// Opens the settings tab and scrolls to the account section.
Future<void> openAccount(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  // The settings list itself; its text fields scroll too.
  final list = find
      .descendant(
        of: find.byType(SettingsView),
        matching: find.byType(Scrollable),
      )
      .first;
  // The list builds rows as they come into view.
  for (var i = 0; i < 20; i++) {
    if (find.byKey(const ValueKey('settings-about')).evaluate().isNotEmpty) {
      break;
    }
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'server_url': 'https://meeting.test:443',
    });
  });

  test('without an account a guest session is created and kept', () async {
    final requests = <RequestOptions>[];
    final api = MeetingApi(dio: fakeServer(requests));
    await api.getRoomMessages('123-456-789');
    await api.getRoomMessages('123-456-789');
    expect(requests.map((r) => r.uri.path), [
      '/guest',
      '/rooms/123-456-789/messages',
      '/rooms/123-456-789/messages',
    ]);
    expect(bearer(requests[1]), 'Bearer guest-1');
    expect(bearer(requests[2]), 'Bearer guest-1');
    expect(await ServerConfig.readGuestToken(), 'guest-1');
  });

  test('requests made together share one guest session', () async {
    final requests = <RequestOptions>[];
    final api = MeetingApi(dio: fakeServer(requests));
    await Future.wait([
      api.getRoomMessages('123-456-789'),
      api.getRoomMessages('123-456-789'),
    ]);
    expect(requests.where((r) => r.uri.path == '/guest'), hasLength(1));
  });

  test('a logged-in user keeps using the account session', () async {
    await ServerConfig.saveToken('account');
    final requests = <RequestOptions>[];
    await MeetingApi(dio: fakeServer(requests)).getRoomMessages('1');
    expect(requests.single.uri.path, '/rooms/1/messages');
    expect(bearer(requests.single), 'Bearer account');
  });

  test('a rejected guest session is renewed once', () async {
    await ServerConfig.saveGuestToken('stale');
    final requests = <RequestOptions>[];
    final api = MeetingApi(
      dio: fakeServer(
        requests,
        respond: (options) => Response<dynamic>(
          requestOptions: options,
          statusCode: bearer(options) == 'Bearer stale' ? 401 : 200,
          data: <dynamic>[],
        ),
      ),
    );
    await api.getRoomMessages('1');
    expect(requests.map((r) => bearer(r)), [
      'Bearer stale',
      null,
      'Bearer guest-1',
    ]);
    expect(await ServerConfig.readGuestToken(), 'guest-1');
  });

  test(
    'an expired account falls back to a guest on the next request',
    () async {
      await ServerConfig.saveToken('expired');
      final requests = <RequestOptions>[];
      final api = MeetingApi(
        dio: fakeServer(
          requests,
          respond: (options) => Response<dynamic>(
            requestOptions: options,
            statusCode: bearer(options) == 'Bearer expired' ? 401 : 200,
            data: <dynamic>[],
          ),
        ),
      );
      await expectLater(
        api.getRoomMessages('1'),
        throwsA(
          isA<MeetingApiException>()
              .having((e) => e.sessionExpired, 'sessionExpired', isTrue)
              .having((e) => e.code, 'code', AppError.accountSessionExpired),
        ),
      );
      expect(await ServerConfig.readToken(), isNull);
      await api.getRoomMessages('1');
      expect(bearer(requests.last), 'Bearer guest-1');
    },
  );

  test('servers without guest sessions ask for a login', () async {
    final requests = <RequestOptions>[];
    await expectLater(
      MeetingApi(dio: fakeServer(requests, guestStatus: 404)).createRoom('Ali'),
      throwsA(
        isA<MeetingApiException>().having(
          (e) => e.loginRequired,
          'loginRequired',
          isTrue,
        ),
      ),
    );
  });

  testWidgets('a configured server opens home without logging in', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: VMeetingApp()));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    await openAccount(tester);
    expect(find.byKey(const ValueKey('settings-login')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-logout')), findsNothing);
  });

  testWidgets('logging out keeps the user home as a guest', (tester) async {
    await ServerConfig.saveToken('account');
    await tester.pumpWidget(const ProviderScope(child: VMeetingApp()));
    await tester.pumpAndSettle();
    await openAccount(tester);
    await tester.tap(find.byKey(const ValueKey('settings-logout')));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(await ServerConfig.readToken(), isNull);
    await openAccount(tester);
    expect(find.byKey(const ValueKey('settings-login')), findsOneWidget);
  });
}
