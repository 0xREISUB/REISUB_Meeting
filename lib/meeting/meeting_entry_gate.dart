import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:v_meeting/meeting/meeting_connection.dart';

/// Keeps the "joining" overlay visible until signalling has connected and the
/// main remote participant's audio and first video frame have arrived, so the
/// user does not see a half-loaded meeting.
class MeetingEntryGate extends ChangeNotifier {
  MeetingEntryGate({
    required bool enabled,
    required this.connection,
    required this.isConnecting,
    required this.mainRemoteParticipant,
  }) : _enabled = enabled,
       _ready = !enabled {
    if (enabled) begin(notify: false);
  }

  static const settleDelay = Duration(milliseconds: 800);
  static const pollInterval = Duration(milliseconds: 300);
  static const timeout = Duration(seconds: 12);

  final MeetingConnection connection;
  final bool Function() isConnecting;
  final RemoteParticipant? Function() mainRemoteParticipant;
  final bool _enabled;

  bool _ready;
  bool _timedOut = false;
  bool _settled = false;
  bool _checking = false;
  bool _disposed = false;
  Timer? _pollTimer;
  Timer? _timeoutTimer;
  Timer? _settleTimer;

  bool get ready => _ready;
  bool get timedOut => _timedOut;

  /// Starts (or restarts, for a rejoin) waiting for the meeting to be ready.
  void begin({bool notify = true}) {
    if (!_enabled || _disposed) return;
    stop();
    _ready = false;
    _timedOut = false;
    _settled = false;
    _settleTimer = Timer(settleDelay, () {
      _settled = true;
      unawaited(_check());
    });
    _pollTimer = Timer.periodic(pollInterval, (_) => unawaited(_check()));
    _timeoutTimer = Timer(timeout, _fail);
    if (notify) notifyListeners();
  }

  void stop() {
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();
    _settleTimer?.cancel();
  }

  void _fail() {
    if (_disposed || _ready) return;
    stop();
    _timedOut = true;
    notifyListeners();
  }

  Future<void> _check() async {
    if (_disposed || _ready || _timedOut || _checking) return;
    if (!isConnecting() &&
        connection.phase == MeetingConnectionPhase.disconnected) {
      _fail();
      return;
    }
    if (!_settled || isConnecting() || !connection.isConnected) return;
    _checking = true;
    try {
      final remote = mainRemoteParticipant();
      if (remote != null && !await remoteMediaReady(remote)) return;
      if (_disposed || _timedOut) return;
      stop();
      _ready = true;
      notifyListeners();
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}

/// Whether a participant's unmuted audio is subscribed and its visible video
/// (screen share before camera) has decoded at least one frame.
Future<bool> remoteMediaReady(RemoteParticipant participant) async {
  final audio = participant.getTrackPublicationBySource(TrackSource.microphone);
  if (audio != null && !audio.muted && audio.track is! RemoteAudioTrack) {
    return false;
  }
  final screen = participant.getTrackPublicationBySource(
    TrackSource.screenShareVideo,
  );
  final camera = participant.getTrackPublicationBySource(TrackSource.camera);
  final video = screen != null && !screen.muted ? screen : camera;
  if (video == null || video.muted) return true;
  final track = video.track;
  if (track is! RemoteVideoTrack) return false;
  try {
    final stats = await track.getReceiverStats();
    return (stats?.framesDecoded ?? 0) > 0;
  } catch (_) {
    return false;
  }
}
