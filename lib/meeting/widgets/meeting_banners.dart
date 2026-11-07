import 'dart:async';

import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

/// Connection status at the top of the meeting, with an optional rejoin action.
class MeetingConnectionBanner extends StatelessWidget {
  const MeetingConnectionBanner({
    super.key,
    required this.message,
    required this.disconnected,
    this.onRejoin,
  });

  final String message;
  final bool disconnected;
  final VoidCallback? onRejoin;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Material(
        color: disconnected ? Colors.red.shade800 : const Color(0xEE2C2C2E),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              if (onRejoin != null)
                TextButton(
                  onPressed: onRejoin,
                  child: Text(
                    AppLocalizations.of(context)!.rejoinMeeting,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Media and meeting errors, with shortcuts to Windows privacy settings.
class MeetingErrorBanner extends StatelessWidget {
  const MeetingErrorBanner({
    super.key,
    required this.message,
    this.onMicrophonePrivacy,
    this.onCameraPrivacy,
  });

  final String message;
  final VoidCallback? onMicrophonePrivacy;
  final VoidCallback? onCameraPrivacy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.red.shade700,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            if (onMicrophonePrivacy != null || onCameraPrivacy != null)
              Wrap(
                spacing: 12,
                children: [
                  if (onMicrophonePrivacy != null)
                    TextButton(
                      onPressed: onMicrophonePrivacy,
                      child: Text(
                        l10n.microphonePrivacySettings,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  if (onCameraPrivacy != null)
                    TextButton(
                      onPressed: onCameraPrivacy,
                      child: Text(
                        l10n.cameraPrivacySettings,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Shows the room code for [visibleFor], counting down, then calls [onClose].
class RoomCodeBanner extends StatefulWidget {
  const RoomCodeBanner({
    super.key,
    required this.roomId,
    required this.onClose,
    this.visibleFor = const Duration(seconds: 30),
  });

  final String roomId;
  final VoidCallback onClose;
  final Duration visibleFor;

  @override
  State<RoomCodeBanner> createState() => _RoomCodeBannerState();
}

class _RoomCodeBannerState extends State<RoomCodeBanner> {
  late int _secondsLeft = widget.visibleFor.inSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        widget.onClose();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: const Color(0xFF2C2C2E),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            const Icon(Icons.meeting_room_rounded, color: Color(0xFFB69BFF)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.roomId,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.roomId,
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
              l10n.secondsRemaining(_secondsLeft),
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            IconButton(
              tooltip: l10n.close,
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
