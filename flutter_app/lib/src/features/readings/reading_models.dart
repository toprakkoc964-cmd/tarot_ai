class ReadingRequest {
  const ReadingRequest({
    required this.intent,
    required this.cards,
    required this.idempotencyKey,
  });

  final String intent;
  final List<String> cards;
  final String idempotencyKey;

  Map<String, dynamic> toJson() => {
        'intent': intent,
        'cards': cards,
        'idempotencyKey': idempotencyKey,
      };
}

class ReadingResult {
  const ReadingResult({
    required this.readingId,
    required this.aiResponse,
    required this.remainingCredits,
    this.audioUrl,
    this.audioStatus,
    this.shareImageUrl,
    this.shareDeepLink,
  });

  factory ReadingResult.fromJson(Map<Object?, Object?> map) {
    return ReadingResult(
      readingId: map['readingId'] as String,
      aiResponse: map['aiResponse'] as String,
      remainingCredits: map['remainingCredits'] as int,
      audioUrl: map['audioUrl'] as String?,
      audioStatus: map['audioStatus'] as String?,
      shareImageUrl: map['shareImageUrl'] as String?,
      shareDeepLink: map['shareDeepLink'] as String?,
    );
  }

  final String readingId;
  final String aiResponse;
  final int remainingCredits;
  final String? audioUrl;
  final String? audioStatus;
  final String? shareImageUrl;
  final String? shareDeepLink;
}
