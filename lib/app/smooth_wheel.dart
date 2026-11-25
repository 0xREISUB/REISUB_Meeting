import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Turns a mouse wheel's jumps into a glide: each notch pushes the page,
/// and it slows to a stop on its own, the longer the faster it was turned.
/// It covers the same distance the notches would have.
class WheelGlide {
  WheelGlide({required this.emit, required this.requestTick});

  /// Sends a smaller scroll on to the page.
  final void Function(PointerScrollEvent event) emit;

  /// Calls back on the next frame with its time stamp.
  final void Function(void Function(Duration time) tick) requestTick;

  /// How quickly the glide dies away: after this long, about a third of
  /// its speed is left.
  static const fade = Duration(milliseconds: 180);

  /// A wheel moves at least this far a notch; smaller steps come from
  /// touchpads, which already move smoothly.
  static const minNotch = 15.0;

  /// Slower than this, in pixels a second, the glide stops.
  static const _restSpeed = 6.0;

  static double get _tau =>
      fade.inMicroseconds / Duration.microsecondsPerSecond;

  Offset _velocity = Offset.zero;
  PointerScrollEvent? _last;
  Duration? _lastTick;
  bool _ticking = false;

  /// Counts glides, so a frame asked for by one that was stopped does not
  /// drive the next.
  int _glideId = 0;

  bool get isGliding => _ticking;

  /// Whether [event] is a mouse wheel's notch, which this smooths.
  static bool takes(PointerScrollEvent event) =>
      event.kind == PointerDeviceKind.mouse &&
      event.scrollDelta.distance >= minNotch;

  void add(PointerScrollEvent event) {
    final delta = event.scrollDelta;
    // Turning back stops the glide first.
    _velocity = Offset(
      _sameWay(_velocity.dx, delta.dx) ? _velocity.dx : 0,
      _sameWay(_velocity.dy, delta.dy) ? _velocity.dy : 0,
    );
    // The speed that, dying away, covers [delta] in all.
    _velocity += delta / _tau;
    _last = event;
    if (!_ticking) {
      _ticking = true;
      _lastTick = null;
      final id = ++_glideId;
      requestTick((time) => _tick(time, id));
    }
  }

  /// Ends the glide at once, as when the page is grabbed.
  void stop() {
    _velocity = Offset.zero;
    _ticking = false;
  }

  static bool _sameWay(double a, double b) =>
      a == 0 || b == 0 || a.sign == b.sign;

  void _tick(Duration time, int id) {
    if (!_ticking || id != _glideId) return;
    final last = _lastTick;
    _lastTick = time;
    final seconds = last == null
        ? 1 / 60
        : ((time - last).inMicroseconds / Duration.microsecondsPerSecond).clamp(
            0.0,
            0.05,
          );
    final decay = math.exp(-seconds / _tau);
    // Exactly how far the speed carries the page while it dies down.
    var step = _velocity * _tau * (1 - decay);
    _velocity *= decay;
    final done = _velocity.distance < _restSpeed;
    // The last step takes what the glide had left, so no bit goes missing.
    if (done) step += _velocity * _tau;
    final event = _last!;
    if (step != Offset.zero) {
      emit(
        PointerScrollEvent(
          timeStamp: event.timeStamp,
          kind: event.kind,
          device: event.device,
          position: event.position,
          viewId: event.viewId,
          scrollDelta: step,
        ),
      );
    }
    if (done) {
      stop();
    } else {
      requestTick((time) => _tick(time, id));
    }
  }
}

/// The app's binding, which glides mouse wheel scrolling on computers.
class SmoothWheelBinding extends WidgetsFlutterBinding {
  late final _glide = WheelGlide(
    emit: super.handlePointerEvent,
    requestTick: (tick) {
      scheduleFrameCallback(tick);
      scheduleFrame();
    },
  );

  static bool get _onComputer =>
      kIsWeb ||
      switch (defaultTargetPlatform) {
        TargetPlatform.linux ||
        TargetPlatform.windows ||
        TargetPlatform.macOS => true,
        _ => false,
      };

  @override
  void handlePointerEvent(PointerEvent event) {
    if (_onComputer) {
      if (event is PointerScrollEvent && WheelGlide.takes(event)) {
        _glide.add(event);
        return;
      }
      // Grabbing the page or scrolling another way stops the glide.
      if (_glide.isGliding &&
          (event is PointerDownEvent || event is PointerScrollEvent)) {
        _glide.stop();
      }
    }
    super.handlePointerEvent(event);
  }
}
