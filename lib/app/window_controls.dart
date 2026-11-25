import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// What the app's own title bar can do with the window.
abstract class WindowControls {
  Future<void> minimize();
  Future<bool> isMaximized();
  Future<void> toggleMaximize();
  Future<void> close();

  /// Moves the window with the pointer, from a press on the title bar.
  Future<void> startDragging();
}

/// The window of a desktop app, through window_manager.
class DesktopWindowControls implements WindowControls {
  const DesktopWindowControls();

  /// Whether the app runs in a window of its own, with a title bar to hide.
  static bool get supported =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.linux ||
        TargetPlatform.windows ||
        TargetPlatform.macOS => true,
        _ => false,
      };

  /// Hides the system's title bar; the app draws its own, which shows when
  /// the pointer rests at the top.
  static Future<void> hideSystemTitleBar() async {
    if (!supported) return;
    await windowManager.ensureInitialized();
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
  }

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<bool> isMaximized() => windowManager.isMaximized();

  @override
  Future<void> toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Future<void> close() => windowManager.close();

  @override
  Future<void> startDragging() => windowManager.startDragging();
}
