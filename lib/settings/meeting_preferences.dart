import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MeetingPreferences {
  const MeetingPreferences({
    this.startWithMicrophone = true,
    this.startWithCamera = true,
    this.mirrorCamera = true,
  });

  static const _microphoneKey = 'meeting.start_with_microphone';
  static const _cameraKey = 'meeting.start_with_camera';
  static const _mirrorKey = 'meeting.mirror_camera';

  final bool startWithMicrophone;
  final bool startWithCamera;
  final bool mirrorCamera;

  static Future<MeetingPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return MeetingPreferences(
      startWithMicrophone: prefs.getBool(_microphoneKey) ?? true,
      startWithCamera: prefs.getBool(_cameraKey) ?? true,
      mirrorCamera: prefs.getBool(_mirrorKey) ?? true,
    );
  }

  static Future<void> save({
    bool? startWithMicrophone,
    bool? startWithCamera,
    bool? mirrorCamera,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (startWithMicrophone != null) {
      await prefs.setBool(_microphoneKey, startWithMicrophone);
    }
    if (startWithCamera != null) {
      await prefs.setBool(_cameraKey, startWithCamera);
    }
    if (mirrorCamera != null) {
      await prefs.setBool(_mirrorKey, mirrorCamera);
    }
  }
}

/// Meeting start-up choices, loaded once and kept in sync with storage.
final meetingPreferencesProvider =
    AsyncNotifierProvider<MeetingPreferencesController, MeetingPreferences>(
      MeetingPreferencesController.new,
    );

class MeetingPreferencesController extends AsyncNotifier<MeetingPreferences> {
  @override
  Future<MeetingPreferences> build() => MeetingPreferences.load();

  Future<void> change({
    bool? startWithMicrophone,
    bool? startWithCamera,
    bool? mirrorCamera,
  }) async {
    final current = state.value ?? const MeetingPreferences();
    state = AsyncData(
      MeetingPreferences(
        startWithMicrophone: startWithMicrophone ?? current.startWithMicrophone,
        startWithCamera: startWithCamera ?? current.startWithCamera,
        mirrorCamera: mirrorCamera ?? current.mirrorCamera,
      ),
    );
    await MeetingPreferences.save(
      startWithMicrophone: startWithMicrophone,
      startWithCamera: startWithCamera,
      mirrorCamera: mirrorCamera,
    );
  }
}
