import 'package:v_meeting/l10n/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/meeting/meeting_sharing.dart';
import 'package:v_meeting/meeting/widgets/meeting_settings_dialog.dart';

class _SharingApi extends MeetingApi {
  MeetingState state = const MeetingState();
  Completer<MeetingState>? pendingRead;

  @override
  Future<MeetingState> getMeetingState(String roomId) async =>
      pendingRead == null ? state : pendingRead!.future;
  @override
  Future<MeetingState> startScreenShare(String roomId, String identity) async =>
      state = MeetingState(screenShareIdentity: identity);
}

void main() {
  testWidgets('meeting settings only hold the device tests', (tester) async {
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
}
