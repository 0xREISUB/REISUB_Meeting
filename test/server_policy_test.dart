import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/app/http.dart';
import 'package:v_meeting/app/invite.dart';
import 'package:v_meeting/auth/auth_api.dart';
import 'package:v_meeting/auth/login_screen.dart';
import 'package:v_meeting/auth/server_policy.dart';
import 'package:v_meeting/home/home_screen.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/l10n/localized_error.dart';
import 'package:v_meeting/meeting/join_screen.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/settings/server_terms_screen.dart';

/// A meeting server. [guests] null means it has no /policy endpoint.
Dio server(List<String> paths, {bool? guests = true}) {
  final dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.uri.path;
          paths.add(path);
          Response<Object?> reply(int status, Object? data) =>
              Response(requestOptions: options, statusCode: status, data: data);
          void fail(int status, Object? data) => handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: reply(status, data),
            ),
          );
          switch (path) {
            case '/policy':
              guests == null
                  ? fail(404, null)
                  : handler.resolve(reply(200, {'guests_allowed': guests}));
            case '/login':
              handler.resolve(reply(200, {'token': 'account-1'}));
            case '/rooms/join':
              // Stop before the meeting screen; reaching here is the point.
              fail(404, {'error': 'room not found'});
            default:
              handler.resolve(
                reply(200, {'message': 'pong', 'status': 'active'}),
              );
          }
        },
      ),
    );
  addTearDown(dio.close);
  return dio;
}

Widget app(Widget home, Dio dio, {InviteLink? invite}) => ProviderScope(
  // A fresh scope each time, so nothing is cached from the last server.
  key: UniqueKey(),
  overrides: [
    dioProvider.overrideWithValue(dio),
    launchInviteProvider.overrideWithValue(invite),
  ],
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

Future<void> logIn(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('login-nick')), 'ali');
  await tester.enterText(find.byKey(const Key('login-password')), 'secret');
  await tester.ensureVisible(find.byKey(const Key('login-submit')));
  await tester.tap(find.byKey(const Key('login-submit')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'server_url': 'https://meeting.test:443',
    });
  });

  test('the policy says whether guests may use meetings', () async {
    final paths = <String>[];
    final api = AuthApi(server(paths, guests: false));
    expect(
      await api.fetchPolicy('https://meeting.test'),
      const ServerPolicy(guestsAllowed: false),
    );
    // A server without the endpoint is an older one that takes guests.
    final legacy = AuthApi(server(paths, guests: null));
    expect(
      await legacy.fetchPolicy('https://meeting.test'),
      ServerPolicy.legacy,
    );
    expect(ServerPolicy.legacy.guestsAllowed, isTrue);
  });

  testWidgets('a server without guests opens login first', (tester) async {
    final paths = <String>[];
    await tester.pumpWidget(
      app(const StartGate(), server(paths, guests: false)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byKey(const Key('login-guests-refused')), findsOneWidget);
    // Nowhere to go back to: another server is offered.
    expect(find.byKey(const Key('login-change-server')), findsOneWidget);
    await logIn(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a server with guests, or a signed-in user, goes home', (
    tester,
  ) async {
    final paths = <String>[];
    await tester.pumpWidget(app(const StartGate(), server(paths)));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    FlutterSecureStorage.setMockInitialValues({'auth_token': 'account-1'});
    await tester.pumpWidget(
      app(const StartGate(), server(paths, guests: false)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('an invite waits through the login, then opens', (tester) async {
    final paths = <String>[];
    await tester.pumpWidget(
      app(
        const StartGate(),
        server(paths, guests: false),
        invite: const InviteLink(roomId: '123-456-789'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    await logIn(tester);
    expect(find.byType(JoinScreen), findsOneWidget);
    expect(find.text('123-456-789'), findsOneWidget);
  });

  testWidgets('joining asks the server again and logs in first if needed', (
    tester,
  ) async {
    final paths = <String>[];
    // Guests were fine when the app started; the server changed its mind.
    await tester.pumpWidget(
      app(
        const JoinScreen(initialRoomId: '123-456-789'),
        server(paths, guests: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Ali');
    final join = find.widgetWithText(ElevatedButton, 'Toplantıya Katıl');
    await tester.ensureVisible(join);
    await tester.tap(join);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-guests-refused')), findsOneWidget);
    expect(paths, isNot(contains('/rooms/join')));
    await logIn(tester);
    // Back on the join screen, the join went on with the account.
    expect(find.byType(JoinScreen), findsOneWidget);
    expect(paths, containsAllInOrder(['/policy', '/login', '/rooms/join']));
  });

  testWidgets('the server terms show whether guests are let in', (
    tester,
  ) async {
    final paths = <String>[];
    await tester.pumpWidget(
      app(const ServerTermsScreen(), server(paths, guests: false)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Misafir girişi'), findsOneWidget);
    expect(
      find.text(
        'İzin verilmiyor: toplantıya katılmak ya da toplantı oluşturmak '
        'için hesap gerekir.',
      ),
      findsOneWidget,
    );
    expect(find.text('https://meeting.test:443'), findsOneWidget);

    await tester.pumpWidget(
      app(const ServerTermsScreen(), server(paths, guests: null)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Bu sunucu koşullarını bildirmiyor. Misafir girişine izin veriliyor.',
      ),
      findsOneWidget,
    );
  });

  test('a request turned away for being a guest asks to log in', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response<Object?>(
                requestOptions: options,
                statusCode: 403,
                data: {'error': 'no guests', 'code': 'guests_not_allowed'},
              ),
            ),
          ),
        ),
      );
    addTearDown(dio.close);
    FlutterSecureStorage.setMockInitialValues({'guest_token': 'guest-1'});
    await expectLater(
      MeetingApi(dio: dio).getRoomMessages('123-456-789'),
      throwsA(
        isA<MeetingApiException>()
            .having((error) => error.loginRequired, 'loginRequired', isTrue)
            .having((error) => error.code, 'code', AppError.loginRequired),
      ),
    );
  });
}
