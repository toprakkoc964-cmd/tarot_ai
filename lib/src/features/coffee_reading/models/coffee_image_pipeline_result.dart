import 'dart:io';

import 'coffee_image_source.dart';
import 'coffee_image_source_evidence.dart';
import 'coffee_photo_step.dart';
import 'coffee_validation_result.dart';

class CoffeeImagePipelineResult {
  const CoffeeImagePipelineResult({
    required this.step,
    required this.compressedImage,
    required this.validationResult,
    required this.tempFiles,
    required this.fingerprint,
    required this.source,
    required this.sourceEvidence,
  });

  final CoffeePhotoStep step;
  final File compressedImage;
  final CoffeeValidationResult validationResult;
  final List<File> tempFiles;
  final String fingerprint;
  final CoffeeImageSource source;
  final CoffeeImageSourceEvidence sourceEvidence;

  bool get fromGallery => source.isGallery;
}
