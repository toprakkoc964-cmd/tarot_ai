import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'
    as image_compress;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';
import '../models/coffee_image_pipeline_result.dart';
import '../models/coffee_photo_step.dart';
import '../models/coffee_validation_result.dart';
import 'coffee_temp_file_cleaner.dart';
import 'coffee_validation_service.dart';

class CoffeePipelineException implements Exception {
  const CoffeePipelineException(
    this.messageKey, {
    this.validationResult,
    this.isPermissionError = false,
  });

  final String messageKey;
  final CoffeeValidationResult? validationResult;
  final bool isPermissionError;

  @override
  String toString() => 'CoffeePipelineException($messageKey)';
}

class CoffeeImagePipelineService {
  CoffeeImagePipelineService({
    required CoffeeValidationService validationService,
    required CoffeeTempFileCleaner tempFileCleaner,
    ImagePicker? picker,
    ImageCropper? cropper,
  })  : _validationService = validationService,
        _tempFileCleaner = tempFileCleaner,
        _picker = picker ?? ImagePicker(),
        _cropper = cropper ?? ImageCropper();

  final CoffeeValidationService _validationService;
  final CoffeeTempFileCleaner _tempFileCleaner;
  final ImagePicker _picker;
  final ImageCropper _cropper;

  Future<CoffeeImagePipelineResult?> processImage(
    ImageSource source,
    CoffeePhotoStep step,
  ) async {
    final ownedTempFiles = <File>[];

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (picked == null) {
        await _tempFileCleaner.cleanup(ownedTempFiles);
        return null;
      }

      final pickedFile = File(picked.path);
      if (source == ImageSource.camera) {
        ownedTempFiles.add(pickedFile);
      }

      final cropped = await _cropImage(pickedFile, step);
      if (cropped == null) {
        await _tempFileCleaner.cleanup(ownedTempFiles);
        return null;
      }

      final croppedFile = File(cropped.path);
      ownedTempFiles.add(croppedFile);

      final compressedFile = await _compressImage(croppedFile, step);
      if (compressedFile == null) {
        await _tempFileCleaner.cleanup(ownedTempFiles);
        throw const CoffeePipelineException('coffeeCompressionFailed');
      }
      ownedTempFiles.add(compressedFile);

      final validationResult =
          await _validationService.validate(compressedFile, step);
      if (!validationResult.isValid) {
        await _tempFileCleaner.cleanup(ownedTempFiles);
        throw CoffeePipelineException(
          'coffeeInvalidImage',
          validationResult: validationResult,
        );
      }

      return CoffeeImagePipelineResult(
        step: step,
        compressedImage: compressedFile,
        validationResult: validationResult,
        tempFiles: List<File>.unmodifiable(ownedTempFiles),
      );
    } on PlatformException catch (e, st) {
      await _tempFileCleaner.cleanup(ownedTempFiles);
      if (kDebugMode) {
        debugPrint('Coffee picker/cropper platform error: ${e.code}');
        debugPrintStack(stackTrace: st);
      }
      throw CoffeePipelineException(
        _isPermissionException(e) ? 'coffeePermissionDenied' : 'error.default',
        isPermissionError: _isPermissionException(e),
      );
    } on CoffeePipelineException {
      rethrow;
    } catch (e, st) {
      await _tempFileCleaner.cleanup(ownedTempFiles);
      if (kDebugMode) {
        debugPrint('Coffee image pipeline failed: $e');
        debugPrintStack(stackTrace: st);
      }
      throw const CoffeePipelineException('coffeeValidationFailed');
    }
  }

  Future<CroppedFile?> _cropImage(File file, CoffeePhotoStep step) {
    final title = AppTexts.t(step.cropTitleKey);
    return _cropper.cropImage(
      sourcePath: file.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 100,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          toolbarColor: AppColors.background,
          toolbarWidgetColor: AppColors.primaryPink,
          backgroundColor: AppColors.background,
          activeControlsWidgetColor: AppColors.primaryNeonPink,
          dimmedLayerColor: Colors.black.withValues(alpha: 0.72),
          cropFrameColor: AppColors.primaryPink,
          cropGridColor: AppColors.secondaryLavender.withValues(alpha: 0.64),
          cropFrameStrokeWidth: 2,
          cropGridStrokeWidth: 1,
          showCropGrid: true,
          lockAspectRatio: true,
          initAspectRatio: CropAspectRatioPreset.square,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
        ),
        IOSUiSettings(
          title: title,
          doneButtonTitle: AppTexts.t('common.done'),
          cancelButtonTitle: AppTexts.t('common.cancel'),
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          resetButtonHidden: true,
          rotateButtonsHidden: false,
          aspectRatioPresets: const [CropAspectRatioPreset.square],
        ),
      ],
    );
  }

  Future<File?> _compressImage(File file, CoffeePhotoStep step) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath = p.join(
        tempDir.path,
        'coffee_${step.metadataKey}_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      final compressed =
          await image_compress.FlutterImageCompress.compressAndGetFile(
        file.path,
        outputPath,
        minWidth: 1024,
        minHeight: 1024,
        quality: 80,
        format: image_compress.CompressFormat.jpeg,
        keepExif: false,
      );
      if (compressed == null) return null;
      return File(compressed.path);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Coffee image compression failed: $e');
        debugPrintStack(stackTrace: st);
      }
      return null;
    }
  }

  bool _isPermissionException(PlatformException error) {
    final code = error.code.toLowerCase();
    final message = (error.message ?? '').toLowerCase();
    return code.contains('permission') ||
        code.contains('denied') ||
        message.contains('permission') ||
        message.contains('denied');
  }
}
