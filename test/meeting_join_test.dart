import 'dart:async';
import 'package:v_meeting/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/meeting/members_screen.dart';
import 'package:v_meeting/meeting/meeting_screen.dart';
import 'package:v_meeting/settings/device_test_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/meeting_fakes.dart';

void main() {
  testWidgets('joining screen stays until connection and media setup finish', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final room = TestRoom(connectSuccessfully: true);
    await tester.pumpWidget(
      meetingApp(room, api: ModerationApi(), credentials: guestCredentials),
    );
    expect(
      find.byKey(const ValueKey('meeting-joining-overlay')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('meeting-joining-overlay')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byKey(const ValueKey('meeting-joining-overlay')), findsNothing);
    expect(room.connectCalls, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed join shows retry and retries the connection', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final room = TestRoom();
    final api = ModerationApi();
    await tester.pumpWidget(
      meetingApp(room, api: api, credentials: guestCredentials),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byKey(const ValueKey('meeting-joining-retry')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('meeting-joining-retry')));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(api.joins, 1);
    expect(room.connectCalls, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('joining screen times out when signaling never finishes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final room = TestRoom(connectResult: Completer<void>());
    await tester.pumpWidget(
      meetingApp(room, api: ModerationApi(), credentials: guestCredentials),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
    expect(find.byKey(const ValueKey('meeting-joining-retry')), findsOneWidget);
    expect(room.disconnects, greaterThanOrEqualTo(1));
    await tester.pumpWidget(const SizedBox());
  });

  for (final deviceCase in [
    (camera: false, enabled: true, locked: false),
    (camera: true, enabled: true, locked: false),
    (camera: false, enabled: false, locked: false),
    (camera: false, enabled: true, locked: true),
  ]) {
    final camera = deviceCase.camera;
    testWidgets(
      'meeting device selection camera=$camera enabled=${deviceCase.enabled} lockDuringTest=${deviceCase.locked}',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const channel = MethodChannel('FlutterWebRTC.Method');
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getSources') {
            return {
              'sources': [
                {
                  'deviceId': 'new-mic',
                  'label': 'USB mikrofon',
                  'kind': 'audioinput',
                },
                {
                  'deviceId': 'new-camera',
                  'label': 'USB kamera',
                  'kind': 'videoinput',
                },
              ],
            };
          }
          if (call.method == 'createVideoRenderer') return {'textureId': 42};
          return null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final source = camera ? TrackSource.camera : TrackSource.microphone;
        final local = TestLocal()..microphone = deviceCase.enabled;
        local.publications[source] = TestPublication('old-device');
        local.publications[TrackSource.screenShareAudio] = TestPublication(
          'screen-audio',
        );
        final room = TestRoom(local: local);
        await openExitTest(tester, room);
        room.events.streamCtrl.add(
          RoomConnectedEvent(room: room, metadata: null),
        );
        room.changed();
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.more_horiz_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ses ve görüntü'));
        await tester.pumpAndSettle();
        expect(find.byType(SwitchListTile), findsNothing);
        await tester.tap(
          find.text(
            camera ? 'Kamera seçimi ve testi' : 'Mikrofon seçimi ve testi',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(DeviceTestScreen), findsOneWidget);
        expect(find.byType(MeetingScreen), findsOneWidget);
        expect(local.removed, ['old-device']);
        expect(
          local.publications.containsKey(TrackSource.screenShareAudio),
          isTrue,
        );
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(camera ? 'USB kamera' : 'USB mikrofon').last,
        );
        await tester.pumpAndSettle();
        if (deviceCase.locked) {
          local.values['meeting.microphone_locked'] = 'true';
          room.changed();
          await tester.pump();
        }
        await tester.tap(find.byType(CloseButton));
        await tester.pumpAndSettle();
        expect(find.byType(DeviceTestScreen), findsNothing);
        expect(
          camera ? local.cameraChanges.last : local.microphoneChanges.last,
          deviceCase.enabled && !deviceCase.locked,
        );
        expect(
          camera ? local.cameraDevices.last : local.microphoneDevices.last,
          camera ? 'new-camera' : 'new-mic',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  }

  for (final reason in [
    DisconnectReason.roomDeleted,
    DisconnectReason.roomClosed,
  ]) {
    testWidgets('server $reason returns home even with a sheet open', (
      tester,
    ) async {
      final room = TestRoom();
      await openExitTest(tester, room);
      await tester.tap(find.byIcon(Icons.people_rounded));
      await tester.pumpAndSettle();
      room.events.streamCtrl.add(RoomDisconnectedEvent(reason: reason));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(MeetingScreen), findsNothing);
      expect(find.byType(MembersScreen), findsNothing);
      expect(
        find.text('Toplantı sunucu tarafından kapatıldı.'),
        findsOneWidget,
      );
      expect(room.disconnects, 1);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  }

  testWidgets('network failure keeps the meeting and rejoin action', (
    tester,
  ) async {
    final room = TestRoom();
    await openExitTest(tester, room);
    room.events.streamCtrl.add(
      RoomDisconnectedEvent(reason: DisconnectReason.reconnectAttemptsExceeded),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MeetingScreen), findsOneWidget);
    expect(find.text('Tekrar katıl'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  for (final host in [false, true]) {
    testWidgets('screen share is unavailable while someone else shares '
        '(host=$host)', (tester) async {
      // A participant who may share, or the full admin.
      final local = TestLocal()..values['meeting.permissions'] = 'share_screen';
      final room = TestRoom(local: local);
      await openExitTest(tester, room, host: host, api: BusySharingApi());
      room.events.streamCtrl.add(
        RoomConnectedEvent(room: room, metadata: null),
      );
      await tester.pumpAndSettle();
      final button = find.byTooltip('Şu anda başka biri ekranını paylaşıyor');
      expect(button, findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(of: button, matching: find.byType(IconButton)),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
  }

  testWidgets('host exit offers end and leave; leave does not close the room', (
    tester,
  ) async {
    final room = TestRoom();
    final api = ModerationApi();
    await openExitTest(tester, room, host: true, api: api);
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Toplantıyı herkes için bitir'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.call_end_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Toplantıyı bitir'), findsOneWidget);
    expect(find.text('Ayrıl'), findsOneWidget);
    await tester.tap(find.text('Ayrıl'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(api.closes, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('host end tolerates server disconnect before API returns', (
    tester,
  ) async {
    final room = TestRoom();
    final api = ModerationApi()
      ..onClose = () {
        room.events.streamCtrl.add(
          RoomDisconnectedEvent(reason: DisconnectReason.roomDeleted),
        );
      };
    await openExitTest(tester, room, host: true, api: api);
    await tester.tap(find.byIcon(Icons.call_end_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toplantıyı bitir'));
    await tester.pumpAndSettle();
    expect(api.closes, 1);
    expect(room.disconnects, 1);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Toplantıyı bitirdiniz.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
