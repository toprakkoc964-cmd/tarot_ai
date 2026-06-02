import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../models/coffee_photo_step.dart';

class CoffeeResidueMetrics {
  const CoffeeResidueMetrics({
    required this.darkResidueRatio,
    required this.textureVariance,
    required this.hasResidue,
  });

  final double darkResidueRatio;
  final double textureVariance;
  final bool hasResidue;
}

class CoffeeResidueDetectionService {
  Future<CoffeeResidueMetrics> analyze(
    File image, {
    required CoffeePhotoStep step,
  }) async {
    final decoded = await _decode(image);
    if (decoded == null) {
      return const CoffeeResidueMetrics(
        darkResidueRatio: 0,
        textureVariance: 0,
        hasResidue: false,
      );
    }

    final resized = img.copyResize(decoded, width: 96, height: 96);
    final roiRadius = step == CoffeePhotoStep.saucer ? 0.48 : 0.43;
    final darkRatio = _darkResidueRatio(resized, roiRadius: roiRadius);
    final textureVariance = _textureVariance(resized, roiRadius: roiRadius);

    return CoffeeResidueMetrics(
      darkResidueRatio: darkRatio,
      textureVariance: textureVariance.toDouble(),
      hasResidue: darkRatio >= 0.03 && textureVariance >= 120,
    );
  }

  Future<img.Image?> _decode(File file) async {
    try {
      return img.decodeImage(await file.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  double _darkResidueRatio(
    img.Image image, {
    required double roiRadius,
  }) {
    var darkCount = 0;
    var total = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        if (!_insideCircularRoi(image, x, y, roiRadius)) continue;
        total++;
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        if (_isDarkCoffeeTone(r, g, b)) darkCount++;
      }
    }
    return total == 0 ? 0 : darkCount / total;
  }

  bool _isDarkCoffeeTone(int r, int g, int b) {
    final max = math.max(r, math.max(g, b));
    final min = math.min(r, math.min(g, b));
    final brightness = (r + g + b) / 3;
    final isBrownish = r > g && g >= b && max - min < 90;
    return brightness < 95 && (isBrownish || brightness < 55);
  }

  double _textureVariance(
    img.Image image, {
    required double roiRadius,
  }) {
    final grayValues = <double>[];
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        if (!_insideCircularRoi(image, x, y, roiRadius)) continue;
        grayValues.add(img.getLuminance(image.getPixel(x, y)).toDouble());
      }
    }
    if (grayValues.isEmpty) return 0;
    final mean = grayValues.reduce((a, b) => a + b) / grayValues.length;
    return (grayValues
                .map((v) => math.pow(v - mean, 2))
                .reduce((a, b) => a + b) /
            grayValues.length)
        .toDouble();
  }

  bool _insideCircularRoi(img.Image image, int x, int y, double radius) {
    final normalizedX = (x + 0.5) / image.width;
    final normalizedY = (y + 0.5) / image.height;
    final dx = normalizedX - 0.5;
    final dy = normalizedY - 0.5;
    return (dx * dx) + (dy * dy) <= radius * radius;
  }
}
