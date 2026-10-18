import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/l10n/app_localizations_en.dart';
import 'package:v_meeting/l10n/app_localizations_tr.dart';
import 'package:v_meeting/l10n/localized_error.dart';
import 'package:v_meeting/main.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/meeting/meeting_media.dart';
import 'package:v_meeting/meeting/meeting_sharing.dart';
import 'package:v_meeting/meeting/members_screen.dart';
import 'package:v_meeting/meeting/widgets/meeting_participant.dart';
import 'package:v_meeting/settings/device_test_screen.dart';
import 'package:v_meeting/settings/language_screen.dart';

Widget localized(Widget child, String language) => MaterialApp(
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('English is the default even when the system locale is Turkish', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.binding.platformDispatcher.localesTestValue = [const Locale('tr')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const ProviderScope(child: VMeetingApp()));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
      const Locale('en'),
    );
    expect(find.text('Server Settings'), findsOneWidget);
    expect(find.text('Save Server Settings'), findsOneWidget);
    expect(find.text('Sunucu Ayarları'), findsNothing);
  });

  testWidgets('language selection switches the visible interface both ways', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) => localized(
            const LanguageScreen(),
            ref.watch(localeProvider).languageCode,
          ),
        ),
      ),
    );
    expect(find.text('Language'), findsOneWidget);
    await tester.tap(find.text('Türkçe'));
    await tester.pumpAndSettle();
    expect(find.text('Dil'), findsOneWidget);
    expect(find.text('İngilizce'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Turkish'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['en', 'tr']) {
    testWidgets('meeting device controls use $language translations', (
      tester,
    ) async {
      final l10n = language == 'en'
          ? AppLocalizationsEn()
          : AppLocalizationsTr();
      await tester.pumpWidget(
        localized(
          Scaffold(body: MeetingSettingsDialog(onDeviceTest: (_) async {})),
          language,
        ),
      );
      expect(find.text(l10n.meetingSettings), findsOneWidget);
      expect(find.text(l10n.microphoneSelectionTest), findsOneWidget);
      expect(find.text(l10n.cameraSelectionTest), findsOneWidget);
    });
  }

  testWidgets(
    'device test errors change language while the panel remains open',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      const channel = MethodChannel('FlutterWebRTC.Method');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getSources') return {'sources': []};
            if (call.method == 'getUserMedia') {
              throw PlatformException(
                code: 'NotAllowedError',
                message: 'Permission denied',
              );
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final language = ValueNotifier('en');
      addTearDown(language.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder<String>(
          valueListenable: language,
          builder: (context, value, _) =>
              localized(const DeviceTestScreen(camera: false), value),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start test'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Check the app’s microphone permission.'),
        findsOneWidget,
      );
      language.value = 'tr';
      await tester.pumpAndSettle();
      expect(find.text('Mikrofon testi ve cihaz seçimi'), findsOneWidget);
      expect(
        find.textContaining('Uygulamanın mikrofon iznini kontrol edin.'),
        findsOneWidget,
      );
      expect(find.text('Testi başlat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'application and capture errors localize without translating server messages',
    () {
      final en = AppLocalizationsEn();
      final tr = AppLocalizationsTr();
      const error = MeetingApiException.localized(AppError.invalidRoomData);
      expect(localizeError(error, en), en.invalidRoomData);
      expect(localizeError(error, tr), tr.invalidRoomData);
      const serverMessage = MeetingApiException('Server-provided message');
      expect(localizeError(serverMessage, en), serverMessage.message);
      expect(localizeError(serverMessage, tr), serverMessage.message);
      expect(
        mediaCaptureError(TrackCreateException(), camera: false, l10n: en),
        contains('microphone'),
      );
      expect(
        mediaCaptureError(TrackCreateException(), camera: true, l10n: tr),
        contains('Kamera'),
      );
      expect(
        localizeError(
          PlatformException(code: 'WindowsAudioRestartRequired'),
          en,
        ),
        en.windowsAudioRestartRequired,
      );
    },
  );

  testWidgets('participant moderation errors follow the selected language', (
    tester,
  ) async {
    final language = ValueNotifier('en');
    addTearDown(language.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<String>(
        valueListenable: language,
        builder: (context, value, _) => localized(
          Scaffold(
            body: MembersScreen(
              isHost: true,
              members: const [
                MemberEntry(
                  id: 'guest',
                  identity: 'guest',
                  name: 'Guest',
                  isLocal: false,
                  isMicEnabled: true,
                ),
              ],
              onMicrophoneChange: (_, _, _) async =>
                  throw const MeetingApiException.localized(
                    AppError.meetingServerUnavailable,
                  ),
            ),
          ),
          value,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('moderate-guest')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppLocalizationsEn().lockMicrophone));
    await tester.pumpAndSettle();
    expect(
      find.text(AppLocalizationsEn().meetingServerUnavailable),
      findsOneWidget,
    );
    language.value = 'tr';
    await tester.pumpAndSettle();
    expect(
      find.text(AppLocalizationsTr().meetingServerUnavailable),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
