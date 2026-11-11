import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/l10n/localized_error.dart';
import 'package:v_meeting/meeting/meeting_member.dart';
import 'package:v_meeting/meeting/widgets/permissions_dialog.dart';

const you = MemberEntry(
  id: 'you',
  identity: 'you',
  name: 'Yusuf',
  isLocal: true,
  isMicEnabled: true,
  grantedPermissions: {MeetingPermission.grantPermissions},
);
const owner = MemberEntry(
  id: 'owner',
  identity: 'owner',
  name: 'Zeynep',
  isLocal: false,
  isMicEnabled: true,
  role: MeetingRole.owner,
);
const ayse = MemberEntry(
  id: 'ayse',
  identity: 'ayse',
  name: 'Ayşe',
  isLocal: false,
  isMicEnabled: true,
  grantedPermissions: {MeetingPermission.shareScreen},
);
const mert = MemberEntry(
  id: 'mert',
  identity: 'mert',
  name: 'Mert',
  isLocal: false,
  isMicEnabled: true,
);

Widget app(Widget child) => MaterialApp(
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  late List<(String, MeetingPermission, bool)> changes;
  late Completer<void>? pendingChange;
  late List<String> transfers;

  setUp(() {
    changes = [];
    pendingChange = null;
    transfers = [];
  });

  Future<void> show(
    WidgetTester tester, {
    List<MemberEntry> members = const [mert, you, ayse, owner],
    bool viewerIsOwner = false,
    Size size = const Size(1000, 700),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        PermissionsDialog(
          members: members,
          canChange: (member) =>
              !member.isLocal && member.role != MeetingRole.owner,
          onChanged: (member, permission, on) {
            changes.add((member.identity, permission, on));
            return pendingChange?.future ?? Future.value();
          },
          onTransferOwnership: viewerIsOwner
              ? (member) async => transfers.add(member.identity)
              : null,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool switchOn(WidgetTester tester, MeetingPermission permission) => tester
      .widget<SwitchListTile>(
        find.byKey(ValueKey('permission-${permission.name}')),
      )
      .value;

  bool switchEnabled(WidgetTester tester, MeetingPermission permission) =>
      tester
          .widget<SwitchListTile>(
            find.byKey(ValueKey('permission-${permission.name}')),
          )
          .onChanged !=
      null;

  testWidgets('the full admin first, then you, then others by name', (
    tester,
  ) async {
    await show(tester);
    final rows = [
      for (final id in ['owner', 'you', 'ayse', 'mert'])
        tester.getTopLeft(find.byKey(ValueKey('permissions-member-$id'))).dy,
    ];
    expect(rows, [...rows]..sort());
    expect(find.text('Tam yönetici'), findsOneWidget);
    expect(find.text('1 izin'), findsNWidgets(2));
    expect(find.text('İzin yok'), findsOneWidget);
  });

  testWidgets('search narrows the list', (tester) async {
    await show(tester);
    await tester.enterText(
      find.byKey(const ValueKey('permissions-search')),
      'ay',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('permissions-member-ayse')), findsOne);
    expect(find.byKey(const ValueKey('permissions-member-mert')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('permissions-search')),
      'xyz',
    );
    await tester.pump();
    expect(find.text('Üye bulunamadı'), findsOneWidget);
  });

  testWidgets('a switch shows the change at once and sends it', (tester) async {
    pendingChange = Completer<void>();
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('permissions-member-mert')));
    await tester.pumpAndSettle();
    expect(switchOn(tester, MeetingPermission.endMeeting), isFalse);
    await tester.tap(find.byKey(const ValueKey('permission-endMeeting')));
    await tester.pump();
    // Still waiting for the server, but already on.
    expect(switchOn(tester, MeetingPermission.endMeeting), isTrue);
    expect(changes, [('mert', MeetingPermission.endMeeting, true)]);
    pendingChange!.complete();
    await tester.pumpAndSettle();
    expect(switchOn(tester, MeetingPermission.endMeeting), isTrue);
  });

  testWidgets('a refused change goes back and says why', (tester) async {
    pendingChange = Completer<void>();
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('permissions-member-ayse')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('permission-shareScreen')));
    await tester.pump();
    expect(switchOn(tester, MeetingPermission.shareScreen), isFalse);
    pendingChange!.completeError(
      const AppException.localized(AppError.permissionRequired),
    );
    await tester.pumpAndSettle();
    expect(switchOn(tester, MeetingPermission.shareScreen), isTrue);
    expect(find.text('Bunun için yetkiniz yok.'), findsOneWidget);
  });

  testWidgets('the full admin and you cannot be changed', (tester) async {
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('permissions-member-owner')));
    await tester.pumpAndSettle();
    expect(find.text('Tam yönetici tüm izinlere sahiptir.'), findsOneWidget);
    for (final permission in MeetingPermission.values) {
      expect(switchOn(tester, permission), isTrue);
      expect(switchEnabled(tester, permission), isFalse);
    }
    await tester.tap(find.byKey(const ValueKey('permissions-member-you')));
    await tester.pumpAndSettle();
    expect(find.text('Kendi izinlerini değiştiremezsin.'), findsOneWidget);
    expect(switchOn(tester, MeetingPermission.grantPermissions), isTrue);
    expect(switchEnabled(tester, MeetingPermission.grantPermissions), isFalse);
    // Only the full admin can hand the role over.
    await tester.tap(find.byKey(const ValueKey('permissions-member-mert')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('permissions-transfer')), findsNothing);
  });

  testWidgets('the full admin hands the role over after confirming', (
    tester,
  ) async {
    const yourself = MemberEntry(
      id: 'you',
      identity: 'you',
      name: 'Yusuf',
      isLocal: true,
      isMicEnabled: true,
      role: MeetingRole.owner,
    );
    await show(tester, members: const [yourself, ayse], viewerIsOwner: true);
    await tester.tap(find.byKey(const ValueKey('permissions-member-ayse')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('permissions-transfer')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ayşe tam yönetici olur'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-transfer')));
    await tester.pumpAndSettle();
    expect(transfers, ['ayse']);
  });

  testWidgets('a phone shows the list, then one person', (tester) async {
    await show(tester, size: const Size(390, 800));
    expect(find.byKey(const ValueKey('permission-shareScreen')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('permissions-member-ayse')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('permissions-search')), findsNothing);
    expect(switchOn(tester, MeetingPermission.shareScreen), isTrue);
    await tester.tap(find.byKey(const ValueKey('permissions-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('permissions-search')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
