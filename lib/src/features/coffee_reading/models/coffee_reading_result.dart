import 'coffee_ai_reading_response.dart';

class CoffeeReadingResult {
  const CoffeeReadingResult({
    required this.readingId,
    required this.reading,
    required this.createdAt,
    required this.chargedCredits,
    required this.remainingCredits,
  });

  final String readingId;
  final CoffeeAiReadingResponse reading;
  final DateTime createdAt;
  final int chargedCredits;
  final int remainingCredits;

  String get past => reading.pastTrace;
  String get present => reading.presentMood;
  String get future => reading.nearFutureMessage;

  Map<String, dynamic> toMap() {
    return {
      'readingId': readingId,
      'reading': reading.toMap(),
      'createdAt': createdAt.toIso8601String(),
      'chargedCredits': chargedCredits,
      'remainingCredits': remainingCredits,
    };
  }

  factory CoffeeReadingResult.fromAnalyzeResponse({
    required String readingId,
    required CoffeeAiReadingResponse reading,
    required int chargedCredits,
    required int remainingCredits,
  }) {
    return CoffeeReadingResult(
      readingId: readingId,
      reading: reading,
      createdAt: DateTime.now(),
      chargedCredits: chargedCredits,
      remainingCredits: remainingCredits,
    );
  }
}
