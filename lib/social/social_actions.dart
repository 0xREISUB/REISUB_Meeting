import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/auth/account.dart';
import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/l10n/localized_error.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/meeting/meeting_screen.dart';
import 'package:v_meeting/meeting/waiting_room_screen.dart';
import 'package:v_meeting/social/social_api.dart';

/// Runs a social action, showing what went wrong if it fails. Returns
/// whether it succeeded; the overview is read again either way.
Future<bool> runSocialAction(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context)!;
  try {
    await action();
    return true;
  } on MeetingApiException catch (error) {
    if (error.sessionExpired) ref.read(signedInProvider.notifier).refresh();
    messenger.showSnackBar(SnackBar(content: Text(localizeError(error, l10n))));
    return false;
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(localizeError(error, l10n))));
    return false;
  } finally {
    ref.read(socialOverviewProvider.notifier).refresh();
  }
}

/// Joins the meeting in [roomId] as the user's display name, through the
/// waiting room when it is on.
Future<void> joinSocialMeeting(
  BuildContext context,
  WidgetRef ref,
  String roomId,
) async {
  final name =
      ref.read(socialOverviewProvider).value?.profile.displayName ?? '';
  final navigator = Navigator.of(context);
  await runSocialAction(context, ref, () async {
    final result = await ref
        .read(meetingApiProvider)
        .joinRoom(roomId: roomId, name: name);
    switch (result) {
      case JoinAdmitted(:final credentials):
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => MeetingScreen(credentials: credentials),
          ),
        );
      case JoinWaiting(:final requestId):
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                WaitingRoomScreen(roomId: roomId, requestId: requestId),
          ),
        );
    }
  });
}

/// Asks for one line of text, such as a friend's username or a team's
/// name; null when cancelled.
Future<String?> askForText(
  BuildContext context, {
  required String title,
  required String label,
  required String action,
  IconData icon = Icons.edit_outlined,
}) => showDialog<String>(
  context: context,
  builder: (context) =>
      _TextDialog(title: title, label: label, action: action, icon: icon),
);

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.label,
    required this.action,
    required this.icon,
  });

  final String title;
  final String label;
  final String action;
  final IconData icon;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  // Owned here, so it lives as long as the field, through the dialog's
  // closing animation.
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('social-text-input'),
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: Icon(widget.icon),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        FilledButton(
          key: const ValueKey('social-text-submit'),
          onPressed: _submit,
          child: Text(widget.action),
        ),
      ],
    );
  }
}

/// Asks before something that cannot be undone; true to go on.
Future<bool> confirmSocial(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        FilledButton(
          key: const ValueKey('social-confirm'),
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
