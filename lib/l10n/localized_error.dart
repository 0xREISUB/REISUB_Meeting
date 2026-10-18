import 'package:flutter/services.dart';
import 'app_localizations.dart';

enum AppError {
  invalidMessageData,
  invalidServerResponse,
  invalidRoomData,
  missingServerSession,
  meetingServerUnavailable,
  missingMeetingDetails,
  mediaRequiresHttps,
  screenShareStartFailed,
  serverSettingsSaveFailed,
  subscriptionFailed,
  meetingJoinFailed,
  microphoneDisableFailed,
  devicePreferenceSaveFailed,
  windowsDevicePrivacyUnavailable,
}

/// Keep application errors as data so an already visible error follows a locale
/// change. Server-provided messages and user content are preserved verbatim.
class AppException implements Exception {
  const AppException(this.message) : code = null, details = null;
  const AppException.localized(this.code, {this.details}) : message = null;

  final String? message;
  final AppError? code;
  final Object? details;

  String localize(AppLocalizations l10n) => switch (code) {
    AppError.invalidMessageData => l10n.invalidMessageData,
    AppError.invalidServerResponse => l10n.invalidServerResponse,
    AppError.invalidRoomData => l10n.invalidRoomData,
    AppError.missingServerSession => l10n.missingServerSession,
    AppError.meetingServerUnavailable => l10n.meetingServerUnavailable,
    AppError.missingMeetingDetails => l10n.missingMeetingDetails,
    AppError.mediaRequiresHttps => l10n.mediaRequiresHttps,
    AppError.screenShareStartFailed => l10n.screenShareStartFailed,
    AppError.serverSettingsSaveFailed => l10n.serverSettingsSaveFailed,
    AppError.subscriptionFailed => l10n.subscriptionFailed(details.toString()),
    AppError.meetingJoinFailed => l10n.meetingJoinFailed(
      localizeError(details!, l10n),
    ),
    AppError.microphoneDisableFailed => l10n.microphoneDisableFailed(
      localizeError(details!, l10n),
    ),
    AppError.devicePreferenceSaveFailed => l10n.devicePreferenceSaveFailed,
    AppError.windowsDevicePrivacyUnavailable =>
      l10n.windowsDevicePrivacyUnavailable(
        details == true ? l10n.cameraName : l10n.microphoneName,
      ),
    null => message!,
  };

  @override
  String toString() => message ?? code!.name;
}

String localizeError(Object error, AppLocalizations l10n) {
  if (error is AppException) return error.localize(l10n);
  if (error is PlatformException) {
    if (error.code == 'WindowsAudioRestartRequired') {
      return l10n.windowsAudioRestartRequired;
    }
    if (error.code == 'WindowsMicrophoneNotFound') {
      return l10n.windowsMicrophoneMissing;
    }
  }
  return error.toString();
}
