import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:unimarket/services/photo_service.dart';

void main() {
  test('photos are valid JPEGs capped at 180 KB and 800 pixels', () async {
    final source = img.Image(width: 1600, height: 1000);
    final compressed = await PhotoService.compress(img.encodePng(source));
    expect(compressed.length, lessThanOrEqualTo(PhotoService.maxBytes));
    final decoded = img.decodeJpg(compressed)!;
    expect(decoded.width, lessThanOrEqualTo(800));
    expect(decoded.height, lessThanOrEqualTo(800));
  });
  test('invalid photo bytes fail clearly', () async {
    await expectLater(
      PhotoService.compress(Uint8List.fromList([1, 2, 3])),
      throwsArgumentError,
    );
  });
}
