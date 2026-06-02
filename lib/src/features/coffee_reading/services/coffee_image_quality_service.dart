import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

class CoffeeImageQualityMetrics {
  const CoffeeImageQualityMetrics({
    required this.isBlurry,
    required this.isTooDark,
    required this.isTooBright,
    required this.sharpnessScore,
    required this.brightnessScore,
  });

  final bool isBlurry;
  final bool isTooDark;
  final bool isTooBright;
  final double sharpnessScore;
  final double brightnessScore;
}

class CoffeeImageQualityService {
  Future<CoffeeImageQualityMetrics> analyze(File image) async {
    final decoded = await _decode(image);
    if (decoded == null) {
      return const CoffeeImageQualityMetrics(
        isBlurry: true,
        isTooDark: true,
        isTooBright: false,
        sharpnessScore: 0,
        brightnessScore: 0,
      );
    }

    final resized = img.copyResize(decoded, width: 128, height: 128);
    final gray = img.grayscale(resized);
    final sharpness = _laplacianVariance(gray);
    final brightness = _averageLuminance(gray);

    final isBlurry = sharpness < 18;
    final isTooDark = brightness < 0.18;
    final isTooBright = brightness > 0.88;

    return CoffeeImageQualityMetrics(
      isBlurry: isBlurry,
      isTooDark: isTooDark,
      isTooBright: isTooBright,
      sharpnessScore: sharpness,
      brightnessScore: brightness,
    );
  }

  Future<img.Image?> _decode(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
  }

  double _laplacianVariance(img.Image gray) {
    final width = gray.width;
    final height = gray.height;
    if (width < 3 || height < 3) return 0;

    final kernel = <double>[
      0,
      1,
      0,
      1,
      -4,
      1,
      0,
      1,
      0,
    ];

    final values = <double>[];
    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        var sum = 0.0;
        var index = 0;
        for (var ky = -1; ky <= 1; ky++) {
          for (var kx = -1; kx <= 1; kx++) {
            final pixel = gray.getPixel(x + kx, y + ky);
            sum += img.getLuminance(pixel) * kernel[index++];
          }
        }
        values.add(sum);
      }
    }

    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) /
            values.length;
    return variance;
  }

  double _averageLuminance(img.Image gray) {
    var total = 0.0;
    final count = gray.width * gray.height;
    for (var y = 0; y < gray.height; y++) {
      for (var x = 0; x < gray.width; x++) {
        total += img.getLuminance(gray.getPixel(x, y));
      }
    }
    return total / count / 255;
  }
}
