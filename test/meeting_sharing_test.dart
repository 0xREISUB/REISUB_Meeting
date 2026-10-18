import 'package:v_meeting/l10n/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/meeting/meeting_sharing.dart';

class _SharingApi extends MeetingApi {
  MeetingState state = const MeetingState();
  Completer<MeetingState>? pendingRead;
  final changes = <bool>[];

  @override
  Future<MeetingState> getMeetingState(String roomId) async =>
      pendingRead == null ? state : pendingRead!.future;
  @override
  Future<MeetingState> updateMeetingSettings(
    String roomId, {
    required bool allowScreenShare,
  }) async {
    changes.add(allowScreenShare);
    return state = MeetingState(allowParticipantScreenShare: allowScreenShare);
  }

  @override
  Future<MeetingState> startScreenShare(String roomId, String identity) async =>
      state = MeetingState(screenShareIdentity: identity);
}

void main() {
  testWidgets('every participant can open microphone and camera tests', (
    tester,
  ) async {
    final opened = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MeetingSettingsDialog(
            onDeviceTest: (camera) async => opened.add(camera),
          ),
        ),
      ),
    );
    expect(find.byType(SwitchListTile), findsNothing);
    await tester.tap(find.text('Mikrofon seçimi ve testi'));
    await tester.tap(find.text('Kamera seçimi ve testi'));
    expect(opened, [false, true]);
    expect(tester.takeException(), isNull);
  });

  test('a stale poll cannot overwrite a newly granted screen share', () async {
    final api = _SharingApi()..pendingRead = Completer<MeetingState>();
    final sharing = MeetingSharing(roomId: '123-456-789', api: api);
    final read = sharing.refresh();
    await sharing.acquire('current-session');
    api.pendingRead!.complete(const MeetingState());
    await read;
    expect(sharing.state.screenShareIdentity, 'current-session');
    sharing.dispose();
  });

  testWidgets(
    'meeting settings start disabled and persist explicit owner changes',
    (tester) async {
      final api = _SharingApi();
      final sharing = MeetingSharing(roomId: '123-456-789', api: api);
      await sharing.refresh();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MeetingSettingsDialog(sharing: sharing)),
        ),
      );
      final toggle = find.byType(SwitchListTile);
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(api.changes, [true]);
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(api.changes, [true, false]);
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      await tester.pumpWidget(const SizedBox());
      sharing.dispose();
    },
  );
}
