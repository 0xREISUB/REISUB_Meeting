import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/meeting/members_screen.dart';
import 'widgets/meeting_components.dart';

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

  @override
  void initState() {
    super.initState();
    _room = Room();
    _room.addListener(_onRoomChanged);
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
      await _room.connect(credentials.liveKitUrl, credentials.token);
      await _room.localParticipant?.setMicrophoneEnabled(_isMicEnabled);
      await _room.localParticipant?.setCameraEnabled(_isCameraEnabled);
      if (mounted) setState(() => _isConnecting = false);
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
    if (mounted) setState(() {});
  }

  VideoTrack? _localVideoTrack() {
    for (final publication
        in _room.localParticipant?.videoTrackPublications ?? const []) {
      final track = publication.track;
      if (track is VideoTrack && !publication.muted) return track;
    }
    return null;
  }

  Future<void> _toggleMicrophone() async {
    final enabled = !_isMicEnabled;
    setState(() => _isMicEnabled = enabled);
    await _room.localParticipant?.setMicrophoneEnabled(enabled);
  }

  Future<void> _toggleCamera() async {
    final enabled = !_isCameraEnabled;
    setState(() => _isCameraEnabled = enabled);
    await _room.localParticipant?.setCameraEnabled(enabled);
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

  void _openMembersScreen() {
    final members = <MemberEntry>[
      MemberEntry(
        name: widget.credentials?.participant ?? 'Sen',
        isLocal: true,
        isMicEnabled: _isMicEnabled,
        videoTrack: _localVideoTrack(),
      ),
      ..._room.remoteParticipants.values.map(
        (participant) => MemberEntry(
          name: participant.name.isEmpty
              ? participant.identity
              : participant.name,
          isLocal: false,
          isMicEnabled: !participant.isMuted,
          videoTrack: _participantVideoTrack(participant),
        ),
      ),
    ];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MembersScreen(
          totalMembers: members.length,
          members: members,
        ),
      ),
    );
  }

  VideoTrack? _participantVideoTrack(RemoteParticipant participant) {
    for (final publication in participant.videoTrackPublications) {
      final track = publication.track;
      if (track is VideoTrack && !publication.muted) return track;
    }
    return null;
  }

  void _openChatSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.65,
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.chatTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(height: 24, color: Colors.white12),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ChatBubble(message: l10n.chatMessage1, isMe: true),
                      const SizedBox(height: 12),
                      ChatBubble(message: l10n.chatMessage2, isMe: false),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: l10n.messageHint,
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF2C2C2E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    unawaited(_room.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localTrack = _localVideoTrack();
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final remoteParticipants = _room.remoteParticipants.values.toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => setState(() => _showControls = !_showControls),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Stack(
                          children: [
                            if (localTrack != null)
                              Positioned.fill(
                                child: VideoTrackRenderer(
                                  localTrack,
                                  fit: VideoViewFit.cover,
                                  mirrorMode: VideoViewMirrorMode.mirror,
                                ),
                              )
                            else
                              Center(
                                child: Text(
                                  _isConnecting
                                      ? 'Bağlanıyor...'
                                      : l10n.mainVideoLabel,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            Positioned(
                              left: 16,
                              bottom: 16,
                              child: Text(
                                widget.credentials?.participant ??
                                    l10n.speakerLabel,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isDesktop) const SizedBox(width: 16),
                    if (isDesktop)
                      SizedBox(
                        width: 260,
                        child: ListView.separated(
                          itemCount: remoteParticipants.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => _RemoteParticipantTile(
                            participant: remoteParticipants[index],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                bottom: _showControls ? 32 : -100,
                left: 0,
                right: 0,
                child: Center(
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
                          onTap: _openMembersScreen,
                        ),
                        const SizedBox(width: 16),
                        ControlButton(
                          icon: Icons.chat_bubble_rounded,
                          isActive: true,
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
                                    style: const TextStyle(color: Colors.white),
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

class _RemoteParticipantTile extends StatelessWidget {
  final RemoteParticipant participant;

  const _RemoteParticipantTile({required this.participant});

  VideoTrack? _videoTrack() {
    for (final publication in participant.videoTrackPublications) {
      final track = publication.track;
      if (track is VideoTrack && !publication.muted) return track;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final track = _videoTrack();
    final displayName = participant.name.isEmpty
        ? participant.identity
        : participant.name;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Stack(
          children: [
            if (track != null)
              Positioned.fill(
                child: VideoTrackRenderer(
                  track,
                  fit: VideoViewFit.cover,
                ),
              )
            else
              const Center(
                child: Icon(Icons.person, size: 32, color: Colors.white54),
              ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      participant.isMuted ? Icons.mic_off : Icons.mic,
                      color: participant.isMuted
                          ? Colors.redAccent
                          : Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
