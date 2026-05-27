class CoffeeReadingResult {
  const CoffeeReadingResult({
    required this.readingId,
    required this.past,
    required this.present,
    required this.future,
    required this.createdAt,
  });

  final String readingId;
  final String past;
  final String present;
  final String future;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'readingId': readingId,
      'past': past,
      'present': present,
      'future': future,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CoffeeReadingResult.fromMap(Map<String, dynamic> map) {
    return CoffeeReadingResult(
      readingId: (map['readingId'] as String?) ?? '',
      past: (map['past'] as String?) ?? '',
      present: (map['present'] as String?) ?? '',
      future: (map['future'] as String?) ?? '',
      createdAt: DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}
