import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/meeting_platform.dart';
import 'package:v_meeting/meeting/widgets/screen_source_picker.dart';

class _Source extends rtc.DesktopCapturerSource {
  _Source(this.id, this.name, this.type);

  @override
  final String id;
  @override
  final String name;
  @override
  final rtc.SourceType type;
  @override
  Uint8List? get thumbnail => null;
  @override
  rtc.ThumbnailSize get thumbnailSize => rtc.ThumbnailSize(320, 180);
  @override
  final onNameChanged = StreamController<String>.broadcast();
  @override
  final onThumbnailChanged = StreamController<Uint8List>.broadcast();
}

class _Capturer extends rtc.DesktopCapturer {
  final sources = [
    _Source('screen-a', 'Entire Screen', rtc.SourceType.Screen),
    _Source('screen-b', 'Screen 2', rtc.SourceType.Screen),
    _Source('window-a', 'Belgeler — Dosyalar', rtc.SourceType.Window),
  ];

  @override
  final onAdded = StreamController<rtc.DesktopCapturerSource>.broadcast();
  @override
  final onRemoved = StreamController<rtc.DesktopCapturerSource>.broadcast();
  @override
  final onNameChanged = StreamController<rtc.DesktopCapturerSource>.broadcast();
  @override
  final onThumbnailChanged =
      StreamController<rtc.DesktopCapturerSource>.broadcast();

  @override
  Future<List<rtc.DesktopCapturerSource>> getSources({
    required List<rtc.SourceType> types,
    rtc.ThumbnailSize? thumbnailSize,
  }) async => sources.where((s) => types.contains(s.type)).toList();

  @override
  Future<bool> updateSources({required List<rtc.SourceType> types}) async =>
      true;
}

Future<Future<ScreenShareChoice?>> openPicker(
  WidgetTester tester,
  SystemAudioSupport audioSupport,
) async {
  late Future<ScreenShareChoice?> result;
  // A typical desktop window.
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => result = ScreenSourcePicker.show(
            context,
            capturer: _Capturer(),
            audioSupport: audioSupport,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('first screen is preselected and shares with computer audio', (
    tester,
  ) async {
    final result = await openPicker(tester, SystemAudioSupport.excludesMeeting);
    expect(find.text('Ekran 1'), findsOneWidget);
    expect(find.text('Ekran 2'), findsOneWidget);
    expect(find.text('Bilgisayar sesini paylaş'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('screen-picker-share')));
    await tester.pumpAndSettle();
    final choice = await result;
    expect(choice?.sourceId, 'screen-a');
    expect(choice?.shareAudio, isTrue);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a window can be chosen and audio turned off', (tester) async {
    final result = await openPicker(tester, SystemAudioSupport.excludesMeeting);
    await tester.tap(find.text('Pencere'));
    await tester.pumpAndSettle();
    expect(find.text('Belgeler — Dosyalar'), findsOneWidget);
    expect(
      find.text('Yalnızca seçilen pencerenin sesi paylaşılır.'),
      findsOneWidget,
    );
    final share = find.byKey(const ValueKey('screen-picker-share'));
    expect(tester.widget<ButtonStyleButton>(share).onPressed, isNull);
    await tester.tap(find.text('Belgeler — Dosyalar'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('screen-picker-audio')));
    await tester.pumpAndSettle();
    expect(tester.widget<ButtonStyleButton>(share).onPressed, isNotNull);
    await tester.tap(share);
    await tester.pumpAndSettle();
    final choice = await result;
    expect(choice?.sourceId, 'window-a');
    expect(choice?.shareAudio, isFalse);
  });

  testWidgets('Linux warns about echo and leaves audio off by default', (
    tester,
  ) async {
    final result = await openPicker(tester, SystemAudioSupport.includesMeeting);
    expect(find.textContaining('kulaklık'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('screen-picker-share')));
    await tester.pumpAndSettle();
    expect((await result)?.shareAudio, isFalse);
  });

  testWidgets('cancelling returns nothing', (tester) async {
    final result = await openPicker(tester, SystemAudioSupport.none);
    expect(find.text('Bilgisayar sesini paylaş'), findsNothing);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('double-clicking a source shares it right away', (tester) async {
    final result = await openPicker(tester, SystemAudioSupport.none);
    await tester.tap(find.text('Ekran 2'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Ekran 2'));
    await tester.pumpAndSettle();
    expect((await result)?.sourceId, 'screen-b');
  });
}
