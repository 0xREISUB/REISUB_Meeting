part of 'meeting_session.dart';

/// The microphone and camera, the app in the background, device tests and screen sharing.
extension MeetingSessionMedia on MeetingSession {
  // ---------------------------------------------------------------------------
  // Microphone and camera

  /// Enforces a host lock and asks for consent when the host requests unmute.
  void _handleMicrophonePolicy() {
    if (_leaving) return;
    final local = room.localParticipant;
    if (local == null) return;
    if (microphoneLocked) {
      isMicEnabled = false;
      if (local.isMicrophoneEnabled() && !_applyingMicLock) {
        unawaited(_disableLockedMicrophone(local));
      }
      return;
    }
    if (!isConnecting) isMicEnabled = local.isMicrophoneEnabled();
    if (_deviceTest != null) return;
    final request = local.attributes[MeetingSession.micRequestAttribute];
    if (isConnecting ||
        request == null ||
        request.isEmpty ||
        request == _lastUnmuteRequest ||
        _unmuteDialogOpen) {
      return;
    }
    _lastUnmuteRequest = request;
    _unmuteDialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_inactive || microphoneLocked) {
        _unmuteDialogOpen = false;
        return;
      }
      unawaited(_confirmUnmute());
    });
  }

  Future<void> _disableLockedMicrophone(LocalParticipant local) async {
    _applyingMicLock = true;
    try {
      await local.setMicrophoneEnabled(false);
    } catch (error) {
      if (!_disposed) {
        connectionError = AppException.localized(
          AppError.microphoneDisableFailed,
          details: error,
        );
        _changed();
      }
    } finally {
      _applyingMicLock = false;
    }
  }

  Future<void> _confirmUnmute() async {
    try {
      final accepted = await _ui.confirmUnmute();
      if (!accepted || _inactive || microphoneLocked) return;
      final local = room.localParticipant;
      if (local == null) return;
      await media.setMicrophoneEnabled(local, true);
      if (microphoneLocked) {
        await local.setMicrophoneEnabled(false);
        return;
      }
      if (!_disposed) {
        isMicEnabled = true;
        microphoneError = null;
        _changed();
      }
    } catch (error) {
      if (!_disposed) {
        microphoneError = error;
        _changed();
      }
    } finally {
      _unmuteDialogOpen = false;
    }
  }

  /// Does nothing while the host has locked the microphone.
  Future<void> toggleMicrophone() async {
    if (microphoneLocked) return;
    final enabled = !isMicEnabled;
    try {
      final participant = room.localParticipant;
      if (participant == null) return;
      await media.setMicrophoneEnabled(participant, enabled);
      if (enabled && microphoneLocked) {
        await participant.setMicrophoneEnabled(false);
        return;
      }
      if (!_disposed) {
        isMicEnabled = enabled;
        microphoneError = null;
        _changed();
      }
    } catch (error) {
      if (!_disposed) {
        microphoneError = error;
        _changed();
      }
    }
  }

  Future<void> toggleCamera() async {
    final enabled = !isCameraEnabled;
    try {
      final participant = room.localParticipant;
      if (participant == null) return;
      await media.setCameraEnabled(participant, enabled);
      if (!_disposed) {
        isCameraEnabled = enabled;
        cameraError = null;
        _changed();
      }
    } catch (error) {
      if (!_disposed) {
        cameraError = error;
        _changed();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Background

  /// Android blocks the camera in the background and the picture would
  /// freeze, so the camera is turned off until the app returns. Audio keeps
  /// running.
  Future<void> pauseCameraForBackground() async {
    final participant = room.localParticipant;
    if (_inactive ||
        !isCameraEnabled ||
        _cameraPausedInBackground ||
        participant == null ||
        !connection.isConnected) {
      return;
    }
    _cameraPausedInBackground = true;
    try {
      await media.setCameraEnabled(participant, false);
    } catch (_) {
      // The camera is released anyway when the app is in the background.
    }
  }

  Future<void> resumeCameraFromBackground() async {
    if (!_cameraPausedInBackground) return;
    _cameraPausedInBackground = false;
    final participant = room.localParticipant;
    if (_inactive || participant == null || !isCameraEnabled) return;
    try {
      await media.setCameraEnabled(participant, true);
    } catch (error) {
      if (!_disposed) {
        isCameraEnabled = false;
        cameraError = error;
        _changed();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Device tests inside the meeting

  /// Starts a device test, or returns null when one cannot run now. Call
  /// [releaseDeviceForTest] next and always finish with [endDeviceTest].
  MeetingDeviceTest? beginDeviceTest({required bool camera}) {
    final participant = room.localParticipant;
    if (_deviceTest != null || participant == null || !connection.isConnected) {
      return null;
    }
    return _deviceTest = MeetingDeviceTest._(
      camera: camera,
      wasEnabled: camera ? isCameraEnabled : isMicEnabled,
      participant: participant,
    );
  }

  /// Frees the device so the test screen can open it.
  Future<void> releaseDeviceForTest(MeetingDeviceTest test) async {
    await media.releaseDevice(test.participant, camera: test.camera);
    if (_inactive) return;
    if (test.camera) {
      isCameraEnabled = false;
    } else {
      isMicEnabled = false;
    }
    _changed();
  }

  /// Restores the device with the selection made during the test.
  Future<void> endDeviceTest(MeetingDeviceTest test) async {
    final participant = test.participant;
    try {
      await test.controller.close();
      if (_inactive || !identical(participant, room.localParticipant)) return;
      final preferences = await MediaPreferences.load();
      if (_inactive || !connection.isConnected) return;
      if (test.camera) {
        media.cameraId = preferences.cameraId;
        await media.setCameraEnabled(participant, test.wasEnabled);
        if (!_disposed) {
          isCameraEnabled = test.wasEnabled;
          cameraError = null;
          _changed();
        }
      } else {
        media.microphoneId = preferences.microphoneId;
        final enable = test.wasEnabled && !microphoneLocked;
        await media.setMicrophoneEnabled(participant, enable);
        if (microphoneLocked && enable) {
          await participant.setMicrophoneEnabled(false);
        }
        if (!_disposed) {
          isMicEnabled = enable && !microphoneLocked;
          microphoneError = null;
          _changed();
        }
      }
    } catch (error) {
      if (!_inactive) {
        if (test.camera) {
          isCameraEnabled = false;
          cameraError = error;
        } else {
          isMicEnabled = false;
          microphoneError = error;
        }
        _changed();
      }
    } finally {
      _deviceTest = null;
      if (!_inactive) _handleMicrophonePolicy();
    }
  }

  // ---------------------------------------------------------------------------
  // Screen sharing

  bool get _localScreenSharing {
    final local = room.localParticipant;
    return local != null && _hasScreenShare(local);
  }

  bool get isSharingScreen => _localScreenSharing || _ownsScreenShare;
}
