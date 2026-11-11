import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/widgets/meeting_countdown.dart';

void main() {
  test('time left reads as minutes and seconds', () {
    expect(
      MeetingCountdown.format(const Duration(minutes: 9, seconds: 5)),
      '9:05',
    );
    expect(MeetingCountdown.format(Duration.zero), '0:00');
    expect(MeetingCountdown.format(const Duration(seconds: -3)), '0:00');
  });

  testWidgets('the pie shrinks from full at ten minutes to empty', (
    tester,
  ) async {
    Future<double> fractionAt(Duration left) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MeetingCountdown(left: left),
        ),
      );
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(MeetingCountdown),
          matching: find.byType(CustomPaint),
        ),
      );
      return (paint.painter! as CountdownPiePainter).fraction;
    }

    expect(await fractionAt(const Duration(minutes: 10)), 1);
    expect(await fractionAt(const Duration(minutes: 5)), 0.5);
    expect(await fractionAt(Duration.zero), 0);
    expect(await fractionAt(const Duration(minutes: 30)), 1);
  });
}
