import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import 'ios_vision_palm_analyzer.dart';
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
  final IOSVisionPalmAnalyzer _iosVisionAnalyzer = IOSVisionPalmAnalyzer();

  Future<PalmDetectionResult> analyze({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
    Size? previewSize,
    Rect? guideRect,
  }) async {
    if (Platform.isIOS) {
      try {
        return await _iosVisionAnalyzer.analyzeImageStream(
          image,
          camera.sensorOrientation,
          isFrontCamera: camera.lensDirection == CameraLensDirection.front,
          previewSize: previewSize,
          guideRect: guideRect,
        );
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('Palm Vision route failed: $e');
          debugPrintStack(stackTrace: st);
        }
        return const PalmDetectionResult(
          state: PalmDetectionState.noHand,
          confidence: 0,
          labels: ['vision_error'],
          source: 'Vision',
          debug: {
            'methodChannelSuccess': false,
            'lastError': 'Vision route failed',
          },
        );
      }
    }

    try {
      final inputImage = _toInputImage(
        image: image,
        camera: camera,
        deviceOrientation: deviceOrientation,
      );
      if (inputImage == null) return const PalmDetectionResult.noHand();

      final labels = await _labeler.processImage(inputImage);
      if (kDebugMode) {
        debugPrint(
          'Palm raw labels: ${labels.map(_formatLabel).join(', ')}',
        );
      }

      final result = _classifyLabels(labels);
      if (kDebugMode) {
        debugPrint(
          'Palm decision: state=${result.state}, '
          'confidence=${result.confidence.toStringAsFixed(2)}, '
          'labels=${result.labels}',
        );
      }

      return result;
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
    double palmConfidence = 0;
    double handConfidence = 0;
    double partialConfidence = 0;
    final relatedLabels = <String>[];

    for (final label in labels) {
      final text = label.label.toLowerCase();
      final confidence = label.confidence;
      final formattedLabel = _formatLabel(label);

      if (_containsAny(text, const ['palm'])) {
        palmConfidence = _max(palmConfidence, confidence);
        relatedLabels.add(formattedLabel);
      }
      if (_containsAny(text, const ['hand'])) {
        handConfidence = _max(handConfidence, confidence);
        relatedLabels.add(formattedLabel);
      }
      if (_containsAny(text, const [
        'finger',
        'fingers',
        'thumb',
        'wrist',
        'arm',
        'skin',
      ])) {
        partialConfidence = _max(partialConfidence, confidence);
        relatedLabels.add(formattedLabel);
      }
    }

    final primaryConfidence = _max(palmConfidence, handConfidence);
    if (primaryConfidence >= 0.75) {
      return PalmDetectionResult(
        state: PalmDetectionState.validHand,
        scanState: PalmScanState.ready,
        confidence: primaryConfidence,
        labels: relatedLabels,
        source: 'MLKit',
        handDetected: true,
        possibleHand: true,
        validPalm: true,
      );
    }

    if (primaryConfidence >= 0.6) {
      return PalmDetectionResult(
        state: PalmDetectionState.possibleHand,
        scanState: PalmScanState.unstable,
        confidence: primaryConfidence,
        labels: relatedLabels,
        source: 'MLKit',
        handDetected: true,
        possibleHand: true,
      );
    }

    if (partialConfidence > 0) {
      return PalmDetectionResult(
        state: PalmDetectionState.partialHand,
        scanState: PalmScanState.openFingers,
        confidence: partialConfidence,
        labels: relatedLabels,
        source: 'MLKit',
        handDetected: true,
      );
    }

    return PalmDetectionResult(
      state: PalmDetectionState.noHand,
      scanState: PalmScanState.noHand,
      confidence: 0,
      labels: relatedLabels,
      source: 'MLKit',
    );
  }

  bool _containsAny(String text, List<String> needles) {
    return needles.any(text.contains);
  }

  double _max(double a, double b) => a > b ? a : b;

  String _formatLabel(ImageLabel label) {
    return '${label.label}:${label.confidence.toStringAsFixed(2)}';
  }

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
