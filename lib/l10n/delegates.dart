import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart'
    show GlobalMaterialLocalizations, LocalizationsDelegate;
import 'package:v_meeting/l10n/app_localizations.dart';

/// The app's translations with Material's, Cupertino's and the widgets'.
/// appLocalizationsDelegates, which Flutter's generator still
/// writes, names the Material and Cupertino ones deprecated since Flutter
/// 3.47; these are their replacements.
const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];
