import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/home/home_screen.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/l10n/localized_error.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/meeting/meeting_connection.dart';
import 'package:v_meeting/meeting/meeting_display.dart';
import 'package:v_meeting/meeting/meeting_media.dart';
import 'package:v_meeting/meeting/meeting_platform.dart';
import 'package:v_meeting/meeting/meeting_session.dart';
import 'package:v_meeting/meeting/members_screen.dart';
import 'package:v_meeting/meeting/widgets/meeting_banners.dart';
import 'package:v_meeting/meeting/widgets/meeting_chat_sheet.dart';
import 'package:v_meeting/meeting/widgets/meeting_controls_bar.dart';
import 'package:v_meeting/meeting/widgets/meeting_joining_overlay.dart';
import 'package:v_meeting/meeting/widgets/meeting_participant.dart';
import 'package:v_meeting/meeting/widgets/meeting_settings_dialog.dart';
import 'package:v_meeting/meeting/widgets/screen_source_picker.dart';
import 'package:v_meeting/settings/device_test_screen.dart';
import 'package:v_meeting/settings/media_privacy.dart';

/// The in-meeting screen. Meeting logic lives in [MeetingSession]; this widget
/// lays out the video, controls and overlays and shows dialogs and sheets.
class MeetingScreen extends ConsumerStatefulWidget {
  const MeetingScreen({
    super.key,
    this.credentials,
    @visibleForTesting this.skipJoiningScreen = false,
  });

  final RoomCredentials? credentials;
  final bool skipJoiningScreen;

  static int _open = 0;

  /// Whether a meeting is on screen; invite links wait until it ends.
  static bool get isOpen => _open > 0;

  @override
  ConsumerState<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends ConsumerState<MeetingScreen>
    with WidgetsBindingObserver
    implements MeetingUi {
  late final MeetingSession _session;
  late final MeetingDisplayMode _display;
  Timer? _controlsTimer;
  bool _showControls = true;
  bool _showRoomCode = false;
  int _roomCodeRequests = 0;
  bool _exitDialogOpen = false;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MeetingScreen._open++;
    final platform = ref.read(meetingPlatformProvider);
    _display = MeetingDisplayMode(platform);
    _session = MeetingSession(
      room: ref.read(meetingRoomFactoryProvider)(),
      api: ref.read(meetingApiProvider),
      platform: platform,
      ui: this,
      credentials: widget.credentials,
      showEntryGate: !widget.skipJoiningScreen,
    )..addListener(_onSessionChanged);
    _scheduleControlsHide();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startBackgroundSupport();
      _session.connect();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _display.enterIfPhone(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _display.onResumed();
        unawaited(_session.resumeCameraFromBackground());
      case AppLifecycleState.paused:
        unawaited(_session.pauseCameraForBackground());
      default:
    }
  }

  /// Keeps the screen awake. The session starts the Android background
  /// service once the meeting's permissions have been asked for.
  void _startBackgroundSupport() {
    unawaited(_session.platform.setKeepScreenOn(true));
  }

  @override
  NotificationText meetingNotification() => (
    channelName: _l10n.meetingNotificationChannel,
    title: _l10n.meetingNotificationTitle,
    body: _l10n.meetingNotificationBody,
  );

  /// System back leaves the meeting running on Android (the app goes to the
  /// background) and asks before leaving elsewhere.
  void _onBack(bool didPop, Object? _) {
    if (didPop) return;
    if (defaultTargetPlatform == TargetPlatform.android && !kIsWeb) {
      unawaited(_session.platform.moveToBackground());
    } else {
      unawaited(_requestLeaveMeeting());
    }
  }

