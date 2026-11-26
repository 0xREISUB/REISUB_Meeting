/// Incoming calls on Android: the phone rings as for a call, with its own
/// ringtone and vibration, full screen on the lock screen, with Answer and
/// Decline. A volume key silences it. The system's call service (Telecom)
/// keeps it to the phone's ringer mode and Do Not Disturb.
library;

import 'dart:async';

import 'package:flutter/services.dart';

/// A call that rings.
class IncomingCall {
  const IncomingCall({
    required this.id,
    required this.roomId,
    required this.caller,
    required this.title,
    required this.kind,
    required this.targetId,
    required this.secret,
    required this.server,
    required this.endsAt,
  });

  final String id;
  final String roomId;

  /// Who calls, and where from: the caller again, or a team's name.
  final String caller;
  final String title;

  /// "friend" or "team", and the friend's or team's id.
  final String kind;
  final String targetId;

  /// Lets the phone decline from the notification, without the app.
  final String secret;

  /// The meeting server, for that decline.
  final String server;

  /// When it stops ringing by itself.
  final DateTime endsAt;

  Map<String, Object> toMap() => {
    'id': id,
    'roomId': roomId,
    'caller': caller,
    'title': title,
    'kind': kind,
    'targetId': targetId,
    'secret': secret,
    'server': server,
    'endsAt': endsAt.millisecondsSinceEpoch,
  };
}

/// What the call screen and notifications say, in the app's language.
class CallLabels {
  const CallLabels({
    required this.incoming,
    required this.answer,
    required this.decline,
    required this.channel,
    required this.missedChannel,
    required this.missed,
  });

  /// Under the name: "is calling you" or "team meeting".
  final String incoming;
  final String answer;
  final String decline;

  /// The notification channels' names.
  final String channel;
  final String missedChannel;

  /// The missed call notification's title.
  final String missed;

  Map<String, String> toMap() => {
    'incoming': incoming,
    'answer': answer,
    'decline': decline,
    'channel': channel,
    'missedChannel': missedChannel,
    'missed': missed,
  };
}

/// What the user did with a call.
class CallAction {
  const CallAction({
    required this.answered,
    required this.id,
    required this.roomId,
    required this.kind,
    required this.targetId,
    required this.title,
  });

  static CallAction? fromMap(Object? value) {
    if (value is! Map) return null;
    return CallAction(
      answered: value['action'] == 'answer',
      id: '${value['id']}',
      roomId: '${value['roomId']}',
      kind: '${value['kind']}',
      targetId: '${value['targetId']}',
      title: '${value['title']}',
    );
  }

  /// True for Answer; Decline is sent to the server by the phone itself.
  final bool answered;
  final String id;
  final String roomId;
  final String kind;
  final String targetId;
  final String title;
}

class ReisubCalls {
  static const _channel = MethodChannel('reisub_calls');
  static final _actions = StreamController<CallAction>.broadcast();
  static bool _listening = false;

  /// Starts ringing; a call already ringing is left as it is.
  static Future<void> show(IncomingCall call, CallLabels labels) =>
      _channel.invokeMethod('show', {...call.toMap(), ...labels.toMap()});

  /// Stops ringing; [missed] leaves a missed call notification saying
  /// [missedText].
  static Future<void> end(
    String id, {
    bool missed = false,
    String? missedText,
    CallLabels? labels,
  }) => _channel.invokeMethod('end', {
    'id': id,
    'missed': missed,
    'missedText': ?missedText,
    ...?labels?.toMap(),
  });

  /// An answer or decline made while the app was not running, once.
  static Future<CallAction?> takePendingAction() async =>
      CallAction.fromMap(await _channel.invokeMethod('takePendingAction'));

  /// Answers and declines made while the app runs.
  static Stream<CallAction> get actions {
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method != 'onCallAction') return;
        final action = await takePendingAction();
        if (action != null) _actions.add(action);
      });
    }
    return _actions.stream;
  }

  /// Whether a call may show full screen on the lock screen (Android 14
  /// asks the user for it).
  static Future<bool> canUseFullScreen() async =>
      await _channel.invokeMethod<bool>('canUseFullScreen') ?? true;

  /// Opens the system setting that allows it.
  static Future<void> openFullScreenSettings() =>
      _channel.invokeMethod('openFullScreenSettings');
}
