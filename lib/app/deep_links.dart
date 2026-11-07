import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:v_meeting/app/invite.dart';

/// Invite links handed to the app by the operating system: Android intents
/// (reisub-meeting:// and verified https links) and, on Windows and Linux, the
/// command line the URL scheme handler starts the app with.
class DeepLinks {
  static const _channel = MethodChannel('reisub_meeting/links');

  /// The invite the app was launched with, if any.
  static Future<InviteLink?> launchInvite(List<String> args) async {
    if (kIsWeb) return null;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        return _parse(await _channel.invokeMethod<String>('getInitialLink'));
      } catch (_) {
        return null;
      }
    }
    for (final arg in args) {
      final invite = _parse(arg);
      if (invite != null) return invite;
    }
    return null;
  }

  /// Calls [onInvite] for links that arrive while the app is running. Only
  /// Android delivers these; desktop links start a new app window.
  static void listen(void Function(InviteLink invite) onInvite) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onLink') return;
      final invite = _parse(call.arguments as String?);
      if (invite != null) onInvite(invite);
    });
  }

  static InviteLink? _parse(String? link) {
    final uri = link == null ? null : Uri.tryParse(link);
    return uri == null ? null : parseInviteLink(uri);
  }
}