  @override
  void didChangeMetrics() {
    _display.onMetricsChanged(
      () => mounted && View.of(context).viewInsets.bottom == 0,
    );
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _showMeetingControls() {
    setState(() => _showControls = true);
    _scheduleControlsHide();
  }

  // ---------------------------------------------------------------------------
  // MeetingUi

  @override
  void exitMeeting(MeetingExitReason reason) {
    if (!mounted) return;
    _controlsTimer?.cancel();
    final notice = switch (reason) {
      MeetingExitReason.left => null,
      MeetingExitReason.endedByYou => _l10n.meetingEndedByYou,
      MeetingExitReason.disconnected => _session.connection.message(_l10n),
    };
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      (_) => false,
    );
    if (notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!messenger.mounted) return;
        messenger.clearSnackBars();
        messenger.showSnackBar(SnackBar(content: Text(notice)));
      });
    }
  }

  @override
  Future<bool> confirmUnmute() async {
    if (!mounted) return false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_l10n.unmuteRequestTitle),
        content: Text(_l10n.unmuteRequestBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_l10n.notNow),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_l10n.unmuteMicrophone),
          ),
        ],
      ),
    );
    return accepted == true;
  }

  @override
  void showMessage(Object message) =>
      _showMessage(localizeError(message, _l10n));

  @override
  Future<ScreenShareChoice?> pickDesktopScreen() async {
    if (!mounted) return null;
    final platform = _session.platform;
    return ScreenSourcePicker.show(
      context,
      capturer: platform.desktopCapturer,
      audioSupport: platform.systemAudioSupport,
    );
  }

  @override
  NotificationText screenShareNotification() => (
    channelName: _l10n.screenShareLabel,
    title: _l10n.screenShareNotificationTitle,
    body: _l10n.screenShareNotificationBody,
  );

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------------
  // Actions

  void _toggleMicrophone() {
    if (_session.microphoneLocked) {
      _showMessage(_l10n.microphoneLocked);
      return;
    }
    unawaited(_session.toggleMicrophone());
  }

  Future<void> _requestLeaveMeeting() async {
    if (_session.endingRoom || _exitDialogOpen) return;
    if (!_session.canModerate) {
      _session.leave(MeetingExitReason.left);
      return;
    }
    final lastOwner = _session.isLastOwner;
    _exitDialogOpen = true;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_l10n.leaveMeeting),
        content: Text(
          lastOwner
              ? '${_l10n.hostLeaveBody}\n\n${_l10n.lastOwnerLeaveHint}'
              : _l10n.hostLeaveBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'leave'),
            child: Text(_l10n.leave),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, 'end'),
            child: Text(_l10n.endMeeting),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (!mounted) return;
    if (action == 'end') {
      await _session.closeRoomForEveryone();
    } else if (action == 'leave') {
      _session.leave(MeetingExitReason.left);
    }
  }

  Future<void> _openPrivacySettings({required bool camera}) async {
    final opened = await openMediaPrivacy(camera: camera);
    if (!opened) _showMessage(_l10n.windowsPrivacyUnavailable);
  }

  void _openMembersSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.65,
        child: ListenableBuilder(
          listenable: _session.room,
          builder: (context, _) => MembersScreen(
            members: _session.members(localName: _l10n.you),
            viewerRole: _session.role,
            onMicrophoneChange: _session.moderateMicrophone,
            onRoleChange: _session.changeRole,
            onTransferOwnership: _session.transferOwnership,
          ),
        ),
      ),
    );
  }

  void _openChatSheet() {
    final chat = _session.chat;
    if (chat == null) return;
    chat.setChatOpen(true);
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MeetingChatSheet(controller: chat),
      ).whenComplete(() => chat.setChatOpen(false)),
    );
  }

  void _openMeetingSettings() {
    final sharing = _session.canModerate ? _session.sharing : null;
    if (sharing != null) unawaited(sharing.refresh());
    showDialog<void>(
      context: context,
      builder: (_) => MeetingSettingsDialog(
        sharing: sharing,
        onDeviceTest: _openMeetingDeviceTest,
      ),
    );
  }

  Future<void> _openMeetingDeviceTest(bool camera) async {
    final test = _session.beginDeviceTest(camera: camera);
    if (test == null) return;
    try {
      await _session.releaseDeviceForTest(test);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.9,
          child: DeviceTestScreen(
            camera: camera,
            inMeeting: true,
            controller: test.controller,
          ),
        ),
      );
    } catch (error) {
      _showMessage(mediaCaptureError(error, camera: camera, l10n: _l10n));
    } finally {
      await _session.endDeviceTest(test);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MeetingScreen._open--;
    final platform = _session.platform;
    unawaited(platform.setKeepScreenOn(false));
    unawaited(platform.stopMeetingService());
    _controlsTimer?.cancel();
    _display.exit();
    _session
      ..removeListener(_onSessionChanged)
      ..dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Layout

  String? _meetingError(AppLocalizations l10n) {
    final errors = [
      if (_session.connectionError case final error?)
        localizeError(error, l10n),
      if (_session.microphoneError case final error?)
        mediaCaptureError(error, camera: false, l10n: l10n),
      if (_session.cameraError case final error?)
        mediaCaptureError(error, camera: true, l10n: l10n),
    ];
    return errors.isEmpty ? null : errors.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = _session;
    final connection = session.connection;
    final members = session.members(localName: l10n.you);
    final mainMember = session.mainMember(members);
    final connectionMessage = connection.message(l10n);
    final meetingError = _meetingError(l10n);
    final roomId = widget.credentials?.roomId;
    final isPhone = MediaQuery.sizeOf(context).shortestSide < 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onBack,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          top: !isPhone,
          bottom: !isPhone,
          left: !isPhone,
          right: !isPhone,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: isPhone ? EdgeInsets.zero : const EdgeInsets.all(16),
                  child: MeetingVideoLayout(
                    members: members,
                    mainMember: mainMember,
                    connecting:
                        session.isConnecting ||
                        connection.phase == MeetingConnectionPhase.reconnecting,
                    onMainPageTap: _showMeetingControls,
                    onStopScreenShare: session.changingScreenShare
                        ? null
                        : session.stopScreenShare,
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                bottom: _showControls ? (isPhone ? 16 : 32) : -100,
                left: 0,
                right: 0,
                child: Listener(
                  onPointerDown: (_) => _scheduleControlsHide(),
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: MeetingControlsBar(
                            microphoneLocked: session.microphoneLocked,
                            microphoneEnabled: session.isMicEnabled,
                            cameraEnabled: session.isCameraEnabled,
                            hasUnreadMessages:
                                session.chat?.hasUnreadMessages ?? false,
                            sharingScreen: session.isSharingScreen,
                            screenSharingAllowed: session.screenSharingAllowed,
                            screenShareBusy: session.screenShareBusy,
                            onToggleMicrophone: _toggleMicrophone,
                            onToggleCamera: session.toggleCamera,
                            onOpenMembers: _openMembersSheet,
                            onOpenChat: _openChatSheet,
                            onToggleScreenShare: session.canToggleScreenShare
                                ? session.toggleScreenShare
                                : null,
                            onOpenSettings: _openMeetingSettings,
                            onShowRoomCode: () => setState(() {
                              _showRoomCode = true;
                              _roomCodeRequests++;
                            }),
                            onLeave: session.endingRoom
                                ? null
                                : _requestLeaveMeeting,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (connectionMessage != null)
                Positioned(
                  top: 16,
                  left: 24,
                  right: 24,
                  child: MeetingConnectionBanner(
                    message: session.isRejoining
                        ? l10n.rejoiningMeeting
                        : connectionMessage,
                    disconnected:
                        connection.phase == MeetingConnectionPhase.disconnected,
                    onRejoin:
                        connection.phase ==
                                MeetingConnectionPhase.disconnected &&
                            connection.canRejoin &&
                            session.credentials != null &&
                            !session.isRejoining
                        ? session.rejoin
                        : null,
                  ),
                ),
              if (meetingError != null && connectionMessage == null)
                Positioned(
                  top: 16,
                  left: 24,
                  right: 24,
                  child: MeetingErrorBanner(
                    message: meetingError,
                    onMicrophonePrivacy:
                        isWindowsDesktop && session.microphoneError != null
                        ? () => _openPrivacySettings(camera: false)
                        : null,
                    onCameraPrivacy:
                        isWindowsDesktop && session.cameraError != null
                        ? () => _openPrivacySettings(camera: true)
                        : null,
                  ),
                ),
              if (_showRoomCode && roomId != null)
                Positioned(
                  top: 16,
                  left: 24,
                  right: 24,
                  child: RoomCodeBanner(
                    // A new key restarts the countdown when shown again.
                    key: ValueKey(_roomCodeRequests),
                    roomId: roomId,
                    inviteLink: _session.inviteLink,
                    onClose: () => setState(() => _showRoomCode = false),
                  ),
                ),
              if (!session.entryGate.ready)
                Positioned.fill(
                  child: MeetingJoiningOverlay(
                    timedOut: session.entryGate.timedOut,
                    onRetry: session.isJoining || session.isRejoining
                        ? null
                        : session.rejoin,
                    onLeave: () => session.leave(MeetingExitReason.left),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
