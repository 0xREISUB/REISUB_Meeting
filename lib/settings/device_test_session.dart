import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'microphone_input.dart';

/// A local-only capture test. The microphone peers exchange media within this
/// process so WebRTC starts its audio engine; no meeting/server is contacted.
class DeviceTestSession {
  rtc.MediaStream? stream;
  rtc.RTCPeerConnection? _sender;
  rtc.RTCPeerConnection? _receiver;
  bool _stopped = false;

  static Future<DeviceTestSession> start({
    required bool camera,
    String? deviceId,
    Future<rtc.MediaStream> Function(Map<String, dynamic>)? getUserMedia,
    Future<rtc.RTCPeerConnection> Function(Map<String, dynamic>)? createPeer,
    MicrophoneInput? microphoneInput,
  }) async {
    final session = DeviceTestSession();
    try {
      final input = microphoneInput ?? MicrophoneInput();
      final resolvedDeviceId = camera
          ? deviceId
          : await input.resolve(deviceId);
      session.stream =
          await (getUserMedia ?? rtc.navigator.mediaDevices.getUserMedia)({
            'audio': camera
                ? false
                : AudioCaptureOptions(
                    deviceId: resolvedDeviceId,
                  ).toMediaConstraintsMap(),
            'video': camera
                ? CameraCaptureOptions(
                    deviceId: deviceId,
                    params: VideoParametersPresets.h480_43,
                  ).toMediaConstraintsMap()
                : false,
          });
      final tracks = camera
          ? session.stream!.getVideoTracks()
          : session.stream!.getAudioTracks();
      if (tracks.isEmpty) throw TrackCreateException();
      if (!camera) {
        await input.select(resolvedDeviceId);
        await session._startMicrophoneMeter(
          createPeer ?? rtc.createPeerConnection,
        );
      }
      return session;
    } catch (_) {
      await session.stop();
      rethrow;
    }
  }

  Future<void> _startMicrophoneMeter(
    Future<rtc.RTCPeerConnection> Function(Map<String, dynamic>) createPeer,
  ) async {
    final config = <String, dynamic>{'iceServers': <dynamic>[]};
    final sender = _sender = await createPeer(config);
    final receiver = _receiver = await createPeer(config);
    final toSender = <rtc.RTCIceCandidate>[];
    final toReceiver = <rtc.RTCIceCandidate>[];
    var ready = false;
    Future<void> deliver(
      rtc.RTCPeerConnection peer,
      rtc.RTCIceCandidate candidate,
    ) async {
      if (_stopped || candidate.candidate == null) return;
      try {
        await peer.addCandidate(candidate);
      } catch (_) {
        /* Closing test. */
      }
    }

    sender.onIceCandidate = (candidate) {
      if (ready) {
        deliver(receiver, candidate);
      } else {
        toReceiver.add(candidate);
      }
    };
    receiver.onIceCandidate = (candidate) {
      if (ready) {
        deliver(sender, candidate);
      } else {
        toSender.add(candidate);
      }
    };
    // Never attach received audio to a renderer: the test must not feed back
    // through the speakers. Only the sender's input-level statistics are read.
    await sender.addTrack(stream!.getAudioTracks().first, stream!);
    final offer = await sender.createOffer();
    await sender.setLocalDescription(offer);
    await receiver.setRemoteDescription(offer);
    final answer = await receiver.createAnswer();
    await receiver.setLocalDescription(answer);
    await sender.setRemoteDescription(answer);
    ready = true;
    for (final candidate in toReceiver) {
      await deliver(receiver, candidate);
    }
    for (final candidate in toSender) {
      await deliver(sender, candidate);
    }
  }

  Future<double?> readLevel() async {
    if (_stopped || _sender == null) return null;
    final reports = await _sender!.getStats();
    for (final report in reports) {
      if (report.type != 'media-source' && report.type != 'track') continue;
      final value = report.values['audioLevel'];
      if (value is num) return value.toDouble().clamp(0, 1);
    }
    return null;
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    // Stop capture first, even if closing a peer subsequently fails.
    for (final track in stream?.getTracks() ?? <rtc.MediaStreamTrack>[]) {
      try {
        await track.stop();
      } catch (_) {
        /* Release remaining resources. */
      }
    }
    for (final peer in [_sender, _receiver]) {
      if (peer == null) continue;
      peer.onIceCandidate = null;
      try {
        await peer.close();
      } catch (_) {
        /* Continue cleanup. */
      }
      try {
        await peer.dispose();
      } catch (_) {
        /* Already closed. */
      }
    }
    try {
      await stream?.dispose();
    } catch (_) {
      /* Already disposed. */
    }
    stream = null;
  }
}
