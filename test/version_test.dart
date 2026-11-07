import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:v_meeting/app/version.dart';

void main() {
  test('the version shown in the app matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*([^+\s]+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(appVersion, version);
  });
}
