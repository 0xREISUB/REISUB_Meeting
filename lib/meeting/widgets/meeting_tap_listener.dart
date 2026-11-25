import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Carries two-finger pinches detected above the page view to the main
/// video, which owns the zoom.
/// Reports a single-finger tap anywhere on [child], even where a widget
/// inside handles the tap itself. On phones the video renderer of the local
/// camera claims taps for focus, which kept a GestureDetector here from ever
/// seeing taps on the video. Drags and pinches are not taps.
class MeetingTapListener extends StatefulWidget {
  const MeetingTapListener({
    super.key,
    required this.onTap,
    required this.child,
  });

  final VoidCallback? onTap;
  final Widget child;

  /// Keeps a pointer that went down on [context]'s widget, for example a
  /// panel laid over the video, from counting as a tap on the video. Call
  /// it from that widget's own onPointerDown, which runs first.
  static void ignorePointer(BuildContext context, int pointer) => context
      .findAncestorStateOfType<_MeetingTapListenerState>()
      ?._ignored
      .add(pointer);

  @override
  State<MeetingTapListener> createState() => _MeetingTapListenerState();
}

class _MeetingTapListenerState extends State<MeetingTapListener> {
  final _down = <int, (Offset, Duration)>{};
  final _ignored = <int>{};
  bool _multiTouch = false;

  void _onDown(PointerDownEvent event) {
    if (_ignored.contains(event.pointer)) return;
    _down[event.pointer] = (event.position, event.timeStamp);
    if (_down.length > 1) _multiTouch = true;
  }

  void _onUp(PointerUpEvent event) {
    _ignored.remove(event.pointer);
    final start = _down.remove(event.pointer);
    final multiTouch = _multiTouch;
    if (_down.isEmpty) _multiTouch = false;
    if (start == null || multiTouch) return;
    final (position, time) = start;
    final moved = (event.position - position).distance;
    final held = event.timeStamp - time;
    if (moved <= kTouchSlop && held <= const Duration(milliseconds: 500)) {
      widget.onTap?.call();
    }
  }

  void _onCancel(PointerCancelEvent event) {
    _ignored.remove(event.pointer);
    _down.remove(event.pointer);
    if (_down.isEmpty) _multiTouch = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onDown,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: widget.child,
    );
  }
}
