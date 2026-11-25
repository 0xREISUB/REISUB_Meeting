import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:v_meeting/l10n/localized_error.dart';

/// Pictures larger than this are not opened: decoding them could run a
/// phone out of memory.
const maxPickedPictureBytes = 20 << 20;

/// The side of the square picture sent to the server, which keeps at most
/// half of it.
const sentPictureSize = 512;

/// Lets the user choose a picture and makes it a square JPEG, upright
/// whichever way the camera held it. Null when nothing was chosen.
Future<Uint8List?> pickProfilePicture() async {
  final file = await FilePicker.pickFile(type: FileType.image);
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.length > maxPickedPictureBytes) {
    throw const AppException.localized(AppError.imageTooLarge);
  }
  final square = await compute(squareJpeg, bytes);
  if (square == null) {
    throw const AppException.localized(AppError.invalidImage);
  }
  return square;
}

/// The middle square of a picture, upright and at most [sentPictureSize],
/// as a JPEG; null when it is not a picture.
@visibleForTesting
Uint8List? squareJpeg(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final upright = img.bakeOrientation(decoded);
  final side = upright.width < upright.height ? upright.width : upright.height;
  final square = img.copyResizeCropSquare(
    upright,
    size: side < sentPictureSize ? side : sentPictureSize,
    interpolation: img.Interpolation.average,
  );
  return img.encodeJpg(square, quality: 88);
}
