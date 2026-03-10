class RestorePurchaseItem {
  const RestorePurchaseItem({
    required this.transactionId,
    required this.productId,
    required this.receiptData,
  });

  final String transactionId;
  final String productId;
  final String receiptData;

  Map<String, dynamic> toJson() => {
    'transactionId': transactionId,
    'productId': productId,
    'receiptData': receiptData,
  };
}
