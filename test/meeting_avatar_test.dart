import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/meeting/meeting_session.dart';
import 'package:v_meeting/meeting/widgets/meeting_participant.dart';

import 'support/meeting_fakes.dart';

Finder pictureOf(String path) => find.byKey(ValueKey('avatar-$path'));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'server_url': 'https://meeting.test:443',
    });
  });

  testWidgets('with the camera off, a profile picture shows in the tile', (
    tester,
  ) async {
    final local = TestLocal()
      ..values[MeetingSession.avatarAttribute] =
          '/avatars/1-0123456789abcdef.jpg';
    await openExitTest(tester, TestRoom(local: local));
    // Asked from the server the app is set to.
    final picture = tester.widget<Image>(
      pictureOf('/avatars/1-0123456789abcdef.jpg').first,
    );
    expect(
      (picture.image as ResizeImage).imageProvider,
      isA<NetworkImage>().having(
        (image) => image.url,
        'url',
        'https://meeting.test:443/avatars/1-0123456789abcdef.jpg',
      ),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('without one, the initials stay', (tester) async {
    await openExitTest(tester, TestRoom(local: TestLocal()));
    expect(find.byType(Image), findsNothing);
    expect(find.byType(MemberAvatar), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
}
