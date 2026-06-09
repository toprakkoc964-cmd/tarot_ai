enum PalmDetectionState { noHand, partialHand, possibleHand, validHand }

enum PalmScanState {
  noHand,
  handOutsideGuide,
  handTooClose,
  handTooFar,
  rotateHand,
  openFingers,
  showPalm,
  unstable,
  ready,
}

class PalmDetectionResult {
  const PalmDetectionResult({
    required this.state,
    required this.confidence,
    required this.labels,
    this.scanState,
    this.handDetected = false,
    this.possibleHand = false,
    this.validPalm = false,
    this.openPalmScore = 0,
    this.extendedFingerCount = 0,
    this.fingerSpreadRatio = 0,
    this.source,
    this.debug,
  });

  const PalmDetectionResult.noHand()
    : state = PalmDetectionState.noHand,
      confidence = 0,
      labels = const [],
      scanState = PalmScanState.noHand,
      handDetected = false,
      possibleHand = false,
      validPalm = false,
      openPalmScore = 0,
      extendedFingerCount = 0,
      fingerSpreadRatio = 0,
      source = null,
      debug = null;

  final PalmDetectionState state;
  final double confidence;
  final List<String> labels;
  final PalmScanState? scanState;
  final bool handDetected;
  final bool possibleHand;
  final bool validPalm;
  final double openPalmScore;
  final int extendedFingerCount;
  final double fingerSpreadRatio;
  final String? source;
  final Map<String, dynamic>? debug;

  PalmScanState get effectiveScanState {
    final explicitState = scanState;
    if (explicitState != null) return explicitState;

    return switch (state) {
      PalmDetectionState.validHand => PalmScanState.ready,
      PalmDetectionState.possibleHand => PalmScanState.unstable,
      PalmDetectionState.partialHand => PalmScanState.openFingers,
      PalmDetectionState.noHand => PalmScanState.noHand,
    };
  }

  bool get isValid =>
      state == PalmDetectionState.validHand &&
      effectiveScanState == PalmScanState.ready &&
      validPalm;

  factory PalmDetectionResult.fromVisionMap(Map<Object?, Object?> map) {
    final rawState = map['state']?.toString();
    final rawScanState = map['scanState']?.toString();
    final rawConfidence = map['confidence'];
    final rawLabels = map['labels'];
    final rawDebug = map['debug'];

    return PalmDetectionResult(
      state: _stateFromString(rawState),
      confidence: rawConfidence is num ? rawConfidence.toDouble() : 0,
      labels: rawLabels is List
          ? rawLabels.map((item) => item.toString()).toList(growable: false)
          : const [],
      scanState: _scanStateFromString(rawScanState),
      handDetected: map['handDetected'] == true,
      possibleHand: map['possibleHand'] == true,
      validPalm: map['validPalm'] == true,
      openPalmScore: _doubleFromMap(map, 'openPalmScore'),
      extendedFingerCount: _intFromMap(map, 'extendedFingerCount'),
      fingerSpreadRatio: _doubleFromMap(map, 'fingerSpreadRatio'),
      source: map['source']?.toString(),
      debug: rawDebug is Map
          ? rawDebug.map((key, value) => MapEntry(key.toString(), value))
          : null,
    );
  }

  static double _doubleFromMap(Map<Object?, Object?> map, String key) {
    final value = map[key];
    if (value is num) return value.toDouble();
    final debug = map['debug'];
    if (debug is Map) {
      final debugValue = debug[key];
      if (debugValue is num) return debugValue.toDouble();
    }
    return 0;
  }

  static int _intFromMap(Map<Object?, Object?> map, String key) {
    final value = map[key];
    if (value is num) return value.toInt();
    final debug = map['debug'];
    if (debug is Map) {
      final debugValue = debug[key];
      if (debugValue is num) return debugValue.toInt();
    }
    return 0;
  }

  static PalmDetectionState _stateFromString(String? value) {
    switch (value) {
      case 'validHand':
        return PalmDetectionState.validHand;
      case 'possibleHand':
        return PalmDetectionState.possibleHand;
      case 'partialHand':
        return PalmDetectionState.partialHand;
      case 'noHand':
      default:
        return PalmDetectionState.noHand;
    }
  }

  static PalmScanState? _scanStateFromString(String? value) {
    switch (value) {
      case 'noHand':
        return PalmScanState.noHand;
      case 'handOutsideGuide':
        return PalmScanState.handOutsideGuide;
      case 'handTooClose':
        return PalmScanState.handTooClose;
      case 'handTooFar':
        return PalmScanState.handTooFar;
      case 'rotateHand':
        return PalmScanState.rotateHand;
      case 'openFingers':
        return PalmScanState.openFingers;
      case 'showPalm':
        return PalmScanState.showPalm;
      case 'unstable':
        return PalmScanState.unstable;
      case 'ready':
        return PalmScanState.ready;
      default:
        return null;
    }
  }
}
