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
  });

  final int index;
  final String name;

  static const String assetFolder = 'assets/card-images';

  String get snakeCaseName => name.trim().toLowerCase().replaceAll(' ', '_');
  String get fileName =>
      '${index.toString().padLeft(2, '0')}_$snakeCaseName.webp';
  String get assetPath => '$assetFolder/$fileName';
  String get displayName => name
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class DrawnTarotCard {
  const DrawnTarotCard({
    required this.card,
    required this.imageUrl,
  });

  final MajorArcanaCard card;

  /// Yerel asset yolu (`assets/card-images/00_the_fool.webp`) veya ag URL.
  final String imageUrl;

  bool get hasLocalAsset =>
      imageUrl.isNotEmpty && !imageUrl.startsWith('http');
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

  static void ensureLocalAssetsCached() {
    final cacheValid = _assetsReady &&
        imageUrlByIndex.length == majorArcana.length &&
        imageUrlByIndex.values
            .every((path) => path.startsWith('${MajorArcanaCard.assetFolder}/'));
    if (cacheValid) {
      return;
    }
    imageUrlByIndex
      ..clear()
      ..addEntries(
        majorArcana.map(
          (card) => MapEntry(card.index, card.assetPath),
        ),
      );
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
    return imageUrlByIndex[index] ?? majorArcana[index].assetPath;
  }

  Future<DrawnTarotCard> getCardByIndex(int index) async {
    if (index < 0 || index >= majorArcana.length) {
      throw RangeError.index(index, majorArcana, 'index');
    }
    final card = majorArcana[index];
    final path = assetPathForIndex(index);
    return DrawnTarotCard(card: card, imageUrl: path);
  }

  Future<DrawnTarotCard> drawRandomCard() async {
    return getCardByIndex(_random.nextInt(majorArcana.length));
  }
}
