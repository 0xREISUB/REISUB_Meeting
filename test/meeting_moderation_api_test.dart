import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/meeting/meeting_api.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'server_url': 'https://meeting.example.test',
      'auth_token': 'app-session-token',
    });
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
}
