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
        problem = 'Katılımcının medya akışı alınamadı (${event.reason.name}).';
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
  String? problem;

  bool get isConnected => phase == MeetingConnectionPhase.connected;

  String? get message {
    switch (phase) {
      case MeetingConnectionPhase.connecting:
        return 'Toplantıya bağlanılıyor…';
      case MeetingConnectionPhase.reconnecting:
        return 'Bağlantı kesildi. Yeniden bağlanılıyor…';
      case MeetingConnectionPhase.disconnected:
        return switch (disconnectReason) {
          DisconnectReason.duplicateIdentity =>
            'Bu oturum başka bir cihazda açıldığı için bağlantı kesildi.',
          DisconnectReason.roomDeleted || DisconnectReason.roomClosed =>
            'Toplantı sunucu tarafından kapatıldı.',
          DisconnectReason.participantRemoved =>
            'Sunucu tarafından toplantıdan çıkarıldınız.',
          DisconnectReason.reconnectAttemptsExceeded =>
            'Bağlantı geri kurulamadı. Tekrar katılmayı deneyin.',
          DisconnectReason.stateMismatch =>
            'Sunucu oturumu kaybetti. Toplantıya tekrar katılın.',
          _ =>
            problem ??
                'Toplantı bağlantısı kesildi. Şu anda odaya bağlı değilsiniz.',
        };
      case MeetingConnectionPhase.connected:
        if (problem != null) return problem;
        if (quality == ConnectionQuality.poor ||
            quality == ConnectionQuality.lost) {
          return 'Medya bağlantısı zayıf. Görüntü ve ses kesilebilir.';
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
    problem = 'Toplantıya bağlanılamadı: $error';
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_events.dispose());
    super.dispose();
  }
}
