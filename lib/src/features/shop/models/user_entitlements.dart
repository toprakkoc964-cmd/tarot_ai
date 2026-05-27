import 'package:cloud_firestore/cloud_firestore.dart';

class PremiumEntitlement {
  const PremiumEntitlement({
    required this.active,
    this.productId,
    this.expiresAt,
    this.willRenew,
  });

  final bool active;
  final String? productId;
  final DateTime? expiresAt;
  final bool? willRenew;

  factory PremiumEntitlement.fromMap(Map<String, dynamic> map) {
    return PremiumEntitlement(
      active: map['active'] == true,
      productId: map['productId']?.toString(),
      expiresAt: _dateFrom(map['expiresAt']),
      willRenew: map['willRenew'] is bool ? map['willRenew'] as bool : null,
    );
  }

  static DateTime? _dateFrom(Object? raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

class UserEntitlements {
  const UserEntitlements({
    required this.premium,
    required this.creditBalance,
  });

  final PremiumEntitlement premium;
  final int creditBalance;

  bool get shouldShowAds => premium.active != true;

  factory UserEntitlements.empty() {
    return const UserEntitlements(
      premium: PremiumEntitlement(active: false),
      creditBalance: 0,
    );
  }

  factory UserEntitlements.fromUserMap(Map<String, dynamic> map) {
    final wallet = Map<String, dynamic>.from((map['wallet'] as Map?) ?? {});
    final entitlements =
        Map<String, dynamic>.from((map['entitlements'] as Map?) ?? {});
    final premium =
        Map<String, dynamic>.from((entitlements['premium'] as Map?) ?? {});

    return UserEntitlements(
      premium: PremiumEntitlement.fromMap(premium),
      creditBalance: (wallet['credits'] as num?)?.toInt() ?? 0,
    );
  }
}

bool shouldShowAds(UserEntitlements entitlements) {
  return entitlements.shouldShowAds;
}
