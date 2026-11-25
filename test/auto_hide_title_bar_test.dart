import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/app/auto_hide_title_bar.dart';
import 'package:v_meeting/app/window_controls.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

class FakeWindow implements WindowControls {
  final calls = <String>[];
  bool maximized = false;

  @override
  Future<void> minimize() async => calls.add('minimize');

  @override
  Future<bool> isMaximized() async => maximized;

  @override
  Future<void> toggleMaximize() async {
    maximized = !maximized;
    calls.add('toggleMaximize');
  }

  @override
  Future<void> close() async => calls.add('close');

  @override
  Future<void> startDragging() async => calls.add('drag');
}

Future<(FakeWindow, TestGesture)> showApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final window = FakeWindow();
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          AutoHideTitleBar(controls: window, child: child!),
      home: const Scaffold(body: Center(child: Text('page'))),
    ),
  );
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(500, 400));
  addTearDown(mouse.removePointer);
  await tester.pump();
  return (window, mouse);
}

/// Whether the bar is down in the window.
bool barShown(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const ValueKey('title-bar'))).dy >= 0;

void main() {
  testWidgets('the bar comes down as soon as the pointer reaches the top', (
    tester,
  ) async {
    final (_, mouse) = await showApp(tester);
    expect(barShown(tester), isFalse);

    await mouse.moveTo(const Offset(500, 30));
    await tester.pumpAndSettle();
    expect(barShown(tester), isFalse);

    await mouse.moveTo(const Offset(500, 10));
    await tester.pumpAndSettle();
    expect(barShown(tester), isTrue);
  });

  testWidgets('passing by the top takes it away again', (tester) async {
    final (_, mouse) = await showApp(tester);
    await mouse.moveTo(const Offset(500, 10));
    await tester.pump();
    await mouse.moveTo(const Offset(500, 300));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(barShown(tester), isFalse);
  });

  testWidgets('it stays while the pointer is on it and goes when it leaves', (
    tester,
  ) async {
    final (_, mouse) = await showApp(tester);
    await mouse.moveTo(const Offset(500, 2));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(barShown(tester), isTrue);

    // Moving about on the bar, for a good while.
    await mouse.moveTo(const Offset(300, 20));
    await tester.pump(const Duration(seconds: 3));
    await mouse.moveTo(const Offset(700, 30));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(barShown(tester), isTrue);

    await mouse.moveTo(const Offset(500, 300));
    await tester.pump(AutoHideTitleBar.hideDelay);
    await tester.pumpAndSettle();
    expect(barShown(tester), isFalse);
  });

  testWidgets('its buttons and its drag reach the window', (tester) async {
    final (window, mouse) = await showApp(tester);
    await mouse.moveTo(const Offset(500, 2));
    await tester.pump();
    await tester.pumpAndSettle();
    await mouse.moveTo(const Offset(500, 20));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('title-bar-maximize')));
    await tester.pumpAndSettle();
    // Restoring shows another icon once maximised.
    expect(find.byIcon(Icons.filter_none_rounded), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('title-bar-close')));
    await tester.drag(
      find.byKey(const ValueKey('title-bar-drag')),
      const Offset(40, 0),
    );
    await tester.pumpAndSettle();
    expect(window.calls, ['toggleMaximize', 'close', 'drag']);

    await tester.tap(find.byKey(const ValueKey('title-bar-minimize')));
    await tester.pumpAndSettle();
    expect(window.calls.last, 'minimize');
    expect(barShown(tester), isFalse);
  });
}
