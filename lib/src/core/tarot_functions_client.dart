import 'package:cloud_functions/cloud_functions.dart';

import '../features/coffee_reading/models/coffee_analyze_response.dart';
import '../features/auth/onboarding_payload.dart';
import '../features/purchases/restore_purchase_item.dart';
import '../features/readings/reading_models.dart';

class TarotFunctionsClient {
  TarotFunctionsClient({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<void> saveOnboardingProfile(OnboardingPayload payload) async {
    final callable = _functions.httpsCallable('saveOnboardingProfile');
    await callable.call(payload.toJson());
  }

  Future<ReadingResult> generateTarotReading(ReadingRequest request) async {
    final callable = _functions.httpsCallable('generateTarotReading');
    final response = await callable.call(request.toJson());
    return ReadingResult.fromJson(response.data as Map<Object?, Object?>);
  }

  Future<String> generateBirthFrequencyComment({
    required String birthDate,
    required String day,
    String? lang,
  }) async {
    final callable = _functions.httpsCallable('generateBirthFrequencyComment');
    final response = await callable.call({
      'birthDate': birthDate,
      'day': day,
      if (lang != null && lang.trim().isNotEmpty) 'lang': lang.trim(),
    });

    final data = Map<String, dynamic>.from(response.data as Map);
    final comment = (data['comment'] as String?)?.trim() ?? '';
    if (comment.isEmpty) {
      throw StateError('empty_birth_frequency_comment');
    }
    return comment;
  }

  Future<Map<String, dynamic>> consumeHomeCardDraw() async {
    final callable = _functions.httpsCallable('consumeHomeCardDraw');
    final response = await callable.call();
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> generateArisOpeningReading({
    String? cardName,
    String? cardImageUrl,
    required String day,
    String? lang,
    List<String>? cardNames,
    String? sessionId,
  }) async {
    final callable = _functions.httpsCallable('generateArisOpeningReading');
    final response = await callable.call({
      if (cardName != null && cardName.trim().isNotEmpty) 'cardName': cardName,
      if (cardImageUrl != null && cardImageUrl.trim().isNotEmpty)
        'cardImageUrl': cardImageUrl,
      'day': day,
      if (lang != null && lang.trim().isNotEmpty) 'lang': lang.trim(),
      if (cardNames != null && cardNames.isNotEmpty) 'cardNames': cardNames,
      if (sessionId != null && sessionId.trim().isNotEmpty)
        'sessionId': sessionId.trim(),
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> analyzePalmReading({
    required String imageBase64,
    String? lang,
    String mimeType = 'image/jpeg',
  }) async {
    final callable = _functions.httpsCallable('analyzePalmReading');
    final response = await callable.call({
      'imageBase64': imageBase64,
      'mimeType': mimeType,
      if (lang != null && lang.trim().isNotEmpty) 'lang': lang.trim(),
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> listArisSessions() async {
    final callable = _functions.httpsCallable('listArisSessions');
    final response = await callable.call();
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> continueArisConversation({
    required String sessionId,
    required String message,
    required String idempotencyKey,
    String? lang,
  }) async {
    final callable = _functions.httpsCallable('continueArisConversation');
    final response = await callable.call({
      'sessionId': sessionId,
      'message': message,
      'idempotencyKey': idempotencyKey,
      if (lang != null && lang.trim().isNotEmpty) 'lang': lang.trim(),
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<CoffeeAnalyzeResponse> analyzeCoffeeReading({
    required String languageCode,
    required Map<String, String> imageRefs,
    required Map<String, dynamic> localValidation,
    required String idempotencyKey,
    String? mood,
  }) async {
    final callable = _functions.httpsCallable('analyzeCoffeeReading');
    final response = await callable.call({
      'languageCode': languageCode,
      'imageRefs': imageRefs,
      'localValidation': localValidation,
      'idempotencyKey': idempotencyKey,
      if (mood != null && mood.trim().isNotEmpty) 'mood': mood.trim(),
    });
    return CoffeeAnalyzeResponse.fromMap(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> deleteCoffeeReadingPhotos({
    required String readingId,
  }) async {
    final callable = _functions.httpsCallable('deleteCoffeeReadingPhotos');
    await callable.call({'readingId': readingId});
  }

  Future<Map<String, dynamic>> validateIosPurchase({
    required String productId,
    required String transactionId,
    required String receiptData,
    required String idempotencyKey,
  }) async {
    final callable = _functions.httpsCallable('validateIosPurchase');
    final response = await callable.call({
      'productId': productId,
      'transactionId': transactionId,
      'receiptData': receiptData,
      'idempotencyKey': idempotencyKey,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> generateShareAsset(String readingId) async {
    final callable = _functions.httpsCallable('generateShareAsset');
    final response = await callable.call({'readingId': readingId});
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> restoreIosPurchases(
    List<RestorePurchaseItem> purchases,
  ) async {
    final callable = _functions.httpsCallable('restoreIosPurchases');
    final response = await callable.call({
      'purchases': purchases.map((p) => p.toJson()).toList(),
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> sendTestDailyNudge() async {
    final callable = _functions.httpsCallable('sendTestDailyNudge');
    final response = await callable.call();
    return Map<String, dynamic>.from(response.data as Map);
  }
}
