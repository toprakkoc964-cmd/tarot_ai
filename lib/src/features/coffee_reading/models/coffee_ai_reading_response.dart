class CoffeeAiReadingResponse {
  const CoffeeAiReadingResponse({
    required this.generalEnergy,
    required this.symbols,
    required this.saucerSigns,
    required this.outerCupMessage,
    required this.pastTrace,
    required this.presentMood,
    required this.nearFutureMessage,
    required this.advice,
    required this.disclaimer,
  });

  final String generalEnergy;
  final String symbols;
  final String saucerSigns;
  final String outerCupMessage;
  final String pastTrace;
  final String presentMood;
  final String nearFutureMessage;
  final String advice;
  final String disclaimer;

  Map<String, dynamic> toMap() {
    return {
      'generalEnergy': generalEnergy,
      'symbols': symbols,
      'saucerSigns': saucerSigns,
      'outerCupMessage': outerCupMessage,
      'pastTrace': pastTrace,
      'presentMood': presentMood,
      'nearFutureMessage': nearFutureMessage,
      'advice': advice,
      'disclaimer': disclaimer,
    };
  }

  factory CoffeeAiReadingResponse.fromMap(Map<String, dynamic> map) {
    String field(String key) => (map[key] as String?)?.trim() ?? '';
    return CoffeeAiReadingResponse(
      generalEnergy: field('generalEnergy'),
      symbols: field('symbols'),
      saucerSigns: field('saucerSigns'),
      outerCupMessage: field('outerCupMessage'),
      pastTrace: field('pastTrace'),
      presentMood: field('presentMood'),
      nearFutureMessage: field('nearFutureMessage'),
      advice: field('advice'),
      disclaimer: field('disclaimer'),
    );
  }
}
