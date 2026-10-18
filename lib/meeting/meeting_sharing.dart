import 'package:v_meeting/l10n/localized_error.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'meeting_api.dart';

class MeetingSharing extends ChangeNotifier {
  MeetingSharing({required this.roomId, required this.api});

  final String roomId;
  final MeetingApi api;
  MeetingState state = const MeetingState();
  Object? error;
  bool loaded = false;
  bool updating = false;
  bool _refreshing = false;
  bool _disposed = false;
  Timer? _timer;

  void start() {
    unawaited(refresh());
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
  }

  void _accept(MeetingState value) {
    if (_disposed) return;
    state = value;
    loaded = true;
    error = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_refreshing || updating || _disposed) return;
    _refreshing = true;
    final revision = _revision;
    try {
      final value = await api.getMeetingState(roomId);
      // An older poll must not overwrite a just-completed mutation.
      if (!updating && revision == _revision) _accept(value);
    } catch (e) {
      if (!_disposed) {
        error = e;
        notifyListeners();
      }
    } finally {
      _refreshing = false;
    }
  }

  int _revision = 0;
  Future<void> _update(Future<MeetingState> Function() request) async {
    updating = true;
    _revision++;
    if (!_disposed) notifyListeners();
    try {
      _accept(await request());
    } finally {
      updating = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> setAllowed(bool value) =>
      _update(() => api.updateMeetingSettings(roomId, allowScreenShare: value));
  Future<void> acquire(String identity) =>
      _update(() => api.startScreenShare(roomId, identity));
  Future<void> release(String identity) =>
      _update(() => api.stopScreenShare(roomId, identity));

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

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
