import 'dart:math';

class TarotCardLoadException implements Exception {
  const TarotCardLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MajorArcanaCard {
  const MajorArcanaCard({
    required this.index,
    required this.name,
    this.assetSubfolder,
    this.assetFileName,
  });

  final int index;
  final String name;
  final String? assetSubfolder;
  final String? assetFileName;

  static const String assetFolder = 'assets/card-images';

  String get snakeCaseName => name.trim().toLowerCase().replaceAll(' ', '_');
  String get fileName =>
      assetFileName ??
      '${index.toString().padLeft(2, '0')}_$snakeCaseName.webp';
  String get assetPath {
    final folder = assetSubfolder == null
        ? assetFolder
        : '$assetFolder/$assetSubfolder';
    return '$folder/$fileName';
  }

  String get displayName => name
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

class DrawnTarotCard {
  const DrawnTarotCard({required this.card, required this.imageUrl});

  final MajorArcanaCard card;

  /// Yerel asset yolu (`assets/card-images/00_the_fool.webp`) veya ag URL.
  final String imageUrl;

  bool get hasLocalAsset => imageUrl.isNotEmpty && !imageUrl.startsWith('http');
}

class TarotService {
  TarotService({Random? random}) : _random = random ?? Random();

  final Random _random;

  static final Map<int, String> imageUrlByIndex = <int, String>{};
  static bool _assetsReady = false;

  static const List<MajorArcanaCard> majorArcana = <MajorArcanaCard>[
    MajorArcanaCard(index: 0, name: 'the_fool'),
    MajorArcanaCard(index: 1, name: 'the_magician'),
    MajorArcanaCard(index: 2, name: 'the_high_priestess'),
    MajorArcanaCard(index: 3, name: 'the_empress'),
    MajorArcanaCard(index: 4, name: 'the_emperor'),
    MajorArcanaCard(index: 5, name: 'the_hierophant'),
    MajorArcanaCard(index: 6, name: 'the_lovers'),
    MajorArcanaCard(index: 7, name: 'the_chariot'),
    MajorArcanaCard(index: 8, name: 'strength'),
    MajorArcanaCard(index: 9, name: 'the_hermit'),
    MajorArcanaCard(index: 10, name: 'the_wheel_of_fortune'),
    MajorArcanaCard(index: 11, name: 'justice'),
    MajorArcanaCard(index: 12, name: 'the_hanged_man'),
    MajorArcanaCard(index: 13, name: 'death'),
    MajorArcanaCard(index: 14, name: 'temperance'),
    MajorArcanaCard(index: 15, name: 'the_devil'),
    MajorArcanaCard(index: 16, name: 'the_tower'),
    MajorArcanaCard(index: 17, name: 'the_star'),
    MajorArcanaCard(index: 18, name: 'the_moon'),
    MajorArcanaCard(index: 19, name: 'the_sun'),
    MajorArcanaCard(index: 20, name: 'judgement'),
    MajorArcanaCard(index: 21, name: 'the_world'),
  ];

  static const List<MajorArcanaCard> minorArcana = <MajorArcanaCard>[
    MajorArcanaCard(
      index: 22,
      name: 'ace_of_wands',
      assetSubfolder: 'wands',
      assetFileName: 'ace_of_wands.webp',
    ),
    MajorArcanaCard(
      index: 23,
      name: 'two_of_wands',
      assetSubfolder: 'wands',
      assetFileName: 'two_of_wands.webp',
    ),
    MajorArcanaCard(
      index: 24,
      name: 'three_of_wands',
      assetSubfolder: 'wands',
      assetFileName: 'three_of_wands.webp',
    ),
    MajorArcanaCard(
      index: 25,
      name: 'four_of_wands',
      assetSubfolder: 'wands',
      assetFileName: 'four_of_wands.webp',
    ),
    MajorArcanaCard(
      index: 26,
      name: 'five_of_wands',
      assetSubfolder: 'wands',
      assetFileName: 'five_of_wands.webp',
    ),
    MajorArcanaCard(
      index: 27,
      name: 'six_of_wands',
      assetSubfolder: 'wands',
      assetFileName: 'six_of_wands.webp',
    ),
    MajorArcanaCard(
      index: 28,
      name: 'seven_of_wands',
      assetSubfolder: 'wands',
      assetFileName: 'seven_of_wands.webp',
    ),
    MajorArcanaCard(
      index: 29,
      name: 'eight_of_wands',
      assetSubfolder: 'wands',
      assetFileName: 'eight_of_wands.webp',
    ),
    MajorArcanaCard(
      index: 30,
      name: 'nine_of_wands',
      assetSubfolder: 'wands',
      assetFileName: 'nine_of_wands.webp',
    ),
    MajorArcanaCard(
      index: 31,
      name: 'ten_of_wands',
      assetSubfolder: 'wands',
      assetFileName: 'ten_of_wands.webp',
    ),
    MajorArcanaCard(
      index: 32,
      name: 'page_of_wands',
      assetSubfolder: 'wands',
      assetFileName: 'page_of_wands.webp',
    ),
    MajorArcanaCard(
      index: 33,
      name: 'knight_of_wands',
      assetSubfolder: 'wands',
      assetFileName: 'knight_of_wands.webp',
    ),
    MajorArcanaCard(
      index: 34,
      name: 'queen_of_wands',
      assetSubfolder: 'wands',
      assetFileName: 'queen_of_wands.webp',
    ),
    MajorArcanaCard(
      index: 35,
      name: 'king_of_wands',
      assetSubfolder: 'wands',
      assetFileName: 'king_of_wands.webp',
    ),
    MajorArcanaCard(
      index: 36,
      name: 'ace_of_cups',
      assetSubfolder: 'cups',
      assetFileName: 'ace_of_cups.webp',
    ),
    MajorArcanaCard(
      index: 37,
      name: 'two_of_cups',
      assetSubfolder: 'cups',
      assetFileName: 'two_of_cups.webp',
    ),
    MajorArcanaCard(
      index: 38,
      name: 'three_of_cups',
      assetSubfolder: 'cups',
      assetFileName: 'three_of_cups.webp',
    ),
    MajorArcanaCard(
      index: 39,
      name: 'four_of_cups',
      assetSubfolder: 'cups',
      assetFileName: 'four_of_cups.webp',
    ),
    MajorArcanaCard(
      index: 40,
      name: 'five_of_cups',
      assetSubfolder: 'cups',
      assetFileName: 'five_of_cups.webp',
    ),
    MajorArcanaCard(
      index: 41,
      name: 'six_of_cups',
      assetSubfolder: 'cups',
      assetFileName: 'six_of_cups.webp',
    ),
    MajorArcanaCard(
      index: 42,
      name: 'seven_of_cups',
      assetSubfolder: 'cups',
      assetFileName: 'seven_of_cups.webp',
    ),
    MajorArcanaCard(
      index: 43,
      name: 'eight_of_cups',
      assetSubfolder: 'cups',
      assetFileName: 'eight_of_cups.webp',
    ),
    MajorArcanaCard(
      index: 44,
      name: 'nine_of_cups',
      assetSubfolder: 'cups',
      assetFileName: 'nine_of_cups.webp',
    ),
    MajorArcanaCard(
      index: 45,
      name: 'ten_of_cups',
      assetSubfolder: 'cups',
      assetFileName: 'ten_of_cups.webp',
    ),
    MajorArcanaCard(
      index: 46,
      name: 'page_of_cups',
      assetSubfolder: 'cups',
      assetFileName: 'page_of_cups.webp',
    ),
    MajorArcanaCard(
      index: 47,
      name: 'knight_of_cups',
      assetSubfolder: 'cups',
      assetFileName: 'knight_of_cups.webp',
    ),
    MajorArcanaCard(
      index: 48,
      name: 'queen_of_cups',
      assetSubfolder: 'cups',
      assetFileName: 'queen_of_cups.webp',
    ),
    MajorArcanaCard(
      index: 49,
      name: 'king_of_cups',
      assetSubfolder: 'cups',
      assetFileName: 'king_of_cups.webp',
    ),
    MajorArcanaCard(
      index: 50,
      name: 'ace_of_swords',
      assetSubfolder: 'swords',
      assetFileName: 'ace_of_swords.webp',
    ),
    MajorArcanaCard(
      index: 51,
      name: 'two_of_swords',
      assetSubfolder: 'swords',
      assetFileName: 'two_of_swords.webp',
    ),
    MajorArcanaCard(
      index: 52,
      name: 'three_of_swords',
      assetSubfolder: 'swords',
      assetFileName: 'three_of_swords.webp',
    ),
    MajorArcanaCard(
      index: 53,
      name: 'four_of_swords',
      assetSubfolder: 'swords',
      assetFileName: 'four_of_swords.webp',
    ),
    MajorArcanaCard(
      index: 54,
      name: 'five_of_swords',
      assetSubfolder: 'swords',
      assetFileName: 'five_of_swords.webp',
    ),
    MajorArcanaCard(
      index: 55,
      name: 'six_of_swords',
      assetSubfolder: 'swords',
      assetFileName: 'six_of_swords.webp',
    ),
    MajorArcanaCard(
      index: 56,
      name: 'seven_of_swords',
      assetSubfolder: 'swords',
      assetFileName: 'seven_of_swords.webp',
    ),
    MajorArcanaCard(
      index: 57,
      name: 'eight_of_swords',
      assetSubfolder: 'swords',
      assetFileName: 'eight_of_swords.webp',
    ),
    MajorArcanaCard(
      index: 58,
      name: 'nine_of_swords',
      assetSubfolder: 'swords',
      assetFileName: 'nine_of_swords.webp',
    ),
    MajorArcanaCard(
      index: 59,
      name: 'ten_of_swords',
      assetSubfolder: 'swords',
      assetFileName: 'ten_of_swords.webp',
    ),
    MajorArcanaCard(
      index: 60,
      name: 'page_of_swords',
      assetSubfolder: 'swords',
      assetFileName: 'page_of_swords.webp',
    ),
    MajorArcanaCard(
      index: 61,
      name: 'knight_of_swords',
      assetSubfolder: 'swords',
      assetFileName: 'knight_of_swords.webp',
    ),
    MajorArcanaCard(
      index: 62,
      name: 'queen_of_swords',
      assetSubfolder: 'swords',
      assetFileName: 'queen_of_swords.webp',
    ),
    MajorArcanaCard(
      index: 63,
      name: 'king_of_swords',
      assetSubfolder: 'swords',
      assetFileName: 'king_of_swords.webp',
    ),
    MajorArcanaCard(
      index: 64,
      name: 'ace_of_pentacles',
      assetSubfolder: 'pentacles',
      assetFileName: 'ace_of_pentacles.webp',
    ),
    MajorArcanaCard(
      index: 65,
      name: 'two_of_pentacles',
      assetSubfolder: 'pentacles',
      assetFileName: 'two_of_pentacles.webp',
    ),
    MajorArcanaCard(
      index: 66,
      name: 'three_of_pentacles',
      assetSubfolder: 'pentacles',
      assetFileName: 'three_of_pentacles.webp',
    ),
    MajorArcanaCard(
      index: 67,
      name: 'four_of_pentacles',
      assetSubfolder: 'pentacles',
      assetFileName: 'four_of_pentacles.webp',
    ),
    MajorArcanaCard(
      index: 68,
      name: 'five_of_pentacles',
      assetSubfolder: 'pentacles',
      assetFileName: 'five_of_pentacles.webp',
    ),
    MajorArcanaCard(
      index: 69,
      name: 'six_of_pentacles',
      assetSubfolder: 'pentacles',
      assetFileName: 'six_of_pentacles.webp',
    ),
    MajorArcanaCard(
      index: 70,
      name: 'seven_of_pentacles',
      assetSubfolder: 'pentacles',
      assetFileName: 'seven_of_pentacles.webp',
    ),
    MajorArcanaCard(
      index: 71,
      name: 'eight_of_pentacles',
      assetSubfolder: 'pentacles',
      assetFileName: 'eight_of_pentacles.webp',
    ),
    MajorArcanaCard(
      index: 72,
      name: 'nine_of_pentacles',
      assetSubfolder: 'pentacles',
      assetFileName: 'nine_of_pentacles.webp',
    ),
    MajorArcanaCard(
      index: 73,
      name: 'ten_of_pentacles',
      assetSubfolder: 'pentacles',
      assetFileName: 'ten_of_pentacles.webp',
    ),
    MajorArcanaCard(
      index: 74,
      name: 'page_of_pentacles',
      assetSubfolder: 'pentacles',
      assetFileName: 'page_of_pentacles.webp',
    ),
    MajorArcanaCard(
      index: 75,
      name: 'knight_of_pentacles',
      assetSubfolder: 'pentacles',
      assetFileName: 'knight_of_pentacles.webp',
    ),
    MajorArcanaCard(
      index: 76,
      name: 'queen_of_pentacles',
      assetSubfolder: 'pentacles',
      assetFileName: 'queen_of_pentacles.webp',
    ),
    MajorArcanaCard(
      index: 77,
      name: 'king_of_pentacles',
      assetSubfolder: 'pentacles',
      assetFileName: 'king_of_pentacles.webp',
    ),
  ];

  static const List<MajorArcanaCard> deck = <MajorArcanaCard>[
    ...majorArcana,
    ...minorArcana,
  ];

  static final Map<int, MajorArcanaCard> _cardByIndex = <int, MajorArcanaCard>{
    for (final card in deck) card.index: card,
  };

  static void ensureLocalAssetsCached() {
    final cacheValid =
        _assetsReady &&
        imageUrlByIndex.length == deck.length &&
        imageUrlByIndex.values.every(
          (path) => path.startsWith('${MajorArcanaCard.assetFolder}/'),
        );
    if (cacheValid) {
      return;
    }
    imageUrlByIndex
      ..clear()
      ..addEntries(deck.map((card) => MapEntry(card.index, card.assetPath)));
    _assetsReady = true;
  }

  static String? cachedUrlForIndex(int index) {
    ensureLocalAssetsCached();
    return imageUrlByIndex[index];
  }

  /// Yerel asset haritasi; aninda tamamlanir.
  static Future<void> preloadAllCardImages({
    TarotService? service,
    bool forceRetry = false,
  }) async {
    if (forceRetry) {
      _assetsReady = false;
      imageUrlByIndex.clear();
    }
    ensureLocalAssetsCached();
  }

  static String assetPathForIndex(int index) {
    ensureLocalAssetsCached();
    return imageUrlByIndex[index] ?? cardForIndex(index).assetPath;
  }

  static MajorArcanaCard cardForIndex(int index) {
    final card = _cardByIndex[index];
    if (card == null) {
      throw RangeError.index(index, deck, 'index');
    }
    return card;
  }

  static MajorArcanaCard cardForDisplayName(String name) {
    final normalized = name.trim().toLowerCase();
    return deck.firstWhere(
      (card) =>
          card.name.toLowerCase() == normalized ||
          card.displayName.toLowerCase() == normalized,
      orElse: () => majorArcana.first,
    );
  }

  Future<DrawnTarotCard> getCardByIndex(int index) async {
    final card = cardForIndex(index);
    final path = assetPathForIndex(index);
    return DrawnTarotCard(card: card, imageUrl: path);
  }

  Future<DrawnTarotCard> drawRandomCard() async {
    return getCardByIndex(_random.nextInt(deck.length));
  }
}
