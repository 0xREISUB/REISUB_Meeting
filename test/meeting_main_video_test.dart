import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/meeting/members_screen.dart';
import 'package:v_meeting/meeting/meeting_member.dart';
import 'package:v_meeting/meeting/widgets/meeting_participant.dart';
import 'support/meeting_fakes.dart';

void main() {
  test('you are on the main video only when alone', () {
    expect(selectMainMember([local]).id, local.id);
    expect(selectMainMember([local, remote]).id, remote.id);
    // Even when you are the one talking in a group.
    for (final speaker in [null, local.id]) {
      expect(
        selectMainMember([local, remote, third], speakerId: speaker).id,
        isNot(local.id),
      );
    }
  });

  test('the main video shows the focused speaker, else another person', () {
    const members = [local, remote, third];
    expect(selectMainMember(members, speakerId: third.id).id, third.id);
    expect(selectMainMember(members, speakerId: remote.id).id, remote.id);
    // A speaker who left.
    expect(selectMainMember(members, speakerId: fourth.id).id, remote.id);
  });

  group('speaker focus', () {
    final start = DateTime(2026);
    DateTime at(int milliseconds) =>
        start.add(Duration(milliseconds: milliseconds));
    const people = ['a', 'b', 'c'];

    test('starts on the first person and switches only after 1.5 s', () {
      final focus = SpeakerFocus();
      focus.update(participantIds: people, speakingIds: [], now: at(0));
      expect(focus.focusId, 'a');

      // b talks; a has been shown long enough, but b only just started.
      final wait = focus.update(
        participantIds: people,
        speakingIds: ['b'],
        now: at(5000),
      );
      expect(focus.focusId, 'a');
      expect(wait, const Duration(milliseconds: 1500));
      focus.update(participantIds: people, speakingIds: ['b'], now: at(6000));
      expect(focus.focusId, 'a');
      focus.update(participantIds: people, speakingIds: ['b'], now: at(6500));
      expect(focus.focusId, 'b');
    });

    test('a short sound or a break in speech does not switch', () {
      final focus = SpeakerFocus();
      focus.update(participantIds: people, speakingIds: [], now: at(0));
      focus.update(participantIds: people, speakingIds: ['b'], now: at(5000));
      focus.update(participantIds: people, speakingIds: [], now: at(5400));
      // b starts again: the 1.5 s count starts over.
      focus.update(participantIds: people, speakingIds: ['b'], now: at(5600));
      focus.update(participantIds: people, speakingIds: ['b'], now: at(6600));
      expect(focus.focusId, 'a');
      focus.update(participantIds: people, speakingIds: ['b'], now: at(7100));
      expect(focus.focusId, 'b');
    });

    test('the shown person stays while still talking and for 4 s', () {
      final focus = SpeakerFocus();
      focus.update(participantIds: people, speakingIds: ['a'], now: at(0));
      // a and b both talking, b louder: a stays.
      focus.update(
        participantIds: people,
        speakingIds: ['b', 'a'],
        now: at(1000),
      );
      focus.update(
        participantIds: people,
        speakingIds: ['b', 'a'],
        now: at(9000),
      );
      expect(focus.focusId, 'a');

      // After a switch to b, c must wait until b has been shown 4 s.
      focus.update(participantIds: people, speakingIds: ['b'], now: at(10000));
      focus.update(participantIds: people, speakingIds: ['b'], now: at(11500));
      expect(focus.focusId, 'b');
      final wait = focus.update(
        participantIds: people,
        speakingIds: ['c'],
        now: at(12000),
      );
      expect(wait, const Duration(milliseconds: 3500));
      focus.update(participantIds: people, speakingIds: ['c'], now: at(15500));
      expect(focus.focusId, 'c');
    });

    test('silence keeps the last speaker; one who leaves is replaced', () {
      final focus = SpeakerFocus();
      focus.update(participantIds: people, speakingIds: ['c'], now: at(0));
      focus.update(participantIds: people, speakingIds: [], now: at(60000));
      expect(focus.focusId, 'c');
      focus.update(participantIds: ['a', 'b'], speakingIds: [], now: at(61000));
      expect(focus.focusId, 'a');
    });
  });

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

  test(
    'screen sharing takes precedence over self, speakers and the last speaker',
    () {
      for (final entries in [
        [shared],
        [local, shared],
        [local, remote, shared],
      ]) {
        final main = selectMainMember(entries, speakerId: remote.id);
        expect(main.id, shared.id);
        expect(main.isScreenShare, isTrue);
        expect(
          main.videoTrack,
          isNull,
        ); // Wait for the screen instead of showing a camera.
      }
    },
  );
}
