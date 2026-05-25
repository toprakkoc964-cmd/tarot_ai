class PalmistryResult {
  const PalmistryResult({
    required this.isValid,
    required this.reading,
  });

  final bool isValid;
  final PalmReading reading;

  factory PalmistryResult.fromMap(Map<String, dynamic> map) {
    return PalmistryResult(
      isValid: map['isValid'] as bool? ?? false,
      reading: PalmReading.fromMap(
        Map<String, dynamic>.from(map['reading'] as Map? ?? const {}),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isValid': isValid,
      'reading': reading.toMap(),
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
