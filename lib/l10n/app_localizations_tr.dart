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

  @override
  String get about => 'Hakkında';

  @override
  String get developer => 'Geliştirici';

  @override
  String get technologies => 'Kullanılan Teknolojiler';

  @override
  String get licenses => 'Lisanslar';

  @override
  String get contact => 'İletişim';

  @override
  String get madeWithFlutter => 'Flutter ile ❤️ kullanılarak geliştirildi.';

  @override
  String get language => 'Dil';

  @override
  String get profile => 'Profil';

  @override
  String get settings => 'Ayarlar';

  @override
  String get logout => 'Çıkış Yap';

  @override
  String get general => 'Genel';

  @override
  String get meeting => 'Toplantılar';

  @override
  String get application => 'Uygulama';

  @override
  String get deviceTest => 'Cihaz Testi';

  @override
  String get darkTheme => 'Koyu Tema';

  @override
  String get notifications => 'Bildirimler';

  @override
  String get comingSoon => 'Yakında';

  @override
  String get startWithMic => 'Mikrofon açık başlat';

  @override
  String get startWithCamera => 'Kamera açık başlat';

  @override
  String get mirrorCamera => 'Kamerayı aynala';

  @override
  String get noiseSuppression => 'Gürültü engelleme';

  @override
  String get highQualityVideo => 'HD Video';

  @override
  String get testMicrophone => 'Mikrofonu Test Et';

  @override
  String get testCamera => 'Kamerayı Test Et';

  @override
  String get testSpeaker => 'Hoparlörü Test Et';

  @override
  String get serverSettings => 'Sunucu Ayarları';

  @override
  String get serverAddress => 'Sunucu Adresi / IP';

  @override
  String get serverPort => 'Sunucu Portu';

  @override
  String get saveServerSettings => 'Sunucu Ayarlarını Kaydet';

  @override
  String get serverSettingsHint => 'Örnek: 192.168.1.10 : 3000';

  @override
  String get version => 'Sürüm';

  @override
  String get checkForUpdates => 'Güncellemeleri Kontrol Et';

  @override
  String get chatTitle => 'Sohbet';

  @override
  String get chatMessage1 => 'Selam, sesim geliyor mu?';

  @override
  String get chatMessage2 => 'Evet, net geliyor. Görüntü de gayet iyi.';

  @override
  String get messageHint => 'Mesaj yaz...';

  @override
  String get mainVideoLabel => 'Ana Video Akışı';

  @override
  String get speakerLabel => 'Konuşmacı';

  @override
  String get membersTitle => 'Üyeler';

  @override
  String membersHeader(Object count, Object current, Object total) {
    return '$count kişi katılıyor · Sayfa $current/$total';
  }

  @override
  String memberCountLabel(Object count) {
    return '$count üye';
  }

  @override
  String screenCountLabel(Object count) {
    return '$count ekran';
  }

  @override
  String userName(Object number) {
    return 'Kullanıcı $number';
  }

  @override
  String get liveBadge => 'CANLI';

  @override
  String get welcome => 'Hoş Geldiniz';

  @override
  String get nickname => 'Kullanıcı Adı (Nick)';

  @override
  String get password => 'Şifre';

  @override
  String get login => 'Giriş Yap';

  @override
  String get noAccountRegister => 'Hesabın yok mu? Kayıt Ol';

  @override
  String get createAccount => 'Yeni Hesap Oluştur';

  @override
  String get confirmPassword => 'Şifreyi Tekrar Girin';

  @override
  String get register => 'Kayıt Ol';

  @override
  String get passwordsNotMatch => 'Şifreler eşleşmiyor!';

  @override
  String get registerSuccess => 'Kayıt başarılı! Giriş yapabilirsiniz.';

  @override
  String get connectionError => 'Bağlantı hatası!';
}
