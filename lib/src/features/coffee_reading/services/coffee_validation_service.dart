import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../models/coffee_photo_step.dart';
import '../models/coffee_validation_result.dart';

class CoffeeValidationService {
  CoffeeValidationService()
      : _imageLabeler = ImageLabeler(
          options: ImageLabelerOptions(confidenceThreshold: 0.35),
        );

  final ImageLabeler _imageLabeler;

  static const Set<String> _baseStrongLabels = {
    'cup',
    'coffee cup',
    'mug',
    'teacup',
    'drinkware',
  };

  static const Set<String> _baseWeakLabels = {
    'tableware',
    'dishware',
    'ceramic',
    'saucer',
    'plate',
    'bowl',
    'drink',
    'beverage',
    'coffee',
    'espresso',
  };

  Future<CoffeeValidationResult> validate(
    File image,
    CoffeePhotoStep step,
  ) async {
    try {
      final inputImage = InputImage.fromFile(image);
      final labels = await _imageLabeler.processImage(inputImage);
      final rawLabels = labels
          .map(
            (label) => '${label.label}:${label.confidence.toStringAsFixed(2)}',
          )
          .toList(growable: false);

      final strongLabels = _strongLabelsFor(step);
      final weakLabels = _weakLabelsFor(step);
      ImageLabel? bestStrong;
      ImageLabel? bestWeak;

      for (final label in labels) {
        final normalized = label.label.trim().toLowerCase();
        if (strongLabels.contains(normalized) &&
            label.confidence >= (bestStrong?.confidence ?? 0)) {
          bestStrong = label;
        }
        if (weakLabels.contains(normalized) &&
            label.confidence >= (bestWeak?.confidence ?? 0)) {
          bestWeak = label;
        }
      }

      if (bestStrong != null && bestStrong.confidence >= 0.60) {
        return CoffeeValidationResult(
          isValid: true,
          hasWarning: false,
          confidence: bestStrong.confidence,
          matchedLabels: [bestStrong.label],
          rawLabels: rawLabels,
        );
      }

      if (bestWeak != null && bestWeak.confidence >= 0.70) {
        return CoffeeValidationResult(
          isValid: true,
          hasWarning: true,
          confidence: bestWeak.confidence,
          matchedLabels: [bestWeak.label],
          rawLabels: rawLabels,
          warningMessage: 'coffeeWeakImageWarning',
        );
      }

      return CoffeeValidationResult(
        isValid: false,
        hasWarning: false,
        confidence: bestStrong?.confidence ?? bestWeak?.confidence ?? 0,
        matchedLabels: [
          if (bestStrong != null) bestStrong.label,
          if (bestWeak != null) bestWeak.label,
        ],
        rawLabels: rawLabels,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Coffee validation failed: $e');
        debugPrintStack(stackTrace: st);
      }
      return const CoffeeValidationResult(
        isValid: false,
        hasWarning: false,
        confidence: 0,
        matchedLabels: [],
        rawLabels: [],
      );
    }
  }

  Future<void> dispose() async {
    await _imageLabeler.close();
  }

  Set<String> _strongLabelsFor(CoffeePhotoStep step) {
    switch (step) {
      case CoffeePhotoStep.cupInside:
        return const {
          'cup',
          'coffee cup',
          'mug',
          'teacup',
          'drinkware',
        };
      case CoffeePhotoStep.saucer:
        return const {
          'saucer',
          'plate',
          'tableware',
          'dishware',
        };
      case CoffeePhotoStep.cupSide:
        return const {
          'cup',
          'coffee cup',
          'mug',
          'teacup',
          'drinkware',
        };
    }
  }

  Set<String> _weakLabelsFor(CoffeePhotoStep step) {
    switch (step) {
      case CoffeePhotoStep.cupInside:
        return {
          ..._baseStrongLabels,
          ..._baseWeakLabels,
          'coffee',
          'espresso',
        };
      case CoffeePhotoStep.saucer:
        return const {
          'ceramic',
          'bowl',
          'cup',
          'coffee cup',
          'mug',
          'coffee',
          'espresso',
        };
      case CoffeePhotoStep.cupSide:
        return const {
          'ceramic',
          'tableware',
          'dishware',
          'coffee',
          'espresso',
          'drink',
          'beverage',
        };
    }
  }
}
