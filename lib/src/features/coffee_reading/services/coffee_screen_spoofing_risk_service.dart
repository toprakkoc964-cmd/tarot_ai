import 'dart:io';
import 'dart:math' as math;

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image/image.dart' as img;

class CoffeeScreenSpoofingMetrics {
  const CoffeeScreenSpoofingMetrics({
    required this.riskScore,
    required this.isLikelySpoofing,
  });

  final double riskScore;
  final bool isLikelySpoofing;
}

class CoffeeScreenSpoofingRiskService {
  static const Set<String> _deviceLabels = {
    'screen',
    'display',
    'monitor',
    'television',
    'laptop',
    'computer',
    'mobile phone',
    'smartphone',
    'tablet',
    'electronic device',
    'keyboard',
  };

  Future<CoffeeScreenSpoofingMetrics> analyze({
    required File image,
    required List<ImageLabel> labels,
  }) async {
    var risk = 0.0;

    for (final label in labels) {
      final normalized = label.label.trim().toLowerCase();
      if (_deviceLabels.contains(normalized)) {
        risk += label.confidence * 0.45;
      }
    }

    final decoded = await _decode(image);
    if (decoded != null) {
      risk += _moireScore(decoded) * 0.35;
      risk += _edgeUniformityScore(decoded) * 0.15;
    }

    return CoffeeScreenSpoofingMetrics(
      riskScore: risk.clamp(0, 1),
      isLikelySpoofing: risk >= 0.62,
    );
  }

  Future<img.Image?> _decode(File file) async {
    try {
      return img.decodeImage(await file.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  double _moireScore(img.Image image) {
    final resized = img.copyResize(image, width: 64, height: 64);
    final gray = img.grayscale(resized);
    var alternating = 0;
    var total = 0;
    for (var y = 1; y < gray.height - 1; y++) {
      for (var x = 1; x < gray.width - 1; x++) {
        final center = img.getLuminance(gray.getPixel(x, y)).toDouble();
        final left = img.getLuminance(gray.getPixel(x - 1, y)).toDouble();
        final right = img.getLuminance(gray.getPixel(x + 1, y)).toDouble();
        if ((center - left).abs() > 18 && (center - right).abs() > 18) {
          alternating++;
        }
        total++;
      }
    }
    if (total == 0) return 0;
    return (alternating / total).clamp(0, 1);
  }

  double _edgeUniformityScore(img.Image image) {
    final resized = img.copyResize(image, width: 48, height: 48);
    final edgeValues = <double>[];
    for (var x = 0; x < resized.width; x++) {
      edgeValues.add(img.getLuminance(resized.getPixel(x, 0)).toDouble());
      edgeValues.add(
        img.getLuminance(resized.getPixel(x, resized.height - 1)).toDouble(),
      );
    }
    for (var y = 0; y < resized.height; y++) {
      edgeValues.add(img.getLuminance(resized.getPixel(0, y)).toDouble());
      edgeValues.add(
        img.getLuminance(resized.getPixel(resized.width - 1, y)).toDouble(),
      );
    }
    if (edgeValues.isEmpty) return 0;
    final mean = edgeValues.reduce((a, b) => a + b) / edgeValues.length;
    final variance =
        edgeValues.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) /
            edgeValues.length;
    return variance < 80 ? 0.35 : 0;
  }
}
