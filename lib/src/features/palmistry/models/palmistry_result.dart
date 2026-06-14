class PalmistryResult {
  const PalmistryResult({
    required this.isValid,
    required this.reading,
    this.sessionId,
    this.openingMessage,
  });

  final bool isValid;
  final PalmReading reading;
  final String? sessionId;
  final String? openingMessage;

  factory PalmistryResult.fromMap(Map<String, dynamic> map) {
    return PalmistryResult(
      isValid: map['isValid'] as bool? ?? false,
      reading: PalmReading.fromMap(
        Map<String, dynamic>.from(map['reading'] as Map? ?? const {}),
      ),
      sessionId: (map['sessionId'] as String?)?.trim(),
      openingMessage: (map['openingMessage'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isValid': isValid,
      'reading': reading.toMap(),
      if (sessionId != null && sessionId!.trim().isNotEmpty)
        'sessionId': sessionId,
      if (openingMessage != null && openingMessage!.trim().isNotEmpty)
        'openingMessage': openingMessage,
    };
  }
}

class PalmReading {
  const PalmReading({
    required this.mindLine,
    required this.heartLine,
    required this.lifeEnergy,
  });

  final String mindLine;
  final String heartLine;
  final String lifeEnergy;

  factory PalmReading.fromMap(Map<String, dynamic> map) {
    return PalmReading(
      mindLine: map['mindLine'] as String? ?? '',
      heartLine: map['heartLine'] as String? ?? '',
      lifeEnergy: map['lifeEnergy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mindLine': mindLine,
      'heartLine': heartLine,
      'lifeEnergy': lifeEnergy,
    };
  }
}
