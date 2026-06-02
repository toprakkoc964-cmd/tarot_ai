import 'coffee_ai_reading_response.dart';
import 'coffee_ai_validation_response.dart';

class CoffeeAnalyzeResponse {
  const CoffeeAnalyzeResponse({
    required this.success,
    required this.chargedCredits,
    required this.remainingCredits,
    required this.readingId,
    required this.validation,
    required this.reading,
  });

  final bool success;
  final int chargedCredits;
  final int remainingCredits;
  final String readingId;
  final CoffeeAiValidationResponse validation;
  final CoffeeAiReadingResponse? reading;

  factory CoffeeAnalyzeResponse.fromMap(Map<String, dynamic> map) {
    final validationMap =
        Map<String, dynamic>.from(map['validation'] as Map? ?? const {});
    CoffeeAiReadingResponse? reading;
    final readingRaw = map['reading'];
    if (readingRaw is Map) {
      reading = CoffeeAiReadingResponse.fromMap(
        Map<String, dynamic>.from(readingRaw),
      );
    }

    return CoffeeAnalyzeResponse(
      success: map['success'] == true,
      chargedCredits: (map['chargedCredits'] as num?)?.toInt() ?? 0,
      remainingCredits: (map['remainingCredits'] as num?)?.toInt() ?? 0,
      readingId: (map['readingId'] as String?) ?? '',
      validation: CoffeeAiValidationResponse.fromMap(validationMap),
      reading: reading,
    );
  }
}
