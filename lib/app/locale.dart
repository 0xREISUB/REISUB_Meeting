import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

/// The interface language. English is the default regardless of the system
/// language; a user's choice is stored and restored on the next launch.
final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale> {
  static const storageKey = 'app.locale';
  static const fallback = Locale('en');

  @override
  Locale build() => fallback;

  /// Loads the saved language. Called once during app startup.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = _supported(prefs.getString(storageKey));
      if (saved != null) state = saved;
    } catch (_) {
      // Unreadable preferences keep the default language.
    }
  }

  Future<void> select(Locale locale) async {
    final supported = _supported(locale.languageCode);
    if (supported == null) return;
    state = supported;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, supported.languageCode);
    } catch (_) {
      // The language still changes for this session.
    }
  }

  static Locale? _supported(String? languageCode) {
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == languageCode) return locale;
    }
    return null;
  }
}
