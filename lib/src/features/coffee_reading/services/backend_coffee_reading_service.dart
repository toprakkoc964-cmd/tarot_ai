import '../../../core/app_locale.dart';
import '../../../core/idempotency_key.dart';
import '../../../core/tarot_functions_client.dart';
import '../models/coffee_analyze_response.dart';
import '../models/coffee_image_pipeline_result.dart';
import '../models/coffee_photo_step.dart';
import '../models/coffee_reading_result.dart';
import 'coffee_backend_service.dart';
import 'coffee_reading_service.dart';

class BackendCoffeeReadingService implements CoffeeReadingService {
  BackendCoffeeReadingService({
    required TarotFunctionsClient functionsClient,
    required CoffeeBackendService backendService,
  })  : _functionsClient = functionsClient,
        _backendService = backendService;

  final TarotFunctionsClient _functionsClient;
  final CoffeeBackendService _backendService;

  @override
  Future<CoffeeReadingResult> analyzeCoffee({
    required String uid,
    required Map<CoffeePhotoStep, CoffeeImagePipelineResult> photos,
    String? idempotencyKey,
    String? languageCode,
  }) async {
    final readingId = 'coffee_${DateTime.now().microsecondsSinceEpoch}';
    final imageRefs = await _backendService.uploadPhotos(
      uid: uid,
      readingId: readingId,
      photos: {
        for (final entry in photos.entries)
          entry.key: entry.value.compressedImage,
      },
    );

    final response = await _functionsClient.analyzeCoffeeReading(
      languageCode: languageCode ?? AppLocale.current,
      imageRefs:
          imageRefs.map((key, value) => MapEntry(key.metadataKey, value)),
      localValidation: {
        for (final entry in photos.entries)
          entry.key.metadataKey: {
            ...entry.value.validationResult.toBackendSummaryMap(),
            'sourceEvidence': entry.value.sourceEvidence.toMap(),
          },
      },
      idempotencyKey: idempotencyKey ?? createIdempotencyKey(),
    );

    if (!response.success || response.reading == null) {
      await _backendService.deleteUploadedPhotos(imageRefs.values);
      throw CoffeeReadingValidationException(response);
    }

    return CoffeeReadingResult.fromAnalyzeResponse(
      readingId: response.readingId.isNotEmpty ? response.readingId : readingId,
      reading: response.reading!,
      chargedCredits: response.chargedCredits,
      remainingCredits: response.remainingCredits,
    );
  }
}

class CoffeeReadingValidationException implements Exception {
  CoffeeReadingValidationException(this.response);

  final CoffeeAnalyzeResponse response;
}
