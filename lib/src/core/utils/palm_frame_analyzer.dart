import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import 'palm_detection_result.dart';

class PalmFrameAnalyzer {
  PalmFrameAnalyzer()
      : _labeler = ImageLabeler(
          options: ImageLabelerOptions(confidenceThreshold: 0.45),
        );

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  final ImageLabeler _labeler;

  Future<PalmDetectionResult> analyze({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) async {
    try {
      final inputImage = _toInputImage(
        image: image,
        camera: camera,
        deviceOrientation: deviceOrientation,
      );
      if (inputImage == null) return const PalmDetectionResult.noHand();

      final labels = await _labeler.processImage(inputImage);
      return _classifyLabels(labels);
    } catch (e, st) {
      debugPrint('Palm frame analysis failed: $e');
      debugPrintStack(stackTrace: st);
      return const PalmDetectionResult.noHand();
    }
  }

  Future<void> dispose() {
    return _labeler.close();
  }

  PalmDetectionResult _classifyLabels(List<ImageLabel> labels) {
    final visibleLabels = labels
        .map((label) => '${label.label}:${label.confidence.toStringAsFixed(2)}')
        .toList(growable: false);

    double palmConfidence = 0;
    double handConfidence = 0;
    double fingerConfidence = 0;
    double wristArmConfidence = 0;
    double distractorConfidence = 0;

    for (final label in labels) {
      final text = label.label.toLowerCase();
      final confidence = label.confidence;

      if (_containsAny(text, const ['palm'])) {
        palmConfidence = _max(palmConfidence, confidence);
      }
      if (_containsAny(text, const ['hand', 'gesture'])) {
        handConfidence = _max(handConfidence, confidence);
      }
      if (_containsAny(text, const ['finger', 'thumb'])) {
        fingerConfidence = _max(fingerConfidence, confidence);
      }
      if (_containsAny(text, const ['wrist', 'arm'])) {
        wristArmConfidence = _max(wristArmConfidence, confidence);
      }
      if (_containsAny(text, const [
        'phone',
        'screen',
        'computer',
        'keyboard',
        'laptop',
        'book',
        'paper',
        'bottle',
        'cup',
        'food',
        'plant',
        'furniture',
      ])) {
        distractorConfidence = _max(distractorConfidence, confidence);
      }
    }

    final primaryConfidence = _max(palmConfidence, handConfidence);
    final supportingConfidence = _max(fingerConfidence, wristArmConfidence);
    final bestConfidence = _max(primaryConfidence, supportingConfidence);

    if (bestConfidence < 0.55) {
      return PalmDetectionResult(
        state: PalmDetectionState.noHand,
        confidence: bestConfidence,
        labels: visibleLabels,
      );
    }

    final hasStrongPrimary = palmConfidence >= 0.72 || handConfidence >= 0.8;
    final hasSupport = supportingConfidence >= 0.56;
    final hasOnlyPartial =
        primaryConfidence < 0.7 && supportingConfidence >= 0.62;
    final blockedByDistractor =
        distractorConfidence >= 0.82 && distractorConfidence > bestConfidence;

    if (blockedByDistractor) {
      return PalmDetectionResult(
        state: hasOnlyPartial
            ? PalmDetectionState.partialHand
            : PalmDetectionState.noHand,
        confidence: bestConfidence,
        labels: visibleLabels,
      );
    }

    if ((palmConfidence >= 0.8 || handConfidence >= 0.86) &&
        (hasSupport || palmConfidence >= 0.88)) {
      return PalmDetectionResult(
        state: PalmDetectionState.validHand,
        confidence: _max(primaryConfidence, supportingConfidence),
        labels: visibleLabels,
      );
    }

    if (hasStrongPrimary || (primaryConfidence >= 0.68 && hasSupport)) {
      return PalmDetectionResult(
        state: PalmDetectionState.possibleHand,
        confidence: _max(primaryConfidence, supportingConfidence),
        labels: visibleLabels,
      );
    }

    return PalmDetectionResult(
      state: hasOnlyPartial
          ? PalmDetectionState.partialHand
          : PalmDetectionState.noHand,
      confidence: bestConfidence,
      labels: visibleLabels,
    );
  }

  bool _containsAny(String text, List<String> needles) {
    return needles.any(text.contains);
  }

  double _max(double a, double b) => a > b ? a : b;

  InputImage? _toInputImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    final rotation = _inputImageRotation(
      camera: camera,
      deviceOrientation: deviceOrientation,
    );
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (Platform.isAndroid && format != InputImageFormat.nv21) {
      return null;
    }
    if (Platform.isIOS && format != InputImageFormat.bgra8888) {
      return null;
    }
    if (image.planes.length != 1) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: Uint8List.fromList(plane.bytes),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  InputImageRotation? _inputImageRotation({
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    final sensorOrientation = camera.sensorOrientation;

    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    if (!Platform.isAndroid) {
      return null;
    }

    final compensation = _orientations[deviceOrientation];
    if (compensation == null) return null;

    final rotationCompensation =
        camera.lensDirection == CameraLensDirection.front
            ? (sensorOrientation + compensation) % 360
            : (sensorOrientation - compensation + 360) % 360;

    return InputImageRotationValue.fromRawValue(rotationCompensation);
  }
}
