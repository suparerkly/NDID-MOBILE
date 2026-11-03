import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndid_mobile/screens/face_scan_screen.dart';

Map<String, Object> _plane(List<int> bytes, int bytesPerRow, int pixelStride) =>
    {
      'bytes': Uint8List.fromList(bytes),
      'bytesPerRow': bytesPerRow,
      'bytesPerPixel': pixelStride,
    };

CameraImage _image(List<Map<String, Object>> planes) =>
    // ignore: deprecated_member_use
    CameraImage.fromPlatformData({
      'format': 35,
      'width': 4,
      'height': 2,
      'planes': planes,
    });

void main() {
  test('removes row padding and orders chroma as V then U', () {
    final image = _image([
      // Y มี padding ท้ายแถว 2 ไบต์
      _plane([1, 2, 3, 4, 0, 0, 5, 6, 7, 8, 0, 0], 6, 1),
      _plane([10, 11], 2, 1),
      _plane([20, 21], 2, 1),
    ]);

    expect(yuv420ToNv21(image), [1, 2, 3, 4, 5, 6, 7, 8, 20, 10, 21, 11]);
  });

  test('handles interleaved chroma with a pixel stride of 2', () {
    final image = _image([
      _plane([1, 2, 3, 4, 5, 6, 7, 8], 4, 1),
      _plane([10, 20, 11], 4, 2),
      _plane([20, 10, 21], 4, 2),
    ]);

    expect(yuv420ToNv21(image), [1, 2, 3, 4, 5, 6, 7, 8, 20, 10, 21, 11]);
  });
}
