import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';

/// In-meeting settings: microphone and camera tests. Who may share the
/// screen is set per person in the permissions window.
class MeetingSettingsDialog extends StatelessWidget {
  const MeetingSettingsDialog({super.key, this.onDeviceTest});
  final Future<void> Function(bool camera)? onDeviceTest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.meetingSettings),
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
