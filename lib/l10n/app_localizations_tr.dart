// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get joinMeeting => 'Toplantıya Katıl';

  @override
  String get yourName => 'Adın';

  @override
  String get roomId => 'Oda ID';

  @override
  String get nameError => 'Bir ad girmelisin';

  @override
  String get roomError => 'Eksik veya hatalı numara';

  @override
  String get emptyErrorMsg =>
      'Lütfen adınızı girin ve 9 haneli oda numarasını tamamlayın.';

  @override
  String get returnMainMenu => 'Ana Menüye Dön';

  @override
  String get appSubtitle => 'Açık Kaynak Toplantı Platformu';

  @override
  String get createRoom => 'Yeni Oda Kur';

  @override
  String get startMeeting => 'Toplantıyı Başlat';
}
