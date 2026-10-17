import 'package:shared_preferences/shared_preferences.dart';

class MediaPreferences {
  const MediaPreferences({this.microphoneId, this.cameraId});

  final String? microphoneId;
  final String? cameraId;

  static Future<MediaPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return MediaPreferences(
      microphoneId: prefs.getString('media.microphone'),
      cameraId: prefs.getString('media.camera'),
    );
  }

  static Future<void> select({required bool camera, String? deviceId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = camera ? 'media.camera' : 'media.microphone';
    if (deviceId == null || deviceId.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, deviceId);
    }
  }
}
