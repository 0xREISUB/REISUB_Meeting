import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/app/window_controls.dart';
import 'package:window_manager/window_manager.dart';

/// Whether the user is looking at the app: on a phone, it is open on
/// screen; on a computer, its window is also shown and has the focus. New
/// messages show inside the app while true, and as system notifications
/// otherwise.
final appInFrontProvider = NotifierProvider<AppInFront, bool>(AppInFront.new);

class AppInFront extends Notifier<bool> with WindowListener {
  bool _open = true;
  bool _focused = true;

  /// Whether to follow the window too: desktop apps, not tests.
  static bool get _watchWindow =>
      DesktopWindowControls.supported &&
      !Platform.environment.containsKey('FLUTTER_TEST');

  @override
  bool build() {
    final lifecycle = AppLifecycleListener(
      onStateChange: (value) {
        // Inactive is a passing moment, as when a dialog of the system
        // shows; the app is still in front.
        _open =
            value == AppLifecycleState.resumed ||
            value == AppLifecycleState.inactive;
        _update();
      },
    );
    ref.onDispose(lifecycle.dispose);
    if (_watchWindow) {
      windowManager.addListener(this);
      ref.onDispose(() => windowManager.removeListener(this));
    }
    return true;
  }

  void _update() {
    final inFront = _open && _focused;
    if (state != inFront) state = inFront;
  }

  /// The window went out of sight, closed to the background.
  void hidden() {
    _focused = false;
    _update();
  }

  @visibleForTesting
  void set({required bool inFront}) {
    _open = inFront;
    _focused = inFront;
    _update();
  }

  @override
  void onWindowFocus() {
    _focused = true;
    _update();
  }

  @override
  void onWindowBlur() {
    _focused = false;
    _update();
  }

  @override
  void onWindowMinimize() {
    _focused = false;
    _update();
  }
}
