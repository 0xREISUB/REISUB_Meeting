import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/app/app.dart';
import 'package:v_meeting/app/app_startup.dart';
import 'package:v_meeting/app/http.dart';
import 'package:v_meeting/notifications/push.dart';

import 'social_tab_test.dart' show FakeSocialServer, settle;

class FakePush implements PushService {
  String? current = 'fcm-1';
  bool asked = false;
  final changes = StreamController<String>.broadcast();

  @override
  Future<String?> token() async => current;

  @override
  Stream<String> get tokenChanges => changes.stream;

  @override
  Future<void> requestPermission() async => asked = true;
}

void main() {
  testWidgets('a signed-in phone tells the server where to push', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'account-1'});
    SharedPreferences.setMockInitialValues({
      'server_url': 'https://meeting.test:443',
    });
    final server = FakeSocialServer();
    final push = FakePush();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(server.dio()),
          appStartupProvider.overrideWith((ref) async => StartDestination.home),
          pushServiceProvider.overrideWithValue(push),
        ],
        child: const VMeetingApp(),
      ),
    );
    await settle(tester);
    expect(push.asked, isTrue);
    expect(server.calls, contains('PUT /me/push-device'));
    expect(server.bodies['PUT /me/push-device'], {
      'token': 'fcm-1',
      'platform': 'android',
    });

    // Firebase gave the phone a new token: the server hears it.
    push.changes.add('fcm-2');
    await settle(tester);
    expect(server.bodies['PUT /me/push-device'], {
      'token': 'fcm-2',
      'platform': 'android',
    });
    await push.changes.close();
  });
}
