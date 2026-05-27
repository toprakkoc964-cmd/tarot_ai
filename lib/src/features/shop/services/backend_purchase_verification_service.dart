import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/purchase_verification_request.dart';
import '../models/purchase_verification_response.dart';

class BackendPurchaseVerificationService {
  BackendPurchaseVerificationService({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<PurchaseVerificationResponse> verifyPurchase(
    PurchaseVerificationRequest request,
  ) async {
    final callable = _functions.httpsCallable('validateIosPurchase');

    if (kDebugMode) {
      debugPrint(
        'Purchase verify request product=${request.productId} tx=${_masked(request.transactionId)}',
      );
    }

    final response = await callable.call<Map<String, dynamic>>(
      request.toCallableData(),
    );
    final data = response.data;
    return PurchaseVerificationResponse.fromMap(
      Map<String, dynamic>.from(data),
    );
  }

  static String _masked(String value) {
    if (value.length <= 8) return '***';
    return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
  }
}
