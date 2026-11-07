import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:v_meeting/meeting/meeting_platform.dart';

/// Shows meetings on phones in landscape fullscreen and restores the normal
/// system UI afterwards.
class MeetingDisplayMode {
  MeetingDisplayMode(this._platform);

  final MeetingPlatform _platform;
  bool _active = false;
  Timer? _systemUiTimer;

  static bool isNativePhone(BuildContext context) =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) &&
      MediaQuery.sizeOf(context).shortestSide < 600;

  void enterIfPhone(BuildContext context) {
    if (_active || !isNativePhone(context)) return;
    _active = true;
    unawaited(_enter());
  }

  Future<void> _enter() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (_active) await _platform.setFullscreen(true);
  }

  void onResumed() {
    if (_active) unawaited(_platform.setFullscreen(true));
  }

  /// Android briefly forces system bars visible after closing the keyboard.
  void onMetricsChanged(bool Function() keyboardHidden) {
    if (!_active) return;
    _systemUiTimer?.cancel();
    _systemUiTimer = Timer(const Duration(milliseconds: 1200), () {
      if (_active && keyboardHidden()) {
        unawaited(_platform.setFullscreen(true));
      }
    });
  }

  void exit() {
    _systemUiTimer?.cancel();
    if (!_active) return;
    _active = false;
    unawaited(SystemChrome.setPreferredOrientations([]));
    unawaited(_platform.setFullscreen(false));
  }
}
