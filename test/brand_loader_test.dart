import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/app/app.dart';
import 'package:v_meeting/app/app_startup.dart';
import 'package:v_meeting/widgets/brand_loader.dart';

void main() {
  testWidgets('the app shows its own loading sign while it starts', (
    tester,
  ) async {
    final starting = Completer<StartDestination>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appStartupProvider.overrideWith((ref) => starting.future)],
        child: const MaterialApp(home: StartupScreen()),
      ),
    );
    // It keeps turning; there is nothing to settle.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(BrandLoader), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('REISUB Meeting'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
