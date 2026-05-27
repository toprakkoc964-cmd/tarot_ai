class CoffeeValidationResult {
  const CoffeeValidationResult({
    required this.isValid,
    required this.hasWarning,
    required this.confidence,
    required this.matchedLabels,
    required this.rawLabels,
    this.warningMessage,
  });

  final bool isValid;
  final bool hasWarning;
  final double confidence;
  final List<String> matchedLabels;
  final List<String> rawLabels;
  final String? warningMessage;

  Map<String, dynamic> toMap() {
    return {
      'isValid': isValid,
      'hasWarning': hasWarning,
      'confidence': confidence,
      'matchedLabels': matchedLabels,
      'rawLabels': rawLabels,
      'warningMessage': warningMessage,
    };
  }

  factory CoffeeValidationResult.fromMap(Map<String, dynamic> map) {
    return CoffeeValidationResult(
      isValid: map['isValid'] == true,
      hasWarning: map['hasWarning'] == true,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      matchedLabels:
          (map['matchedLabels'] as List?)?.whereType<String>().toList() ??
              const [],
      rawLabels:
          (map['rawLabels'] as List?)?.whereType<String>().toList() ?? const [],
      warningMessage: map['warningMessage'] as String?,
    );
  }
}
