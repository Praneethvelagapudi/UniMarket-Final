import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class PhotoService {
  static const maxBytes = 180000;
  static Future<Uint8List> compress(Uint8List input) =>
      compute(_compress, input);
  static Uint8List _compress(Uint8List input) {
    final decoded = img.decodeImage(input);
    if (decoded == null) {
      throw ArgumentError(
        'This photo could not be read. Choose a different image.',
      );
    }
    final oriented = img.bakeOrientation(decoded);
    var resized = oriented.width >= oriented.height
        ? img.copyResize(
            oriented,
            width: oriented.width > 800 ? 800 : oriented.width,
          )
        : img.copyResize(
            oriented,
            height: oriented.height > 800 ? 800 : oriented.height,
          );
    for (final quality in [80, 65, 50, 35]) {
      final result = img.encodeJpg(resized, quality: quality);
      if (result.length <= maxBytes) return result;
    }
    resized = img.copyResize(
      resized,
      width: (resized.width / 2).round().clamp(1, 400),
      height: (resized.height / 2).round().clamp(1, 400),
    );
    final result = img.encodeJpg(resized, quality: 35);
    if (result.length > maxBytes) {
      throw ArgumentError('This photo is too detailed. Try a smaller image.');
    }
    return result;
  }
}
