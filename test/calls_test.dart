import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reisub_calls/reisub_calls.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/app/app.dart';
import 'package:v_meeting/app/app_startup.dart';
import 'package:v_meeting/app/http.dart';
import 'package:v_meeting/calls/call_ringer.dart';
import 'package:v_meeting/calls/ringing_call.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/notifications/app_focus.dart';
import 'package:v_meeting/notifications/system_notifications.dart';
import 'package:v_meeting/social/realtime.dart';

import 'realtime_test.dart' show FakeSocket;
import 'social_tab_test.dart' show FakeSocialServer, settle;
import 'system_notifications_test.dart' show FakeSystemNotifier;

/// Rings as the test sees it: a computer's (the app shows the call) or a
/// phone's (the system's call screen).
class FakeRinger implements CallRinger {
  FakeRinger({this.ownScreen = false, this.pending});

  @override
  final bool ownScreen;
  CallAction? pending;
  final rung = <String>[];
  final stopped = <(String, bool)>[];
  final _actions = StreamController<CallAction>.broadcast();

  @override
  Future<void> ring(
    RingingCall call,
    AppLocalizations l10n,
    String server,
  ) async => rung.add(call.id);

  @override
  Future<void> stop(
    RingingCall call,
    AppLocalizations l10n, {
    bool missed = false,
  }) async => stopped.add((call.id, missed));

  @override
  Stream<CallAction> get actions => _actions.stream;

  @override
  Future<CallAction?> takePending() async {
    final action = pending;
    pending = null;
    return action;
  }

  void act(CallAction action) => _actions.add(action);
}

class Phone {
  final server = FakeSocialServer();
  final system = FakeSystemNotifier();
  late final FakeRinger ringer;
  late final ProviderContainer container;
  FakeSocket? socket;
}

Future<Phone> showApp(WidgetTester tester, {FakeRinger? ringer}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  FlutterSecureStorage.setMockInitialValues({'auth_token': 'account-1'});
  SharedPreferences.setMockInitialValues({
    'server_url': 'https://meeting.test:443',
  });
  final phone = Phone()..ringer = ringer ?? FakeRinger();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(phone.server.dio()),
        appStartupProvider.overrideWith((ref) async => StartDestination.home),
        systemNotifierProvider.overrideWithValue(phone.system),
        callRingerProvider.overrideWithValue(phone.ringer),
        realtimeConnectorProvider.overrideWithValue((uri) async {
          return phone.socket = FakeSocket();
        }),
      ],
      child: const VMeetingApp(),
    ),
  );
  await settle(tester);
  phone.container = ProviderScope.containerOf(
    tester.element(find.byType(VMeetingApp)),
  );
  phone.socket!.push({'type': 'ready'});
  await settle(tester);
  return phone;
}

Map<String, Object?> callEvent({String id = '7', String kind = 'friend'}) => {
  'type': 'call',
  'call': {
    'id': int.parse(id),
    'room_id': '123-456-789',
    'caller': 'Elif',
    'title': kind == 'team' ? 'Core' : 'Elif',
    'kind': kind,
    'target_id': kind == 'team' ? 11 : 2,
    'ends_at': DateTime.now()
        .add(const Duration(seconds: 45))
        .toUtc()
        .toIso8601String(),
    'secret': 's3cret',
  },
};

Finder card(String id) => find.byKey(ValueKey('call-$id'));

