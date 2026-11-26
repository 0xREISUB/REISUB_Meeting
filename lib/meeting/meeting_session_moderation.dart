part of 'meeting_session.dart';

/// The time limit, the waiting room, roles and permissions, and diagnostics.
extension MeetingSessionModeration on MeetingSession {
  // ---------------------------------------------------------------------------
  // Time limit

  /// How long until the server ends the meeting; null without a limit.
  Duration? get timeLeft => _deadline.timeLeft;

  /// Whether the meeting has reached its time limit.
  bool get timeLimitReached => _deadline.reached;

  // ---------------------------------------------------------------------------
  // Waiting room

  /// Whether this user may turn the waiting room on and let people in.
  bool get canAdmit => can(MeetingPermission.admitMembers);
  bool get waitingRoomOn => sharing?.state.waitingRoom ?? false;

  /// People waiting to be let in, oldest first; only for those who may.
  List<WaitingPerson> get waiting =>
      canAdmit ? (sharing?.state.waiting ?? const []) : const [];

  /// Throws the server's error so the caller can show it.
  Future<void> setWaitingRoom(bool on) async {
    if (!canAdmit) return;
    await sharing?.setWaitingRoom(on);
  }

  /// Lets [person] in or turns them away. Throws the server's error.
  Future<void> answerWaiting(
    WaitingPerson person, {
    required bool admit,
  }) async {
    if (!canAdmit) return;
    await sharing?.answer(person.requestId, admit: admit);
  }

  /// Whether this participant may share their screen at all.
  bool get screenSharingAllowed => can(MeetingPermission.shareScreen);

  bool get canToggleScreenShare {
    if (changingScreenShare || !connection.isConnected) return false;
    if (isSharingScreen) return true;
    // Only one person can share at a time, the full admin included.
    if (screenShareBusy) return false;
    return screenSharingAllowed;
  }

  /// Another participant holds the room's single screen share.
  bool get screenShareBusy {
    final holder = sharing?.state.screenShareIdentity ?? '';
    if (holder.isNotEmpty && holder != room.localParticipant?.identity) {
      return true;
    }
    return connection.isConnected &&
        room.remoteParticipants.values.any(_hasScreenShare);
  }

  static bool _maySharescreen(ParticipantPermissions permissions) =>
      permissions.canPublish &&
      (permissions.canPublishSources.isEmpty ||
          permissions.canPublishSources.any((s) => s.name == 'SCREEN_SHARE'));

  /// The server revokes the permission when the host turns sharing off; stop
  /// at once instead of waiting for the next state poll.
  void _onLocalPermissionsChanged(ParticipantPermissions permissions) {
    if (_inactive || changingScreenShare || !isSharingScreen) return;
    if (_maySharescreen(permissions)) return;
    _stopRevokedScreenShare();
  }

  void _stopRevokedScreenShare() {
    _ui.showMessage(
      const AppException.localized(AppError.screenShareStoppedByHost),
    );
    unawaited(stopScreenShare());
  }

  Future<void> _stopScreenService() async {
    if (!_screenServiceRunning) return;
    _screenServiceRunning = false;
    await platform.stopScreenShareService();
  }

  Future<void> stopScreenShare() async {
    if (changingScreenShare) return;
    changingScreenShare = true;
    _changed();
    final identity = room.localParticipant?.identity;
    try {
      await room.localParticipant?.setScreenShareEnabled(false);
      _ownsScreenShare = false;
      await _stopScreenService();
      if (identity != null) await sharing?.release(identity);
    } catch (error) {
      if (!_inactive) _ui.showMessage(error);
    } finally {
      if (!_disposed) {
        changingScreenShare = false;
        _changed();
      }
    }
  }

  Future<void> toggleScreenShare() async {
    if (changingScreenShare || _leaving) return;
    if (isSharingScreen) {
      await stopScreenShare();
      return;
    }
    final local = room.localParticipant;
    final sharing = this.sharing;
    if (local == null || sharing == null || !connection.isConnected) return;
    changingScreenShare = true;
    _changed();
    var reserved = false;
    try {
      ScreenShareChoice? choice;
      if (platform.isDesktop) {
        choice = await _ui.pickDesktopScreen();
        if (choice == null || _inactive) return;
      } else if (!await platform.requestScreenCapturePermission() ||
          _inactive) {
        return;
      }
      // The server grants one screen share at a time.
      await sharing.acquire(local.identity);
      reserved = true;
      if (_inactive) return;
      // Wait for the permission update on the signaling channel as well as HTTP.
      for (var i = 0; i < 30; i++) {
        if (_maySharescreen(local.permissions)) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (_inactive) return;
      }
      _screenServiceRunning = await platform.startScreenShareService(
        _ui.screenShareNotification(),
      );
      if (_inactive) return;
      // Browsers offer their own "share audio" choice.
      final shareAudio = choice?.shareAudio ?? kIsWeb;
      final publication = await local.setScreenShareEnabled(
        true,
        captureScreenAudio: shareAudio,
        screenShareCaptureOptions: ScreenShareCaptureOptions(
          sourceId: choice?.sourceId,
          maxFrameRate: 15,
          captureScreenAudio: shareAudio,
        ),
      );
      if (publication == null) {
        throw const MeetingApiException.localized(
          AppError.screenShareStartFailed,
        );
      }
      if (_inactive) {
        await local.setScreenShareEnabled(false);
        return;
      }
      _ownsScreenShare = true;
      reserved = false;
    } catch (error) {
      if (!_inactive) _ui.showMessage(error);
    } finally {
      if (reserved) {
        try {
          await local.setScreenShareEnabled(false);
        } catch (_) {}
        try {
          await sharing.release(local.identity);
        } catch (_) {}
      }
      if (!_ownsScreenShare) await _stopScreenService();
      if (!_disposed) {
        changingScreenShare = false;
        _changed();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Diagnostics

  Future<void> _logVideoStats() async {
    if (!connection.isConnected || _readingVideoStats) return;
    _readingVideoStats = true;
    try {
      for (final participant in room.remoteParticipants.values.toList()) {
        final track = _videoTrack(participant);
        if (track is! RemoteVideoTrack) continue;
        final stats = await track.getReceiverStats();
        if (_disposed || stats == null) continue;
        // Never log access tokens or signaling URLs.
        developer.log(
          'room=${_credentials?.roomId} participantSid=${participant.sid} '
          'codec=${stats.mimeType} decoder=${stats.decoderImplementation} '
          'size=${stats.frameWidth}x${stats.frameHeight} fps=${stats.framesPerSecond} '
          'packets=${stats.packetsReceived} lost=${stats.packetsLost} '
          'bytes=${stats.bytesReceived} decoded=${stats.framesDecoded} '
          'dropped=${stats.framesDropped} jitter=${stats.jitter}',
          name: 'meeting.video',
        );
      }
    } catch (error) {
      developer.log(
        'Video statistics unavailable: ${error.runtimeType}',
        name: 'meeting.video',
      );
    } finally {
      _readingVideoStats = false;
    }
  }
}
