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

  @override
  String get about => 'About';

  @override
  String get developer => 'Developer';

  @override
  String get technologies => 'Technologies';

  @override
  String get licenses => 'Licenses';

  @override
  String get contact => 'Contact';

  @override
  String get madeWithFlutter => 'Made with ❤️ using Flutter.';

  @override
  String get language => 'Language';

  @override
  String get profile => 'Profile';

  @override
  String get profileMenu => 'Profile menu';

  @override
  String get settings => 'Settings';

  @override
  String get logout => 'Log Out';

  @override
  String get general => 'General';

  @override
  String get meeting => 'Meetings';

  @override
  String get application => 'Application';

  @override
  String get deviceTest => 'Device Test';

  @override
  String get darkTheme => 'Dark Theme';

  @override
  String get notifications => 'Notifications';

  @override
  String get comingSoon => 'Coming Soon';

  @override
  String get startWithMic => 'Start with microphone on';

  @override
  String get startWithCamera => 'Start with camera on';

  @override
  String get mirrorCamera => 'Mirror camera';

  @override
  String get noiseSuppression => 'Noise suppression';

  @override
  String get highQualityVideo => 'HD Video';

  @override
  String get testMicrophone => 'Test Microphone';

  @override
  String get testCamera => 'Test Camera';

  @override
  String get testSpeaker => 'Test Speaker';

  @override
  String get serverSettings => 'Server Settings';

  @override
  String get serverAddress => 'Server Address / IP';

  @override
  String get serverPort => 'Server Port';

  @override
  String get saveServerSettings => 'Save Server Settings';

  @override
  String get serverSettingsHint => 'Example: meeting.example.com';

  @override
  String get version => 'Version';

  @override
  String get checkForUpdates => 'Check for Updates';

  @override
  String get chatTitle => 'Chat';

  @override
  String get chatMessage1 => 'Hey, can you hear me?';

  @override
  String get chatMessage2 => 'Yes, it\'s clear. The video looks great too.';

  @override
  String get messageHint => 'Type a message...';

  @override
  String get mainVideoLabel => 'Main Video Stream';

  @override
  String get speakerLabel => 'Speaker';

  @override
  String get membersTitle => 'Members';

  @override
  String membersHeader(Object count, Object current, Object total) {
    return '$count people attending · Page $current/$total';
  }

  @override
  String memberCountLabel(Object count) {
    return '$count members';
  }

  @override
  String screenCountLabel(Object count) {
    return '$count screens';
  }

  @override
  String userName(Object number) {
    return 'User $number';
  }

  @override
  String get liveBadge => 'LIVE';

  @override
  String get welcome => 'Welcome';

  @override
  String get nickname => 'Username (Nick)';

  @override
  String get password => 'Password';

  @override
  String get login => 'Log In';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register';

  @override
  String get createAccount => 'Create New Account';

  @override
  String get confirmPassword => 'Re-enter Password';

  @override
  String get register => 'Register';

  @override
  String get passwordsNotMatch => 'Passwords don\'t match!';

  @override
  String get registerSuccess => 'Registration successful! You can log in now.';

  @override
  String get connectionError => 'Connection error!';

  @override
  String get connecting => 'Connecting...';

  @override
  String get moreOptions => 'More options';

  @override
  String get close => 'Close';

  @override
  String get cancel => 'Cancel';

  @override
  String get send => 'Send';

  @override
  String get notNow => 'Not now';

  @override
  String get you => 'You';

  @override
  String secondsRemaining(int seconds) {
    return '$seconds s';
  }

  @override
  String get meetingSettings => 'Meeting settings';

  @override
  String get microphoneSelectionTest => 'Microphone selection and test';

  @override
  String get cameraSelectionTest => 'Camera selection and test';

  @override
  String get microphoneSelectionHint =>
      'Microphone selection and live audio level';

  @override
  String get cameraSelectionHint => 'Camera selection and live preview';

  @override
  String get audioInputHint => 'Input device and live audio level';

  @override
  String get cameraInputHint => 'Camera device and live preview';

  @override
  String get allowScreenSharing => 'Allow participants to share their screens';

  @override
  String get oneScreenShareHint =>
      'Only one person can share their screen at a time.';

  @override
  String get microphoneManagement => 'Microphone controls';

  @override
  String get unlockMicrophone => 'Unlock microphone';

  @override
  String get lockMicrophone => 'Mute and lock microphone';

  @override
  String get unlockAndRequestMicrophone => 'Unlock and request unmute';

  @override
  String get requestMicrophone => 'Request unmute';

  @override
  String get unmuteRequestTitle => 'Unmute request';

  @override
  String get unmuteRequestBody =>
      'The host is asking you to unmute your microphone. Would you like to unmute?';

  @override
  String get unmuteMicrophone => 'Unmute microphone';

  @override
  String get microphoneLocked => 'Your microphone has been locked by the host.';

  @override
  String get leaveMeeting => 'Leave meeting';

  @override
  String get hostLeaveBody =>
      'Ending the meeting disconnects everyone and closes the room. If you only leave, the meeting continues.';

  @override
  String get leave => 'Leave';

  @override
  String get endMeeting => 'End meeting';

  @override
  String get meetingEndedByYou => 'You ended the meeting.';

  @override
  String get selectScreenToShare => 'Choose a screen to share';

  @override
  String get screen => 'Screen';

  @override
  String get window => 'Window';

  @override
  String get share => 'Share';

  @override
  String get screenShareLabel => 'Screen sharing';

  @override
  String get stopScreenSharing => 'Stop sharing';

  @override
  String get shareScreen => 'Share screen';

  @override
  String get screenSharingDisabled =>
      'Screen sharing has been disabled by the host';

  @override
  String get exitFullscreen => 'Exit fullscreen';

  @override
  String get fullscreenMainVideo => 'Show main video fullscreen';

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String get resetZoom => 'Reset zoom';

  @override
  String get rejoiningMeeting => 'Rejoining the meeting…';

  @override
  String get rejoinMeeting => 'Rejoin';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get microphonePrivacySettings => 'Microphone privacy settings';

  @override
  String get cameraPrivacySettings => 'Camera privacy settings';

  @override
  String get windowsPrivacyUnavailable =>
      'Could not open Windows settings. Open Settings > Privacy & security.';

  @override
  String get missingMeetingDetails => 'Meeting details are missing';

  @override
  String get mediaRequiresHttps =>
      'Camera and microphone access in a mobile browser requires HTTPS. Open the app using a secure HTTPS address.';

  @override
  String get joiningMeeting => 'Connecting to the meeting…';

  @override
  String get reconnectingMeeting => 'Connection lost. Reconnecting…';

  @override
  String get duplicateSession =>
      'Disconnected because this session was opened on another device.';

  @override
  String get meetingClosedByServer => 'The meeting was closed by the server.';

  @override
  String get removedFromMeeting =>
      'You were removed from the meeting by the server.';

  @override
  String get reconnectFailed =>
      'Could not restore the connection. Try rejoining.';

  @override
  String get meetingSessionLost =>
      'The server lost the session. Please rejoin the meeting.';

  @override
  String get meetingDisconnected =>
      'Disconnected from the meeting. You are no longer connected to the room.';

  @override
  String get poorMediaConnection =>
      'The media connection is weak. Audio and video may cut out.';

  @override
  String subscriptionFailed(String reason) {
    return 'Could not receive a participant’s media stream ($reason).';
  }

  @override
  String meetingJoinFailed(String error) {
    return 'Could not join the meeting: $error';
  }

  @override
  String microphoneDisableFailed(String error) {
    return 'Could not turn off the microphone: $error';
  }

  @override
  String get screenShareStartFailed => 'Could not start screen sharing.';

  @override
  String get invalidMessageData => 'The server returned invalid message data';

  @override
  String get invalidServerResponse => 'The server returned an invalid response';

  @override
  String get invalidRoomData => 'The server returned invalid room details';

  @override
  String get missingServerSession =>
      'The session or server configuration is missing';

  @override
  String get meetingServerUnavailable =>
      'Could not connect to the meeting server';

  @override
  String get serverSettingsReadFailed =>
      'Could not read the saved server settings.';

  @override
  String get serverSettingsSaveFailed =>
      'Could not save the server settings. Please try again.';

  @override
  String get invalidServerAddressPort =>
      'Please enter a valid server address and port.';

  @override
  String serverSettingsSaved(String url) {
    return 'Server settings saved: $url';
  }

  @override
  String get cameraName => 'Camera';

  @override
  String get microphoneName => 'Microphone';

  @override
  String get captureVideo => 'video';

  @override
  String get captureAudio => 'audio';

  @override
  String deviceTestTitle(String device) {
    return '$device test and selection';
  }

  @override
  String meetingDeviceTestHint(String device) {
    return 'Your meeting’s $device is paused while this panel is open. The test runs only on this device. When you close the panel, your selection is applied to the meeting; a previously disabled device stays off.';
  }

  @override
  String get localDeviceTestHint =>
      'Your selection is saved for your next meeting. The test runs only on this device; no audio or video is sent to the server.';

  @override
  String devicePreference(String device) {
    return '$device preference';
  }

  @override
  String get systemDefault => 'System default';

  @override
  String get savedDeviceMissing => 'Saved device is disconnected';

  @override
  String deviceNumber(String device, int number) {
    return '$device $number';
  }

  @override
  String get refreshDevices => 'Refresh devices';

  @override
  String get microphoneLevelHint =>
      'Speak and check that the audio level bar moves.';

  @override
  String get microphoneLevelWaiting =>
      'Microphone is on. Waiting for audio levels; some drivers may not provide level information.';

  @override
  String get microphoneAudioDetected =>
      'Audio is being captured from the microphone.';

  @override
  String get microphoneSilent => 'Microphone is on, currently silent.';

  @override
  String get deviceOpening => 'Opening device…';

  @override
  String get stopTest => 'Stop test';

  @override
  String get startTest => 'Start test';

  @override
  String get devicePreferenceSaveFailed =>
      'Could not save the device preference. Please try again.';

  @override
  String windowsDevicePermissionHint(String device) {
    return 'If Windows access is disabled, allow $device access and access for desktop apps. Then return here and restart the test.';
  }

  @override
  String windowsDevicePrivacyUnavailable(String device) {
    return 'Could not open Windows settings. Open Settings > Privacy & security > $device.';
  }

  @override
  String openWindowsDevicePrivacy(String device) {
    return 'Open Windows $device privacy settings';
  }

  @override
  String captureFailed(String device, String error) {
    return 'Could not open $device: $error';
  }

  @override
  String captureUnavailable(String device, String media) {
    return 'Could not open $device; no $media could be captured. Check that the device is connected and is not in use by another application.';
  }

  @override
  String windowsCaptureAccessHint(String device) {
    return 'In Windows settings, enable $device access and access for desktop apps.';
  }

  @override
  String appCaptureAccessHint(String device) {
    return 'Check the app’s $device permission.';
  }

  @override
  String captureRetryHint(String device) {
    return 'Then try again using the $device button.';
  }

  @override
  String get windowsAudioRestartRequired =>
      'The Windows audio component is outdated. Rebuild the application, fully close it, and start it again.';

  @override
  String get windowsMicrophoneMissing =>
      'The Windows default microphone could not be found. Select an input device in Sound settings.';

  @override
  String get englishLanguage => 'English';

  @override
  String get turkishLanguage => 'Turkish';

  @override
  String get screenShareNotificationTitle => 'Your screen is being shared';

  @override
  String get screenShareNotificationBody =>
      'Return to the meeting to stop sharing.';
}
