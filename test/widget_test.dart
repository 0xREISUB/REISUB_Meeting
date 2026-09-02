// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Riverpod importu eklendi
import 'package:v_meeting/main.dart';

void main() {
  testWidgets('app builds and shows home screen', (WidgetTester tester) async {
    // Uygulamayı Riverpod state'lerinin çalışabilmesi için ProviderScope ile sarıyoruz
    await tester.pumpWidget(const ProviderScope(child: VMeetingApp()));

    // İlk açılışın HomeScreen olduğunu doğrulamak için ekrandaki elementleri arıyoruz
    // 1. Uygulama adının ekranda olduğunu doğrula
    expect(find.text('v_meeting'), findsOneWidget);

    // 2. Oda Kur butonunun ekranda olduğunu doğrula
    expect(find.text('Yeni Oda Kur'), findsOneWidget);

    // 3. Toplantıya Katıl butonunun ekranda olduğunu doğrula
    expect(find.text('Toplantıya Katıl'), findsOneWidget);
  });
}
