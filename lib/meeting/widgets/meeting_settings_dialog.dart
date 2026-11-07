import 'package:flutter/material.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/l10n/localized_error.dart';
import 'package:v_meeting/meeting/meeting_sharing.dart';

/// In-meeting settings: device tests for everyone, screen-share policy for
/// the host.
class MeetingSettingsDialog extends StatelessWidget {
  const MeetingSettingsDialog({super.key, this.sharing, this.onDeviceTest});
  final MeetingSharing? sharing;
  final Future<void> Function(bool camera)? onDeviceTest;

  @override
  Widget build(BuildContext context) {
    final sharing = this.sharing;
    return sharing == null
        ? _dialog(context)
        : ListenableBuilder(
            listenable: sharing,
            builder: (context, _) => _dialog(context),
          );
  }

  Widget _dialog(BuildContext context) {
    final sharing = this.sharing;
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.meetingSettings),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mic_rounded),
                title: Text(
                  AppLocalizations.of(context)!.microphoneSelectionTest,
                ),
                subtitle: Text(AppLocalizations.of(context)!.audioInputHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: onDeviceTest == null ? null : () => onDeviceTest!(false),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.videocam_rounded),
                title: Text(AppLocalizations.of(context)!.cameraSelectionTest),
                subtitle: Text(AppLocalizations.of(context)!.cameraInputHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: onDeviceTest == null ? null : () => onDeviceTest!(true),
              ),
              if (sharing != null) ...[
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(AppLocalizations.of(context)!.allowScreenSharing),
                  subtitle: Text(
                    AppLocalizations.of(context)!.oneScreenShareHint,
                  ),
                  value: sharing.state.allowParticipantScreenShare,
                  onChanged: !sharing.loaded || sharing.updating
                      ? null
                      : (value) async {
                          try {
                            await sharing.setAllowed(value);
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    localizeError(
                                      error,
                                      AppLocalizations.of(context)!,
                                    ),
                                  ),
                                ),
                              );
                            }
                          }
                        },
                ),
                if (sharing.error != null)
                  Text(
                    localizeError(
                      sharing.error!,
                      AppLocalizations.of(context)!,
                    ),
                    style: const TextStyle(color: Colors.redAccent),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.close),
        ),
      ],
    );
  }
}
