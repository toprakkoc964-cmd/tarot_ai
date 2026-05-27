import 'user_entitlements.dart';

class PurchaseVerificationResponse {
  const PurchaseVerificationResponse({
    required this.success,
    this.creditedAmount = 0,
    this.remainingCredits,
    this.entitlements,
    this.message,
  });

  final bool success;
  final int creditedAmount;
  final int? remainingCredits;
  final UserEntitlements? entitlements;
  final String? message;

  factory PurchaseVerificationResponse.fromMap(Map<String, dynamic> map) {
    final entitlementsRaw = map['entitlements'];
    final entitlements = entitlementsRaw is Map
        ? Map<String, dynamic>.from(entitlementsRaw)
        : const <String, dynamic>{};
    final premium =
        Map<String, dynamic>.from((entitlements['premium'] as Map?) ?? {});
    final credits =
        Map<String, dynamic>.from((entitlements['credits'] as Map?) ?? {});
    final balance = (map['remainingCredits'] as num?)?.toInt() ??
        (credits['balance'] as num?)?.toInt();

    return PurchaseVerificationResponse(
      success: map['success'] != false,
      creditedAmount: (map['creditedAmount'] as num?)?.toInt() ?? 0,
      remainingCredits: balance,
      entitlements: entitlementsRaw is Map
          ? UserEntitlements.fromUserMap(
              <String, dynamic>{
                'wallet': {'credits': balance ?? 0},
                'entitlements': {'premium': premium},
              },
            )
          : null,
      message: map['message']?.toString(),
    );
  }
}
