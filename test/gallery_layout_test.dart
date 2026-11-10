import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/meeting/widgets/meeting_participant.dart';

void main() {
  group('galleryLayout', () {
    // A portrait phone's gallery area.
    const phone = Size(370, 700);

    test('stacks landscape videos in one column on a portrait phone', () {
      final layout = galleryLayout(
        count: 4,
        maxColumns: 2,
        area: phone,
        aspectRatio: 16 / 9,
      );
      expect(layout.columns, 1);
      expect(layout.tileSize.aspectRatio, closeTo(16 / 9, 0.001));
      // Four rows and three gaps fit the height.
      expect(layout.tileSize.height * 4 + 30, lessThanOrEqualTo(700.001));
    });

    test('puts portrait videos side by side', () {
      final layout = galleryLayout(
        count: 4,
        maxColumns: 2,
        area: phone,
        aspectRatio: 9 / 16,
      );
      expect(layout.columns, 2);
      expect(layout.tileSize.aspectRatio, closeTo(9 / 16, 0.001));
      expect(layout.tileSize.width * 2 + 10, lessThanOrEqualTo(370.001));
      expect(layout.tileSize.height * 2 + 10, lessThanOrEqualTo(700.001));
    });

    test('never uses more columns than allowed or than members', () {
      final wide = galleryLayout(
        count: 2,
        maxColumns: 4,
        area: const Size(1600, 400),
        aspectRatio: 16 / 9,
      );
      expect(wide.columns, 2);
    });
  });
}
