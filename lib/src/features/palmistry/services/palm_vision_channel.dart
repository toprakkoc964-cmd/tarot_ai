import 'dart:developer' as dev;
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import '../../../core/diagnostics/camera_diagnostics.dart';
import '../../../core/utils/palm_detection_result.dart';

class PalmVisionChannel {
  static const MethodChannel _channel = MethodChannel('tarot_ai/palm_vision');

  Future<PalmDetectionResult> analyzeFrame(
    CameraImage image, {
    required Rect guideRect,
    required Size previewSize,
    required int sensorOrientation,
    bool debugMode = false,
  }) async {
    if (!Platform.isIOS || image.planes.isEmpty) {
      return const PalmDetectionResult.noHand();
    }

    final plane = image.planes.first;
    final payload = <String, Object?>{
      'bytes': plane.bytes,
      'width': image.width,
      'height': image.height,
      'bytesPerRow': plane.bytesPerRow,
      'bytesPerPixel': plane.bytesPerPixel,
      'formatGroup': 'bgra8888',
      'sensorOrientation': sensorOrientation,
      'isFrontCamera': false,
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
      final diagnosticsEnabled = debugMode || CameraDiagnostics.isEnabledSync;
      if (diagnosticsEnabled) {
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
        CameraDiagnostics.logSync(
          'palmvision_result',
          flow: 'palm_vision',
          data: {
            'state': result.state.name,
            'scanState': result.effectiveScanState.name,
            'confidence': result.confidence,
            'validPalm': result.validPalm,
            'source': result.source,
            'labels': result.labels,
            if (debug != null) 'debug': debug,
          },
        );
      }
      return result;
    } on PlatformException catch (error) {
      final diagnosticsEnabled = debugMode || CameraDiagnostics.isEnabledSync;
      if (diagnosticsEnabled) {
        dev.log(
          '[palmvision] platformError code=${error.code} '
          'message=${error.message}',
          name: 'palmvision',
        );
        CameraDiagnostics.logSync(
          'palmvision_platform_error',
          flow: 'palm_vision',
          data: {'code': error.code, 'message': error.message},
          error: error,
        );
      }
      return PalmDetectionResult(
        state: PalmDetectionState.noHand,
        confidence: 0,
        labels: const ['vision_error'],
        source: 'Vision',
        debug: {
          'methodChannelSuccess': false,
          'lastError': error.message ?? error.code,
        },
      );
    } catch (error) {
      final diagnosticsEnabled = debugMode || CameraDiagnostics.isEnabledSync;
      if (diagnosticsEnabled) {
        dev.log('[palmvision] error=$error', name: 'palmvision');
        CameraDiagnostics.logSync(
          'palmvision_unknown_error',
          flow: 'palm_vision',
          error: error,
        );
      }
      return const PalmDetectionResult.noHand();
    }
  }
}
