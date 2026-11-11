import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/l10n/localized_error.dart';

/// Microphone and camera tests during a meeting.
class AudioVideoSettingsDialog extends StatelessWidget {
  const AudioVideoSettingsDialog({super.key, this.onDeviceTest});
  final Future<void> Function(bool camera)? onDeviceTest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.audioVideoSettings),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mic_rounded),
                title: Text(l10n.microphoneSelectionTest),
                subtitle: Text(l10n.audioInputHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: onDeviceTest == null ? null : () => onDeviceTest!(false),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.videocam_rounded),
                title: Text(l10n.cameraSelectionTest),
                subtitle: Text(l10n.cameraInputHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: onDeviceTest == null ? null : () => onDeviceTest!(true),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

/// Meeting settings for people who may let others in: the waiting room,
/// and whether to be told when someone arrives.
class MeetingSettingsDialog extends StatefulWidget {
  const MeetingSettingsDialog({
    super.key,
    required this.listenable,
    required this.waitingRoomOn,
    required this.onWaitingRoomChanged,
    required this.notifyArrivals,
    required this.onNotifyArrivalsChanged,
  });

  /// Rebuilds the dialog when the room's settings change.
  final Listenable listenable;
  final bool Function() waitingRoomOn;

  /// Throws the server's error so the dialog can show it.
  final Future<void> Function(bool on) onWaitingRoomChanged;
  final bool notifyArrivals;
  final ValueChanged<bool> onNotifyArrivalsChanged;

  @override
  State<MeetingSettingsDialog> createState() => _MeetingSettingsDialogState();
}

class _MeetingSettingsDialogState extends State<MeetingSettingsDialog> {
  late bool _notifyArrivals = widget.notifyArrivals;

  /// The waiting room switch while the server has not yet confirmed it.
  bool? _pendingWaitingRoom;
  Object? _error;

  Future<void> _setWaitingRoom(bool on) async {
    setState(() {
      _pendingWaitingRoom = on;
      _error = null;
    });
    try {
      await widget.onWaitingRoomChanged(on);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _pendingWaitingRoom = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: widget.listenable,
      builder: (context, _) => AlertDialog(
        title: Text(l10n.meetingSettings),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  key: const ValueKey('setting-waiting-room'),
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.hourglass_top_rounded),
                  title: Text(l10n.waitingRoom),
                  subtitle: Text(l10n.waitingRoomHint),
                  value: _pendingWaitingRoom ?? widget.waitingRoomOn(),
                  onChanged: _pendingWaitingRoom == null
                      ? _setWaitingRoom
                      : null,
                ),
                SwitchListTile(
                  key: const ValueKey('setting-notify-arrivals'),
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.notifications_active_rounded),
                  title: Text(l10n.notifyArrivals),
                  subtitle: Text(l10n.notifyArrivalsHint),
                  value: _notifyArrivals,
                  onChanged: (on) {
                    setState(() => _notifyArrivals = on);
                    widget.onNotifyArrivalsChanged(on);
                  },
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      localizeError(_error!, l10n),
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }
}
