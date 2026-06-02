import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image_picker/image_picker.dart';

import '../models/coffee_photo_step.dart';
import '../models/coffee_image_source_evidence.dart';
import '../models/coffee_validation_failure_reason.dart';
import '../models/coffee_validation_result.dart';
import 'coffee_image_quality_service.dart';
import 'coffee_image_similarity_service.dart';
import 'coffee_residue_detection_service.dart';
import 'coffee_screen_spoofing_risk_service.dart';
import 'coffee_screenshot_risk_service.dart';

class CoffeeValidationService {
  CoffeeValidationService({
    ImageLabeler? imageLabeler,
    CoffeeImageQualityService? qualityService,
    CoffeeResidueDetectionService? residueService,
    CoffeeImageSimilarityService? similarityService,
    CoffeeScreenshotRiskService? screenshotRiskService,
    CoffeeScreenSpoofingRiskService? screenSpoofingRiskService,
  })  : _imageLabeler = imageLabeler ??
            ImageLabeler(
              options: ImageLabelerOptions(confidenceThreshold: 0.35),
            ),
        _qualityService = qualityService ?? CoffeeImageQualityService(),
        _residueService = residueService ?? CoffeeResidueDetectionService(),
        _similarityService =
            similarityService ?? CoffeeImageSimilarityService(),
        _screenshotRiskService =
            screenshotRiskService ?? CoffeeScreenshotRiskService(),
        _screenSpoofingRiskService =
            screenSpoofingRiskService ?? CoffeeScreenSpoofingRiskService();

  final ImageLabeler _imageLabeler;
  final CoffeeImageQualityService _qualityService;
  final CoffeeResidueDetectionService _residueService;
  final CoffeeImageSimilarityService _similarityService;
  final CoffeeScreenshotRiskService _screenshotRiskService;
  final CoffeeScreenSpoofingRiskService _screenSpoofingRiskService;

  static const Set<String> _inappropriateLabels = {
    'nudity',
    'underwear',
    'swimwear',
    'weapon',
    'gun',
    'knife',
    'violence',
    'blood',
    'drug',
    'id card',
    'passport',
    'credit card',
  };

