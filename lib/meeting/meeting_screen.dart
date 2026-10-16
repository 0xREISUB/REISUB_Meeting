import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/meeting/meeting_chat.dart';
import 'package:v_meeting/meeting/members_screen.dart';
import 'widgets/meeting_components.dart';
import 'widgets/meeting_participant.dart';

class MeetingScreen extends StatefulWidget {
  final RoomCredentials? credentials;

  const MeetingScreen({super.key, this.credentials});

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  late final Room _room;
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
    _room = Room(
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
    _room.addListener(_onRoomChanged);
    final roomId = widget.credentials?.roomId;
    if (roomId != null) {
      _chatController = MeetingChatController(roomId: roomId)
        ..addListener(_onChatChanged)
        ..start();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _connectToRoom());
  }

  Future<void> _connectToRoom() async {
    final credentials = widget.credentials;
    if (credentials == null) {
      setState(() {
        _isConnecting = false;
        _connectionError = 'Toplantı bilgileri bulunamadı';
      });
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

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        // Android 12+ requires runtime permission for Bluetooth headsets.
        // Denial still allows using the phone's microphone and speaker.
        await Permission.bluetoothConnect.request();
        if (!mounted) return;
      }
      await _room.connect(credentials.liveKitUrl, credentials.token);
      if (!mounted) return;
      final mediaErrors = <String>[];
      // A microphone permission/device failure must not prevent video startup.
      try {
        await _room.localParticipant?.setMicrophoneEnabled(_isMicEnabled);
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
          _connectionError = 'Toplantıya bağlanılamadı: $error';
        });
      }
    }
  }

  void _onRoomChanged() {
    if (!mounted) return;
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
        isLocal: true,
        isMicEnabled: local?.isMicrophoneEnabled() ?? _isMicEnabled,
        isSpeaking: local?.isSpeaking ?? false,
        videoTrack: local == null ? null : _participantVideoTrack(local),
      ),
      ..._room.remoteParticipants.values.map(
        (participant) => MemberEntry(
          id: participant.sid,
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

  Future<void> _toggleMicrophone() async {
    final enabled = !_isMicEnabled;
    try {
      final participant = _room.localParticipant;
      if (participant == null) return;
      await participant.setMicrophoneEnabled(enabled);
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
            names: _members().map((member) => member.name).toList(),
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => setState(() => _showControls = !_showControls),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    MediaQuery.sizeOf(context).width > 800 && _showControls
                        ? 120
                        : 16,
                  ),
                  child: MeetingVideoLayout(
                    members: members,
                    mainMember: mainMember,
                    connecting: _isConnecting,
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                bottom: _showControls ? 32 : -100,
                left: 0,
                right: 0,
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
                          color: const Color(0xFF2C2C2E).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ControlButton(
                              icon: _isMicEnabled
                                  ? Icons.mic_rounded
                                  : Icons.mic_off_rounded,
                              isActive: _isMicEnabled,
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
                                }
                              },
                              itemBuilder: (context) => [
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
              if (_connectionError != null)
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
      ),
    );
  }
}
