import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseVerificationRequest {
  const PurchaseVerificationRequest({
    required this.userId,
    required this.productId,
    required this.transactionId,
    required this.receiptData,
    required this.idempotencyKey,
    required this.platform,
    required this.purchaseStatus,
    this.transactionDate,
  });

  final String userId;
  final String productId;
  final String transactionId;
  final String receiptData;
  final String idempotencyKey;
  final String platform;
  final String purchaseStatus;
  final String? transactionDate;

  factory PurchaseVerificationRequest.fromPurchaseDetails({
    required String userId,
    required PurchaseDetails purchase,
  }) {
    final transactionId = (purchase.purchaseID?.trim().isNotEmpty ?? false)
        ? purchase.purchaseID!.trim()
        : '${purchase.productID}_${purchase.transactionDate ?? DateTime.now().millisecondsSinceEpoch}';

    return PurchaseVerificationRequest(
      userId: userId,
      productId: purchase.productID,
      transactionId: transactionId,
      receiptData: purchase.verificationData.serverVerificationData,
      idempotencyKey: transactionId,
      platform: purchase.verificationData.source,
      purchaseStatus: purchase.status.name,
      transactionDate: purchase.transactionDate,
    );
  }

  Map<String, dynamic> toCallableData() {
    return <String, dynamic>{
      'userId': userId,
      'productId': productId,
      'transactionId': transactionId,
      'purchaseId': transactionId,
      'signedTransaction': receiptData,
      'receiptData': receiptData,
      'verificationData': receiptData,
      'idempotencyKey': idempotencyKey,
      'platform': platform,
      'purchaseStatus': purchaseStatus,
      if (transactionDate != null) 'transactionDate': transactionDate,
    };
  }
}
