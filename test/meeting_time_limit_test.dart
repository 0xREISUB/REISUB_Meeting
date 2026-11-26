import 'package:v_meeting/home/home_screen.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/meeting_fakes.dart';

void main() {
  group('time limit', () {
    final countdown = find.byKey(const ValueKey('meeting-countdown'));

    Future<void> poll(WidgetTester tester) async {
      // The room's state is fetched every two seconds.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
    }

    testWidgets('everyone is warned at ten minutes and at one', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = WaitingApi()..state = const MeetingState(secondsLeft: 900);
      await openExitTest(tester, TestRoom(), api: api);
      await poll(tester);
      // Fifteen minutes left: nothing yet.
      expect(countdown, findsNothing);
      expect(find.byKey(const ValueKey('meeting-time-notice')), findsNothing);

      api.state = const MeetingState(secondsLeft: 600);
      await poll(tester);
      expect(countdown, findsOneWidget);
      expect(
        find.text('Toplantının bitmesine 10 dakika kaldı.'),
        findsOneWidget,
      );
      expect(
        find.descendant(of: countdown, matching: find.textContaining('9:5')),
        findsOneWidget,
      );
      // The notice goes after a while; the countdown stays.
      await tester.pump(const Duration(seconds: 9));
      expect(find.text('Toplantının bitmesine 10 dakika kaldı.'), findsNothing);
      expect(countdown, findsOneWidget);

      api.state = const MeetingState(secondsLeft: 59);
      await poll(tester);
      expect(
        find.text('Toplantının bitmesine 1 dakika kaldı.'),
        findsOneWidget,
      );

      // The limit lifted: the countdown goes.
      api.state = const MeetingState();
      await poll(tester);
      expect(countdown, findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('joining late warns once with the minutes left', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final api = WaitingApi()..state = const MeetingState(secondsLeft: 250);
      await openExitTest(tester, TestRoom(), api: api);
      await poll(tester);
      expect(
        find.text('Toplantının bitmesine 5 dakika kaldı.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('a meeting closed at its limit says so', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final room = TestRoom();
      final api = WaitingApi()..state = const MeetingState(secondsLeft: 2);
      await openExitTest(tester, room, api: api);
      await poll(tester);
      room.events.streamCtrl.add(
        RoomDisconnectedEvent(reason: DisconnectReason.roomDeleted),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        find.text('Toplantı süre sınırına ulaştı ve sona erdi.'),
        findsOneWidget,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });
}
