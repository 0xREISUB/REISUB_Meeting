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
  String get roomCodeCopied => 'Oda kodu kopyalandı';

  @override
  String get invite => 'Davet et';

  @override
  String get inviteLinkCopied => 'Davet bağlantısı kopyalandı';

  @override
  String get inviteServerTitle => 'Sunucu değiştirilsin mi?';

  @override
  String inviteServerBody(String server) {
    return 'Bu davet $server sunucusundaki bir toplantı için. Geçerseniz şu anki sunucudaki oturumunuz kapanır.';
  }

  @override
  String get switchServer => 'Geç';

  @override
  String get inviteFinishMeetingFirst =>
      'Daveti açmak için önce bu toplantıdan ayrılın.';

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
  String get profileMenu => 'Profil menüsü';

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
  String get serverSettingsHint => 'Örnek: meeting.example.com';

  @override
  String get webServerFixed => 'Web sürümü, yayınlandığı sunucuyu kullanır.';

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
  String moreParticipants(int count) {
    return '+$count kişi daha';
  }

  @override
  String get collapseParticipants => 'Tek kişi göster';

  @override
  String get expandParticipants => 'Daha fazla kişi göster';

  @override
  String get showPictureInPicture => 'Küçük videoyu göster';

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
  String get credentialsRequired => 'Kullanıcı adınızı ve şifrenizi girin.';

  @override
  String get accountSessionExpired =>
      'Oturumunuzun süresi doldu. Misafir olarak devam edebilir ya da yeniden giriş yapabilirsiniz.';

  @override
  String get guestUnavailable =>
      'Bu sunucu hesap gerektiriyor. Lütfen giriş yapın.';

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

  @override
  String get connecting => 'Bağlanıyor...';

  @override
  String get moreOptions => 'Daha fazla';

  @override
  String get close => 'Kapat';

  @override
  String get cancel => 'Vazgeç';

  @override
  String get send => 'Gönder';

  @override
  String get notNow => 'Şimdi değil';

  @override
  String get you => 'Sen';

  @override
  String secondsRemaining(int seconds) {
    return '$seconds sn';
  }

  @override
  String get meetingSettings => 'Toplantı ayarları';

  @override
  String get microphoneSelectionTest => 'Mikrofon seçimi ve testi';

  @override
  String get cameraSelectionTest => 'Kamera seçimi ve testi';

  @override
  String get microphoneSelectionHint => 'Mikrofon seçimi ve canlı ses seviyesi';

  @override
  String get cameraSelectionHint => 'Kamera seçimi ve canlı önizleme';

  @override
  String get audioInputHint => 'Giriş aygıtı ve canlı ses seviyesi';

  @override
  String get cameraInputHint => 'Kamera aygıtı ve canlı önizleme';

  @override
  String get allowScreenSharing => 'Başkalarının ekran paylaşmasına izin ver';

  @override
  String get oneScreenShareHint =>
      'Aynı anda yalnızca bir kişi ekran paylaşabilir.';

  @override
  String get microphoneManagement => 'Mikrofon yönetimi';

  @override
  String get unlockMicrophone => 'Mikrofon kilidini kaldır';

  @override
  String get lockMicrophone => 'Mikrofonu kapat ve kilitle';

  @override
  String get unlockAndRequestMicrophone => 'Kilidi kaldır ve açmasını iste';

  @override
  String get requestMicrophone => 'Mikrofonu açmasını iste';

  @override
  String get unmuteRequestTitle => 'Mikrofon açma isteği';

  @override
  String get unmuteRequestBody =>
      'Yönetici mikrofonunuzu açmanızı istiyor. Açmak istiyor musunuz?';

  @override
  String get unmuteMicrophone => 'Mikrofonu aç';

  @override
  String get microphoneLocked => 'Mikrofonunuz yönetici tarafından kilitlendi.';

  @override
  String get leaveMeeting => 'Toplantıdan çık';

  @override
  String get hostLeaveBody =>
      'Toplantıyı bitirirseniz tüm katılımcılar çıkarılır ve oda kapanır. Yalnızca ayrılırsanız toplantı devam eder.';

  @override
  String get leave => 'Ayrıl';

  @override
  String get endMeeting => 'Toplantıyı bitir';

  @override
  String get meetingNotificationChannel => 'Toplantı';

  @override
  String get meetingNotificationTitle => 'Toplantı sürüyor';

  @override
  String get meetingNotificationBody => 'Toplantıya dönmek için dokunun.';

  @override
  String get roleOwner => 'Tam yönetici';

  @override
  String get roleModerator => 'Yönetici';

  @override
  String get participantActions => 'Katılımcı işlemleri';

  @override
  String get makeOwner => 'Tam yönetici yap';

  @override
  String get makeModerator => 'Yönetici yap';

  @override
  String get removeAdminRole => 'Yöneticiliği kaldır';

  @override
  String get transferOwnership => 'Tam yöneticiliği devret';

  @override
  String get transferOwnershipTitle => 'Tam yöneticilik devredilsin mi?';

  @override
  String transferOwnershipBody(String name) {
    return '$name tam yönetici olur, siz yönetici olarak kalırsınız.';
  }

  @override
  String get transfer => 'Devret';

  @override
  String get lastOwnerLeaveHint =>
      'Tek tam yönetici sizsiniz. Ayrılırsanız tam yöneticilik bir yöneticiye, yoksa rastgele bir katılımcıya geçer.';

  @override
  String get youAreOwnerNow => 'Artık tam yöneticisiniz.';

  @override
  String get youAreModeratorNow => 'Artık yöneticisiniz.';

  @override
  String get lastOwnerError => 'En az bir tam yönetici kalmalı.';

  @override
  String get targetProtectedError =>
      'Bu katılımcı üzerinde bu işlemi yapamazsınız.';

  @override
  String get ownerRequiredError =>
      'Bu işlemi yalnızca tam yöneticiler yapabilir.';

  @override
  String get moderatorRequiredError =>
      'Bu işlemi yalnızca yöneticiler yapabilir.';

  @override
  String get meetingEndedByYou => 'Toplantıyı bitirdiniz.';

  @override
  String get selectScreenToShare => 'Paylaşılacak ekranı seç';

  @override
  String get screen => 'Ekran';

  @override
  String get window => 'Pencere';

  @override
  String get share => 'Paylaş';

  @override
  String get shareSystemAudio => 'Bilgisayar sesini paylaş';

  @override
  String get shareSystemAudioScreenHint =>
      'Bu toplantı dışındaki tüm bilgisayar sesleri paylaşılır.';

  @override
  String get shareSystemAudioWindowHint =>
      'Yalnızca seçilen pencerenin sesi paylaşılır.';

  @override
  String get shareSystemAudioEchoHint =>
      'Toplantının sesi de yakalanır. Diğerleri yankı duymasın diye kulaklık kullanın.';

  @override
  String get noShareSources =>
      'Paylaşılabilecek ekran veya pencere bulunamadı.';

  @override
  String get screenShareInUse => 'Şu anda başka biri ekranını paylaşıyor';

  @override
  String get screenShareStoppedByHost =>
      'Oda sahibi ekran paylaşımını kapattığı için paylaşımınız durduruldu.';

  @override
  String get screenShareLabel => 'Ekran paylaşımı';

  @override
  String get stopScreenSharing => 'Paylaşımı durdur';

  @override
  String get shareScreen => 'Ekranı paylaş';

  @override
  String get screenSharingDisabled =>
      'Ekran paylaşımı oda sahibi tarafından kapatıldı';

  @override
  String get exitFullscreen => 'Tam ekrandan çık';

  @override
  String get fullscreenMainVideo => 'Ana yayını tam ekran göster';

  @override
  String get previousPage => 'Önceki sayfa';

  @override
  String get nextPage => 'Sonraki sayfa';

  @override
  String get resetZoom => 'Yakınlaştırmayı sıfırla';

  @override
  String get rejoiningMeeting => 'Toplantıya tekrar katılınıyor…';

  @override
  String get rejoinMeeting => 'Tekrar katıl';

  @override
  String get noMessagesYet => 'Henüz mesaj yok';

  @override
  String get microphonePrivacySettings => 'Mikrofon gizlilik ayarları';

  @override
  String get cameraPrivacySettings => 'Kamera gizlilik ayarları';

  @override
  String get windowsPrivacyUnavailable =>
      'Windows ayarları açılamadı. Ayarlar > Gizlilik ve güvenlik bölümünü açın.';

  @override
  String get missingMeetingDetails => 'Toplantı bilgileri bulunamadı';

  @override
  String get mediaRequiresHttps =>
      'Telefon tarayıcısında kamera ve mikrofon için HTTPS gerekir. Uygulamayı güvenli bir HTTPS adresinden açın.';

  @override
  String get joiningMeeting => 'Toplantıya bağlanılıyor…';

  @override
  String get preparingMeetingMedia => 'Ses ve görüntü hazırlanıyor…';

  @override
  String get meetingMediaTimeout =>
      'Ses veya görüntü beklenenden uzun sürüyor. Bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String get reconnectingMeeting => 'Bağlantı kesildi. Yeniden bağlanılıyor…';

  @override
  String get duplicateSession =>
      'Bu oturum başka bir cihazda açıldığı için bağlantı kesildi.';

  @override
  String get meetingClosedByServer => 'Toplantı sunucu tarafından kapatıldı.';

  @override
  String get removedFromMeeting =>
      'Sunucu tarafından toplantıdan çıkarıldınız.';

  @override
  String get reconnectFailed =>
      'Bağlantı geri kurulamadı. Tekrar katılmayı deneyin.';

  @override
  String get meetingSessionLost =>
      'Sunucu oturumu kaybetti. Toplantıya tekrar katılın.';

  @override
  String get meetingDisconnected =>
      'Toplantı bağlantısı kesildi. Şu anda odaya bağlı değilsiniz.';

  @override
  String get videoLoading => 'Görüntü yükleniyor…';

  @override
  String get videoLoadingSlow =>
      'Görüntü hâlâ bekleniyor. Bağlantı yavaş olabilir.';

  @override
  String get poorMediaConnection =>
      'Medya bağlantısı zayıf. Görüntü ve ses kesilebilir.';

  @override
  String subscriptionFailed(String reason) {
    return 'Katılımcının medya akışı alınamadı ($reason).';
  }

  @override
  String meetingJoinFailed(String error) {
    return 'Toplantıya bağlanılamadı: $error';
  }

  @override
  String microphoneDisableFailed(String error) {
    return 'Mikrofon kapatılamadı: $error';
  }

  @override
  String get screenShareStartFailed => 'Ekran paylaşımı başlatılamadı.';

  @override
  String get invalidMessageData => 'Sunucudan geçersiz mesaj verisi alındı';

  @override
  String get invalidServerResponse => 'Sunucudan geçersiz yanıt alındı';

  @override
  String get invalidRoomData => 'Sunucudan geçersiz oda bilgisi alındı';

  @override
  String get missingServerSession => 'Oturum veya sunucu ayarı bulunamadı';

  @override
  String get meetingServerUnavailable => 'Toplantı sunucusuna bağlanılamadı';

  @override
  String get serverSettingsReadFailed => 'Kayıtlı sunucu ayarları okunamadı.';

  @override
  String get serverSettingsSaveFailed =>
      'Sunucu ayarları kaydedilemedi. Tekrar deneyin.';

  @override
  String get invalidServerAddressPort =>
      'Lütfen geçerli bir sunucu IP/host ve port girin.';

  @override
  String serverSettingsSaved(String url) {
    return 'Sunucu ayarları kaydedildi: $url';
  }

  @override
  String get cameraName => 'Kamera';

  @override
  String get microphoneName => 'Mikrofon';

  @override
  String get captureVideo => 'görüntü';

  @override
  String get captureAudio => 'ses';

  @override
  String deviceTestTitle(String device) {
    return '$device testi ve cihaz seçimi';
  }

  @override
  String meetingDeviceTestHint(String device) {
    return 'Bu panel açıkken toplantıdaki $device yayının duraklatılır. Test yalnızca bu cihazda çalışır. Paneli kapatınca seçtiğin cihaz toplantıya uygulanır; önceden kapalı olan yayın kapalı kalır.';
  }

  @override
  String get localDeviceTestHint =>
      'Seçiminiz kaydedilir ve bir sonraki toplantıda kullanılır. Test yalnızca bu cihazda çalışır; sunucuya ses veya görüntü gönderilmez.';

  @override
  String devicePreference(String device) {
    return '$device tercihi';
  }

  @override
  String get systemDefault => 'Sistem varsayılanı';

  @override
  String get savedDeviceMissing => 'Kayıtlı cihaz bağlı değil';

  @override
  String deviceNumber(String device, int number) {
    return '$device $number';
  }

  @override
  String get refreshDevices => 'Cihazları yenile';

  @override
  String get microphoneLevelHint =>
      'Konuşun; ses seviyesi çubuğunun hareket ettiğini kontrol edin.';

  @override
  String get microphoneLevelWaiting =>
      'Mikrofon açık. Ses seviyesi bekleniyor; bazı sürücüler seviye bilgisi sağlamayabilir.';

  @override
  String get microphoneAudioDetected => 'Mikrofondan ses alınıyor.';

  @override
  String get microphoneSilent => 'Mikrofon açık, şu anda sessiz.';

  @override
  String get deviceOpening => 'Cihaz açılıyor…';

  @override
  String get stopTest => 'Testi durdur';

  @override
  String get startTest => 'Testi başlat';

  @override
  String get devicePreferenceSaveFailed =>
      'Cihaz tercihi kaydedilemedi. Tekrar deneyin.';

  @override
  String windowsDevicePermissionHint(String device) {
    return 'Windows erişimi kapalıysa $device erişimini ve masaüstü uygulamalarının erişimini açın. Sonra buraya dönüp testi yeniden başlatın.';
  }

  @override
  String windowsDevicePrivacyUnavailable(String device) {
    return 'Windows ayarları açılamadı. Ayarlar > Gizlilik ve güvenlik > $device bölümünü açın.';
  }

  @override
  String openWindowsDevicePrivacy(String device) {
    return 'Windows $device gizlilik ayarlarını aç';
  }

  @override
  String captureFailed(String device, String error) {
    return '$device açılamadı: $error';
  }

  @override
  String captureUnavailable(String device, String media) {
    return '$device açılamadı; cihazdan $media alınamadı. Cihazın bağlı olduğunu ve başka bir uygulama tarafından kullanılmadığını kontrol edin.';
  }

  @override
  String windowsCaptureAccessHint(String device) {
    return 'Windows ayarlarında $device erişimini ve masaüstü uygulamalarının erişimini açın.';
  }

  @override
  String appCaptureAccessHint(String device) {
    return 'Uygulamanın $device iznini kontrol edin.';
  }

  @override
  String captureRetryHint(String device) {
    return 'Ardından $device düğmesiyle tekrar deneyin.';
  }

  @override
  String get windowsAudioRestartRequired =>
      'Windows ses bileşeni güncel değil. Uygulamayı yeniden derleyip tamamen kapatarak yeniden başlatın.';

  @override
  String get windowsMicrophoneMissing =>
      'Windows varsayılan mikrofonu bulunamadı. Ses ayarlarından bir giriş aygıtı seçin.';

  @override
  String get englishLanguage => 'İngilizce';

  @override
  String get turkishLanguage => 'Türkçe';

  @override
  String get screenShareNotificationTitle => 'Ekranınız paylaşılıyor';

  @override
  String get screenShareNotificationBody =>
      'Paylaşımı durdurmak için toplantıya dönün.';
}
