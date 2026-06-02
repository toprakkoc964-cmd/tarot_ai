import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_ai/src/features/readings/tarot_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all major arcana card assets are bundled', () async {
    TarotService.ensureLocalAssetsCached();
    for (final card in TarotService.majorArcana) {
      final bytes = await rootBundle.load(card.assetPath);
      expect(bytes.lengthInBytes, greaterThan(1000));
    }
  });
}
