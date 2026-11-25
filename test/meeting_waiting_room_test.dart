import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/meeting/widgets/meeting_controls_bar.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/meeting/meeting_platform.dart';
import 'package:v_meeting/meeting/meeting_screen.dart';
import 'package:v_meeting/meeting/waiting_room_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/meeting_fakes.dart';

void main() {
  group('waiting room', () {
    const ece = WaitingPerson(requestId: 'r1', name: 'Ece');
    const can = WaitingPerson(requestId: 'r2', name: 'Can');
    final waitingButton = find.byKey(const ValueKey('waiting-room-button'));

    Future<void> poll(WidgetTester tester) async {
      // The room's state is fetched every two seconds.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    }

    /// Brings the dock back if it hid itself.
    Future<void> showControls(WidgetTester tester) async {
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final bar = find.byType(MeetingControlsBar);
      if (tester.getRect(bar).top >= screenHeight) {
        await tester.tapAt(const Offset(200, 150));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('newcomers are counted, announced and let in or turned away', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final api = WaitingApi()
        ..state = const MeetingState(waitingRoom: true, waiting: [ece]);
      await openExitTest(tester, TestRoom(), host: true, api: api);
      await poll(tester);
      expect(waitingButton, findsOneWidget);
      expect(
        find.descendant(of: waitingButton, matching: find.text('1')),
        findsOneWidget,
      );
      expect(find.text('Ece katılmak istiyor'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('arrival-r1-admit')));
      await tester.pumpAndSettle();
      expect(api.answers, [('r1', true)]);
      expect(find.text('Ece katılmak istiyor'), findsNothing);

      // Someone new arrives: one notice, and the list can turn them away.
      api.state = const MeetingState(waitingRoom: true, waiting: [can]);
      await poll(tester);
      expect(find.text('Can katılmak istiyor'), findsOneWidget);
      await showControls(tester);
      await tester.tap(waitingButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('r2-reject')));
      await tester.pumpAndSettle();
      expect(api.answers.last, ('r2', false));
      // Answered from the list, the notice goes too.
      expect(find.text('Can katılmak istiyor'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('notices can be switched off', (tester) async {
      SharedPreferences.setMockInitialValues({
        'meeting.notify_arrivals': false,
      });
      final api = WaitingApi()
        ..state = const MeetingState(waitingRoom: true, waiting: [ece]);
      await openExitTest(tester, TestRoom(), host: true, api: api);
      await poll(tester);
      expect(waitingButton, findsOneWidget);
      expect(find.text('Ece katılmak istiyor'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('people who may not let others in see none of it', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final api = WaitingApi()
        ..state = const MeetingState(waitingRoom: true, waiting: [ece]);
      await openExitTest(tester, TestRoom(), api: api);
      await poll(tester);
      expect(waitingButton, findsNothing);
      expect(find.text('Ece katılmak istiyor'), findsNothing);
      await showControls(tester);
      await tester.tap(find.byTooltip('Daha fazla'));
      await tester.pumpAndSettle();
      expect(find.text('Toplantı ayarları'), findsNothing);
      expect(find.text('Ses ve görüntü'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('the meeting settings turn the waiting room on and off', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final api = WaitingApi()..state = const MeetingState();
      await openExitTest(tester, TestRoom(), host: true, api: api);
      await poll(tester);
      expect(waitingButton, findsNothing);
      await showControls(tester);
      await tester.tap(find.byTooltip('Daha fazla'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toplantı ayarları'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('setting-waiting-room')));
      await tester.pumpAndSettle();
      expect(api.waitingRoomChanges, [true]);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('setting-waiting-room')),
            )
            .value,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('setting-notify-arrivals')));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('meeting.notify_arrivals'), isFalse);
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      expect(waitingButton, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    Future<WaitingApi> openWaiting(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = WaitingApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meetingRoomFactoryProvider.overrideWithValue(TestRoom.new),
            meetingApiProvider.overrideWithValue(api),
            meetingPlatformProvider.overrideWithValue(TestPlatform()),
          ],
          child: localized(
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const WaitingRoomScreen(
                        roomId: '123-456-789',
                        requestId: 'r9',
                        pollInterval: Duration(milliseconds: 100),
                      ),
                    ),
                  ),
                  child: const Text('join'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('join'));
      // The spinner never settles, so time is pumped instead: one frame to
      // start the route, then its transition.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('Yetkililerin sizi içeri alması bekleniyor'),
        findsOneWidget,
      );
      return api;
    }

    testWidgets('a turned-away guest goes back and is told', (tester) async {
      final api = await openWaiting(tester);
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        find.text('Yetkililerin sizi içeri alması bekleniyor'),
        findsOneWidget,
      );
      api.statuses.add(const WaitingUpdate(WaitingStatus.rejected));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.text('join'), findsOneWidget);
      expect(find.text('Toplantıya alınmadınız.'), findsOneWidget);
    });

    testWidgets('a guest can stop waiting', (tester) async {
      final api = await openWaiting(tester);
      await tester.tap(find.byKey(const ValueKey('waiting-room-cancel')));
      await tester.pumpAndSettle();
      expect(find.text('join'), findsOneWidget);
      expect(api.cancels, ['r9']);
    });

    testWidgets('a guest who is let in joins the meeting', (tester) async {
      final api = await openWaiting(tester);
      api.statuses.add(
        const WaitingUpdate(
          WaitingStatus.admitted,
          RoomCredentials(
            roomId: '123-456-789',
            liveKitUrl: 'wss://example.test',
            token: 'test',
            participant: 'Konuk',
            isHost: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.byType(MeetingScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });
}
