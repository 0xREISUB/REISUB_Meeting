import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

bool get isWindowsDesktop =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

Future<bool> openMediaPrivacy({required bool camera}) async {
  try {
    if (isWindowsDesktop) {
      return await const MethodChannel(
            'reisub_meeting/privacy',
          ).invokeMethod<bool>(
            camera ? 'openCameraSettings' : 'openMicrophoneSettings',
          ) ??
          false;
    }
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return await openAppSettings();
    }
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
  return false;
}
