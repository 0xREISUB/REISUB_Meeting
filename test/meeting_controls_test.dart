import 'package:v_meeting/home/home_screen.dart';
import 'package:v_meeting/meeting/widgets/meeting_controls_bar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/meeting/meeting_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/meeting_fakes.dart';

void main() {
  testWidgets('a tap on the video toggles the controls, not one on them', (
    tester,
  ) async {
    await openExitTest(tester, TestRoom());
    final bar = find.byType(MeetingControlsBar);
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    bool shown() => tester.getRect(bar).top < screenHeight;
    expect(shown(), isTrue);

    await tester.tapAt(const Offset(200, 150));
    await tester.pumpAndSettle();
    expect(shown(), isFalse);

    await tester.tapAt(const Offset(200, 150));
    await tester.pumpAndSettle();
    expect(shown(), isTrue);

    // The bar's own background, between its buttons' edges.
    await tester.tapAt(tester.getRect(bar).topLeft + const Offset(12, 30));
    await tester.pumpAndSettle();
    expect(shown(), isTrue);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a participant leaves at once and tells the server', (
    tester,
  ) async {
    final room = TestRoom(local: TestLocal());
    final api = ModerationApi();
    await openExitTest(tester, room, api: api);
    await tester.tap(find.byIcon(Icons.call_end_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(api.leaves, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  group('background', () {
    testWidgets('a meeting keeps the screen awake and runs in the background', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final room = TestRoom();
      final platform = TestPlatform(connectCalls: () => room.connectCalls);
      await openExitTest(tester, room, platform: platform);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      // Permissions come first, before connecting and before the service,
      // so no prompt opens while the meeting connects.
      expect(platform.calls, [
        'keepScreenOn:true',
        'permissions:camera=true,connects=0',
        'startService:Toplantı sürüyor',
      ]);
      expect(room.connectCalls, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(
        platform.calls,
        containsAll(['keepScreenOn:false', 'stopService']),
      );
    });

    testWidgets('Android back keeps the meeting and leaves the app running', (
      tester,
    ) async {
      final platform = TestPlatform();
      final api = ModerationApi();
      await openExitTest(tester, TestRoom(), platform: platform, api: api);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(platform.calls.last, 'moveToBackground');
      expect(find.byType(MeetingScreen), findsOneWidget);
      expect(api.leaves, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('desktop back leaves the meeting properly', (tester) async {
      final api = ModerationApi();
      await openExitTest(tester, TestRoom(), api: api);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(api.leaves, 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('the camera pauses in the background and comes back', (
      tester,
    ) async {
      final local = TestLocal();
      final room = TestRoom(local: local);
      await openExitTest(tester, room);
      room.events.streamCtrl.add(
        RoomConnectedEvent(room: room, metadata: null),
      );
      await tester.pumpAndSettle();
      local.cameraChanges.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(local.cameraChanges, [false]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(local.cameraChanges, [false, true]);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  });

  testWidgets('locked microphone stops capture and cannot be opened locally', (
    tester,
  ) async {
    final participant = TestLocal()..microphone = true;
    participant.values['meeting.microphone_locked'] = 'true';
    final room = TestRoom(local: participant);
    await tester.pumpWidget(meetingApp(room));
    await tester.pumpAndSettle();
    room.changed();
    await tester.pumpAndSettle();
    expect(participant.microphoneChanges, [false]);
    await tester.tap(find.byIcon(Icons.lock_rounded));
    await tester.pumpAndSettle();
    expect(participant.microphoneChanges, [false]);
    expect(
      find.text('Mikrofonunuz yönetici tarafından kilitlendi.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'microphone requests require consent and a new lock overrides consent',
    (tester) async {
      final participant = TestLocal();
      final room = TestRoom(local: participant);
      await tester.pumpWidget(meetingApp(room));
      await tester.pumpAndSettle();
      participant.values['meeting.microphone_request'] = 'request-1';
      room.changed();
      await tester.pumpAndSettle();
      expect(find.text('Mikrofon açma isteği'), findsOneWidget);
      expect(participant.microphoneChanges, isEmpty);
      await tester.tap(find.text('Şimdi değil'));
      await tester.pumpAndSettle();
      expect(participant.microphoneChanges, isEmpty);
      participant.values['meeting.microphone_request'] = 'request-2';
      room.changed();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mikrofonu aç'));
      await tester.pumpAndSettle();
      expect(participant.microphoneChanges, [true]);
      participant.microphone = false;
      participant.values['meeting.microphone_request'] = 'request-3';
      room.changed();
      await tester.pumpAndSettle();
      participant.values['meeting.microphone_locked'] = 'true';
      room.changed();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mikrofonu aç'));
      await tester.pumpAndSettle();
      expect(participant.microphoneChanges, [true]);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
