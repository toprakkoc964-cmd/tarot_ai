enum PalmDetectionState {
  noHand,
  partialHand,
  possibleHand,
  validHand,
}

class PalmDetectionResult {
  const PalmDetectionResult({
    required this.state,
    required this.confidence,
    required this.labels,
    this.source,
    this.debug,
  });

  const PalmDetectionResult.noHand()
      : state = PalmDetectionState.noHand,
        confidence = 0,
        labels = const [],
        source = null,
        debug = null;

  final PalmDetectionState state;
  final double confidence;
  final List<String> labels;
  final String? source;
  final Map<String, dynamic>? debug;

  bool get isValid => state == PalmDetectionState.validHand;

  factory PalmDetectionResult.fromVisionMap(Map<Object?, Object?> map) {
    final rawState = map['state']?.toString();
    final rawConfidence = map['confidence'];
    final rawLabels = map['labels'];
    final rawDebug = map['debug'];

    return PalmDetectionResult(
      state: _stateFromString(rawState),
      confidence: rawConfidence is num ? rawConfidence.toDouble() : 0,
      labels: rawLabels is List
          ? rawLabels.map((item) => item.toString()).toList(growable: false)
          : const [],
      source: map['source']?.toString(),
      debug: rawDebug is Map
          ? rawDebug.map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : null,
    );
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
}
