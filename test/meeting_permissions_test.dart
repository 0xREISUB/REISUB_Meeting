import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/meeting/members_screen.dart';
import 'package:v_meeting/meeting/meeting_member.dart';

import 'support/meeting_fakes.dart';

void main() {
  testWidgets('microphone controls follow the viewer\'s permissions', (
    tester,
  ) async {
    const guest = MemberEntry(
      id: 'guest',
      identity: 'guest',
      name: 'Konuk',
      isLocal: false,
      isMicEnabled: true,
    );
    const lockedGuest = MemberEntry(
      id: 'guest',
      identity: 'guest',
      name: 'Konuk',
      isLocal: false,
      isMicEnabled: false,
      isMicrophoneLocked: true,
    );
    final actions = <(bool, bool)>[];
    Future<void> render(
      Set<MeetingPermission> viewer,
      MemberEntry entry,
    ) async {
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: MembersScreen(
              members: [local, entry],
              viewerPermissions: viewer,
              onMicrophoneChange: (_, locked, request) async =>
                  actions.add((locked, request)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openMenu() async {
      await tester.tap(find.byKey(const ValueKey('moderate-guest')));
      await tester.pumpAndSettle();
    }

    await render({}, guest);
    expect(find.byTooltip('Katılımcı işlemleri'), findsNothing);
    await render({MeetingPermission.shareScreen}, guest);
    expect(find.byTooltip('Katılımcı işlemleri'), findsNothing);

    // Muting alone: lock, but no unmute request.
    await render({MeetingPermission.muteOthers}, guest);
    await openMenu();
    expect(find.text('Mikrofonu açmasını iste'), findsNothing);
    await tester.tap(find.text('Mikrofonu kapat ve kilitle'));
    await tester.pumpAndSettle();
    expect(actions, [(true, false)]);

    // Asking alone: a request, but nothing for a locked microphone.
    await render({MeetingPermission.requestUnmute}, guest);
    await openMenu();
    expect(find.text('Mikrofonu kapat ve kilitle'), findsNothing);
    await tester.tap(find.text('Mikrofonu açmasını iste'));
    await tester.pumpAndSettle();
    expect(actions.last, (false, true));
    await render({MeetingPermission.requestUnmute}, lockedGuest);
    expect(find.byKey(const ValueKey('moderate-guest')), findsNothing);

    // Both: unlock and ask at once.
    await render({
      MeetingPermission.muteOthers,
      MeetingPermission.requestUnmute,
    }, lockedGuest);
    await openMenu();
    await tester.tap(find.text('Kilidi kaldır ve açmasını iste'));
    await tester.pumpAndSettle();
    expect(actions.last, (false, true));
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing someone asks first and spares the full admin', (
    tester,
  ) async {
    const guest = MemberEntry(
      id: 'guest',
      identity: 'guest',
      name: 'Konuk',
      isLocal: false,
      isMicEnabled: true,
    );
    const fullAdmin = MemberEntry(
      id: 'owner',
      identity: 'owner',
      name: 'Sahip Can',
      isLocal: false,
      isMicEnabled: true,
      role: MeetingRole.owner,
    );
    final removed = <String>[];
    Future<void> render(Set<MeetingPermission> viewer) async {
      await tester.pumpWidget(
        localized(
          Scaffold(
            body: MembersScreen(
              members: const [local, guest, fullAdmin],
              viewerPermissions: viewer,
              onMicrophoneChange: (_, _, _) async {},
              onRemove: (member) async => removed.add(member.identity),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await render({MeetingPermission.muteOthers});
    await tester.tap(find.byKey(const ValueKey('moderate-guest')));
    await tester.pumpAndSettle();
    expect(find.text('Toplantıdan çıkar'), findsNothing);
    // Close that menu.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    // Removing alone is enough for the menu.
    await render({MeetingPermission.removeMembers});
    expect(find.byKey(const ValueKey('moderate-owner')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('moderate-guest')));
    await tester.pumpAndSettle();
    expect(find.text('Mikrofonu kapat ve kilitle'), findsNothing);
    await tester.tap(find.text('Toplantıdan çıkar'));
    await tester.pumpAndSettle();
    expect(find.text('Konuk toplantıdan çıkarılsın mı?'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(removed, isEmpty);

    await tester.tap(find.byKey(const ValueKey('moderate-guest')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toplantıdan çıkar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-remove')));
    await tester.pumpAndSettle();
    expect(removed, ['guest']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the members panel marks and protects the full admin', (
    tester,
  ) async {
    const fullAdmin = MemberEntry(
      id: 'owner',
      identity: 'owner',
      name: 'Sahip Can',
      isLocal: false,
      isMicEnabled: true,
      role: MeetingRole.owner,
    );
    const guest = MemberEntry(
      id: 'guest',
      identity: 'guest',
      name: 'Konuk',
      isLocal: false,
      isMicEnabled: true,
    );
    await tester.pumpWidget(
      localized(
        Scaffold(
          body: MembersScreen(
            members: const [local, guest, fullAdmin],
            viewerPermissions: MeetingPermission.values.toSet(),
            onMicrophoneChange: (_, _, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('role-badge-owner')), findsOneWidget);
    expect(find.byKey(const ValueKey('moderate-owner')), findsNothing);
    expect(find.byKey(const ValueKey('moderate-guest')), findsOneWidget);
    // Roles and transfers live in the permissions window now.
    await tester.tap(find.byKey(const ValueKey('moderate-guest')));
    await tester.pumpAndSettle();
    expect(find.text('Tam yöneticiliği devret'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the end-meeting permission unlocks ending the meeting', (
    tester,
  ) async {
    final participant = TestLocal();
    participant.values['meeting.permissions'] = 'end_meeting';
    final room = TestRoom(local: participant);
    final api = ModerationApi();
    await openExitTest(tester, room, api: api);
    await tester.tap(find.byIcon(Icons.call_end_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Toplantıyı bitir'), findsOneWidget);
    await tester.tap(find.text('Ayrıl'));
    await tester.pumpAndSettle();
    expect(api.leaves, 1);
    expect(api.closes, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('only people who may give permissions see the menu entry', (
    tester,
  ) async {
    Future<void> openMenu() async {
      await tester.tap(find.byTooltip('Daha fazla'));
      await tester.pumpAndSettle();
    }

    final participant = TestLocal()
      ..values['meeting.permissions'] = 'share_screen';
    await openExitTest(tester, TestRoom(local: participant));
    await openMenu();
    expect(find.text('Yetkilendirmeler'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    final granter = TestLocal()
      ..values['meeting.permissions'] = 'grant_permissions';
    await openExitTest(tester, TestRoom(local: granter));
    await openMenu();
    await tester.tap(find.text('Yetkilendirmeler'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('permissions-search')), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
