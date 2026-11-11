import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:v_meeting/auth/account.dart';
import 'package:v_meeting/auth/auth_api.dart';
import 'package:v_meeting/auth/login_screen.dart';
import 'package:v_meeting/auth/server_config.dart';

/// The rules a meeting server sets for its users.
@immutable
class ServerPolicy {
  const ServerPolicy({
    required this.guestsAllowed,
    this.reported = true,
    this.meetingTimeLimit,
    this.meetingCooldown,
  });

  /// A server too old to state its rules; it lets guests in.
  static const legacy = ServerPolicy(guestsAllowed: true, reported: false);

  /// Whether meetings can be used without an account.
  final bool guestsAllowed;

  /// False when the server does not state its rules.
  final bool reported;

  /// How long a meeting may last; null for no limit.
  final Duration? meetingTimeLimit;

  /// How long someone waits, after their meeting reached the limit, before
  /// starting another; null for no wait.
  final Duration? meetingCooldown;

  factory ServerPolicy.fromJson(Map<String, dynamic> json) => ServerPolicy(
    guestsAllowed: json['guests_allowed'] as bool? ?? true,
    meetingTimeLimit: _minutes(json['meeting_time_limit_minutes']),
    meetingCooldown: _minutes(json['meeting_cooldown_minutes']),
  );

  /// Zero, missing or not a number means none.
  static Duration? _minutes(Object? value) =>
      value is num && value > 0 ? Duration(minutes: value.round()) : null;

  @override
  bool operator ==(Object other) =>
      other is ServerPolicy &&
      other.guestsAllowed == guestsAllowed &&
      other.reported == reported &&
      other.meetingTimeLimit == meetingTimeLimit &&
      other.meetingCooldown == meetingCooldown;

  @override
  int get hashCode =>
      Object.hash(guestsAllowed, reported, meetingTimeLimit, meetingCooldown);
}

/// The saved server's rules, read when the app starts or the server
/// changes. Null without a server, or when it can't be reached.
final serverPolicyProvider = FutureProvider<ServerPolicy?>((ref) async {
  final serverUrl = await ServerConfig.readUrl();
  if (serverUrl == null) return null;
  try {
    return await ref.read(authApiProvider).fetchPolicy(serverUrl);
  } catch (_) {
    return null;
  }
});

/// Whether the server takes no guests while nobody is signed in, asked of
/// the server right now.
Future<bool> loginNeeded(WidgetRef ref) async {
  final serverUrl = await ServerConfig.readUrl();
  if (serverUrl == null) return false;
  ServerPolicy policy;
  try {
    policy = await ref.read(authApiProvider).fetchPolicy(serverUrl);
  } catch (_) {
    // Unreachable: the meeting request itself will report it.
    return false;
  }
  if (policy.guestsAllowed) return false;
  return !await ref.read(signedInProvider.future);
}

/// Called before joining or creating a meeting. When the server takes no
/// guests and nobody is signed in, opens the login screen; returns whether
/// to go on.
Future<bool> ensureMayEnterMeeting(BuildContext context, WidgetRef ref) async {
  if (!await loginNeeded(ref)) return true;
  if (!context.mounted) return false;
  final signedIn = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen(guestsRefused: true)),
  );
  return signedIn == true;
}
