import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/app/orientation.dart';
import 'package:v_meeting/meeting/meeting_display.dart';
import 'package:v_meeting/meeting/meeting_platform.dart';

class _Platform extends MeetingPlatform {
  @override
  Future<void> setFullscreen(bool enabled) async {}
}

void main() {
  late List<List<String>> orientations;

  setUp(() {
    orientations = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            orientations.add(List<String>.from(call.arguments as List));
          }
          return null;
        });
  });

  tearDown(() {
    AppOrientation.base = const [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> showHome(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [appRouteObserver],
        home: PortraitOnPhone(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const Text('next')),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a phone keeps the home screen upright and lets others rotate', (
    tester,
  ) async {
    await showHome(tester, const Size(390, 844));
    expect(orientations.last, ['DeviceOrientation.portraitUp']);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(orientations.last, isEmpty);
    Navigator.of(tester.element(find.text('next'))).pop();
    await tester.pumpAndSettle();
    expect(orientations.last, ['DeviceOrientation.portraitUp']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('tablets and computers are not locked', (tester) async {
    await showHome(tester, const Size(1280, 800));
    expect(orientations, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a phone meeting goes back to upright when it ends', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppOrientation.base = const [DeviceOrientation.portraitUp];
    final display = MeetingDisplayMode(_Platform());
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          display.enterIfPhone(context);
          return const SizedBox();
        },
      ),
    );
    await tester.pump();
    expect(orientations.last, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
    display.exit();
    await tester.pump();
    expect(orientations.last, ['DeviceOrientation.portraitUp']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
