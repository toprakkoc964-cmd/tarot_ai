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
  });

  const PalmDetectionResult.noHand()
      : state = PalmDetectionState.noHand,
        confidence = 0,
        labels = const [];

  final PalmDetectionState state;
  final double confidence;
  final List<String> labels;

  bool get isValid => state == PalmDetectionState.validHand;
}
