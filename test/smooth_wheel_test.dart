import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/app/smooth_wheel.dart';

PointerScrollEvent notch(
  double dy, {
  PointerDeviceKind kind = PointerDeviceKind.mouse,
}) => PointerScrollEvent(
  kind: kind,
  position: const Offset(10, 10),
  scrollDelta: Offset(0, dy),
);

/// Drives a [WheelGlide] frame by frame at 60 frames a second.
class GlideHarness {
  GlideHarness() {
    glide = WheelGlide(emit: steps.add, requestTick: pending.add);
  }

  late final WheelGlide glide;
  final steps = <PointerScrollEvent>[];
  final pending = <void Function(Duration)>[];
  var time = Duration.zero;

  /// Runs [frames] frames, or until the glide stops.
  void run([int frames = 1000]) {
    for (var i = 0; i < frames && pending.isNotEmpty; i++) {
      time += const Duration(microseconds: 16667);
      final ticks = [...pending];
      pending.clear();
      for (final tick in ticks) {
        tick(time);
      }
    }
  }

  double get moved =>
      steps.fold(0.0, (sum, event) => sum + event.scrollDelta.dy);
}

void main() {
  test('a notch glides the distance it would have jumped, then stops', () {
    final harness = GlideHarness();
    harness.glide.add(notch(100));
    harness.run();
    expect(harness.moved, closeTo(100, 1));
    expect(harness.steps.length, greaterThan(10));
    // Each step is smaller than the one before: it slows down. The last
    // one also takes the bit left over.
    for (var i = 1; i < harness.steps.length - 1; i++) {
      expect(
        harness.steps[i].scrollDelta.dy,
        lessThan(harness.steps[i - 1].scrollDelta.dy),
      );
    }
    expect(harness.glide.isGliding, isFalse);
  });

  test('turning faster carries the page further after the last notch', () {
    double glideAfterLast(int notches) {
      final harness = GlideHarness();
      for (var i = 0; i < notches; i++) {
        harness.glide.add(notch(50));
        harness.run(3);
      }
      final before = harness.moved;
      harness.run();
      return harness.moved - before;
    }

    expect(glideAfterLast(6), greaterThan(glideAfterLast(1) * 2));
  });

  test('turning back stops the glide the other way', () {
    final harness = GlideHarness();
    harness.glide.add(notch(100));
    harness.run(3);
    harness.glide.add(notch(-100));
    harness.run(1);
    expect(harness.steps.last.scrollDelta.dy, isNegative);
  });

  test('a stopped glide does not drive the next one twice', () {
    final harness = GlideHarness();
    harness.glide.add(notch(100));
    harness.glide.stop();
    harness.glide.add(notch(100));
    harness.run();
    expect(harness.moved, closeTo(100, 1));
  });

  test('touchpad steps and other devices are left alone', () {
    expect(WheelGlide.takes(notch(4)), isFalse);
    expect(
      WheelGlide.takes(notch(100, kind: PointerDeviceKind.trackpad)),
      isFalse,
    );
    expect(WheelGlide.takes(notch(53)), isTrue);
  });
}
