import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/notifications/notification_text.dart';
import 'package:v_meeting/social/social_models.dart';

/// Shows notifications with the system's own notification centre, for
/// when the app is not in front.
abstract class SystemNotifier {
  /// Gets ready; [onOpen] is called with the conversation of a tapped
  /// notification. Answers the one the app was started from, if any.
  Future<ChatTarget?> start({
    required AppLocalizations l10n,
    required void Function(ChatTarget target) onOpen,
  });

  Future<void> show(SystemNotice notice);

  /// Takes down what was shown for a conversation, once it is read.
  Future<void> clear(ChatTarget target);
}

/// Whether this platform has system notifications here: Android and Linux,
/// and not in tests.
bool get systemNotificationsSupported =>
    !kIsWeb &&
    (Platform.isAndroid || Platform.isLinux) &&
    !Platform.environment.containsKey('FLUTTER_TEST');

final systemNotifierProvider = Provider<SystemNotifier>(
  (ref) => systemNotificationsSupported
      ? LocalSystemNotifier()
      : const NoSystemNotifier(),
);

/// Where the system shows nothing.
class NoSystemNotifier implements SystemNotifier {
  const NoSystemNotifier();

  @override
  Future<ChatTarget?> start({
    required AppLocalizations l10n,
    required void Function(ChatTarget target) onOpen,
  }) async => null;

  @override
  Future<void> show(SystemNotice notice) async {}

  @override
  Future<void> clear(ChatTarget target) async {}
}

/// The Android notification channel for messages and calls.
const messageChannelId = 'messages';

/// Through flutter_local_notifications: Android's notification shade, and on
/// Linux the desktop's notifications (org.freedesktop.Notifications).
class LocalSystemNotifier implements SystemNotifier {
  LocalSystemNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  AppLocalizations? _l10n;
  final _shown = <String, Set<int>>{};

  @override
  Future<ChatTarget?> start({
    required AppLocalizations l10n,
    required void Function(ChatTarget target) onOpen,
  }) async {
    _l10n = l10n;
    await initializeNotifications(
      _plugin,
      l10n,
      onTap: (payload) {
        final target = SystemNotice.targetOf(payload);
        if (target != null) onOpen(target);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      return SystemNotice.targetOf(launch!.notificationResponse?.payload);
    }
    return null;
  }

  @override
  Future<void> show(SystemNotice notice) async {
    final l10n = _l10n;
    if (l10n == null) return;
    _shown.putIfAbsent(notice.target.id, () => {}).add(notice.id);
    await showNotice(_plugin, notice, l10n);
  }

  @override
  Future<void> clear(ChatTarget target) async {
    final ids = _shown.remove(target.id);
    if (ids == null) return;
    for (final id in ids) {
      try {
        await _plugin.cancel(id: id);
      } catch (_) {
        // Already gone.
      }
    }
  }
}

/// Sets the plugin up; shared with the push handler, which runs apart from
/// the app.
Future<void> initializeNotifications(
  FlutterLocalNotificationsPlugin plugin,
  AppLocalizations l10n, {
  void Function(String? payload)? onTap,
}) async {
  await plugin.initialize(
    settings: InitializationSettings(
      android: const AndroidInitializationSettings('ic_notification'),
      linux: LinuxInitializationSettings(
        defaultActionName: l10n.notificationOpen,
        defaultIcon: AssetsLinuxIcon('assets/branding/logo.png'),
      ),
    ),
    onDidReceiveNotificationResponse: onTap == null
        ? null
        : (response) => onTap(response.payload),
  );
  final android = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await android?.createNotificationChannel(
    AndroidNotificationChannel(
      messageChannelId,
      l10n.notificationChannelMessages,
      importance: Importance.high,
    ),
  );
}

/// Shows [notice]. The same message twice (once over the app's own
/// connection, once as a push) replaces itself rather than sounding again.
Future<void> showNotice(
  FlutterLocalNotificationsPlugin plugin,
  SystemNotice notice,
  AppLocalizations l10n,
) => plugin.show(
  id: notice.id,
  title: notice.title,
  body: notice.body,
  payload: notice.payload,
  notificationDetails: NotificationDetails(
    android: AndroidNotificationDetails(
      messageChannelId,
      l10n.notificationChannelMessages,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      icon: 'ic_notification',
      onlyAlertOnce: true,
      autoCancel: true,
    ),
    // GNOME ties it to the app through the process that sends it, so the
    // dock counts it on the app's icon.
    linux: const LinuxNotificationDetails(
      category: LinuxNotificationCategory.imReceived,
    ),
  ),
);

/// Whether a notification with [id] is up already (Android).
Future<bool> noticeShown(FlutterLocalNotificationsPlugin plugin, int id) async {
  final android = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (android == null) return false;
  try {
    final active = await android.getActiveNotifications();
    return active.any((n) => n.id == id);
  } catch (_) {
    return false;
  }
}
