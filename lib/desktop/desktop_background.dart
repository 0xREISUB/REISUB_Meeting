import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:v_meeting/app/locale.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/meeting_screen.dart';
import 'package:v_meeting/notifications/app_focus.dart';
import 'package:window_manager/window_manager.dart';

/// Whether the app can live on in the background when its window closes:
/// on Linux, whose runner keeps one copy of the app and brings its window
/// back when it is started again; not in tests.
bool get desktopBackgroundSupported =>
    !kIsWeb &&
    Platform.isLinux &&
    !Platform.environment.containsKey('FLUTTER_TEST');

/// The command line flag the app starts with at login: no window until
/// it is asked for.
const startHiddenFlag = '--hidden';

/// What the user chose for the app on a computer.
class DesktopSettings {
  const DesktopSettings({
    this.runInBackground = true,
    this.startAtLogin = false,
  });

  /// Closing the window keeps the app running, for notifications.
  final bool runInBackground;

  /// The app starts, hidden, when the user signs in to the computer.
  final bool startAtLogin;

  DesktopSettings copyWith({bool? runInBackground, bool? startAtLogin}) =>
      DesktopSettings(
        runInBackground: runInBackground ?? this.runInBackground,
        startAtLogin: startAtLogin ?? this.startAtLogin,
      );
}

final desktopSettingsProvider =
    AsyncNotifierProvider<DesktopSettingsController, DesktopSettings>(
      DesktopSettingsController.new,
    );

class DesktopSettingsController extends AsyncNotifier<DesktopSettings> {
  static const _backgroundKey = 'desktop.run_in_background';

  @override
  Future<DesktopSettings> build() async {
    var runInBackground = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      runInBackground = prefs.getBool(_backgroundKey) ?? true;
    } catch (_) {
      // The defaults.
    }
    return DesktopSettings(
      runInBackground: runInBackground,
      startAtLogin: await Autostart.enabled(),
    );
  }

  Future<void> setRunInBackground(bool value) async {
    state = AsyncData(
      (state.value ?? const DesktopSettings()).copyWith(runInBackground: value),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_backgroundKey, value);
    } catch (_) {
      // Kept for this run.
    }
  }

  Future<void> setStartAtLogin(bool value) async {
    try {
      await Autostart.set(value);
    } catch (_) {
      return;
    }
    state = AsyncData(
      (state.value ?? const DesktopSettings()).copyWith(startAtLogin: value),
    );
  }
}

/// The XDG autostart entry that starts the app at login, hidden.
class Autostart {
  static File get _file {
    final config =
        Platform.environment['XDG_CONFIG_HOME'] ??
        '${Platform.environment['HOME']}/.config';
    return File('$config/autostart/xyz.reisub.meeting.desktop');
  }

  static Future<bool> enabled() async {
    if (!desktopBackgroundSupported) return false;
    try {
      return await _file.exists();
    } catch (_) {
      return false;
    }
  }

  static Future<void> set(bool on) async {
    final file = _file;
    if (!on) {
      if (await file.exists()) await file.delete();
      return;
    }
    // The installed command when there is one, else this very program.
    const installed = '/usr/bin/reisub-meeting';
    final command = await File(installed).exists()
        ? installed
        : Platform.resolvedExecutable;
    await file.parent.create(recursive: true);
    await file.writeAsString('''[Desktop Entry]
Type=Application
Name=REISUB Meeting
Exec="$command" $startHiddenFlag
Icon=xyz.reisub.meeting
Terminal=false
X-GNOME-Autostart-enabled=true
''');
  }
}

/// Runs the app in the background on a computer: closing the window hides
/// it, a tray icon brings it back or quits, and it can start at login.
/// Watched while the app runs.
final desktopBackgroundProvider = Provider<DesktopBackground?>((ref) {
  if (!desktopBackgroundSupported) return null;
  final background = DesktopBackground(ref);
  unawaited(background.start());
  ref.onDispose(background.dispose);
  return background;
});

class DesktopBackground with WindowListener, TrayListener {
  DesktopBackground(this._ref);

  final Ref _ref;
  bool _quitting = false;

  Future<void> start() async {
    windowManager.addListener(this);
    trayManager.addListener(this);
    await windowManager.setPreventClose(true);
    try {
      await trayManager.setIcon('assets/branding/logo.png');
      await _setMenu(lookupAppLocalizations(_ref.read(localeProvider)));
      _ref.listen(localeProvider, (_, locale) {
        unawaited(_setMenu(lookupAppLocalizations(locale)));
      });
    } catch (_) {
      // No tray on this desktop; the dock and a new start still bring the
      // window back.
    }
  }

  Future<void> _setMenu(AppLocalizations l10n) => trayManager.setContextMenu(
    Menu(
      items: [
        MenuItem(key: 'open', label: l10n.trayOpen),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: l10n.trayQuit),
      ],
    ),
  );

  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
  }

  /// Brings the window back to the front.
  static Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onWindowClose() => unawaited(_close());

  Future<void> _close() async {
    if (_quitting) return;
    final settings =
        _ref.read(desktopSettingsProvider).value ?? const DesktopSettings();
    if (!settings.runInBackground) {
      await quit();
      return;
    }
    // No camera or microphone left on behind a hidden window.
    MeetingScreen.leaveAll();
    _ref.read(appInFrontProvider.notifier).hidden();
    await windowManager.hide();
  }

  /// Ends the app for good.
  Future<void> quit() async {
    _quitting = true;
    MeetingScreen.leaveAll();
    try {
      await trayManager.destroy();
    } catch (_) {}
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onTrayIconMouseDown() => unawaited(showWindow());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
        unawaited(showWindow());
      case 'quit':
        unawaited(quit());
    }
  }
}
