import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'palm_detection_result.dart';

class IOSVisionPalmAnalyzer {
  static const MethodChannel _channel = MethodChannel('tarot_ai/palm_vision');
  static const Duration _perfLogInterval = Duration(milliseconds: 1200);

  DateTime? _lastPerfLogAt;

  Future<PalmDetectionResult> analyzeImageStream(
    CameraImage image,
    int sensorOrientation, {
    required bool isFrontCamera,
    Size? previewSize,
    Rect? guideRect,
  }) async {
    final totalWatch = Stopwatch()..start();
    if (!Platform.isIOS || image.planes.isEmpty) {
      return const PalmDetectionResult.noHand();
    }

    final plane = image.planes.first;
    final bytes = plane.bytes;
    final formatGroup = image.format.group.name;
    final debugPayload = <String, Object?>{
      'platformIsIOS': Platform.isIOS,
      'formatGroup': formatGroup,
      'formatRaw': image.format.raw.toString(),
      'width': image.width,
      'height': image.height,
      'planesLength': image.planes.length,
      'byteCount': bytes.length,
      'bytesPerRow': plane.bytesPerRow,
      'bytesPerPixel': plane.bytesPerPixel,
      'sensorOrientation': sensorOrientation,
      'isFrontCamera': isFrontCamera,
      'previewWidth': previewSize?.width,
      'previewHeight': previewSize?.height,
      'guideLeft': guideRect?.left,
      'guideTop': guideRect?.top,
      'guideWidth': guideRect?.width,
      'guideHeight': guideRect?.height,
    };

    if (formatGroup != 'bgra8888') {
      return _visionError(
        'Unexpected image format: $formatGroup',
        debug: debugPayload,
      );
    }

    if (bytes.isEmpty || image.width <= 0 || image.height <= 0) {
      return PalmDetectionResult(
        state: PalmDetectionState.noHand,
        confidence: 0,
        labels: const ['vision_error'],
        source: 'Vision',
        debug: {
          'methodChannelSuccess': false,
          'lastError': 'Invalid Flutter camera frame',
          ...debugPayload,
        },
      );
    }

    final payload = <String, Object?>{
      'bytes': bytes,
      'width': image.width,
      'height': image.height,
      'bytesPerRow': plane.bytesPerRow,
      'bytesPerPixel': plane.bytesPerPixel,
      'formatGroup': formatGroup,
      'sensorOrientation': sensorOrientation,
      'isFrontCamera': isFrontCamera,
      'debugMode': kDebugMode,
    };
    if (previewSize != null &&
        guideRect != null &&
        previewSize.width > 0 &&
        previewSize.height > 0 &&
        guideRect.width > 0 &&
        guideRect.height > 0) {
      payload.addAll({
        'previewWidth': previewSize.width,
        'previewHeight': previewSize.height,
        'guideLeft': guideRect.left,
        'guideTop': guideRect.top,
        'guideWidth': guideRect.width,
        'guideHeight': guideRect.height,
      });
    }

    try {
      final channelWatch = Stopwatch()..start();
      final response = await _channel.invokeMapMethod<Object?, Object?>(
        'analyzePalmFrame',
        payload,
      );
      channelWatch.stop();
      if (response == null) {
        return _visionError('Empty Vision response');
      }

      final parseWatch = Stopwatch()..start();
      final result = PalmDetectionResult.fromVisionMap(response);
      parseWatch.stop();
      totalWatch.stop();

      final debug = <String, dynamic>{
        ...?result.debug,
        'channelMs': channelWatch.elapsedMilliseconds,
        'parseMs': parseWatch.elapsedMicroseconds / 1000,
        'totalMs': totalWatch.elapsedMilliseconds,
      };
      _logPerf(debug);
      return PalmDetectionResult(
        state: result.state,
        scanState: result.scanState,
        confidence: result.confidence,
        labels: result.labels,
        handDetected: result.handDetected,
        possibleHand: result.possibleHand,
        validPalm: result.validPalm,
        source: result.source,
        debug: debug,
      );
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('Palm Vision platform error: ${e.code}');
      }
      return _visionError(
        e.message ?? e.code,
        debug: debugPayload,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Palm Vision channel failed: $e');
        debugPrintStack(stackTrace: st);
      }
      return _visionError(
        e.toString(),
        debug: debugPayload,
      );
    }
  }

  PalmDetectionResult _visionError(
    String message, {
    Map<String, Object?> debug = const <String, Object?>{},
  }) {
    if (kDebugMode) {
      debugPrint(
        'PalmVision ERROR: '
        'source=Vision, '
        'methodChannelSuccess=false, '
        'lastError=$message',
      );
    }

    return PalmDetectionResult(
      state: PalmDetectionState.noHand,
      confidence: 0,
      labels: const ['vision_error'],
      source: 'Vision',
      debug: {
        'methodChannelSuccess': false,
        'lastError': message,
        ...debug,
      },
    );
  }

  void _logPerf(Map<String, dynamic> debug) {
    if (!kDebugMode) return;

    final now = DateTime.now();
    final lastLog = _lastPerfLogAt;
    if (lastLog != null && now.difference(lastLog) < _perfLogInterval) {
      return;
    }

    _lastPerfLogAt = now;
    debugPrint(
      'PalmPerf: channel=${debug['channelMs']}ms, '
      'vision=${debug['visionMs'] ?? '-'}ms, '
      'convert=${debug['convertMs'] ?? '-'}ms, '
      'parse=${debug['parseMs']}ms, '
      'total=${debug['totalMs']}ms',
    );
  }
}
