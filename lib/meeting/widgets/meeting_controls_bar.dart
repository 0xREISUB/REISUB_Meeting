import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

/// The floating bar with microphone, camera, people, chat, screen-share,
/// more-options and leave buttons.
class MeetingControlsBar extends StatelessWidget {
  const MeetingControlsBar({
    super.key,
    required this.microphoneLocked,
    required this.microphoneEnabled,
    required this.cameraEnabled,
    required this.hasUnreadMessages,
    required this.sharingScreen,
    required this.screenSharingAllowed,
    this.screenShareBusy = false,
    required this.onToggleMicrophone,
    required this.onToggleCamera,
    required this.onOpenMembers,
    required this.onOpenChat,
    required this.onToggleScreenShare,
    required this.onOpenSettings,
    required this.onShowRoomCode,
    required this.onLeave,
  });

  final bool microphoneLocked;
  final bool microphoneEnabled;
  final bool cameraEnabled;
  final bool hasUnreadMessages;
  final bool sharingScreen;
  final bool screenSharingAllowed;

  /// Someone else is sharing; only one share is allowed at a time.
  final bool screenShareBusy;
  final VoidCallback onToggleMicrophone;
  final VoidCallback onToggleCamera;
  final VoidCallback onOpenMembers;
  final VoidCallback onOpenChat;

  /// Null disables the screen-share button.
  final VoidCallback? onToggleScreenShare;
  final VoidCallback onOpenSettings;
  final VoidCallback onShowRoomCode;

  /// Null disables the leave button, e.g. while the meeting is being ended.
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          ControlButton(
            icon: microphoneLocked
                ? Icons.lock_rounded
                : microphoneEnabled
                ? Icons.mic_rounded
                : Icons.mic_off_rounded,
            isActive: microphoneEnabled && !microphoneLocked,
            onTap: onToggleMicrophone,
          ),
          ControlButton(
            icon: cameraEnabled
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            isActive: cameraEnabled,
            onTap: onToggleCamera,
          ),
          ControlButton(
            icon: Icons.people_rounded,
            isActive: true,
            onTap: onOpenMembers,
          ),
          ControlButton(
            icon: Icons.chat_bubble_rounded,
            isActive: true,
            showBadge: hasUnreadMessages,
            onTap: onOpenChat,
          ),
          IconButton(
            tooltip: sharingScreen
                ? l10n.stopScreenSharing
                : screenShareBusy
                ? l10n.screenShareInUse
                : screenSharingAllowed
                ? l10n.shareScreen
                : l10n.screenSharingDisabled,
            onPressed: onToggleScreenShare,
            icon: Icon(
              sharingScreen
                  ? Icons.stop_screen_share_rounded
                  : Icons.screen_share_rounded,
            ),
            color: sharingScreen ? Colors.redAccent : Colors.white,
          ),
          PopupMenuButton<String>(
            tooltip: l10n.moreOptions,
            color: const Color(0xFF2C2C2E),
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: Colors.white,
              size: 28,
            ),
            onSelected: (value) {
              if (value == 'room_id') {
                onShowRoomCode();
              } else if (value == 'meeting_settings') {
                onOpenSettings();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'meeting_settings',
                child: Text(
                  l10n.meetingSettings,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              PopupMenuItem<String>(
                value: 'room_id',
                child: Row(
                  children: [
                    const Icon(Icons.tag_rounded, color: Colors.white70),
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
          IconButton(
            onPressed: onLeave,
            tooltip: l10n.leaveMeeting,
            style: IconButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.call_end_rounded),
          ),
        ],
      ),
    );
  }
}

/// A round toggle: dark grey when on, red when off.
class ControlButton extends StatelessWidget {
  const ControlButton({
    super.key,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.showBadge = false,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final background = isActive ? const Color(0xFF3A3A3C) : Colors.redAccent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            if (showBadge)
              Positioned(
                top: -2,
                right: -3,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF3A3A3C)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
