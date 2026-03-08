import 'package:cloud_functions/cloud_functions.dart';

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
}
