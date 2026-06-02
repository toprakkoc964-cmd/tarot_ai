import 'coffee_validation_failure_reason.dart';

class CoffeeValidationResult {
  const CoffeeValidationResult({
    required this.isValid,
    required this.confidence,
    required this.matchedLabels,
    required this.rawLabels,
    this.failureReason,
    this.hasCup = false,
    this.hasSaucer = false,
    this.hasCoffee = false,
    this.hasTasseographyLikeTexture = false,
    this.isLikelyScreenshotOrStock = false,
    this.isLikelyScreenSpoofing = false,
    this.isDuplicateLikePrevious = false,
    this.isBlurry = false,
    this.isTooDark = false,
    this.isTooBright = false,
    this.userMessage,
    this.validationScore = 0,
  });

  final bool isValid;
  final double confidence;
  final CoffeeValidationFailureReason? failureReason;
  final List<String> matchedLabels;
  final List<String> rawLabels;

  final bool hasCup;
  final bool hasSaucer;
  final bool hasCoffee;
  final bool hasTasseographyLikeTexture;

  final bool isLikelyScreenshotOrStock;
  final bool isLikelyScreenSpoofing;
  final bool isDuplicateLikePrevious;

  final bool isBlurry;
  final bool isTooDark;
  final bool isTooBright;

  final String? userMessage;
  final double validationScore;

  bool get hasWarning => isValid && confidence < 0.78;

  Map<String, dynamic> toMap() {
    return {
      'isValid': isValid,
      'confidence': confidence,
      'failureReason': failureReason?.name,
      'matchedLabels': matchedLabels,
      'rawLabels': rawLabels,
      'hasCup': hasCup,
      'hasSaucer': hasSaucer,
      'hasCoffee': hasCoffee,
      'hasTasseographyLikeTexture': hasTasseographyLikeTexture,
      'isLikelyScreenshotOrStock': isLikelyScreenshotOrStock,
      'isLikelyScreenSpoofing': isLikelyScreenSpoofing,
      'isDuplicateLikePrevious': isDuplicateLikePrevious,
      'isBlurry': isBlurry,
      'isTooDark': isTooDark,
      'isTooBright': isTooBright,
      'userMessage': userMessage,
      'validationScore': validationScore,
    };
  }

  Map<String, dynamic> toBackendSummaryMap() {
    return {
      'isValid': isValid,
      'confidence': confidence,
      'failureReason': failureReason?.name,
      'hasCup': hasCup,
      'hasSaucer': hasSaucer,
      'hasCoffee': hasCoffee,
      'hasTasseographyLikeTexture': hasTasseographyLikeTexture,
      'isLikelyScreenshotOrStock': isLikelyScreenshotOrStock,
      'isLikelyScreenSpoofing': isLikelyScreenSpoofing,
      'isDuplicateLikePrevious': isDuplicateLikePrevious,
      'isBlurry': isBlurry,
      'isTooDark': isTooDark,
      'isTooBright': isTooBright,
      'validationScore': validationScore,
    };
  }

  factory CoffeeValidationResult.fromMap(Map<String, dynamic> map) {
    CoffeeValidationFailureReason? failureReason;
    final rawReason = map['failureReason'] as String?;
    if (rawReason != null) {
      failureReason = CoffeeValidationFailureReason.values
          .cast<CoffeeValidationFailureReason?>()
          .firstWhere(
            (value) => value?.name == rawReason,
            orElse: () => CoffeeValidationFailureReason.unknown,
          );
    }

    return CoffeeValidationResult(
      isValid: map['isValid'] == true,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      failureReason: failureReason,
      matchedLabels:
          (map['matchedLabels'] as List?)?.whereType<String>().toList() ??
              const [],
      rawLabels:
          (map['rawLabels'] as List?)?.whereType<String>().toList() ?? const [],
      hasCup: map['hasCup'] == true,
      hasSaucer: map['hasSaucer'] == true,
      hasCoffee: map['hasCoffee'] == true,
      hasTasseographyLikeTexture: map['hasTasseographyLikeTexture'] == true,
      isLikelyScreenshotOrStock: map['isLikelyScreenshotOrStock'] == true,
      isLikelyScreenSpoofing: map['isLikelyScreenSpoofing'] == true,
      isDuplicateLikePrevious: map['isDuplicateLikePrevious'] == true,
      isBlurry: map['isBlurry'] == true,
      isTooDark: map['isTooDark'] == true,
      isTooBright: map['isTooBright'] == true,
      userMessage: map['userMessage'] as String?,
      validationScore: (map['validationScore'] as num?)?.toDouble() ?? 0,
    );
  }
}
