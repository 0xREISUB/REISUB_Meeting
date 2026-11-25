import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/meeting/meeting_member.dart';
import 'package:v_meeting/meeting/widgets/meeting_participant.dart';
import 'support/meeting_fakes.dart';

void main() {
  testWidgets('shared screen zooms with the mouse wheel and resets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: MeetingVideoLayout(
            members: const [local, shared],
            mainMember: selectMainMember([local, shared]),
          ),
        ),
      ),
    );
    final zoom = find.byKey(const ValueKey('main-video-zoom'));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(zoom),
        scrollDelta: const Offset(0, -200),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InteractiveViewer>(zoom)
          .transformationController!
          .value
          .getMaxScaleOnAxis(),
      greaterThan(1),
    );
    await tester.tap(find.byKey(const ValueKey('reset-video-zoom')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InteractiveViewer>(zoom)
          .transformationController!
          .value
          .getMaxScaleOnAxis(),
      closeTo(1, .001),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'phone screen pinch zooms; one-finger swipes still change pages at 1x',
    (tester) async {
      tester.view.physicalSize = const Size(920, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: MeetingVideoLayout(
              members: const [local, shared],
              mainMember: selectMainMember([local, shared]),
            ),
          ),
        ),
      );
      final zoom = find.byKey(const ValueKey('main-video-zoom'));
      final center = tester.getCenter(zoom);
      final first = await tester.startGesture(
        center - const Offset(40, 0),
        pointer: 1,
      );
      final second = await tester.startGesture(
        center + const Offset(40, 0),
        pointer: 2,
      );
      await tester.pump();
      await first.moveTo(center - const Offset(120, 0));
      await second.moveTo(center + const Offset(120, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<InteractiveViewer>(zoom)
            .transformationController!
            .value
            .getMaxScaleOnAxis(),
        greaterThan(1),
      );
      await tester.tap(find.byKey(const ValueKey('reset-video-zoom')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('meeting-pages')),
        const Offset(-850, 0),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('gallery-page-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('phone pinch works when one finger lands and moves first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(920, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: MeetingVideoLayout(
            members: const [local, shared],
            mainMember: selectMainMember([local, shared]),
          ),
        ),
      ),
    );
    final zoom = find.byKey(const ValueKey('main-video-zoom'));
    final center = tester.getCenter(zoom);
    // Real fingers rarely land together: the first one has already slid
    // sideways a little when the second touches the screen.
    final first = await tester.startGesture(
      center - const Offset(40, 0),
      pointer: 1,
    );
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 4; i++) {
      await first.moveBy(const Offset(-6, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final second = await tester.startGesture(
      center + const Offset(40, 0),
      pointer: 2,
    );
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 10; i++) {
      await first.moveBy(const Offset(-10, 0));
      await second.moveBy(const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<InteractiveViewer>(zoom)
          .transformationController!
          .value
          .getMaxScaleOnAxis(),
      greaterThan(1.5),
    );
    expect(find.byKey(const ValueKey('gallery-page-1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ending a zoomed share restores phone paging', (tester) async {
    tester.view.physicalSize = const Size(920, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entries = ValueNotifier<List<MemberEntry>>([local, shared]);
    addTearDown(entries.dispose);
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: ValueListenableBuilder<List<MemberEntry>>(
            valueListenable: entries,
            builder: (context, value, _) => MeetingVideoLayout(
              members: value,
              mainMember: selectMainMember(value),
            ),
          ),
        ),
      ),
    );
    final zoom = find.byKey(const ValueKey('main-video-zoom'));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(zoom),
        scrollDelta: const Offset(0, -200),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reset-video-zoom')), findsOneWidget);
    entries.value = [local, remote];
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('meeting-pages')),
      const Offset(-850, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('gallery-page-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
