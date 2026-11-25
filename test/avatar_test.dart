import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_meeting/meeting/meeting_api.dart';
import 'package:v_meeting/social/avatar_picker.dart';
import 'package:v_meeting/social/social_api.dart';

/// A picture whose left half is red and right half blue.
img.Image halves(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (var x = 0; x < width; x++) {
    for (var y = 0; y < height; y++) {
      image.setPixelRgb(
        x,
        y,
        x < width / 2 ? 255 : 0,
        0,
        x < width / 2 ? 0 : 255,
      );
    }
  }
  return image;
}

bool isRed(img.Pixel pixel) => pixel.r > 200 && pixel.b < 60;
bool isBlue(img.Pixel pixel) => pixel.b > 200 && pixel.r < 60;

void main() {
  test('a picture becomes its middle square, at most the sent size', () {
    final wide = squareJpeg(img.encodePng(halves(1200, 600)))!;
    final decoded = img.decodeJpg(wide)!;
    expect([decoded.width, decoded.height], [sentPictureSize, sentPictureSize]);
    // The middle: red on the left, blue on the right.
    expect(isRed(decoded.getPixel(20, 256)), isTrue);
    expect(isBlue(decoded.getPixel(490, 256)), isTrue);

    final small = img.decodeJpg(squareJpeg(img.encodePng(halves(100, 60)))!)!;
    expect([small.width, small.height], [60, 60]);
  });

  test('a photo turned by the camera comes out upright', () {
    final photo = halves(300, 100);
    // Taken holding the phone upright: shown turned a quarter clockwise.
    photo.exif.imageIfd.orientation = 6;
    final upright = img.decodeJpg(squareJpeg(img.encodeJpg(photo))!)!;
    // Turned, the red half is on top and the blue below.
    expect(isRed(upright.getPixel(50, 10)), isTrue);
    expect(isBlue(upright.getPixel(50, 90)), isTrue);
  });

  test('a file that is not a picture is refused', () {
    expect(squareJpeg(Uint8List.fromList([1, 2, 3])), isNull);
  });

  test('the photo goes to the server as a form upload', () async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'account-1'});
    SharedPreferences.setMockInitialValues({
      'server_url': 'https://meeting.test:443',
    });
    RequestOptions? sent;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sent = options;
            handler.resolve(
              Response(requestOptions: options, statusCode: 200, data: {}),
            );
          },
        ),
      );
    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
    await SocialApi(MeetingApi(dio: dio)).uploadAvatar(jpeg);
    expect(sent!.method, 'PUT');
    expect(sent!.uri.path, '/me/avatar');
    final form = sent!.data as FormData;
    final file = form.files.single;
    expect(file.key, 'avatar');
    expect(file.value.contentType.toString(), 'image/jpeg');
    expect(file.value.length, jpeg.length);
  });
}