void main() {
  testWidgets('a call on a computer rings and joins its meeting', (
    tester,
  ) async {
    final phone = await showApp(tester);
    phone.socket!.push(callEvent());
    await settle(tester);
    expect(phone.ringer.rung, ['7']);
    expect(card('7'), findsOneWidget);
    expect(find.text('is calling you'), findsOneWidget);

    // The same call again, as a push: it rings once.
    phone.socket!.push(callEvent());
    await settle(tester);
    expect(phone.ringer.rung, ['7']);

    await tester.tap(find.byKey(const ValueKey('call-join-7')));
    await settle(tester);
    expect(card('7'), findsNothing);
    expect(phone.ringer.stopped, [('7', false)]);
    expect(phone.server.calls, contains('POST /calls/7/answer'));
    expect(
      phone.server.bodies['POST /rooms/join'],
      containsPair('room_id', '123-456-789'),
    );
  });

  testWidgets('declining tells the server and stops the ring', (tester) async {
    final phone = await showApp(tester);
    phone.socket!.push(callEvent(kind: 'team'));
    await settle(tester);
    // A team's meeting says who started it.
    expect(find.text('Elif started the meeting'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('call-decline-7')));
    await settle(tester);
    expect(card('7'), findsNothing);
    expect(phone.server.calls, contains('POST /calls/7/decline'));
    expect(phone.server.calls, isNot(contains('POST /rooms/join')));
  });

  testWidgets('a call nobody took leaves a missed call', (tester) async {
    final phone = await showApp(tester);
    phone.socket!.push(callEvent());
    await settle(tester);
    phone.socket!.push({
      'type': 'call_end',
      'call': {
        'id': 7,
        'missed': true,
        'caller': 'Elif',
        'title': 'Elif',
        'kind': 'friend',
        'target_id': 2,
      },
    });
    await settle(tester);
    expect(card('7'), findsNothing);
    expect(phone.ringer.stopped, [('7', true)]);
    expect(phone.system.shown.single.title, 'Missed call');
    expect(phone.system.shown.single.body, 'Elif');
  });

  testWidgets('away from the app, the system shows the call', (tester) async {
    final phone = await showApp(tester);
    phone.container.read(appInFrontProvider.notifier).set(inFront: false);
    phone.socket!.push(callEvent());
    await settle(tester);
    expect(phone.system.calls.keys, ['7']);
    // Join from the notification.
    phone.system.calls['7']!(true);
    await settle(tester);
    expect(phone.server.calls, contains('POST /calls/7/answer'));
    expect(phone.system.calls, isEmpty);
  });

  testWidgets('on a phone the call screen is the system\'s, and an answer '
      'there opens the meeting', (tester) async {
    final ringer = FakeRinger(
      ownScreen: true,
      // Answered on the lock screen before the app ran.
      pending: const CallAction(
        answered: true,
        id: '5',
        roomId: '123-456-789',
        kind: 'friend',
        targetId: '2',
        title: 'Elif',
      ),
    );
    final phone = await showApp(tester, ringer: ringer);
    expect(phone.server.calls, contains('POST /calls/5/answer'));
    expect(phone.server.calls, contains('POST /rooms/join'));

    // A call while it runs rings there, with no card in the app.
    phone.socket!.push(callEvent());
    await settle(tester);
    expect(ringer.rung, ['7']);
    expect(card('7'), findsNothing);
    // Declined on the phone's screen: the phone told the server itself.
    ringer.act(
      const CallAction(
        answered: false,
        id: '7',
        roomId: '123-456-789',
        kind: 'friend',
        targetId: '2',
        title: 'Elif',
      ),
    );
    await settle(tester);
    expect(phone.server.calls, isNot(contains('POST /calls/7/decline')));
  });

  testWidgets('the caller hears a call was turned down', (tester) async {
    final phone = await showApp(tester);
    phone.socket!.push({
      'type': 'call_declined',
      'call': {'id': 7, 'by': 'Elif'},
    });
    await settle(tester);
    expect(find.text('Elif declined the call'), findsOneWidget);
  });

  test('a push describes the call it rings', () {
    final call = RingingCall.fromPush({
      'type': 'call',
      'call_id': '9',
      'room_id': '123-456-789',
      'caller': 'Burak',
      'title': 'Core',
      'kind': 'team',
      'target_id': '11',
      'ends_at': '2026-11-26T12:00:45Z',
      'secret': 'x',
    })!;
    expect(
      (call.id, call.team, call.target.id, call.missedText()),
      ('9', true, 'team-11', 'Core · Burak'),
    );
    expect(RingingCall.fromPush({'type': 'call'}), isNull);
  });
}
