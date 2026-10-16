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
