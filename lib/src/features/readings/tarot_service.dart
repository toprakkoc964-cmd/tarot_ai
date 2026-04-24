import 'dart:math';

import 'package:firebase_storage/firebase_storage.dart';

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

  String get snakeCaseName => name.trim().toLowerCase().replaceAll(' ', '_');
  String get fileName =>
      '${index.toString().padLeft(2, '0')}_$snakeCaseName.webp';
  String get storagePath => 'tarot_cards-major_arcana/$fileName';
  String get displayName => name
      .split('_')
      .map((part) => part.isEmpty
          ? part
          : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class DrawnTarotCard {
  const DrawnTarotCard({
    required this.card,
    required this.imageUrl,
  });

  final MajorArcanaCard card;
  final String imageUrl;
}

class TarotService {
  TarotService({
    FirebaseStorage? storage,
    Random? random,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _random = random ?? Random();

  final FirebaseStorage _storage;
  final Random _random;

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

  Future<String> getCardDownloadUrlByFileName(String fileName) async {
    final path = 'tarot_cards-major_arcana/$fileName';
    try {
      return await _storage.ref(path).getDownloadURL();
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        throw TarotCardLoadException('Tarot karti bulunamadi: $path');
      }
      throw TarotCardLoadException(
        'Tarot karti yuklenemedi: ${error.message ?? error.code}',
      );
    } catch (error) {
      throw TarotCardLoadException('Tarot karti yuklenemedi: $error');
    }
  }

  Future<String> getCardDownloadUrl(MajorArcanaCard card) async {
    return getCardDownloadUrlByFileName(card.fileName);
  }

  Future<DrawnTarotCard> getCardByIndex(int index) async {
    if (index < 0 || index >= majorArcana.length) {
      throw RangeError.index(index, majorArcana, 'index');
    }

    final card = majorArcana[index];
    final normalizedName = card.name.trim().toLowerCase().replaceAll(' ', '_');
    final fileName =
        '${index.toString().padLeft(2, '0')}_$normalizedName.webp';
    final imageUrl = await getCardDownloadUrlByFileName(fileName);
    return DrawnTarotCard(card: card, imageUrl: imageUrl);
  }

  Future<DrawnTarotCard> drawRandomCard() async {
    final randomIndex = _random.nextInt(majorArcana.length);
    return getCardByIndex(randomIndex);
  }
}
