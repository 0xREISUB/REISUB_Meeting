import 'package:material_ui/material_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/meeting/meeting_member.dart';
import 'package:v_meeting/meeting/widgets/meeting_participant.dart';

import 'support/meeting_fakes.dart';

void main() {
  testWidgets('fullscreen hides the desktop sidebar and restores it', (
    tester,
  ) async {
    await showMeeting(tester, const Size(1280, 800));
    expect(find.byKey(const ValueKey('meeting-sidebar')), findsOneWidget);
    final before = tester.getSize(find.byKey(const ValueKey('main-remote-0')));
    await tester.tap(find.byKey(const ValueKey('main-fullscreen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('meeting-sidebar')), findsNothing);
    expect(find.byKey(const ValueKey('meeting-next-page')), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('main-remote-0'))).width,
      greaterThan(before.width),
    );
    await tester.tap(find.byKey(const ValueKey('main-fullscreen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('meeting-sidebar')), findsOneWidget);
  });

  testWidgets('desktop sidebar shows four people, the rest, and arrows page', (
    tester,
  ) async {
    await showMeeting(tester, const Size(1280, 800));
    final sidebar = find.byKey(const ValueKey('meeting-sidebar'));
    // Four previews and a fifth slot standing in for everyone else.
    expect(
      find.descendant(
        of: sidebar,
        matching: find.byType(MeetingParticipantTile),
      ),
      findsNWidgets(4),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('meeting-sidebar-count')))
          .data,
      '${members.length}',
    );
    final more = find.byKey(const ValueKey('meeting-sidebar-more'));
    expect(
      find.descendant(
        of: more,
        matching: find.text('+${members.length - 1 - 4} kişi daha'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('preview-remote-0')), findsNothing);
    expect(find.byKey(const ValueKey('main-remote-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('meeting-next-page')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-remote-0')), findsNothing);
    expect(find.byType(MeetingParticipantTile), findsNWidgets(16));
    expect(find.byKey(const ValueKey('local')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('meeting-next-page')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('remote-29')), findsOneWidget);
    expect(find.byKey(const ValueKey('meeting-next-page')), findsNothing);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(const ValueKey('meeting-previous-page')));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('main-remote-0')), findsOneWidget);
    // The extra slot opens the gallery.
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-remote-0')), findsNothing);
    expect(find.byType(MeetingParticipantTile), findsNWidgets(16));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop frame holds its buttons and a touchpad swipe pages', (
    tester,
  ) async {
    await showMeeting(tester, const Size(1280, 800));
    final main = find.byKey(const ValueKey('main-remote-0'));
    // The main tile; the floating panel's previews sit inside it too.
    final frame = tester.getRect(
      find
          .descendant(of: main, matching: find.byType(MeetingParticipantTile))
          .first,
    );
    final button = tester.getRect(
      find.byKey(const ValueKey('main-fullscreen')),
    );
    expect(frame.contains(button.topLeft), isTrue);
    expect(frame.contains(button.bottomRight), isTrue);
    expect(find.byKey(const ValueKey('meeting-page-dots')), findsOneWidget);

    final pager = find.byKey(const ValueKey('meeting-pages'));
    final swipe = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await swipe.panZoomStart(tester.getCenter(pager));
    await swipe.panZoomUpdate(
      tester.getCenter(pager),
      pan: const Offset(-600, 0),
    );
    await swipe.panZoomEnd();
    await tester.pumpAndSettle();
    expect(main, findsNothing);
    expect(find.byType(MeetingParticipantTile), findsNWidgets(16));
    expect(tester.takeException(), isNull);
  });

  testWidgets('people without video show their initials', (tester) async {
    await tester.pumpWidget(
      localized(
        const Scaffold(
          body: SizedBox(
            width: 320,
            height: 180,
            child: MeetingParticipantTile(member: fourth),
          ),
        ),
      ),
    );
    expect(find.text('D'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsNothing);
    expect(MemberAvatar.initials('Yusuf Enes Kaya'), 'YK');
    expect(MemberAvatar.initials('  '), '?');
  });

  testWidgets('the floating panel collapses, moves and keeps taps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: MeetingVideoLayout(
            // Five people besides the one on the main video.
            members: members.take(6).toList(),
            mainMember: members[1],
            onMainPageTap: () => taps++,
          ),
        ),
      ),
    );
    final panel = find.byKey(const ValueKey('meeting-sidebar'));
    final previews = find.descendant(
      of: panel,
      matching: find.byType(MeetingParticipantTile),
    );
    expect(previews, findsNWidgets(5));
    // It starts in the bottom-right corner.
    final start = tester.getRect(panel);
    expect(start.center.dx, greaterThan(640));
    expect(start.center.dy, greaterThan(400));

    // Collapse to one person and back; taps on it leave the controls alone.
    await tester.tap(find.byKey(const ValueKey('meeting-island-collapse')));
    await tester.pumpAndSettle();
    expect(previews, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('meeting-island-collapse')));
    await tester.pumpAndSettle();
    expect(previews, findsNWidgets(5));
    await tester.tap(previews.first);
    await tester.pumpAndSettle();
    expect(taps, 0);

    // Dragged most of the way to the top-left, it settles in that corner.
    await tester.drag(panel, const Offset(-900, -500));
    await tester.pumpAndSettle();
    final moved = tester.getRect(panel);
    expect(moved.center.dx, lessThan(640));
    expect(moved.center.dy, lessThan(400));
    expect(taps, 0);

    // The video beside it still toggles the controls.
    await tester.tapAt(const Offset(900, 600));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the floating panel resizes and keeps its 16:9 previews', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: MeetingVideoLayout(
            members: members.take(3).toList(),
            mainMember: members[1],
            onMainPageTap: () => taps++,
          ),
        ),
      ),
    );
    final preview = find.byKey(const ValueKey('preview-local'));
    final before = tester.getSize(preview);
    final handle = find.byKey(const ValueKey('meeting-island-resize'));
    // Anchored bottom-right, so the grip is top-left and grows outwards.
    await tester.drag(handle, const Offset(-120, -40));
    await tester.pumpAndSettle();
    final after = tester.getSize(preview);
    expect(after.width, greaterThan(before.width + 100));
    expect(after.width / after.height, closeTo(16 / 9, 0.01));
    expect(taps, 0);

    // The size outlives collapsing and expanding.
    await tester.tap(find.byKey(const ValueKey('meeting-island-collapse')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('meeting-island-collapse')));
    await tester.pumpAndSettle();
    expect(tester.getSize(preview), after);

    // It never grows past what fits in the frame.
    await tester.drag(handle, const Offset(-2000, -2000));
    await tester.pumpAndSettle();
    final panel = tester.getRect(find.byKey(const ValueKey('meeting-sidebar')));
    expect(panel.top, greaterThanOrEqualTo(0));
    expect(panel.left, greaterThanOrEqualTo(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop previews keep their shape and size as people join', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entries = ValueNotifier<List<MemberEntry>>([local, remote]);
    addTearDown(entries.dispose);
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: ValueListenableBuilder<List<MemberEntry>>(
            valueListenable: entries,
            builder: (context, value, _) =>
                MeetingVideoLayout(members: value, mainMember: remote),
          ),
        ),
      ),
    );
    final preview = find.byKey(const ValueKey('preview-local'));
    final before = tester.getSize(preview);
    expect(before.width / before.height, closeTo(16 / 9, 0.001));
    expect(before.height, lessThan(170));
    entries.value = [local, remote, third, fourth, ...members.skip(3).take(2)];
    await tester.pumpAndSettle();
    expect(tester.getSize(preview), before);
    final sidebar = find.byKey(const ValueKey('meeting-sidebar'));
    final tiles = find.descendant(
      of: sidebar,
      matching: find.byType(MeetingParticipantTile),
    );
    expect(tiles, findsNWidgets(5));
    for (var i = 0; i < 5; i++) {
      expect(tester.getSize(tiles.at(i)), before);
    }
    tester.view.physicalSize = const Size(1280, 600);
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      final rect = tester.getRect(tiles.at(i));
      expect(rect.width / rect.height, closeTo(16 / 9, 0.001));
      expect(rect.bottom, lessThanOrEqualTo(600.001));
    }
    expect(tester.takeException(), isNull);
  });

  test('a single floating tile shows the sharer, else the last speaker', () {
    const sharing = MemberEntry(
      id: 'remote',
      name: 'Ayşe',
      isLocal: false,
      isMicEnabled: true,
      isScreenShare: true,
    );
    // During a screen share, the sharer's camera.
    expect(soloMember([local, remote, third], sharing)?.id, remote.id);
    // Otherwise whoever was on the main video before...
    expect(
      soloMember([local, remote, third], remote, previousMainId: third.id)?.id,
      third.id,
    );
    // ...else you, else anyone else.
    expect(soloMember([local, remote, third], remote)?.id, local.id);
    expect(soloMember([remote, third], remote)?.id, third.id);
    expect(soloMember([local], local), isNull);
  });

  testWidgets('the collapsed panel follows the previous main person', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final main = ValueNotifier<MemberEntry>(remote);
    addTearDown(main.dispose);
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: ValueListenableBuilder<MemberEntry>(
            valueListenable: main,
            builder: (context, value, _) => MeetingVideoLayout(
              members: const [local, remote, third, fourth],
              mainMember: value,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('meeting-island-collapse')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('preview-local')), findsOneWidget);
    main.value = third;
    await tester.pumpAndSettle();
    // Ayşe was on the main video before Can.
    expect(find.byKey(const ValueKey('preview-remote')), findsOneWidget);
    expect(find.byKey(const ValueKey('preview-local')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
