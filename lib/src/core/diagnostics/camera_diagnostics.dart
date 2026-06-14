import 'dart:async';
import 'dart:collection';
import 'dart:developer' as dev;

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CameraDiagnostics {
  CameraDiagnostics._();

  static const String preferencesKey = 'cameraDiagnosticsEnabled';
  static const bool _dartDefineEnabled = bool.fromEnvironment(
    'CAMERA_DIAGNOSTICS_ENABLED',
  );
  static const int _maxLines = 200;
  static final ListQueue<String> _ringBuffer = ListQueue<String>(_maxLines);
  static final String _sessionId = DateTime.now().microsecondsSinceEpoch
      .toString();
  static bool? _cachedEnabled;

  static bool get isEnabledSync =>
      !kReleaseMode || _dartDefineEnabled || (_cachedEnabled ?? false);

  static Future<bool> isEnabled() async {
    if (!kReleaseMode || _dartDefineEnabled) return true;
    final cached = _cachedEnabled;
    if (cached != null) return cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(preferencesKey) ?? false;
      _cachedEnabled = enabled;
      return enabled;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    _cachedEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(preferencesKey, enabled);
  }

  static List<String> recentLines() => List<String>.unmodifiable(_ringBuffer);

  static Future<void> log(
    String event, {
    String flow = 'camera',
    Map<String, Object?> data = const {},
    Object? error,
    StackTrace? stackTrace,
  }) async {
    final enabled = await isEnabled();
    _logInternal(
      event,
      flow: flow,
      data: data,
      error: error,
      stackTrace: stackTrace,
      enabled: enabled,
    );
  }

  static void logSync(
    String event, {
    String flow = 'camera',
    Map<String, Object?> data = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logInternal(
      event,
      flow: flow,
      data: data,
      error: error,
      stackTrace: stackTrace,
      enabled: isEnabledSync,
    );
  }

  static Map<String, Object?> describeCamera(CameraDescription camera) {
    return {
      'name': camera.name,
      'lensDirection': camera.lensDirection.name,
      'sensorOrientation': camera.sensorOrientation,
    };
  }

  static Map<String, Object?> describeCameras(List<CameraDescription> cameras) {
    return {
      'count': cameras.length,
      'lenses': cameras
          .map((camera) => camera.lensDirection.name)
          .toList(growable: false),
      'cameras': cameras.map(describeCamera).toList(growable: false),
    };
  }

  static Map<String, Object?> describeController(CameraController? controller) {
    if (controller == null) return {'controller': 'null'};
    final value = controller.value;
    return {
      'isInitialized': value.isInitialized,
      'isStreamingImages': value.isStreamingImages,
      'isTakingPicture': value.isTakingPicture,
      'hasError': value.hasError,
      'errorDescription': value.errorDescription,
      'previewWidth': value.previewSize?.width,
      'previewHeight': value.previewSize?.height,
      'flashMode': value.flashMode.name,
      'focusMode': value.focusMode.name,
      'exposureMode': value.exposureMode.name,
      'camera': describeCamera(controller.description),
    };
  }

  static void _logInternal(
    String event, {
    required String flow,
    required Map<String, Object?> data,
    required bool enabled,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final safeData = _sanitize(data);
    final errorText = error == null ? null : '${error.runtimeType}: $error';
    final line =
        '[$timestamp][session=$_sessionId][$flow] $event'
        '${safeData.isEmpty ? '' : ' data=$safeData'}'
        '${errorText == null ? '' : ' error=$errorText'}';
    _append(line);

    if (enabled) {
      debugPrint(line);
      dev.log(line, name: 'camera', error: error, stackTrace: stackTrace);
    }

    if (enabled) {
      unawaited(
        _writeFirestore(
          event: event,
          flow: flow,
          line: line,
          data: safeData,
          errorText: errorText,
          stackTrace: stackTrace?.toString(),
        ),
      );
    }
  }

  static void _append(String line) {
    if (_ringBuffer.length == _maxLines) {
      _ringBuffer.removeFirst();
    }
    _ringBuffer.addLast(line);
  }

  static Future<void> _writeFirestore({
    required String event,
    required String flow,
    required String line,
    required Map<String, Object?> data,
    String? errorText,
    String? stackTrace,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) return;
      await FirebaseFirestore.instance
          .collection('diagnostics')
          .doc(uid)
          .collection('camera')
          .add({
            'createdAt': FieldValue.serverTimestamp(),
            'sessionId': _sessionId,
            'event': event,
            'flow': flow,
            'line': line,
            'data': data,
            if (errorText != null) 'error': errorText,
            if (stackTrace != null) 'stackTrace': stackTrace,
          });
    } catch (_) {
      // Diagnostics must never affect camera or auth flows.
    }
  }

  static Map<String, Object?> _sanitize(Map<String, Object?> data) {
    return data.map((key, value) => MapEntry(key, _sanitizeValue(value)));
  }

  static Object? _sanitizeValue(Object? value) {
    if (value == null ||
        value is String ||
        value is num ||
        value is bool ||
        value is Timestamp) {
      return value;
    }
    if (value is DateTime) return value.toIso8601String();
    if (value is Iterable) {
      return value.map(_sanitizeValue).toList(growable: false);
    }
    if (value is Map) {
      return value.map(
        (key, mapValue) => MapEntry(key.toString(), _sanitizeValue(mapValue)),
      );
    }
    return value.toString();
  }
}
