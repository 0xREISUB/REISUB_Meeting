import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/social/social_models.dart';

/// A notification for the system to show: a new message or call in a
/// conversation.
class SystemNotice {
  const SystemNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.target,
  });

  /// The same for the same message, however it arrived, so it is shown
  /// once.
  final int id;
  final String title;
  final String body;

  /// The conversation to open when it is tapped.
  final ChatTarget target;

  /// What a tap hands back: the conversation, as "kind|id|title".
  String get payload => '${target.kind}|${target.targetId}|$title';

  /// The conversation a [payload] names; null if it is not one.
  static ChatTarget? targetOf(String? payload) {
    final parts = payload?.split('|');
    if (parts == null || parts.length < 3) return null;
    final kind = parts[0];
    if (kind != 'friend' && kind != 'team') return null;
    return ChatTarget.of(
      kind: kind,
      id: parts[1],
      title: parts.sublist(2).join('|'),
    );
  }

  /// Notification ids are 31-bit; message ids stay well below that.
  static int idFor(int messageId) => messageId & 0x7fffffff;

  /// For a message that came over the app's own connection: the text is
  /// here, so it is shown.
  factory SystemNotice.forMessage(
    SocialNotification notification,
    AppLocalizations l10n,
  ) {
    final message = notification.message;
    final team = notification.target.team != null;
    String body;
    if (message.roomId != null) {
      body = l10n.notificationCall(message.sender);
    } else if (team) {
      body = l10n.notificationFromSender(message.sender, message.text);
    } else {
      body = message.text;
    }
    return SystemNotice(
      id: idFor(message.id),
      title: notification.title,
      body: body,
      target: notification.target,
    );
  }

  /// For a push: who wrote, where, and what. A push without the text says
  /// "new message". Null if it is not a message push.
  static SystemNotice? forPush(
    Map<String, dynamic> data,
    AppLocalizations l10n,
  ) {
    final messageId = int.tryParse('${data['message_id'] ?? ''}');
    final kind = '${data['kind'] ?? ''}';
    final targetId = '${data['target_id'] ?? ''}';
    if (data['type'] != 'message' || messageId == null || targetId.isEmpty) {
      return null;
    }
    final title = '${data['title'] ?? ''}';
    final sender = '${data['sender'] ?? ''}';
    final content = '${data['content'] ?? ''}'.trim();
    final text = content.isEmpty ? l10n.notificationNewMessage : content;
    final String body;
    if (data['invite'] == '1') {
      body = l10n.notificationCall(sender);
    } else if (kind == 'team') {
      body = l10n.notificationFromSender(sender, text);
    } else {
      body = text;
    }
    return SystemNotice(
      id: idFor(messageId),
      title: title,
      body: body,
      target: ChatTarget.of(kind: kind, id: targetId, title: title),
    );
  }
}
