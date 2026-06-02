import 'dart:io';

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../models/coffee_image_source_evidence.dart';

class CoffeeScreenshotRiskMetrics {
  const CoffeeScreenshotRiskMetrics({
    required this.riskScore,
    required this.isHighRisk,
  });

  final double riskScore;
  final bool isHighRisk;
}

class CoffeeScreenshotRiskService {
  static const Set<String> _riskLabels = {
    'screenshot',
    'text',
    'poster',
    'website',
    'display',
    'screen',
    'logo',
    'document',
    'advertisement',
    'brochure',
  };

  Future<CoffeeScreenshotRiskMetrics> analyze({
    required File image,
    required List<ImageLabel> labels,
    required CoffeeImageSourceEvidence sourceEvidence,
  }) async {
    var risk = 0.0;

    for (final label in labels) {
      final normalized = label.label.trim().toLowerCase();
      if (_riskLabels.contains(normalized)) {
        risk += label.confidence * 0.35;
      }
    }

    final aspect = sourceEvidence.originalAspectRatio;
    if (aspect > 0 && (aspect > 1.8 || aspect < 0.55)) {
      risk += 0.12;
    }
    if (sourceEvidence.originalWidth >= 1400 &&
        sourceEvidence.originalHeight >= 1400) {
      risk += 0.08;
    }
    if (sourceEvidence.fromGallery) risk += 0.12;
    if (!sourceEvidence.hasExifMetadata && sourceEvidence.fromGallery) {
      risk += 0.08;
    }

    return CoffeeScreenshotRiskMetrics(
      riskScore: risk.clamp(0, 1),
      isHighRisk: risk >= 0.55,
    );
  }
}
