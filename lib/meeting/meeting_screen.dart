import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'members_screen.dart';
import 'widgets/meeting_components.dart';
import 'package:livekit_client/livekit_client.dart';


class MeetingScreen extends StatefulWidget {
  final String livekitToken;
  final String roomUrl;
  final int totalMembers;
  const MeetingScreen({
    super.key, 
    required this.livekitToken, 
    this.roomUrl = 'ws://127.0.0.1:7880',
    this.totalMembers = 19
    });

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {

  late final Room _room;
  EventsListener<RoomEvent>? _listener;
  VideoTrack? _localVideoTrack;

  bool _isMicEnabled = true;
  bool _isCameraEnabled = true;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _connectToRoom();
  }

  Future<void> _connectToRoom() async {
    _room = Room();
    _listener = _room.createListener();

    try {
      await _room.connect(widget.roomUrl, widget.livekitToken);
      await _room.localParticipant?.setCameraEnabled(true);
      await _room.localParticipant?.setMicrophoneEnabled(true);

      if (mounted) {
        setState(() {
          _localVideoTrack = _room.localParticipant?.videoTrackPublications.firstOrNull?.track as VideoTrack?;
        });
      }
    } catch (e) {
      print("LiveKit Bağlantı Hatası: $e");
    }
  }

  @override
  void dispose() {
    _listener?.dispose();
    _room.disconnect();
    super.dispose();
  }

  void _toggleControls() => setState(() => _showControls = !_showControls);
  void _handleLeaveOrEndMeeting() => Navigator.pop(context);
  
  void _openMembersScreen() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => MembersScreen(totalMembers: widget.totalMembers)));
  }

  void _openChatSheet() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.65,
            decoration: const BoxDecoration(color: Color(0xFF1C1C1E), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(99))),
                const SizedBox(height: 16),
                Text(l10n.chatTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Colors.white12),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: l10n.messageHint, hintStyle: const TextStyle(color: Colors.white38),
                              filled: true, fillColor: const Color(0xFF2C2C2E),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 24, backgroundColor: const Color(0xFF8A5CFF),
                          child: IconButton(onPressed: () {}, icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20)),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: GestureDetector(
          onTap: _toggleControls,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white12)),
                        child: Stack(
                          children: [
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircleAvatar(radius: 40, backgroundColor: Color(0xFF2C2C2E), child: Icon(Icons.person, size: 40, color: Colors.white54)),
                                  const SizedBox(height: 16),
                                  Text(l10n.mainVideoLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white70)),
                                ],
                              ),
                            ),
                            Positioned(
                              left: 16, bottom: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.mic_off, size: 14, color: Colors.redAccent),
                                    const SizedBox(width: 6),
                                    Text(l10n.speakerLabel, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  ],
                                ),
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
                          itemCount: 5,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => ParticipantTile(index: index),
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                bottom: _showControls ? 32 : -100, left: 0, right: 0,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ControlButton(
                            icon: _isMicEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                            isActive: _isMicEnabled,
                            onTap: () => setState(() => _isMicEnabled = !_isMicEnabled),
                          ),
                          const SizedBox(width: 16),
                          ControlButton(
                            icon: _isCameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                            isActive: _isCameraEnabled,
                            onTap: () => setState(() => _isCameraEnabled = !_isCameraEnabled),
                          ),
                          const SizedBox(width: 16),
                          ControlButton(icon: Icons.people_rounded, isActive: true, onTap: _openMembersScreen),
                          const SizedBox(width: 16),
                          ControlButton(icon: Icons.chat_bubble_rounded, isActive: true, onTap: _openChatSheet),
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: _handleLeaveOrEndMeeting,
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(30)),
                              child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 24),
                            ),
                          ),
                        ],
                      ),
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