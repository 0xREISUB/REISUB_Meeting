part of 'meeting_session.dart';

/// Joining the meeting, and leaving it.
extension MeetingSessionJoining on MeetingSession {
  // ---------------------------------------------------------------------------
  // Joining

  Future<void> connect() async {
    if (_isJoining || _inactive) return;
    final credentials = _credentials;
    if (credentials == null) {
      isConnecting = false;
      connectionError = const AppException.localized(
        AppError.missingMeetingDetails,
      );
      _changed();
      connection.fail(
        const AppException.localized(AppError.missingMeetingDetails),
      );
      return;
    }

    if (kIsWeb &&
        Uri.base.scheme != 'https' &&
        Uri.base.host != 'localhost' &&
        Uri.base.host != '127.0.0.1') {
      isConnecting = false;
      connectionError = const AppException.localized(
        AppError.mediaRequiresHttps,
      );
      _changed();
      return;
    }

    _isJoining = true;
    connection.startConnecting();
    try {
      final mediaPreferences = await MediaPreferences.load();
      final meetingPreferences = await MeetingPreferences.load();
      media.microphoneId = mediaPreferences.microphoneId;
      media.cameraId = mediaPreferences.cameraId;
      if (!_initialPreferencesLoaded) {
        isMicEnabled = meetingPreferences.startWithMicrophone;
        isCameraEnabled = meetingPreferences.startWithCamera;
        _initialPreferencesLoaded = true;
      }
      mirrorCamera = meetingPreferences.mirrorCamera;
      if (_inactive) return;
      await platform.requestMeetingPermissions(camera: isCameraEnabled);
      if (_inactive) return;
      // After the permissions, so that Android lets the service keep the
      // microphone running in the background.
      if (!_backgroundServiceStarted) {
        _backgroundServiceStarted = true;
        await platform.startMeetingService(_ui.meetingNotification());
      }
      if (_inactive) return;
      await room
          .connect(credentials.liveKitUrl, credentials.token)
          .timeout(MeetingSession.connectTimeout);
      if (_inactive) return;
      connection.markConnected();
      microphoneError = null;
      cameraError = null;
      // A microphone permission/device failure must not prevent video startup.
      try {
        final startMic = isMicEnabled && !microphoneLocked;
        final participant = room.localParticipant;
        if (participant != null) {
          await media.setMicrophoneEnabled(participant, startMic);
        }
        isMicEnabled = startMic;
      } catch (error) {
        isMicEnabled = false;
        microphoneError = error;
      }
      if (_inactive) return;
      try {
        final participant = room.localParticipant;
        if (participant != null) {
          await media.setCameraEnabled(participant, isCameraEnabled);
        }
      } catch (error) {
        isCameraEnabled = false;
        cameraError = error;
      }
      if (_inactive) return;
      isConnecting = false;
      connectionError = null;
      _changed();
    } catch (error) {
      var failure = error;
      if (error is TimeoutException) {
        // Stop the attempt that is still running in the background.
        failure = const AppException.localized(
          AppError.meetingServerUnavailable,
        );
        try {
          await room.disconnect();
        } catch (_) {}
      }
      if (!_inactive) {
        isConnecting = false;
        _changed();
        connection.fail(failure);
      }
    } finally {
      _isJoining = false;
      if (!_inactive) _handleMicrophonePolicy();
    }
  }

  /// Joins again with a fresh token, which also recovers expired credentials
  /// and stale server sessions.
  Future<void> rejoin() async {
    final previous = _credentials;
    if (previous == null || isRejoining || _isJoining) return;
    entryGate.begin();
    isRejoining = true;
    isConnecting = true;
    connectionError = null;
    _changed();
    connection.startConnecting();
    try {
      await room.disconnect();
      if (_disposed) return;
      connection.startConnecting();
      final result = await api.joinRoom(
        roomId: previous.roomId,
        name: previous.participant,
      );
      if (_disposed) return;
      switch (result) {
        case JoinAdmitted(:final credentials):
          _credentials = credentials;
          _deadline.setSecondsLeft(credentials.secondsLeft);
        case JoinWaiting(:final requestId):
          // Someone already in the meeting is let back in by the server;
          // if it asks to wait anyway, rejoining goes through the join screen.
          unawaited(
            api
                .cancelWaiting(previous.roomId, requestId)
                .catchError((Object _) {}),
          );
          throw const AppException.localized(AppError.waitingRoomRejoin);
      }
      await connect();
    } catch (error) {
      // An expired account continues as a guest on the next attempt.
      if (!_disposed) connection.fail(error);
    } finally {
      if (!_disposed) {
        isRejoining = false;
        isConnecting = false;
        _changed();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Leaving

  /// Releases meeting resources and asks the screen to navigate away.
  void leave(MeetingExitReason reason) {
    if (_inactive) return;
    _leaving = true;
    unawaited(_deviceTest?.controller.close());
    entryGate.stop();
    if (_ownsScreenShare) {
      final identity = room.localParticipant?.identity;
      if (identity != null) {
        unawaited(sharing?.release(identity).catchError((Object _) {}));
      }
      _ownsScreenShare = false;
    }
    unawaited(_stopScreenService());
    final roomId = _credentials?.roomId;
    if (reason == MeetingExitReason.left && roomId != null) {
      // Lets the server hand ownership on at once. If this fails, LiveKit's
      // disconnect webhook does the same a little later.
      unawaited(api.leaveRoom(roomId).catchError((Object _) {}));
    }
    unawaited(room.disconnect());
    _ui.exitMeeting(reason);
  }

  Future<void> closeRoomForEveryone() async {
    final credentials = _credentials;
    if (_inactive ||
        credentials == null ||
        !can(MeetingPermission.endMeeting) ||
        endingRoom) {
      return;
    }
    endingRoom = true;
    _changed();
    try {
      await api.closeRoom(credentials.roomId);
      if (!_inactive) leave(MeetingExitReason.endedByYou);
    } catch (error) {
      if (!_inactive) _ui.showMessage(error);
    } finally {
      if (!_inactive) {
        endingRoom = false;
        _changed();
      }
    }
  }
}
