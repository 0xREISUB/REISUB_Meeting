import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/auth/server_config.dart';
import 'package:v_meeting/l10n/localized_error.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/meeting/meeting_member.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      'server_url': 'https://meeting.example.test',
      'auth_token': 'app-session-token',
    });
  });

  test('unauthorized responses clear the session and request login', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              response: Response<dynamic>(
                requestOptions: options,
                statusCode: 401,
                data: {'error': 'expired'},
              ),
            ),
          ),
        ),
      );
    final api = MeetingApi(dio: dio);
    await expectLater(
      api.createRoom('Test'),
      throwsA(
        isA<MeetingApiException>().having(
          (error) => error.sessionExpired,
          'sessionExpired',
          isTrue,
        ),
      ),
    );
    expect(await ServerConfig.readToken(), isNull);
    dio.close();
  });

  test(
    'moderation requests use authenticated backend routes and explicit actions',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {},
                ),
              );
            },
          ),
        );
      final api = MeetingApi(dio: dio);
      await api.closeRoom('123-456-789');
      await api.setParticipantMicrophone(
        roomId: '123-456-789',
        identity: 'user-22-session',
        locked: true,
      );
      await api.setParticipantMicrophone(
        roomId: '123-456-789',
        identity: 'user-22-session',
        locked: false,
        requestUnmute: true,
      );
      expect(requests[0].uri.path, '/rooms/123-456-789/close');
      expect(
        requests[1].uri.path,
        '/rooms/123-456-789/participants/user-22-session/microphone',
      );
      expect(requests[1].data, {'locked': true, 'request_unmute': false});
      expect(requests[2].data, {'locked': false, 'request_unmute': true});
      for (final request in requests) {
        expect(request.headers['Authorization'], 'Bearer app-session-token');
        expect(request.method, 'POST');
      }
      dio.close();
    },
  );

  test(
    'screen sharing and settings use authenticated server-controlled routes',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'allow_participant_screen_share': false,
                    'screen_share_identity': '',
                  },
                ),
              );
            },
          ),
        );
      final api = MeetingApi(dio: dio);
      expect(
        (await api.getMeetingState('123-456-789')).allowParticipantScreenShare,
        isFalse,
      );
      await api.updateMeetingSettings('123-456-789', allowScreenShare: true);
      await api.startScreenShare('123-456-789', 'my-identity');
      await api.stopScreenShare('123-456-789', 'my-identity');
      expect(requests.map((r) => r.uri.path), [
        '/rooms/123-456-789/state',
        '/rooms/123-456-789/settings',
        '/rooms/123-456-789/screen-share/start',
        '/rooms/123-456-789/screen-share/stop',
      ]);
      expect(requests.first.method, 'GET');
      expect(requests[1].data, {'allow_participant_screen_share': true});
      for (final request in requests) {
        expect(request.headers['Authorization'], 'Bearer app-session-token');
      }
      expect(requests[2].data, {'identity': 'my-identity'});
      expect(requests[3].data, {'identity': 'my-identity'});
      dio.close();
    },
  );

  test(
    'server authorization failures are presented without claiming success',
    () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response<dynamic>(
                    requestOptions: options,
                    statusCode: 403,
                    data: {'error': 'Bu işlem yalnızca oda yöneticisine açık'},
                  ),
                ),
              );
            },
          ),
        );
      await expectLater(
        MeetingApi(dio: dio).closeRoom('123-456-789'),
        throwsA(
          isA<MeetingApiException>().having(
            (e) => e.message,
            'message',
            contains('oda yöneticisine'),
          ),
        ),
      );
      dio.close();
    },
  );

  test('room ids are encoded in chat routes', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response<dynamic>(requestOptions: options, statusCode: 200),
            );
          },
        ),
      );
    expect(await MeetingApi(dio: dio).getRoomMessages('a/b?c'), isEmpty);
    expect(requests.single.uri.path, '/rooms/a%2Fb%3Fc/messages');
    dio.close();
  });

  test(
    'an empty or malformed state response is an error, not a crash',
    () async {
      for (final body in [
        null,
        'unexpected',
        {'allow_participant_screen_share': 'yes'},
      ]) {
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) => handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: body,
                ),
              ),
            ),
          );
        await expectLater(
          MeetingApi(dio: dio).getMeetingState('123-456-789'),
          throwsA(
            isA<MeetingApiException>().having(
              (error) => error.code,
              'code',
              AppError.invalidServerResponse,
            ),
          ),
        );
        dio.close();
      }
    },
  );

  test('role, transfer and leave use the role routes', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response<dynamic>(requestOptions: options, statusCode: 200),
            );
          },
        ),
      );
    final api = MeetingApi(dio: dio);
    await api.setParticipantRole(
      roomId: '123-456-789',
      identity: 'user-7-a',
      role: MeetingRole.moderator,
    );
    await api.transferOwnership('123-456-789', 'user-7-a');
    await api.leaveRoom('123-456-789');
    expect(requests.map((r) => r.uri.path), [
      '/rooms/123-456-789/participants/user-7-a/role',
      '/rooms/123-456-789/transfer-ownership',
      '/rooms/123-456-789/leave',
    ]);
    expect(requests[0].data, {'role': 'moderator'});
    expect(requests[1].data, {'identity': 'user-7-a'});
    for (final request in requests) {
      expect(request.method, 'POST');
      expect(request.headers['Authorization'], 'Bearer app-session-token');
    }
    dio.close();
  });

  test('known server error codes are shown in the app language', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response<dynamic>(
                requestOptions: options,
                statusCode: 409,
                data: {'error': 'Son owner', 'code': 'last_owner'},
              ),
            ),
          ),
        ),
      );
    await expectLater(
      MeetingApi(dio: dio).setParticipantRole(
        roomId: '123-456-789',
        identity: 'user-1-a',
        role: MeetingRole.participant,
      ),
      throwsA(
        isA<MeetingApiException>().having(
          (error) => error.code,
          'code',
          AppError.lastOwner,
        ),
      ),
    );
    dio.close();
  });

  test('join responses carry the role, falling back to is_host', () {
    RoomCredentials parse(Map<String, dynamic> extra) =>
        RoomCredentials.fromJson({
          'room_id': '123-456-789',
          'livekit_url': 'wss://example.test',
          'token': 't',
          'participant': 'Ali',
          ...extra,
        });
    expect(
      parse({'is_host': true, 'role': 'moderator'}).initialRole,
      MeetingRole.moderator,
    );
    expect(parse({'is_host': true}).initialRole, MeetingRole.owner);
    expect(parse({}).initialRole, MeetingRole.participant);
  });
}
