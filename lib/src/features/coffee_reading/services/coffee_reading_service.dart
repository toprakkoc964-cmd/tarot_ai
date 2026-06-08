import '../models/coffee_image_pipeline_result.dart';
import '../models/coffee_photo_step.dart';
import '../models/coffee_reading_result.dart';

abstract class CoffeeReadingService {
  Future<CoffeeReadingResult> analyzeCoffee({
    required String uid,
    required Map<CoffeePhotoStep, CoffeeImagePipelineResult> photos,
    String? idempotencyKey,
    String? languageCode,
    String? mood,
  });
}
