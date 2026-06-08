import '../models/coffee_ai_reading_response.dart';
import '../models/coffee_image_pipeline_result.dart';
import '../models/coffee_photo_step.dart';
import '../models/coffee_reading_result.dart';
import 'coffee_reading_service.dart';

class MockCoffeeReadingService implements CoffeeReadingService {
  @override
  Future<CoffeeReadingResult> analyzeCoffee({
    required String uid,
    required Map<CoffeePhotoStep, CoffeeImagePipelineResult> photos,
    String? idempotencyKey,
    String? languageCode,
    String? mood,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 3));
    final now = DateTime.now();
    return CoffeeReadingResult.fromAnalyzeResponse(
      readingId: 'coffee_${now.microsecondsSinceEpoch}',
      reading: const CoffeeAiReadingResponse(
        generalEnergy:
            'Fincanın genel enerjisi yumuşak bir dönüşüm ve içsel netlik taşıyor.',
        symbols:
            'Telvede beliren küçük bir kuş izi, yakında hafif bir haber geleceğini fısıldıyor.',
        saucerSigns:
            'Tabağın kenarındaki izler, sabırla beklediğin bir konunun yavaşça açılacağını söylüyor.',
        outerCupMessage:
            'Fincanın dışındaki hatlar, dış dünyaya daha dengeli adımlarla yaklaşmanı öneriyor.',
        pastTrace:
            'Geçmişten gelen bir kararsızlık izi hâlâ fincanın dibinde yankılanıyor.',
        presentMood:
            'Şu anki ruh halin daha sakin, gözlemci ve sezgisel bir tonda.',
        nearFutureMessage:
            'Yakın dönemde küçük ama sevindirici bir haber kapını çalabilir.',
        advice:
            'Madam Aris, acele etmeden kalbini dinlemenin doğru yolu açacağını söylüyor.',
        disclaimer:
            'Bu yorum eğlence ve kişisel farkındalık amacıyla hazırlanmıştır; tıbbi, finansal, hukuki veya kesin gelecek tahmini içermez.',
      ),
      chargedCredits: 0,
      remainingCredits: 0,
    );
  }
}
