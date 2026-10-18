import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @joinMeeting.
  ///
  /// In en, this message translates to:
  /// **'Join Meeting'**
  String get joinMeeting;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your Name'**
  String get yourName;

  /// No description provided for @roomId.
  ///
  /// In en, this message translates to:
  /// **'Room ID'**
  String get roomId;

  /// No description provided for @nameError.
  ///
  /// In en, this message translates to:
  /// **'You must enter a name'**
  String get nameError;

  /// No description provided for @roomError.
  ///
  /// In en, this message translates to:
  /// **'Incomplete or invalid number'**
  String get roomError;

  /// No description provided for @emptyErrorMsg.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name and complete the 9-digit room number.'**
  String get emptyErrorMsg;

  /// No description provided for @returnMainMenu.
  ///
  /// In en, this message translates to:
  /// **'Return to Main Menu'**
  String get returnMainMenu;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open Source Meeting Platform'**
  String get appSubtitle;

  /// No description provided for @createRoom.
  ///
  /// In en, this message translates to:
  /// **'Create New Room'**
  String get createRoom;

  /// No description provided for @startMeeting.
  ///
  /// In en, this message translates to:
  /// **'Start Meeting'**
  String get startMeeting;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// No description provided for @technologies.
  ///
  /// In en, this message translates to:
  /// **'Technologies'**
  String get technologies;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get licenses;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @madeWithFlutter.
  ///
  /// In en, this message translates to:
  /// **'Made with ❤️ using Flutter.'**
  String get madeWithFlutter;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @profileMenu.
  ///
  /// In en, this message translates to:
  /// **'Profile menu'**
  String get profileMenu;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @meeting.
  ///
  /// In en, this message translates to:
  /// **'Meetings'**
  String get meeting;

  /// No description provided for @application.
  ///
  /// In en, this message translates to:
  /// **'Application'**
  String get application;

  /// No description provided for @deviceTest.
  ///
  /// In en, this message translates to:
  /// **'Device Test'**
  String get deviceTest;

  /// No description provided for @darkTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark Theme'**
  String get darkTheme;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// No description provided for @startWithMic.
  ///
  /// In en, this message translates to:
  /// **'Start with microphone on'**
  String get startWithMic;

  /// No description provided for @startWithCamera.
  ///
  /// In en, this message translates to:
  /// **'Start with camera on'**
  String get startWithCamera;

  /// No description provided for @mirrorCamera.
  ///
  /// In en, this message translates to:
  /// **'Mirror camera'**
  String get mirrorCamera;

  /// No description provided for @noiseSuppression.
  ///
  /// In en, this message translates to:
  /// **'Noise suppression'**
  String get noiseSuppression;

  /// No description provided for @highQualityVideo.
  ///
  /// In en, this message translates to:
  /// **'HD Video'**
  String get highQualityVideo;

  /// No description provided for @testMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Test Microphone'**
  String get testMicrophone;

  /// No description provided for @testCamera.
  ///
  /// In en, this message translates to:
  /// **'Test Camera'**
  String get testCamera;

  /// No description provided for @testSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Test Speaker'**
  String get testSpeaker;

  /// No description provided for @serverSettings.
  ///
  /// In en, this message translates to:
  /// **'Server Settings'**
  String get serverSettings;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Server Address / IP'**
  String get serverAddress;

  /// No description provided for @serverPort.
  ///
  /// In en, this message translates to:
  /// **'Server Port'**
  String get serverPort;

  /// No description provided for @saveServerSettings.
  ///
  /// In en, this message translates to:
  /// **'Save Server Settings'**
  String get saveServerSettings;

  /// No description provided for @serverSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Example: meeting.example.com'**
  String get serverSettingsHint;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkForUpdates;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTitle;

  /// No description provided for @chatMessage1.
  ///
  /// In en, this message translates to:
  /// **'Hey, can you hear me?'**
  String get chatMessage1;

  /// No description provided for @chatMessage2.
  ///
  /// In en, this message translates to:
  /// **'Yes, it\'s clear. The video looks great too.'**
  String get chatMessage2;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get messageHint;

  /// No description provided for @mainVideoLabel.
  ///
  /// In en, this message translates to:
  /// **'Main Video Stream'**
  String get mainVideoLabel;

  /// No description provided for @speakerLabel.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get speakerLabel;

  /// No description provided for @membersTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get membersTitle;

  /// No description provided for @membersHeader.
  ///
  /// In en, this message translates to:
  /// **'{count} people attending · Page {current}/{total}'**
  String membersHeader(Object count, Object current, Object total);

  /// No description provided for @memberCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String memberCountLabel(Object count);

  /// No description provided for @screenCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} screens'**
  String screenCountLabel(Object count);

  /// No description provided for @userName.
  ///
  /// In en, this message translates to:
  /// **'User {number}'**
  String userName(Object number);

  /// No description provided for @liveBadge.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get liveBadge;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Username (Nick)'**
  String get nickname;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get login;

  /// No description provided for @noAccountRegister.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Register'**
  String get noAccountRegister;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create New Account'**
  String get createAccount;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Re-enter Password'**
  String get confirmPassword;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @passwordsNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match!'**
  String get passwordsNotMatch;

  /// No description provided for @registerSuccess.
  ///
  /// In en, this message translates to:
  /// **'Registration successful! You can log in now.'**
  String get registerSuccess;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error!'**
  String get connectionError;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @secondsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String secondsRemaining(int seconds);

  /// No description provided for @meetingSettings.
  ///
  /// In en, this message translates to:
  /// **'Meeting settings'**
  String get meetingSettings;

  /// No description provided for @microphoneSelectionTest.
  ///
  /// In en, this message translates to:
  /// **'Microphone selection and test'**
  String get microphoneSelectionTest;

  /// No description provided for @cameraSelectionTest.
  ///
  /// In en, this message translates to:
  /// **'Camera selection and test'**
  String get cameraSelectionTest;

  /// No description provided for @microphoneSelectionHint.
  ///
  /// In en, this message translates to:
  /// **'Microphone selection and live audio level'**
  String get microphoneSelectionHint;

  /// No description provided for @cameraSelectionHint.
  ///
  /// In en, this message translates to:
  /// **'Camera selection and live preview'**
  String get cameraSelectionHint;

  /// No description provided for @audioInputHint.
  ///
  /// In en, this message translates to:
  /// **'Input device and live audio level'**
  String get audioInputHint;

  /// No description provided for @cameraInputHint.
  ///
  /// In en, this message translates to:
  /// **'Camera device and live preview'**
  String get cameraInputHint;

  /// No description provided for @allowScreenSharing.
  ///
  /// In en, this message translates to:
  /// **'Allow participants to share their screens'**
  String get allowScreenSharing;

  /// No description provided for @oneScreenShareHint.
  ///
  /// In en, this message translates to:
  /// **'Only one person can share their screen at a time.'**
  String get oneScreenShareHint;

  /// No description provided for @microphoneManagement.
  ///
  /// In en, this message translates to:
  /// **'Microphone controls'**
  String get microphoneManagement;

  /// No description provided for @unlockMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Unlock microphone'**
  String get unlockMicrophone;

  /// No description provided for @lockMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Mute and lock microphone'**
  String get lockMicrophone;

  /// No description provided for @unlockAndRequestMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Unlock and request unmute'**
  String get unlockAndRequestMicrophone;

  /// No description provided for @requestMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Request unmute'**
  String get requestMicrophone;

  /// No description provided for @unmuteRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Unmute request'**
  String get unmuteRequestTitle;

  /// No description provided for @unmuteRequestBody.
  ///
  /// In en, this message translates to:
  /// **'The host is asking you to unmute your microphone. Would you like to unmute?'**
  String get unmuteRequestBody;

  /// No description provided for @unmuteMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Unmute microphone'**
  String get unmuteMicrophone;

  /// No description provided for @microphoneLocked.
  ///
  /// In en, this message translates to:
  /// **'Your microphone has been locked by the host.'**
  String get microphoneLocked;

  /// No description provided for @leaveMeeting.
  ///
  /// In en, this message translates to:
  /// **'Leave meeting'**
  String get leaveMeeting;

  /// No description provided for @hostLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'Ending the meeting disconnects everyone and closes the room. If you only leave, the meeting continues.'**
  String get hostLeaveBody;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @endMeeting.
  ///
  /// In en, this message translates to:
  /// **'End meeting'**
  String get endMeeting;

  /// No description provided for @meetingEndedByYou.
  ///
  /// In en, this message translates to:
  /// **'You ended the meeting.'**
  String get meetingEndedByYou;

  /// No description provided for @selectScreenToShare.
  ///
  /// In en, this message translates to:
  /// **'Choose a screen to share'**
  String get selectScreenToShare;

  /// No description provided for @screen.
  ///
  /// In en, this message translates to:
  /// **'Screen'**
  String get screen;

  /// No description provided for @window.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get window;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @screenShareLabel.
  ///
  /// In en, this message translates to:
  /// **'Screen sharing'**
  String get screenShareLabel;

  /// No description provided for @stopScreenSharing.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing'**
  String get stopScreenSharing;

  /// No description provided for @shareScreen.
  ///
  /// In en, this message translates to:
  /// **'Share screen'**
  String get shareScreen;

  /// No description provided for @screenSharingDisabled.
  ///
  /// In en, this message translates to:
  /// **'Screen sharing has been disabled by the host'**
  String get screenSharingDisabled;

  /// No description provided for @exitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen'**
  String get exitFullscreen;

  /// No description provided for @fullscreenMainVideo.
  ///
  /// In en, this message translates to:
  /// **'Show main video fullscreen'**
  String get fullscreenMainVideo;

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// No description provided for @resetZoom.
  ///
  /// In en, this message translates to:
  /// **'Reset zoom'**
  String get resetZoom;

  /// No description provided for @rejoiningMeeting.
  ///
  /// In en, this message translates to:
  /// **'Rejoining the meeting…'**
  String get rejoiningMeeting;

  /// No description provided for @rejoinMeeting.
  ///
  /// In en, this message translates to:
  /// **'Rejoin'**
  String get rejoinMeeting;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @microphonePrivacySettings.
  ///
  /// In en, this message translates to:
  /// **'Microphone privacy settings'**
  String get microphonePrivacySettings;

  /// No description provided for @cameraPrivacySettings.
  ///
  /// In en, this message translates to:
  /// **'Camera privacy settings'**
  String get cameraPrivacySettings;

  /// No description provided for @windowsPrivacyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not open Windows settings. Open Settings > Privacy & security.'**
  String get windowsPrivacyUnavailable;

  /// No description provided for @missingMeetingDetails.
  ///
  /// In en, this message translates to:
  /// **'Meeting details are missing'**
  String get missingMeetingDetails;

  /// No description provided for @mediaRequiresHttps.
  ///
  /// In en, this message translates to:
  /// **'Camera and microphone access in a mobile browser requires HTTPS. Open the app using a secure HTTPS address.'**
  String get mediaRequiresHttps;

  /// No description provided for @joiningMeeting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to the meeting…'**
  String get joiningMeeting;

  /// No description provided for @reconnectingMeeting.
  ///
  /// In en, this message translates to:
  /// **'Connection lost. Reconnecting…'**
  String get reconnectingMeeting;

  /// No description provided for @duplicateSession.
  ///
  /// In en, this message translates to:
  /// **'Disconnected because this session was opened on another device.'**
  String get duplicateSession;

  /// No description provided for @meetingClosedByServer.
  ///
  /// In en, this message translates to:
  /// **'The meeting was closed by the server.'**
  String get meetingClosedByServer;

  /// No description provided for @removedFromMeeting.
  ///
  /// In en, this message translates to:
  /// **'You were removed from the meeting by the server.'**
  String get removedFromMeeting;

  /// No description provided for @reconnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not restore the connection. Try rejoining.'**
  String get reconnectFailed;

  /// No description provided for @meetingSessionLost.
  ///
  /// In en, this message translates to:
  /// **'The server lost the session. Please rejoin the meeting.'**
  String get meetingSessionLost;

  /// No description provided for @meetingDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected from the meeting. You are no longer connected to the room.'**
  String get meetingDisconnected;

  /// No description provided for @poorMediaConnection.
  ///
  /// In en, this message translates to:
  /// **'The media connection is weak. Audio and video may cut out.'**
  String get poorMediaConnection;

  /// No description provided for @subscriptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not receive a participant’s media stream ({reason}).'**
  String subscriptionFailed(String reason);

  /// No description provided for @meetingJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not join the meeting: {error}'**
  String meetingJoinFailed(String error);

  /// No description provided for @microphoneDisableFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not turn off the microphone: {error}'**
  String microphoneDisableFailed(String error);

  /// No description provided for @screenShareStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start screen sharing.'**
  String get screenShareStartFailed;

  /// No description provided for @invalidMessageData.
  ///
  /// In en, this message translates to:
  /// **'The server returned invalid message data'**
  String get invalidMessageData;

  /// No description provided for @invalidServerResponse.
  ///
  /// In en, this message translates to:
  /// **'The server returned an invalid response'**
  String get invalidServerResponse;

  /// No description provided for @invalidRoomData.
  ///
  /// In en, this message translates to:
  /// **'The server returned invalid room details'**
  String get invalidRoomData;

  /// No description provided for @missingServerSession.
  ///
  /// In en, this message translates to:
  /// **'The session or server configuration is missing'**
  String get missingServerSession;

  /// No description provided for @meetingServerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the meeting server'**
  String get meetingServerUnavailable;

  /// No description provided for @serverSettingsReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the saved server settings.'**
  String get serverSettingsReadFailed;

  /// No description provided for @serverSettingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the server settings. Please try again.'**
  String get serverSettingsSaveFailed;

  /// No description provided for @invalidServerAddressPort.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid server address and port.'**
  String get invalidServerAddressPort;

  /// No description provided for @serverSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Server settings saved: {url}'**
  String serverSettingsSaved(String url);

  /// No description provided for @cameraName.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get cameraName;

  /// No description provided for @microphoneName.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get microphoneName;

  /// No description provided for @captureVideo.
  ///
  /// In en, this message translates to:
  /// **'video'**
  String get captureVideo;

  /// No description provided for @captureAudio.
  ///
  /// In en, this message translates to:
  /// **'audio'**
  String get captureAudio;

  /// No description provided for @deviceTestTitle.
  ///
  /// In en, this message translates to:
  /// **'{device} test and selection'**
  String deviceTestTitle(String device);

  /// No description provided for @meetingDeviceTestHint.
  ///
  /// In en, this message translates to:
  /// **'Your meeting’s {device} is paused while this panel is open. The test runs only on this device. When you close the panel, your selection is applied to the meeting; a previously disabled device stays off.'**
  String meetingDeviceTestHint(String device);

  /// No description provided for @localDeviceTestHint.
  ///
  /// In en, this message translates to:
  /// **'Your selection is saved for your next meeting. The test runs only on this device; no audio or video is sent to the server.'**
  String get localDeviceTestHint;

  /// No description provided for @devicePreference.
  ///
  /// In en, this message translates to:
  /// **'{device} preference'**
  String devicePreference(String device);

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @savedDeviceMissing.
  ///
  /// In en, this message translates to:
  /// **'Saved device is disconnected'**
  String get savedDeviceMissing;

  /// No description provided for @deviceNumber.
  ///
  /// In en, this message translates to:
  /// **'{device} {number}'**
  String deviceNumber(String device, int number);

  /// No description provided for @refreshDevices.
  ///
  /// In en, this message translates to:
  /// **'Refresh devices'**
  String get refreshDevices;

  /// No description provided for @microphoneLevelHint.
  ///
  /// In en, this message translates to:
  /// **'Speak and check that the audio level bar moves.'**
  String get microphoneLevelHint;

  /// No description provided for @microphoneLevelWaiting.
  ///
  /// In en, this message translates to:
  /// **'Microphone is on. Waiting for audio levels; some drivers may not provide level information.'**
  String get microphoneLevelWaiting;

  /// No description provided for @microphoneAudioDetected.
  ///
  /// In en, this message translates to:
  /// **'Audio is being captured from the microphone.'**
  String get microphoneAudioDetected;

  /// No description provided for @microphoneSilent.
  ///
  /// In en, this message translates to:
  /// **'Microphone is on, currently silent.'**
  String get microphoneSilent;

  /// No description provided for @deviceOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening device…'**
  String get deviceOpening;

  /// No description provided for @stopTest.
  ///
  /// In en, this message translates to:
  /// **'Stop test'**
  String get stopTest;

  /// No description provided for @startTest.
  ///
  /// In en, this message translates to:
  /// **'Start test'**
  String get startTest;

  /// No description provided for @devicePreferenceSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the device preference. Please try again.'**
  String get devicePreferenceSaveFailed;

  /// No description provided for @windowsDevicePermissionHint.
  ///
  /// In en, this message translates to:
  /// **'If Windows access is disabled, allow {device} access and access for desktop apps. Then return here and restart the test.'**
  String windowsDevicePermissionHint(String device);

  /// No description provided for @windowsDevicePrivacyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not open Windows settings. Open Settings > Privacy & security > {device}.'**
  String windowsDevicePrivacyUnavailable(String device);

  /// No description provided for @openWindowsDevicePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Open Windows {device} privacy settings'**
  String openWindowsDevicePrivacy(String device);

  /// No description provided for @captureFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open {device}: {error}'**
  String captureFailed(String device, String error);

  /// No description provided for @captureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not open {device}; no {media} could be captured. Check that the device is connected and is not in use by another application.'**
  String captureUnavailable(String device, String media);

  /// No description provided for @windowsCaptureAccessHint.
  ///
  /// In en, this message translates to:
  /// **'In Windows settings, enable {device} access and access for desktop apps.'**
  String windowsCaptureAccessHint(String device);

  /// No description provided for @appCaptureAccessHint.
  ///
  /// In en, this message translates to:
  /// **'Check the app’s {device} permission.'**
  String appCaptureAccessHint(String device);

  /// No description provided for @captureRetryHint.
  ///
  /// In en, this message translates to:
  /// **'Then try again using the {device} button.'**
  String captureRetryHint(String device);

  /// No description provided for @windowsAudioRestartRequired.
  ///
  /// In en, this message translates to:
  /// **'The Windows audio component is outdated. Rebuild the application, fully close it, and start it again.'**
  String get windowsAudioRestartRequired;

  /// No description provided for @windowsMicrophoneMissing.
  ///
  /// In en, this message translates to:
  /// **'The Windows default microphone could not be found. Select an input device in Sound settings.'**
  String get windowsMicrophoneMissing;

  /// No description provided for @englishLanguage.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get englishLanguage;

  /// No description provided for @turkishLanguage.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get turkishLanguage;

  /// No description provided for @screenShareNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Your screen is being shared'**
  String get screenShareNotificationTitle;

  /// No description provided for @screenShareNotificationBody.
  ///
  /// In en, this message translates to:
  /// **'Return to the meeting to stop sharing.'**
  String get screenShareNotificationBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