  Future<CoffeeValidationResult> validate({
    required File image,
    required CoffeePhotoStep step,
    required ImageSource source,
    required CoffeeImageSourceEvidence sourceEvidence,
    List<String> previousFingerprints = const [],
  }) async {
    try {
      final labels =
          await _imageLabeler.processImage(InputImage.fromFile(image));
      final rawLabels = labels
          .map(
            (label) => '${label.label}:${label.confidence.toStringAsFixed(2)}',
          )
          .toList(growable: false);

      final quality = await _qualityService.analyze(image);
      if (quality.isBlurry) {
        return _invalid(
          reason: CoffeeValidationFailureReason.imageTooBlurry,
          rawLabels: rawLabels,
          isBlurry: true,
        );
      }
      if (quality.isTooDark) {
        return _invalid(
          reason: CoffeeValidationFailureReason.imageTooDark,
          rawLabels: rawLabels,
          isTooDark: true,
        );
      }
      if (quality.isTooBright) {
        return _invalid(
          reason: CoffeeValidationFailureReason.imageTooBright,
          rawLabels: rawLabels,
          isTooBright: true,
        );
      }

      for (final label in labels) {
        if (_inappropriateLabels.contains(label.label.trim().toLowerCase()) &&
            label.confidence >= 0.55) {
          return _invalid(
            reason: CoffeeValidationFailureReason.inappropriateContent,
            rawLabels: rawLabels,
          );
        }
      }

      final fingerprint = await _similarityService.fingerprint(image);
      for (final previous in previousFingerprints) {
        if (_similarityService.isDuplicate(fingerprint, previous)) {
          return _invalid(
            reason: CoffeeValidationFailureReason.duplicateImage,
            rawLabels: rawLabels,
            isDuplicateLikePrevious: true,
          );
        }
      }

      final fromGallery = source == ImageSource.gallery;
      final screenshotRisk = await _screenshotRiskService.analyze(
        image: image,
        labels: labels,
        sourceEvidence: sourceEvidence,
      );
      if (screenshotRisk.isHighRisk) {
        return _invalid(
          reason: CoffeeValidationFailureReason.screenshotOrStockLike,
          rawLabels: rawLabels,
          isLikelyScreenshotOrStock: true,
        );
      }

      final spoofingRisk = await _screenSpoofingRiskService.analyze(
        image: image,
        labels: labels,
      );
      if (spoofingRisk.isLikelySpoofing) {
        return _invalid(
          reason: CoffeeValidationFailureReason.screenSpoofing,
          rawLabels: rawLabels,
          isLikelyScreenSpoofing: true,
        );
      }

      final labelScores = _labelScores(step, labels);
      final hasCup = labelScores.hasCup;
      final hasSaucer = labelScores.hasSaucer;
      final hasCoffee = labelScores.hasCoffee;
      final stepMatchScore = labelScores.stepMatchScore;
      final objectLabelScore = labelScores.objectLabelScore;

      CoffeeResidueMetrics? residue;
      var residueTextureScore = 0.0;
      var hasTasseographyLikeTexture = false;

      if (step == CoffeePhotoStep.cupInside || step == CoffeePhotoStep.saucer) {
        residue = await _residueService.analyze(image, step: step);
        final minRatio = step == CoffeePhotoStep.cupInside ? 0.03 : 0.015;
        final hasResidue = step == CoffeePhotoStep.saucer
            ? residue.darkResidueRatio >= minRatio ||
                (hasCoffee && residue.textureVariance >= 120)
            : residue.darkResidueRatio >= minRatio && residue.hasResidue;

        residueTextureScore =
            hasResidue ? 1 : residue.darkResidueRatio / minRatio;
        hasTasseographyLikeTexture = hasResidue;

        if (!hasResidue) {
          if (step == CoffeePhotoStep.cupInside && hasCup) {
            return _invalid(
              reason: CoffeeValidationFailureReason.emptyCup,
              rawLabels: rawLabels,
              hasCup: hasCup,
              hasCoffee: hasCoffee,
            );
          }
          return _invalid(
            reason: CoffeeValidationFailureReason.noCoffeeResidueDetected,
            rawLabels: rawLabels,
            hasCup: hasCup,
            hasSaucer: hasSaucer,
            hasCoffee: hasCoffee,
          );
        }
      } else {
        residueTextureScore = hasCup ? 0.85 : 0.2;
        hasTasseographyLikeTexture = hasCoffee;
      }

      if (!_stepObjectValid(step, hasCup: hasCup, hasSaucer: hasSaucer)) {
        return _invalid(
          reason: step == CoffeePhotoStep.saucer
              ? CoffeeValidationFailureReason.noSaucerDetected
              : CoffeeValidationFailureReason.noCupDetected,
          rawLabels: rawLabels,
          hasCup: hasCup,
          hasSaucer: hasSaucer,
        );
      }

      if (stepMatchScore < 0.45) {
        return _invalid(
          reason: CoffeeValidationFailureReason.wrongStepImage,
          rawLabels: rawLabels,
          hasCup: hasCup,
          hasSaucer: hasSaucer,
        );
      }

      final imageQualityScore = _qualityScore(quality);
      final uniquenessScore = 1.0;
      final sourceTrustScore = fromGallery ? 0.55 : 1.0;

      final validationScore = (objectLabelScore * 0.25) +
          (stepMatchScore * 0.25) +
          (residueTextureScore.clamp(0, 1) * 0.20) +
          (imageQualityScore * 0.15) +
          (uniquenessScore * 0.10) +
          (sourceTrustScore * 0.05);

      final threshold = fromGallery ? 0.78 : 0.70;
      final strictThreshold =
          screenshotRisk.riskScore >= 0.35 ? 0.85 : threshold;

      if (validationScore < strictThreshold) {
        return _invalid(
          reason: CoffeeValidationFailureReason.lowConfidence,
          rawLabels: rawLabels,
          hasCup: hasCup,
          hasSaucer: hasSaucer,
          hasCoffee: hasCoffee,
          hasTasseographyLikeTexture: hasTasseographyLikeTexture,
          validationScore: validationScore,
          confidence: validationScore,
          matchedLabels: labelScores.matchedLabels,
        );
      }

      return CoffeeValidationResult(
        isValid: true,
        confidence: validationScore.clamp(0, 1),
        matchedLabels: labelScores.matchedLabels,
        rawLabels: rawLabels,
        hasCup: hasCup,
        hasSaucer: hasSaucer,
        hasCoffee: hasCoffee,
        hasTasseographyLikeTexture: hasTasseographyLikeTexture,
        validationScore: validationScore,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Coffee validation failed: $e');
        debugPrintStack(stackTrace: st);
      }
      return const CoffeeValidationResult(
        isValid: false,
        confidence: 0,
        failureReason: CoffeeValidationFailureReason.unknown,
        matchedLabels: [],
        rawLabels: [],
      );
    }
  }

  CoffeeValidationResult _invalid({
    required CoffeeValidationFailureReason reason,
    required List<String> rawLabels,
    bool hasCup = false,
    bool hasSaucer = false,
    bool hasCoffee = false,
    bool hasTasseographyLikeTexture = false,
    bool isLikelyScreenshotOrStock = false,
    bool isLikelyScreenSpoofing = false,
    bool isDuplicateLikePrevious = false,
    bool isBlurry = false,
    bool isTooDark = false,
    bool isTooBright = false,
    double validationScore = 0,
    double confidence = 0,
    List<String> matchedLabels = const [],
  }) {
    return CoffeeValidationResult(
      isValid: false,
      confidence: confidence,
      failureReason: reason,
      matchedLabels: matchedLabels,
      rawLabels: rawLabels,
      hasCup: hasCup,
      hasSaucer: hasSaucer,
      hasCoffee: hasCoffee,
      hasTasseographyLikeTexture: hasTasseographyLikeTexture,
      isLikelyScreenshotOrStock: isLikelyScreenshotOrStock,
      isLikelyScreenSpoofing: isLikelyScreenSpoofing,
      isDuplicateLikePrevious: isDuplicateLikePrevious,
      isBlurry: isBlurry,
      isTooDark: isTooDark,
      isTooBright: isTooBright,
      validationScore: validationScore,
    );
  }

