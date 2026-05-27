import 'dart:io';

import 'coffee_photo_step.dart';
import 'coffee_validation_result.dart';

class CoffeeImagePipelineResult {
  const CoffeeImagePipelineResult({
    required this.step,
    required this.compressedImage,
    required this.validationResult,
    required this.tempFiles,
  });

  final CoffeePhotoStep step;
  final File compressedImage;
  final CoffeeValidationResult validationResult;
  final List<File> tempFiles;
}
