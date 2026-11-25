import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Rounds the corners of the app's window on Linux, whose window, with the
/// system's title bar hidden, would otherwise be square. The runner makes
/// the window see-through so the corners show the desktop. A maximised or
/// full-screen window meets the screen's edges and stays square.
///
/// Windows 11 and macOS round their windows themselves.
class RoundedWindow extends StatefulWidget {
  const RoundedWindow({super.key, required this.child});

  final Widget child;

  static const radius = 12.0;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  @override
  State<RoundedWindow> createState() => _RoundedWindowState();
}

class _RoundedWindowState extends State<RoundedWindow> with WindowListener {
  /// Whether the window fills the screen, so its corners stay square.
  bool _filling = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _readState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _readState() async {
    final filling =
        await windowManager.isMaximized() || await windowManager.isFullScreen();
    if (mounted) setState(() => _filling = filling);
  }

  @override
  void onWindowMaximize() => setState(() => _filling = true);

  @override
  void onWindowUnmaximize() => _readState();

  @override
  void onWindowEnterFullScreen() => setState(() => _filling = true);

  @override
  void onWindowLeaveFullScreen() => _readState();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_filling ? 0 : RoundedWindow.radius),
      child: widget.child,
    );
  }
}
