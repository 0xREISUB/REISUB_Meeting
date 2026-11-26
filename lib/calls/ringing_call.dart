import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/social/social_models.dart';

/// A call ringing for this user: a friend calling, or a team's meeting
/// starting.
class RingingCall {
  const RingingCall({
    required this.id,
    required this.roomId,
    required this.caller,
    required this.title,
    required this.kind,
    required this.targetId,
    required this.secret,
    required this.endsAt,
  });

  /// From the realtime connection's "call".
  static RingingCall? fromJson(Object? json) {
    if (json is! Map) return null;
    return _from(
      id: json['id'],
      roomId: json['room_id'],
      caller: json['caller'],
      title: json['title'],
      kind: json['kind'],
      targetId: json['target_id'],
      secret: json['secret'],
      endsAt: json['ends_at'],
    );
  }

  /// From a push's data.
  static RingingCall? fromPush(Map<String, dynamic> data) => _from(
    id: data['call_id'],
    roomId: data['room_id'],
    caller: data['caller'],
    title: data['title'],
    kind: data['kind'],
    targetId: data['target_id'],
    secret: data['secret'],
    endsAt: data['ends_at'],
  );

  static RingingCall? _from({
    required Object? id,
    required Object? roomId,
    required Object? caller,
    required Object? title,
    required Object? kind,
    required Object? targetId,
    required Object? secret,
    required Object? endsAt,
  }) {
    final callId = '${id ?? ''}';
    final room = '${roomId ?? ''}';
    if (callId.isEmpty || room.isEmpty) return null;
    return RingingCall(
      id: callId,
      roomId: room,
      caller: '${caller ?? ''}',
      title: '${title ?? ''}',
      kind: '${kind ?? ''}',
      targetId: '${targetId ?? ''}',
      secret: '${secret ?? ''}',
      endsAt:
          DateTime.tryParse('${endsAt ?? ''}') ??
          DateTime.now().add(const Duration(seconds: 45)),
    );
  }

  final String id;
  final String roomId;
  final String caller;

  /// Who or where: the caller, or the team's name.
  final String title;
  final String kind;
  final String targetId;

  /// Lets a phone answer from its notification without the app.
  final String secret;
  final DateTime endsAt;

  bool get team => kind == 'team';

  /// The conversation the call came from.
  ChatTarget get target =>
      ChatTarget.of(kind: kind, id: targetId, title: title);

  /// Under the name: "is calling you", or for a team who started it.
  String subtitle(AppLocalizations l10n) =>
      team ? l10n.callTeamIncoming(caller) : l10n.callIncoming;

  /// What a missed call says: who called, and for a team where.
  String missedText() => team ? '$title · $caller' : title;
}

/// A call that stopped ringing, as "call_end" (realtime or push) describes
/// it: enough to stop it and leave a missed call.
RingingCall endedCall(Map<dynamic, dynamic> info) => RingingCall(
  id: '${info['id'] ?? info['call_id'] ?? ''}',
  roomId: '',
  caller: '${info['caller'] ?? ''}',
  title: '${info['title'] ?? ''}',
  kind: '${info['kind'] ?? ''}',
  targetId: '${info['target_id'] ?? ''}',
  secret: '',
  endsAt: DateTime.now(),
);
