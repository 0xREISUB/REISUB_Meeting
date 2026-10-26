import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/settings/meeting_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('meeting media choices persist and have safe defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final defaults = await MeetingPreferences.load();
    expect(defaults.startWithMicrophone, isTrue);
    expect(defaults.startWithCamera, isTrue);
    expect(defaults.mirrorCamera, isTrue);

    await MeetingPreferences.save(
      startWithMicrophone: false,
      startWithCamera: false,
      mirrorCamera: false,
    );
    final saved = await MeetingPreferences.load();
    expect(saved.startWithMicrophone, isFalse);
    expect(saved.startWithCamera, isFalse);
    expect(saved.mirrorCamera, isFalse);
  });
}
