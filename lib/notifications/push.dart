import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/app/locale.dart';
import 'package:v_meeting/auth/account.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/notifications/notification_text.dart';
import 'package:v_meeting/notifications/system_notifications.dart';

/// Push notifications from the server, through Firebase Cloud Messaging:
/// they reach the phone while the app is in the background or closed.
abstract class PushService {
  /// The device's push token; null when there is none.
  Future<String?> token();

  /// New tokens, when Firebase changes the device's.
  Stream<String> get tokenChanges;

  /// Asks for permission to show notifications (Android 13+).
  Future<void> requestPermission();
}

/// Whether Firebase started: only on Android, and only in builds with the
/// project's google-services.json.
bool _firebaseReady = false;

/// Starts Firebase before the app runs, on Android. Without the Firebase
/// project's settings in the build it fails quietly, and push is off.
Future<void> startPush() async {
  if (kIsWeb ||
      !Platform.isAndroid ||
      Platform.environment.containsKey('FLUTTER_TEST')) {
    return;
  }
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(showPushInBackground);
    _firebaseReady = true;
  } catch (_) {
    // No google-services.json in this build.
  }
}

final pushServiceProvider = Provider<PushService?>(
  (ref) => _firebaseReady ? FirebasePushService() : null,
);

/// Uses the registration token the server sends to with FCM's HTTP v1
/// "token" target. Firebase now also offers register()/onRegistered, which
/// give an installation id for a newer kind of sending; the server does not
/// send that way, so the token API stays until it does.
class FirebasePushService implements PushService {
  @override
  // ignore: deprecated_member_use
  Future<String?> token() => FirebaseMessaging.instance.getToken();

  @override
  // ignore: deprecated_member_use
  Stream<String> get tokenChanges => FirebaseMessaging.instance.onTokenRefresh;

  @override
  Future<void> requestPermission() async {
    await FirebaseMessaging.instance.requestPermission();
  }
}

/// Keeps this device's push token known to the server while the user is
/// signed in. Signing out ends the session on the server, and its device
/// with it.
final pushRegistrationProvider = Provider<void>((ref) {
  final push = ref.watch(pushServiceProvider);
  final signedIn = ref.watch(signedInProvider).value ?? false;
  if (push == null || !signedIn) return;
  final api = ref.watch(meetingApiProvider);
  Future<void> register(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await api.send(
        'PUT',
        '/me/push-device',
        data: {'token': token, 'platform': 'android'},
      );
    } catch (_) {
      // Tried again with the next start or token change.
    }
  }

  unawaited(() async {
    try {
      await push.requestPermission();
      await register(await push.token());
    } catch (_) {
      // No token now; maybe with the next start.
    }
  }());
  final changes = push.tokenChanges.listen(register);
  ref.onDispose(changes.cancel);
});

/// Shows a push that came while the app was not in front. It runs apart
/// from the app, so it sets up what it needs itself. A notification already
/// shown for the same message, over the app's own connection, stays.
@pragma('vm:entry-point')
Future<void> showPushInBackground(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final l10n = lookupAppLocalizations(await _savedLocale());
  final notice = SystemNotice.forPush(message.data, l10n);
  if (notice == null) return;
  final plugin = FlutterLocalNotificationsPlugin();
  await initializeNotifications(plugin, l10n);
  if (await noticeShown(plugin, notice.id)) return;
  await showNotice(plugin, notice, l10n);
}

Future<Locale> _savedLocale() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(LocaleController.storageKey);
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == code) return locale;
    }
  } catch (_) {
    // The default language.
  }
  return LocaleController.fallback;
}
