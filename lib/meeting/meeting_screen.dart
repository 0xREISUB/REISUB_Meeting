import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/meeting/meeting_chat.dart';
import 'package:v_meeting/meeting/meeting_connection.dart';
import 'package:v_meeting/meeting/members_screen.dart';
import 'widgets/meeting_components.dart';
import 'widgets/meeting_participant.dart';

class MeetingScreen extends StatefulWidget {
  final RoomCredentials? credentials;
  @visibleForTesting
  final Room? room;

  const MeetingScreen({super.key, this.credentials, this.room});

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen>
    with WidgetsBindingObserver {
  static const _displayChannel = MethodChannel('reisub_meeting/display');
  bool _mobileDisplayActive = false;
  Timer? _controlsTimer;
  Timer? _systemUiTimer;
  late final Room _room;
  late final MeetingConnection _connection;
  RoomCredentials? _credentials;
  bool _isRejoining = false;
  bool _isJoining = false;
  bool _endingRoom = false;
  bool _applyingMicLock = false;
  bool _unmuteDialogOpen = false;
  String? _lastUnmuteRequest;
  static const _micLockAttribute = 'meeting.microphone_locked';
  static const _micRequestAttribute = 'meeting.microphone_request';
  bool get _microphoneLocked =>
      _room.localParticipant?.attributes[_micLockAttribute] == 'true';
  Timer? _videoStatsTimer;
  bool _readingVideoStats = false;
  bool _isMicEnabled = true;
  bool _isCameraEnabled = true;
  bool _showControls = true;
  bool _isConnecting = true;
  String? _connectionError;
  Timer? _roomCodeTimer;
  bool _showRoomCode = false;
  int _roomCodeSeconds = 30;
  String? _mainMemberId;
  MeetingChatController? _chatController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleControlsHide();
    _room =
        widget.room ??
        Room(
          roomOptions: const RoomOptions(
            adaptiveStream: true,
            dynacast: true,
            // Reduce camera/encoder load while keeping lower simulcast layers
            // available for participants on slower connections.
            defaultCameraCaptureOptions: CameraCaptureOptions(
              params: VideoParametersPresets.h540_169,
            ),
          ),
        );
    _credentials = widget.credentials;
    _connection = MeetingConnection(_room)..addListener(_onConnectionChanged);
    _room.addListener(_onRoomChanged);
    if (kDebugMode) {
      _videoStatsTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _logVideoStats(),
      );
    }
    final roomId = widget.credentials?.roomId;
    if (roomId != null) {
      _chatController = MeetingChatController(roomId: roomId)
        ..addListener(_onChatChanged)
        ..start();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _connectToRoom());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isNativePhone =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) &&
        MediaQuery.sizeOf(context).shortestSide < 600;
    if (isNativePhone && !_mobileDisplayActive) {
      _mobileDisplayActive = true;
      unawaited(_enterMobileDisplay());
    }
  }

  Future<void> _enterMobileDisplay() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!mounted || !_mobileDisplayActive) return;
    await _setFullscreen(true);
  }

  Future<void> _setFullscreen(bool enabled) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Use Android's insets controller directly for target SDK 36 as well.
      await _displayChannel.invokeMethod<void>('setFullscreen', enabled);
    } else {
      await SystemChrome.setEnabledSystemUIMode(
        enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_mobileDisplayActive && state == AppLifecycleState.resumed) {
      unawaited(_setFullscreen(true));
    }
  }

  @override
  void didChangeMetrics() {
    if (!_mobileDisplayActive) return;
    _systemUiTimer?.cancel();
    // Android briefly forces system bars visible after closing the keyboard.
    _systemUiTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted &&
          _mobileDisplayActive &&
          View.of(context).viewInsets.bottom == 0) {
        unawaited(_setFullscreen(true));
      }
    });
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

  Future<void> _connectToRoom() async {
    if (_isJoining) return;
    final credentials = _credentials;
    if (credentials == null) {
      setState(() {
        _isConnecting = false;
        _connectionError = 'Toplantı bilgileri bulunamadı';
      });
      _connection.fail('Toplantı bilgileri bulunamadı');
      return;
    }

    if (kIsWeb &&
        Uri.base.scheme != 'https' &&
        Uri.base.host != 'localhost' &&
        Uri.base.host != '127.0.0.1') {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectionError =
              'Telefon tarayıcısında kamera ve mikrofon için HTTPS gerekir. '
              'Uygulamayı güvenli bir HTTPS adresinden açın.';
        });
      }
      return;
    }

    _isJoining = true;
    _connection.startConnecting();
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        // Android 12+ requires runtime permission for Bluetooth headsets.
        // Denial still allows using the phone's microphone and speaker.
        await Permission.bluetoothConnect.request();
        if (!mounted) return;
      }
      await _room.connect(credentials.liveKitUrl, credentials.token);
      if (!mounted) return;
      _connection.markConnected();
      final mediaErrors = <String>[];
      // A microphone permission/device failure must not prevent video startup.
      try {
        final startMic = _isMicEnabled && !_microphoneLocked;
        await _room.localParticipant?.setMicrophoneEnabled(startMic);
        _isMicEnabled = startMic;
      } catch (error) {
        _isMicEnabled = false;
        mediaErrors.add('Mikrofon açılamadı: $error');
      }
      if (!mounted) return;
      try {
        await _room.localParticipant?.setCameraEnabled(_isCameraEnabled);
      } catch (error) {
        _isCameraEnabled = false;
        mediaErrors.add('Kamera açılamadı: $error');
      }
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _connectionError = mediaErrors.isEmpty
              ? null
              : mediaErrors.join('\n');
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
        _connection.fail(error);
      }
    } finally {
      _isJoining = false;
      if (mounted) _handleMicrophonePolicy();
    }
  }

  void _onConnectionChanged() {
    if (!mounted) return;
    if (!_connection.isConnected) _mainMemberId = null;
    developer.log(
      'phase=${_connection.phase.name} reason=${_connection.disconnectReason?.name} '
      'quality=${_connection.quality.name} room=${_credentials?.roomId}',
      name: 'meeting.connection',
    );
    setState(() {});
  }

  Future<void> _rejoinRoom() async {
    final previous = _credentials;
    if (previous == null || _isRejoining || _isJoining) return;
    setState(() {
      _isRejoining = true;
      _isConnecting = true;
      _connectionError = null;
    });
    _connection.startConnecting();
    try {
      await _room.disconnect();
      if (!mounted) return;
      _connection.startConnecting();
      // A new token also recovers expired credentials and stale server sessions.
      _credentials = await MeetingApi().joinRoom(
        roomId: previous.roomId,
        name: previous.participant,
      );
      if (!mounted) return;
      await _connectToRoom();
    } catch (error) {
      if (mounted) _connection.fail(error);
    } finally {
      if (mounted) {
        setState(() {
          _isRejoining = false;
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _logVideoStats() async {
    if (!_connection.isConnected || _readingVideoStats) return;
    _readingVideoStats = true;
    try {
      for (final participant in _room.remoteParticipants.values.toList()) {
        final track = _participantVideoTrack(participant);
        if (track is! RemoteVideoTrack) continue;
        final stats = await track.getReceiverStats();
        if (!mounted || stats == null) continue;
        // Never log access tokens or signaling URLs.
        developer.log(
          'room=${_credentials?.roomId} participantSid=${participant.sid} '
          'codec=${stats.mimeType} decoder=${stats.decoderImplementation} '
          'size=${stats.frameWidth}x${stats.frameHeight} fps=${stats.framesPerSecond} '
          'packets=${stats.packetsReceived} lost=${stats.packetsLost} '
          'bytes=${stats.bytesReceived} decoded=${stats.framesDecoded} '
          'dropped=${stats.framesDropped} jitter=${stats.jitter}',
          name: 'meeting.video',
        );
      }
    } catch (error) {
      developer.log(
        'Video statistics unavailable: ${error.runtimeType}',
        name: 'meeting.video',
      );
    } finally {
      _readingVideoStats = false;
    }
  }

  void _onRoomChanged() {
    if (!mounted) return;
    _handleMicrophonePolicy();
    final members = _members();
    final mainMember = selectMainMember(
      members,
      activeSpeakerIds: _room.activeSpeakers.map((p) => p.sid).toList(),
      previousSpeakerId: _mainMemberId,
    );
    setState(() => _mainMemberId = mainMember.id);
  }

  void _onChatChanged() {
    if (mounted) setState(() {});
  }

  List<MemberEntry> _members() {
    final local = _room.localParticipant;
    return [
      MemberEntry(
        id: local?.sid ?? 'local',
        name: widget.credentials?.participant ?? 'Sen',
        identity: local?.identity ?? '',
        isMicrophoneLocked: _microphoneLocked,
        isLocal: true,
        isMicEnabled: local?.isMicrophoneEnabled() ?? _isMicEnabled,
        isSpeaking: local?.isSpeaking ?? false,
        videoTrack: local == null ? null : _participantVideoTrack(local),
      ),
      if (_connection.isConnected)
        ..._room.remoteParticipants.values.map(
          (participant) => MemberEntry(
            id: participant.sid,
            identity: participant.identity,
            isMicrophoneLocked:
                participant.attributes[_micLockAttribute] == 'true',
            name: participant.name.isEmpty
                ? participant.identity
                : participant.name,
            isLocal: false,
            isMicEnabled: participant.isMicrophoneEnabled(),
            isSpeaking: participant.isSpeaking,
            videoTrack: _participantVideoTrack(participant),
          ),
        ),
    ];
  }

  void _handleMicrophonePolicy() {
    final local = _room.localParticipant;
    if (local == null) return;
    if (_microphoneLocked) {
      _isMicEnabled = false;
      if (local.isMicrophoneEnabled() && !_applyingMicLock) {
        unawaited(_disableLockedMicrophone(local));
      }
      return;
    }
    if (!_isConnecting) _isMicEnabled = local.isMicrophoneEnabled();
    final request = local.attributes[_micRequestAttribute];
    if (_isConnecting ||
        request == null ||
        request.isEmpty ||
        request == _lastUnmuteRequest ||
        _unmuteDialogOpen) {
      return;
    }
    _lastUnmuteRequest = request;
    _unmuteDialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _microphoneLocked) {
        _unmuteDialogOpen = false;
        return;
      }
      unawaited(_confirmUnmute());
    });
  }

  Future<void> _disableLockedMicrophone(LocalParticipant local) async {
    _applyingMicLock = true;
    try {
      await local.setMicrophoneEnabled(false);
    } catch (error) {
      if (mounted) {
        setState(() => _connectionError = 'Mikrofon kapatılamadı: $error');
      }
    } finally {
      _applyingMicLock = false;
    }
  }

  Future<void> _confirmUnmute() async {
    try {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Mikrofon açma isteği'),
          content: const Text(
            'Yönetici mikrofonunuzu açmanızı istiyor. Açmak istiyor musunuz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Şimdi değil'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Mikrofonu aç'),
            ),
          ],
        ),
      );
      if (accepted == true && mounted && !_microphoneLocked) {
        final local = _room.localParticipant;
        if (local == null) return;
        await local.setMicrophoneEnabled(true);
        if (_microphoneLocked) {
          await local.setMicrophoneEnabled(false);
          return;
        }
        if (mounted) setState(() => _isMicEnabled = true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _connectionError = 'Mikrofon açılamadı: $error');
      }
    } finally {
      _unmuteDialogOpen = false;
    }
  }

  Future<void> _moderateMicrophone(
    MemberEntry member,
    bool locked,
    bool requestUnmute,
  ) async {
    final credentials = _credentials;
    if (credentials == null || !credentials.isHost) return;
    await MeetingApi().setParticipantMicrophone(
      roomId: credentials.roomId,
      identity: member.identity,
      locked: locked,
      requestUnmute: requestUnmute,
    );
  }

  Future<void> _closeRoomForEveryone() async {
    final credentials = _credentials;
    if (credentials == null || !credentials.isHost || _endingRoom) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Toplantı herkes için bitirilsin mi?'),
        content: const Text(
          'Tüm katılımcıların bağlantısı kesilecek ve bu oda kodu tekrar kullanılamayacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Herkes için bitir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _endingRoom = true);
    try {
      await MeetingApi().closeRoom(credentials.roomId);
      if (mounted) _leaveMeeting();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _endingRoom = false);
    }
  }

  Future<void> _toggleMicrophone() async {
    if (_microphoneLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mikrofonunuz yönetici tarafından kilitlendi.'),
        ),
      );
      return;
    }
    final enabled = !_isMicEnabled;
    try {
      final participant = _room.localParticipant;
      if (participant == null) return;
      await participant.setMicrophoneEnabled(enabled);
      if (enabled && _microphoneLocked) {
        await participant.setMicrophoneEnabled(false);
        return;
      }
      if (mounted) setState(() => _isMicEnabled = enabled);
    } catch (error) {
      if (mounted) {
        setState(() => _connectionError = 'Mikrofon değiştirilemedi: $error');
      }
    }
  }

  Future<void> _toggleCamera() async {
    final enabled = !_isCameraEnabled;
    try {
      final participant = _room.localParticipant;
      if (participant == null) return;
      await participant.setCameraEnabled(enabled);
      if (mounted) setState(() => _isCameraEnabled = enabled);
    } catch (error) {
      if (mounted) {
        setState(() => _connectionError = 'Kamera değiştirilemedi: $error');
      }
    }
  }

  void _showRoomCodeForThirtySeconds() {
    _roomCodeTimer?.cancel();
    setState(() {
      _showRoomCode = true;
      _roomCodeSeconds = 30;
    });
    _roomCodeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_roomCodeSeconds <= 1) {
        timer.cancel();
        setState(() => _showRoomCode = false);
        return;
      }
      setState(() => _roomCodeSeconds--);
    });
  }

  void _closeRoomCode() {
    _roomCodeTimer?.cancel();
    setState(() => _showRoomCode = false);
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
          listenable: _room,
          builder: (context, _) => MembersScreen(
            members: _members(),
            isHost: _credentials?.isHost ?? false,
            onMicrophoneChange: _moderateMicrophone,
          ),
        ),
      ),
    );
  }

  VideoTrack? _participantVideoTrack(Participant participant) {
    final publication = participant.getTrackPublicationBySource(
      TrackSource.camera,
    );
    final track = publication?.track;
    return track is VideoTrack && !publication!.muted ? track : null;
  }

  void _openChatSheet() {
    final chatController = _chatController;
    if (chatController == null) return;
    chatController.setChatOpen(true);

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MeetingChatSheet(controller: chatController),
      ).whenComplete(() => chatController.setChatOpen(false)),
    );
  }

  void _leaveMeeting() {
    unawaited(_room.disconnect());
    Navigator.pop(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsTimer?.cancel();
    _systemUiTimer?.cancel();
    _videoStatsTimer?.cancel();
    _connection.removeListener(_onConnectionChanged);
    _connection.dispose();
    if (_mobileDisplayActive) {
      _mobileDisplayActive = false;
      unawaited(SystemChrome.setPreferredOrientations([]));
      unawaited(_setFullscreen(false));
    }
    _roomCodeTimer?.cancel();
    _room.removeListener(_onRoomChanged);
    _chatController
      ?..removeListener(_onChatChanged)
      ..dispose();
    unawaited(_room.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final members = _members();
    final mainMember = selectMainMember(
      members,
      activeSpeakerIds: _room.activeSpeakers.map((p) => p.sid).toList(),
      previousSpeakerId: _mainMemberId,
    );

    final isPhone = MediaQuery.sizeOf(context).shortestSide < 600;
    return Scaffold(
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
                      _isConnecting ||
                      _connection.phase == MeetingConnectionPhase.reconnecting,
                  onMainPageTap: _showMeetingControls,
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
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2C2C2E,
                            ).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ControlButton(
                                icon: _microphoneLocked
                                    ? Icons.lock_rounded
                                    : _isMicEnabled
                                    ? Icons.mic_rounded
                                    : Icons.mic_off_rounded,
                                isActive: _isMicEnabled && !_microphoneLocked,
                                onTap: _toggleMicrophone,
                              ),
                              const SizedBox(width: 16),
                              ControlButton(
                                icon: _isCameraEnabled
                                    ? Icons.videocam_rounded
                                    : Icons.videocam_off_rounded,
                                isActive: _isCameraEnabled,
                                onTap: _toggleCamera,
                              ),
                              const SizedBox(width: 16),
                              ControlButton(
                                icon: Icons.people_rounded,
                                isActive: true,
                                onTap: _openMembersSheet,
                              ),
                              const SizedBox(width: 16),
                              ControlButton(
                                icon: Icons.chat_bubble_rounded,
                                isActive: true,
                                showBadge:
                                    _chatController?.hasUnreadMessages ?? false,
                                onTap: _openChatSheet,
                              ),
                              const SizedBox(width: 16),
                              PopupMenuButton<String>(
                                tooltip: 'Daha fazla',
                                color: const Color(0xFF2C2C2E),
                                icon: const Icon(
                                  Icons.more_horiz_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onSelected: (value) {
                                  if (value == 'room_id') {
                                    _showRoomCodeForThirtySeconds();
                                  } else if (value == 'close_room') {
                                    unawaited(_closeRoomForEveryone());
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (_credentials?.isHost ?? false)
                                    PopupMenuItem<String>(
                                      value: 'close_room',
                                      enabled: !_endingRoom,
                                      child: const Text(
                                        'Toplantıyı herkes için bitir',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ),
                                  PopupMenuItem<String>(
                                    value: 'room_id',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.tag_rounded,
                                          color: Colors.white70,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          l10n.roomId,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                onPressed: _leaveMeeting,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.call_end_rounded),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_connection.message != null)
              Positioned(
                top: 16,
                left: 24,
                right: 24,
                child: SafeArea(
                  bottom: false,
                  child: Material(
                    color:
                        _connection.phase == MeetingConnectionPhase.disconnected
                        ? Colors.red.shade800
                        : const Color(0xEE2C2C2E),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isRejoining
                                ? 'Toplantıya tekrar katılınıyor…'
                                : _connection.message!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          if (_connection.phase ==
                                  MeetingConnectionPhase.disconnected &&
                              _connection.canRejoin &&
                              _credentials != null &&
                              !_isRejoining)
                            TextButton(
                              onPressed: _rejoinRoom,
                              child: const Text(
                                'Tekrar katıl',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_connectionError != null && _connection.message == null)
              Positioned(
                top: 16,
                left: 24,
                right: 24,
                child: Material(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _connectionError!,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            if (_showRoomCode && widget.credentials?.roomId != null)
              Positioned(
                top: 16,
                left: 24,
                right: 24,
                child: Material(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.meeting_room_rounded,
                          color: Color(0xFFB69BFF),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.roomId,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.credentials!.roomId,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$_roomCodeSeconds sn',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Kapat',
                          onPressed: _closeRoomCode,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
