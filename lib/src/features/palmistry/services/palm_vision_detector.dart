import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/palm_detection_result.dart';

class PalmVisionDetector {
  static const MethodChannel _channel = MethodChannel('palmistry/vision');

  Future<PalmDetectionResult> detect(
    CameraImage image, {
    CameraDescription? camera,
    Size? previewSize,
    Rect? guideRect,
  }) async {
    if (!Platform.isIOS || image.planes.isEmpty) {
      return const PalmDetectionResult.noHand();
    }

    final plane = image.planes.first;
    final formatGroup = image.format.group.name;
    if (formatGroup != 'bgra8888') {
      return PalmDetectionResult(
        state: PalmDetectionState.noHand,
        confidence: 0,
        labels: const ['vision_error'],
        source: 'apple_vision',
        debug: {
          'methodChannelSuccess': false,
          'lastError': 'Unexpected image format: $formatGroup',
        },
      );
    }

    final payload = <String, Object?>{
      'frameBytes': plane.bytes,
      'bytes': plane.bytes,
      'width': image.width,
      'height': image.height,
      'bytesPerRow': plane.bytesPerRow,
      'bytesPerPixel': plane.bytesPerPixel,
      'formatGroup': formatGroup,
      'sensorOrientation': camera?.sensorOrientation ?? 0,
      'isFrontCamera': camera?.lensDirection == CameraLensDirection.front,
      'debugMode': kDebugMode,
      if (previewSize != null) 'previewWidth': previewSize.width,
      if (previewSize != null) 'previewHeight': previewSize.height,
      if (guideRect != null) 'guideLeft': guideRect.left,
      if (guideRect != null) 'guideTop': guideRect.top,
      if (guideRect != null) 'guideWidth': guideRect.width,
      if (guideRect != null) 'guideHeight': guideRect.height,
    };

    try {
      final response = await _channel.invokeMapMethod<Object?, Object?>(
        'detect',
        payload,
      );
      if (response == null) return const PalmDetectionResult.noHand();
      final result = PalmDetectionResult.fromVisionMap(response);
      return PalmDetectionResult(
        state: result.state,
        scanState: result.scanState,
        confidence: result.confidence,
        labels: result.labels,
        handDetected: result.handDetected,
        possibleHand: result.possibleHand,
        validPalm: result.validPalm,
        source: result.source ?? 'apple_vision',
        debug: result.debug,
      );
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint('PalmVisionDetector failed: ${error.code}');
      }
      return PalmDetectionResult(
        state: PalmDetectionState.noHand,
        confidence: 0,
        labels: const ['vision_error'],
        source: 'apple_vision',
        debug: {
          'methodChannelSuccess': false,
          'lastError': error.message ?? error.code,
        },
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('PalmVisionDetector failed: $error');
      }
      return const PalmDetectionResult(
        state: PalmDetectionState.noHand,
        confidence: 0,
        labels: ['vision_error'],
        source: 'apple_vision',
      );
    }
  }
}
