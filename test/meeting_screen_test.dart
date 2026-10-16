import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/members_screen.dart';
import 'package:v_meeting/meeting/widgets/meeting_participant.dart';

const local = MemberEntry(
  id: 'local',
  name: 'Ali',
  isLocal: true,
  isMicEnabled: true,
);
const remote = MemberEntry(
  id: 'remote',
  name: 'Ayşe',
  isLocal: false,
  isMicEnabled: true,
);
const third = MemberEntry(
  id: 'third',
  name: 'Can',
  isLocal: false,
  isMicEnabled: false,
);
const fourth = MemberEntry(
  id: 'fourth',
  name: 'Deniz',
  isLocal: false,
  isMicEnabled: true,
);

Widget localized(Widget child) => MaterialApp(
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  test('alone shows self; two participants always show the other person', () {
    expect(selectMainMember([local], activeSpeakerIds: []).id, local.id);
    expect(
      selectMainMember([local, remote], activeSpeakerIds: [local.id]).id,
      remote.id,
    );
  });

  test(
    'group follows the loudest speaker, including self and camera-off users',
    () {
      const members = [local, remote, third];
      for (final speaker in members) {
        expect(
          selectMainMember(
            members,
            activeSpeakerIds: [speaker.id, fourth.id],
            previousSpeakerId: remote.id,
          ).id,
          speaker.id,
        );
      }
    },
  );

  test(
    'silence keeps last speaker and a departed speaker falls back safely',
    () {
      expect(
        selectMainMember(
          [local, remote, third],
          activeSpeakerIds: [],
          previousSpeakerId: third.id,
        ).id,
        third.id,
      );
      expect(
        selectMainMember(
          [local, remote, fourth],
          activeSpeakerIds: [third.id],
          previousSpeakerId: third.id,
        ).id,
        remote.id,
      );
      expect(
        selectMainMember(
          [local],
          activeSpeakerIds: [third.id],
          previousSpeakerId: third.id,
        ).id,
        local.id,
      );
    },
  );

  testWidgets(
    'members panel lists names and rebuilds when membership changes',
    (tester) async {
      final names = ValueNotifier<List<String>>(['Ali', 'Ayşe']);
      addTearDown(names.dispose);
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: ValueListenableBuilder<List<String>>(
              valueListenable: names,
              builder: (context, value, _) => MembersScreen(names: value),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ali'), findsOneWidget);
      expect(find.text('Ayşe'), findsOneWidget);
      expect(find.byType(MeetingParticipantTile), findsNothing);
      names.value = ['Ali', 'Can'];
      await tester.pump();
      expect(find.text('Ayşe'), findsNothing);
      expect(find.text('Can'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  final members = [
    local,
    ...List.generate(
      30,
      (index) => MemberEntry(
        id: 'remote-$index',
        name: 'Katılımcı $index',
        isLocal: false,
        isMicEnabled: false,
      ),
    ),
  ];

  Future<void> showMeeting(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: MeetingVideoLayout(members: members, mainMember: members[1]),
        ),
      ),
    );
  }

  testWidgets('desktop has five previews and arrows page through the gallery', (
    tester,
  ) async {
    await showMeeting(tester, const Size(1280, 800));
    final sidebar = find.byKey(const ValueKey('meeting-sidebar'));
    expect(
      find.descendant(
        of: sidebar,
        matching: find.byType(MeetingParticipantTile),
      ),
      findsNWidgets(5),
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile main video fills page and galleries use swipes only', (
    tester,
  ) async {
    await showMeeting(tester, const Size(360, 720));
    final pager = find.byKey(const ValueKey('meeting-pages'));
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(MeetingParticipantTile), findsOneWidget);
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
}
