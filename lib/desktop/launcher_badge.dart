import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/social/social_api.dart';

/// A count on the app's icon in the dock.
abstract class LauncherBadge {
  Future<void> show(int count);
}

/// Whether the desktop has a dock count here: Linux, not in tests.
bool get launcherBadgeSupported =>
    !kIsWeb &&
    Platform.isLinux &&
    !Platform.environment.containsKey('FLUTTER_TEST');

final launcherBadgeProvider = Provider<LauncherBadge>((ref) {
  if (!launcherBadgeSupported) return const NoLauncherBadge();
  final badge = UnityLauncherBadge();
  ref.onDispose(badge.close);
  return badge;
});

class NoLauncherBadge implements LauncherBadge {
  const NoLauncherBadge();

  @override
  Future<void> show(int count) async {}
}

/// The Unity launcher API, which Ubuntu's dock, Dash to Dock, Dash to Panel
/// and Zorin's taskbar draw as a red count on the icon.
class UnityLauncherBadge implements LauncherBadge {
  static const _appUri = 'application://xyz.reisub.meeting.desktop';

  DBusClient? _client;
  int? _shown;

  @override
  Future<void> show(int count) async {
    if (_shown == count) return;
    _shown = count;
    try {
      final client = _client ??= DBusClient.session();
      await client.emitSignal(
        path: DBusObjectPath('/xyz/reisub/meeting/LauncherEntry'),
        interface: 'com.canonical.Unity.LauncherEntry',
        name: 'Update',
        values: [
          const DBusString(_appUri),
          DBusDict.stringVariant({
            'count': DBusInt64(count),
            'count-visible': DBusBoolean(count > 0),
          }),
        ],
      );
    } catch (_) {
      // No session bus, or no dock that listens: nothing to show it on.
      _shown = null;
    }
  }

  Future<void> close() async {
    await _client?.close();
    _client = null;
  }
}

/// Keeps the dock count equal to what waits in the social tab: unread
/// messages and friend requests. Watched while the app runs.
final launcherCountProvider = Provider<void>((ref) {
  if (!launcherBadgeSupported) return;
  final badge = ref.watch(launcherBadgeProvider);
  ref.listen(socialOverviewProvider, (_, next) {
    // Signed out, nothing waits.
    if (next.hasValue) badge.show(next.value?.waiting ?? 0);
  }, fireImmediately: true);
  ref.onDispose(() => badge.show(0));
});
