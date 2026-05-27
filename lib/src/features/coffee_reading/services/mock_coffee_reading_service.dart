import 'dart:io';

import '../models/coffee_reading_result.dart';
import 'coffee_reading_service.dart';

class MockCoffeeReadingService implements CoffeeReadingService {
  @override
  Future<CoffeeReadingResult> analyzeCoffee(List<File> validImages) async {
    await Future<void>.delayed(const Duration(seconds: 3));
    final now = DateTime.now();
    return CoffeeReadingResult(
      readingId: 'coffee_${now.microsecondsSinceEpoch}',
      past:
          'Telvenin dipte toplanan izi, geride bıraktığın bir konunun hâlâ iç sesinde yankılandığını söylüyor.',
      present:
          'Fincanın orta hattındaki yumuşak açıklık, şu anda kararlarını daha sakin ve net görmeye başladığını fısıldıyor.',
      future:
          'Kenara doğru yükselen izler, yakın dönemde küçük ama sevindirici bir haberin kapını çalabileceğini anlatıyor.',
      createdAt: now,
    );
  }
}
