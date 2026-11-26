import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/app/app.dart';
import 'package:v_meeting/app/app_startup.dart';
import 'package:v_meeting/app/http.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/notifications/app_focus.dart';
import 'package:v_meeting/notifications/notification_text.dart';
import 'package:v_meeting/notifications/system_notifications.dart';
import 'package:v_meeting/social/social_models.dart';

import 'notifications_test.dart' show card, poll;
import 'social_tab_test.dart' show FakeSocialServer, settle;

/// The system's notification centre, as the test sees it.
class FakeSystemNotifier implements SystemNotifier {
  FakeSystemNotifier({this.launchedFrom});

  final ChatTarget? launchedFrom;
  final shown = <SystemNotice>[];
  final cleared = <String>[];
  void Function(ChatTarget target)? _onOpen;

  @override
  Future<ChatTarget?> start({
    required AppLocalizations l10n,
    required void Function(ChatTarget target) onOpen,
  }) async {
    _onOpen = onOpen;
    return launchedFrom;
  }

  @override
  Future<void> show(SystemNotice notice) async => shown.add(notice);

  @override
  Future<void> clear(ChatTarget target) async => cleared.add(target.id);

  /// Calls shown, by id, with what Join / Decline do.
  final calls = <String, void Function(bool join)>{};

  @override
  Future<void> showCall({
    required String id,
    required String title,
    required String body,
    required String join,
    required String decline,
    required void Function(bool join) onAction,
  }) async => calls[id] = onAction;

  @override
  Future<void> hideCall(String id) async => calls.remove(id);

  /// The user taps the notification.
  void tap(SystemNotice notice) =>
      _onOpen!(SystemNotice.targetOf(notice.payload)!);
}

Future<(FakeSocialServer, FakeSystemNotifier, ProviderContainer)> showApp(
  WidgetTester tester, {
  ChatTarget? launchedFrom,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  FlutterSecureStorage.setMockInitialValues({'auth_token': 'account-1'});
  SharedPreferences.setMockInitialValues({
    'server_url': 'https://meeting.test:443',
  });
  final server = FakeSocialServer();
  final system = FakeSystemNotifier(launchedFrom: launchedFrom);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(server.dio()),
        appStartupProvider.overrideWith((ref) async => StartDestination.home),
        systemNotifierProvider.overrideWithValue(system),
      ],
      child: const VMeetingApp(),
    ),
  );
  await settle(tester);
  final container = ProviderScope.containerOf(
    tester.element(find.byType(VMeetingApp)),
  );
  return (server, system, container);
}

void main() {
  testWidgets('away from the app, messages go to the system', (tester) async {
    final (server, system, container) = await showApp(tester);
    await poll(tester);
    container.read(appInFrontProvider.notifier).set(inFront: false);

    server.notify(
      kind: 'friend',
      targetId: 2,
      title: 'Elif',
      sender: 'Elif',
      content: 'Akşam müsait misin?',
    );
    await poll(tester);
    // The system shows it, with the text: it came over the app's own
    // connection, not through Google.
    expect(system.shown, hasLength(1));
    final notice = system.shown.single;
    expect((notice.title, notice.body), ('Elif', 'Akşam müsait misin?'));
    expect(notice.id, 101);
    expect(card(101), findsNothing);

    // The same message again (a late poll, or the push) is not shown twice.
    server.pendingNotifications.add({
      'id': 101,
      'sender_id': 99,
      'sender': 'Elif',
      'content': 'Akşam müsait misin?',
      'created_at': '2026-11-25T18:30:00Z',
      'is_mine': false,
      'kind': 'friend',
      'target_id': 2,
      'title': 'Elif',
    });
    await poll(tester);
    expect(system.shown, hasLength(1));

    // Back at the app, new messages show inside it again.
    container.read(appInFrontProvider.notifier).set(inFront: true);
    server.notify(kind: 'friend', targetId: 3, title: 'Burak', sender: 'Burak');
    await poll(tester);
    expect(system.shown, hasLength(1));
    expect(card(102), findsOneWidget);
  });

  testWidgets('tapping a system notification opens its chat', (tester) async {
    final (server, system, container) = await showApp(tester);
    await poll(tester);
    container.read(appInFrontProvider.notifier).set(inFront: false);
    server.notify(
      kind: 'team',
      targetId: 11,
      title: 'Core',
      sender: 'Burak',
      content: '5 dakikaya oradayım',
    );
    await poll(tester);
    // A team's message says who wrote it.
    expect(system.shown.single.body, 'Burak: 5 dakikaya oradayım');

    container.read(appInFrontProvider.notifier).set(inFront: true);
    system.tap(system.shown.single);
    await settle(tester);
    expect(find.byKey(const ValueKey('chat-team-11')), findsOneWidget);
    // Read now: its notification goes from the system's list.
    expect(system.cleared, contains('team-11'));
  });

  testWidgets('started from a notification, its chat opens', (tester) async {
    await showApp(
      tester,
      launchedFrom: ChatTarget.of(kind: 'team', id: '11', title: 'Core'),
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('chat-team-11')), findsOneWidget);
  });

  group('what a notification says', () {
    final l10n = lookupAppLocalizations(const Locale('tr'));

    test('a push shows who wrote, where and what', () {
      Map<String, dynamic> push(
        String kind,
        String content, {
        bool call = false,
      }) => {
        'type': 'message',
        'kind': kind,
        'target_id': kind == 'team' ? '11' : '2',
        'title': kind == 'team' ? 'Core' : 'Elif',
        'sender': kind == 'team' ? 'Burak' : 'Elif',
        'message_id': '205',
        'invite': call ? '1' : '',
        'content': content,
      };
      final friend = SystemNotice.forPush(
        push('friend', 'Akşam müsait misin?'),
        l10n,
      )!;
      expect(
        (friend.id, friend.title, friend.body),
        (205, 'Elif', 'Akşam müsait misin?'),
      );
      expect(friend.target.id, 'friend-2');

      final team = SystemNotice.forPush(
        push('team', '5 dakikaya oradayım'),
        l10n,
      )!;
      expect((team.title, team.body), ('Core', 'Burak: 5 dakikaya oradayım'));
      expect(team.target.id, 'team-11');

      // A call says so; a push without the text says there is one.
      expect(
        SystemNotice.forPush(push('team', '', call: true), l10n)!.body,
        'Burak seni toplantıya çağırıyor',
      );
      expect(
        SystemNotice.forPush(push('friend', ''), l10n)!.body,
        'Yeni mesaj',
      );
      expect(SystemNotice.forPush({'type': 'other'}, l10n), isNull);
    });

    test('a tap brings back the conversation it was about', () {
      final notice = SystemNotice.forPush({
        'type': 'message',
        'kind': 'team',
        'target_id': '11',
        'title': 'Core | Ekip',
        'sender': 'Burak',
        'message_id': '7',
      }, l10n)!;
      final target = SystemNotice.targetOf(notice.payload)!;
      expect((target.id, target.name), ('team-11', 'Core | Ekip'));
      expect(SystemNotice.targetOf('nonsense'), isNull);
    });
  });
}
