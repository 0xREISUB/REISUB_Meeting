// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get joinMeeting => 'Join Meeting';

  @override
  String get yourName => 'Your Name';

  @override
  String get roomId => 'Room ID';

  @override
  String get nameError => 'You must enter a name';

  @override
  String get roomError => 'Incomplete or invalid number';

  @override
  String get emptyErrorMsg =>
      'Please enter your name and complete the 9-digit room number.';

  @override
  String get returnMainMenu => 'Return to Main Menu';

  @override
  String get appSubtitle => 'Open Source Meeting Platform';

  @override
  String get createRoom => 'Create New Room';

  @override
  String get startMeeting => 'Start Meeting';
}