  bool _stepObjectValid(
    CoffeePhotoStep step, {
    required bool hasCup,
    required bool hasSaucer,
  }) {
    switch (step) {
      case CoffeePhotoStep.cupInside:
      case CoffeePhotoStep.cupSide:
        return hasCup;
      case CoffeePhotoStep.saucer:
        return hasSaucer;
    }
  }

  double _qualityScore(CoffeeImageQualityMetrics quality) {
    var score = 1.0;
    if (quality.isBlurry) score -= 0.5;
    if (quality.isTooDark) score -= 0.35;
    if (quality.isTooBright) score -= 0.35;
    return score.clamp(0, 1);
  }

  _LabelScores _labelScores(CoffeePhotoStep step, List<ImageLabel> labels) {
    final strong = _strongLabelsFor(step);
    final weak = _weakLabelsFor(step);
    final matched = <String>[];
    var bestStrong = 0.0;
    var bestWeak = 0.0;
    var hasCup = false;
    var hasSaucer = false;
    var hasCoffee = false;

    for (final label in labels) {
      final normalized = label.label.trim().toLowerCase();
      matched.add(label.label);
      if (_cupLabels.contains(normalized) && label.confidence >= 0.45) {
        hasCup = true;
      }
      if (_saucerLabels.contains(normalized) && label.confidence >= 0.45) {
        hasSaucer = true;
      }
      if (_coffeeLabels.contains(normalized) && label.confidence >= 0.40) {
        hasCoffee = true;
      }
      if (strong.contains(normalized)) {
        bestStrong =
            bestStrong < label.confidence ? label.confidence : bestStrong;
      }
      if (weak.contains(normalized)) {
        bestWeak = bestWeak < label.confidence ? label.confidence : bestWeak;
      }
    }

    final objectLabelScore =
        (bestStrong > 0 ? bestStrong : bestWeak * 0.7).clamp(0.0, 1.0);
    final stepMatchScore = switch (step) {
      CoffeePhotoStep.cupInside =>
        hasCup && !hasSaucer ? 1.0 : (hasCup ? 0.75 : bestStrong),
      CoffeePhotoStep.saucer =>
        hasSaucer && !hasCup ? 1.0 : (hasSaucer ? 0.8 : bestStrong),
      CoffeePhotoStep.cupSide =>
        hasCup && !hasSaucer ? 0.95 : (hasCup ? 0.7 : bestStrong),
    };

    return _LabelScores(
      hasCup: hasCup,
      hasSaucer: hasSaucer,
      hasCoffee: hasCoffee,
      objectLabelScore: objectLabelScore,
      stepMatchScore: stepMatchScore.clamp(0, 1),
      matchedLabels: matched.take(6).toList(growable: false),
    );
  }

  static const Set<String> _cupLabels = {
    'cup',
    'coffee cup',
    'mug',
    'teacup',
    'drinkware',
  };

  static const Set<String> _saucerLabels = {
    'saucer',
    'plate',
    'dish',
    'tableware',
    'dishware',
  };

  static const Set<String> _coffeeLabels = {
    'coffee',
    'espresso',
    'beverage',
    'drink',
  };

  Set<String> _strongLabelsFor(CoffeePhotoStep step) {
    switch (step) {
      case CoffeePhotoStep.cupInside:
        return const {
          'cup',
          'coffee cup',
          'mug',
          'teacup',
          'drinkware',
          'coffee',
          'espresso',
        };
      case CoffeePhotoStep.saucer:
        return const {
          'saucer',
          'plate',
          'dish',
          'tableware',
          'ceramic',
        };
      case CoffeePhotoStep.cupSide:
        return const {
          'cup',
          'coffee cup',
          'mug',
          'drinkware',
          'ceramic',
        };
    }
  }

  Set<String> _weakLabelsFor(CoffeePhotoStep step) {
    switch (step) {
      case CoffeePhotoStep.cupInside:
        return const {
          'tableware',
          'dishware',
          'ceramic',
          'beverage',
          'drink',
        };
      case CoffeePhotoStep.saucer:
        return const {
          'bowl',
          'cup',
          'coffee',
          'espresso',
        };
      case CoffeePhotoStep.cupSide:
        return const {
          'tableware',
          'dishware',
          'coffee',
          'espresso',
          'drink',
          'beverage',
        };
    }
  }

  Future<void> dispose() async {
    await _imageLabeler.close();
  }
}

class _LabelScores {
  const _LabelScores({
    required this.hasCup,
    required this.hasSaucer,
    required this.hasCoffee,
    required this.objectLabelScore,
    required this.stepMatchScore,
    required this.matchedLabels,
  });

  final bool hasCup;
  final bool hasSaucer;
  final bool hasCoffee;
  final double objectLabelScore;
  final double stepMatchScore;
  final List<String> matchedLabels;
}
