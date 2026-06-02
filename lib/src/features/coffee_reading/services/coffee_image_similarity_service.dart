import 'dart:io';

import 'package:image/image.dart' as img;

class CoffeeImageSimilarityService {
  Future<String> fingerprint(File image) async {
    final decoded = await _decode(image);
    if (decoded == null) return '';
    final resized = img.copyResize(decoded, width: 8, height: 8);
    final gray = img.grayscale(resized);
    return _averageHash(gray);
  }

  double similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0;
    var matches = 0;
    for (var i = 0; i < a.length; i++) {
      if (a[i] == b[i]) matches++;
    }
    return matches / a.length;
  }

  bool isDuplicate(String a, String b, {double threshold = 0.85}) {
    return similarity(a, b) >= threshold;
  }

  Future<img.Image?> _decode(File file) async {
    try {
      return img.decodeImage(await file.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  String _averageHash(img.Image gray) {
    final values = <int>[];
    for (var y = 0; y < gray.height; y++) {
      for (var x = 0; x < gray.width; x++) {
        values.add(img.getLuminance(gray.getPixel(x, y)).round());
      }
    }
    final average = values.reduce((a, b) => a + b) / values.length;
    final buffer = StringBuffer();
    for (final value in values) {
      buffer.write(value >= average ? '1' : '0');
    }
    return buffer.toString();
  }
}
