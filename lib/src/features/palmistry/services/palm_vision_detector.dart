import 'dart:io';
import 'dart:developer' as dev;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/palm_detection_result.dart';

class PalmVisionDetector {
  static const MethodChannel _channel = MethodChannel('tarot_ai/palm_vision');

  Future<PalmDetectionResult> analyzeFrame(
    CameraImage image, {
    required Rect guideRect,
    required Size previewSize,
    int sensorOrientation = 0,
    bool isFrontCamera = false,
    bool debugMode = false,
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
      'bytes': plane.bytes,
      'width': image.width,
      'height': image.height,
      'bytesPerRow': plane.bytesPerRow,
      'bytesPerPixel': plane.bytesPerPixel,
      'formatGroup': formatGroup,
      'sensorOrientation': sensorOrientation,
      'isFrontCamera': isFrontCamera,
      'debugMode': debugMode,
      'previewWidth': previewSize.width,
      'previewHeight': previewSize.height,
      'guideLeft': guideRect.left,
      'guideTop': guideRect.top,
      'guideWidth': guideRect.width,
      'guideHeight': guideRect.height,
    };

    try {
      final response = await _channel.invokeMapMethod<Object?, Object?>(
        'analyzePalmFrame',
        payload,
      );
      if (response == null) return const PalmDetectionResult.noHand();
      final result = PalmDetectionResult.fromVisionMap(response);
      _logResult(result, debugMode: debugMode);
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
      if (debugMode || !kReleaseMode) {
        dev.log(
          '[palmvision] platformError code=${error.code} '
          'message=${error.message}',
          name: 'palmvision',
        );
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
      if (debugMode || !kReleaseMode) {
        dev.log('[palmvision] error=$error', name: 'palmvision');
      }
      return const PalmDetectionResult(
        state: PalmDetectionState.noHand,
        confidence: 0,
        labels: ['vision_error'],
        source: 'apple_vision',
      );
    }
  }

  void _logResult(PalmDetectionResult result, {required bool debugMode}) {
    if (!debugMode && kReleaseMode) return;
    dev.log(
      '[palmvision] state=${result.state.name} '
      'scan=${result.effectiveScanState.name} '
      'conf=${result.confidence.toStringAsFixed(2)} '
      'valid=${result.validPalm} labels=${result.labels} '
      'source=${result.source}',
      name: 'palmvision',
    );
    final debug = result.debug;
    if (debug != null) {
      dev.log('[palmvision] debug=$debug', name: 'palmvision');
    }
  }
}
