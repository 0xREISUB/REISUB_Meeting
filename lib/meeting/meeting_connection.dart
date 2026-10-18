import 'package:v_meeting/l10n/app_localizations.dart';
import 'package:v_meeting/l10n/localized_error.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

enum MeetingConnectionPhase {
  connecting,
  connected,
  reconnecting,
  disconnected,
}

/// Keeps transport state separate from camera/microphone permission errors.
class MeetingConnection extends ChangeNotifier {
  MeetingConnection(Room room) {
    _events = room.createListener()
      ..on<RoomConnectedEvent>((_) => markConnected())
      ..on<RoomReconnectedEvent>((_) => markConnected())
      ..on<ReconnectingEvent>((_) {
        phase = MeetingConnectionPhase.reconnecting;
        problem = null;
        notifyListeners();
      })
      ..on<RoomDisconnectedEvent>((event) {
        phase = MeetingConnectionPhase.disconnected;
        disconnectReason = event.reason;
        problem = null;
        notifyListeners();
      })
      ..on<TrackSubscriptionExceptionEvent>((event) {
        problem = AppException.localized(
          AppError.subscriptionFailed,
          details: event.reason.name,
        );
        notifyListeners();
      })
      ..on<TrackSubscribedEvent>((_) {
        problem = null;
        notifyListeners();
      })
      ..on<ParticipantConnectionQualityUpdatedEvent>((event) {
        if (event.participant is! LocalParticipant) return;
        quality = event.connectionQuality;
        notifyListeners();
      });
  }

  late final EventsListener<RoomEvent> _events;
  MeetingConnectionPhase phase = MeetingConnectionPhase.connecting;
  DisconnectReason? disconnectReason;
  ConnectionQuality quality = ConnectionQuality.unknown;
  Object? problem;

  bool get isConnected => phase == MeetingConnectionPhase.connected;
  bool get canRejoin =>
      disconnectReason != DisconnectReason.roomDeleted &&
      disconnectReason != DisconnectReason.roomClosed &&
      disconnectReason != DisconnectReason.participantRemoved;

  String? message(AppLocalizations l10n) {
    switch (phase) {
      case MeetingConnectionPhase.connecting:
        return l10n.joiningMeeting;
      case MeetingConnectionPhase.reconnecting:
        return l10n.reconnectingMeeting;
      case MeetingConnectionPhase.disconnected:
        return switch (disconnectReason) {
          DisconnectReason.duplicateIdentity => l10n.duplicateSession,
          DisconnectReason.roomDeleted ||
          DisconnectReason.roomClosed => l10n.meetingClosedByServer,
          DisconnectReason.participantRemoved => l10n.removedFromMeeting,
          DisconnectReason.reconnectAttemptsExceeded => l10n.reconnectFailed,
          DisconnectReason.stateMismatch => l10n.meetingSessionLost,
          _ =>
            problem == null
                ? l10n.meetingDisconnected
                : localizeError(problem!, l10n),
        };
      case MeetingConnectionPhase.connected:
        if (problem != null) return localizeError(problem!, l10n);
        if (quality == ConnectionQuality.poor ||
            quality == ConnectionQuality.lost) {
          return l10n.poorMediaConnection;
        }
        return null;
    }
  }

  void startConnecting() {
    phase = MeetingConnectionPhase.connecting;
    disconnectReason = null;
    problem = null;
    quality = ConnectionQuality.unknown;
    notifyListeners();
  }

  void markConnected() {
    phase = MeetingConnectionPhase.connected;
    disconnectReason = null;
    problem = null;
    quality = ConnectionQuality.unknown;
    notifyListeners();
  }

  void fail(Object error) {
    phase = MeetingConnectionPhase.disconnected;
    disconnectReason = null;
    problem = AppException.localized(
      AppError.meetingJoinFailed,
      details: error,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_events.dispose());
    super.dispose();
  }
}
