import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/meeting/meeting_member.dart';
import 'package:v_meeting/meeting/widgets/meeting_participant.dart';

import 'support/meeting_fakes.dart';

void main() {
  testWidgets('mobile main video fills page and galleries use swipes only', (
    tester,
  ) async {
    await showMeeting(tester, const Size(360, 720));
    final pager = find.byKey(const ValueKey('meeting-pages'));
    expect(find.byType(IconButton), findsNothing);
    // The main video and the small floating one, showing you.
    expect(find.byType(MeetingParticipantTile), findsNWidgets(2));
    expect(find.byKey(const ValueKey('pip-local')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('main-remote-0'))),
      const Size(360, 720),
    );
    await tester.drag(pager, const Offset(-320, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-remote-0')), findsNothing);
    expect(find.byType(MeetingParticipantTile), findsNWidgets(4));
    expect(find.byKey(const ValueKey('local')), findsOneWidget);
    for (var i = 0; i < 7; i++) {
      await tester.drag(pager, const Offset(-320, 0));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('remote-29')), findsOneWidget);
    for (var i = 0; i < 8; i++) {
      await tester.drag(pager, const Offset(320, 0));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('main-remote-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the phone video floats, resizes, goes away and comes back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    var taps = 0;
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: MeetingVideoLayout(
            members: const [local, remote, third],
            mainMember: remote,
            onMainPageTap: () => taps++,
          ),
        ),
      ),
    );
    final pip = find.byKey(const ValueKey('meeting-pip'));
    // One person, in the top-right corner, over the whole page.
    expect(
      find.descendant(of: pip, matching: find.byType(MeetingParticipantTile)),
      findsOneWidget,
    );
    final start = tester.getRect(pip);
    expect(start.center.dx, greaterThan(180));
    expect(start.center.dy, lessThan(360));
    await tester.tap(pip);
    expect(taps, 0);

    // Resizing keeps 16:9.
    await tester.drag(
      find.byKey(const ValueKey('meeting-island-resize')),
      const Offset(-60, 0),
    );
    await tester.pumpAndSettle();
    final bigger = tester.getSize(pip);
    expect(bigger.width, greaterThan(start.width + 40));
    expect(bigger.width / bigger.height, closeTo(16 / 9, 0.01));

    // Dragged to the top centre it fades, vibrates and goes away.
    final drag = await tester.startGesture(tester.getCenter(pip));
    // The first move starts the drag, the next one moves the video.
    await drag.moveBy(const Offset(-20, 0));
    await drag.moveBy(const Offset(-10, 0));
    await tester.pump();
    final target = find.byKey(const ValueKey('meeting-pip-dismiss-target'));
    expect(target, findsOneWidget);
    await drag.moveTo(Offset(180, tester.getSize(pip).height / 2 + 12));
    await tester.pump();
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
    await drag.up();
    await tester.pumpAndSettle();
    expect(pip, findsNothing);
    expect(target, findsNothing);

    // Pulling the tab high on the right edge brings it back, same size.
    final tab = find.byKey(const ValueKey('meeting-pip-restore'));
    expect(tester.getRect(tab).right, 360);
    expect(tester.getCenter(tab).dy, lessThan(720 * 0.3));
    await tester.drag(tab, const Offset(-60, 0));
    await tester.pumpAndSettle();
    expect(pip, findsOneWidget);
    expect(tester.getSize(pip), bigger);
    expect(find.byKey(const ValueKey('main-remote')), findsOneWidget);
    expect(taps, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery returns safely when participants leave', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entries = ValueNotifier(members);
    addTearDown(entries.dispose);
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: ValueListenableBuilder<List<MemberEntry>>(
            valueListenable: entries,
            builder: (context, value, _) =>
                MeetingVideoLayout(members: value, mainMember: value.first),
          ),
        ),
      ),
    );
    final pager = find.byKey(const ValueKey('meeting-pages'));
    for (var i = 0; i < 3; i++) {
      await tester.drag(pager, const Offset(-320, 0));
      await tester.pumpAndSettle();
    }
    entries.value = [local];
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-local')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape phone stays swipeable and taps reveal controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(920, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: MeetingVideoLayout(
            members: const [local, remote, third, fourth],
            mainMember: remote,
            onMainPageTap: () => taps++,
          ),
        ),
      ),
    );
    expect(find.byType(IconButton), findsNothing);
    expect(find.byKey(const ValueKey('meeting-sidebar')), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('main-remote'))),
      const Size(920, 400),
    );
    await tester.tapAt(const Offset(5, 200));
    expect(taps, 1);
    final pager = find.byKey(const ValueKey('meeting-pages'));
    await tester.drag(pager, const Offset(-850, 0));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.byType(MeetingParticipantTile), findsNWidgets(4));
    // The participant gallery reveals the controls too.
    await tester.tapAt(const Offset(100, 100));
    expect(taps, 2);
    await tester.drag(pager, const Offset(850, 0));
    await tester.pumpAndSettle();
    expect(taps, 2);
    await tester.tapAt(const Offset(915, 200));
    expect(taps, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('taps reach the controls even where the video claims them', (
    tester,
  ) async {
    var taps = 0;
    var innerTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MeetingTapListener(
          onTap: () => taps++,
          // Like the phone's local camera renderer, which takes taps for
          // focus and pinches for zoom.
          child: GestureDetector(
            onTap: () => innerTaps++,
            onScaleUpdate: (_) {},
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(200, 300));
    expect(innerTaps, 1);
    expect(taps, 1);

    // A pinch is not a tap.
    final first = await tester.startGesture(const Offset(150, 300));
    final second = await tester.startGesture(const Offset(250, 300));
    await first.up();
    await second.up();
    expect(taps, 1);

    // Neither is a drag.
    await tester.dragFrom(const Offset(200, 300), const Offset(-120, 0));
    expect(taps, 1);
  });

  testWidgets(
    'phone enters fullscreen, controls overlay video, exit restores UI',
    (tester) async {
      tester.view.physicalSize = const Size(920, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <MethodCall>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
      const display = MethodChannel('reisub_meeting/display');
      messenger.setMockMethodCallHandler(display, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        messenger.setMockMethodCallHandler(display, null);
      });
      await tester.pumpWidget(meetingApp(TestRoom()));
      await tester.pumpAndSettle();
      expect(
        calls.any(
          (call) => call.method == 'setFullscreen' && call.arguments == true,
        ),
        isTrue,
      );
      expect(
        calls
            .where(
              (call) => call.method == 'SystemChrome.setPreferredOrientations',
            )
            .last
            .arguments,
        ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight'],
      );
      final video = find.byKey(const ValueKey('main-local'));
      final before = tester.getRect(video);
      expect(before.size, const Size(920, 400));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.mic_rounded).hitTestable(), findsNothing);
      expect(tester.getRect(video), before);
      await tester.tapAt(const Offset(5, 200));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.mic_rounded).hitTestable(), findsOneWidget);
      expect(tester.getRect(video), before);
      // A second tap on the video hides the controls again.
      await tester.tapAt(const Offset(915, 200));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.mic_rounded).hitTestable(), findsNothing);
      expect(tester.getRect(video), before);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'setFullscreen').last.arguments,
        false,
      );
      expect(
        calls
            .where(
              (call) => call.method == 'SystemChrome.setPreferredOrientations',
            )
            .last
            .arguments,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
