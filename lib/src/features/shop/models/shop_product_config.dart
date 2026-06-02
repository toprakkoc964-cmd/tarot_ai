class ShopProductConfig {
  const ShopProductConfig({
    required this.productId,
    required this.titleKey,
    required this.subtitleKey,
    required this.featureKeys,
    this.badgeKey,
    this.iconKey,
    this.isHighlighted = false,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String productId;
  final String titleKey;
  final String subtitleKey;
  final List<String> featureKeys;
  final String? badgeKey;
  final String? iconKey;
  final bool isHighlighted;
  final bool isActive;
  final int sortOrder;

  factory ShopProductConfig.fromMap(Map<String, dynamic> map) {
    final featureKeysRaw = map['featureKeys'] ?? map['feature_keys'];
    return ShopProductConfig(
      productId: (map['productId'] ?? map['product_id'] ?? '').toString(),
      titleKey: (map['titleKey'] ?? map['title_key'] ?? '').toString(),
      subtitleKey: (map['subtitleKey'] ?? map['subtitle_key'] ?? '').toString(),
      featureKeys: featureKeysRaw is List
          ? featureKeysRaw
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
          : const [],
      badgeKey: _optionalString(map['badgeKey'] ?? map['badge_key']),
      iconKey: _optionalString(map['iconKey'] ?? map['icon_key']),
      isHighlighted:
          map['isHighlighted'] == true || map['is_highlighted'] == true,
      isActive: map['isActive'] != false && map['is_active'] != false,
      sortOrder: _intFrom(map['sortOrder'] ?? map['sort_order']),
    );
  }

  static String? _optionalString(Object? raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static int _intFrom(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }
}

class ShopLegalConfig {
  const ShopLegalConfig({
    required this.termsUrls,
    required this.privacyUrls,
  });

  final Map<String, String> termsUrls;
  final Map<String, String> privacyUrls;

  factory ShopLegalConfig.fromMap(Map<String, dynamic> map) {
    return ShopLegalConfig(
      termsUrls: _urlMap(map['termsUrl'] ?? map['terms_url']),
      privacyUrls: _urlMap(map['privacyUrl'] ?? map['privacy_url']),
    );
  }

  String termsUrlFor(String languageCode) {
    return _urlFor(termsUrls, languageCode);
  }

  String privacyUrlFor(String languageCode) {
    return _urlFor(privacyUrls, languageCode);
  }

  static String _urlFor(Map<String, String> urls, String languageCode) {
    final lang = languageCode.trim().toLowerCase();
    return urls[lang] ?? urls['default'] ?? '';
  }

  static Map<String, String> _urlMap(Object? raw) {
    if (raw is! Map) return const {};
    final result = <String, String>{};
    raw.forEach((key, value) {
      final safeKey = key.toString().trim().toLowerCase();
      final safeValue = value.toString().trim();
      if (safeKey.isNotEmpty && safeValue.isNotEmpty) {
        result[safeKey] = safeValue;
      }
    });
    return result;
  }
}

class ShopConfig {
  const ShopConfig({
    required this.creditProducts,
    required this.premiumProducts,
    required this.legal,
  });

  final List<ShopProductConfig> creditProducts;
  final List<ShopProductConfig> premiumProducts;
  final ShopLegalConfig legal;

  factory ShopConfig.fromMap(Map<String, dynamic> map) {
    final creditRaw = map['credits'] ?? map['creditProducts'];
    final premiumRaw = map['premium'] ?? map['premiumProducts'];
    return ShopConfig(
      creditProducts: _productsFrom(creditRaw),
      premiumProducts: _productsFrom(premiumRaw),
      legal: ShopLegalConfig.fromMap(
        Map<String, dynamic>.from((map['legal'] as Map?) ?? const {}),
      ),
    );
  }

  static List<ShopProductConfig> _productsFrom(Object? raw) {
    if (raw is! List) return const [];
    final products = raw
        .whereType<Map>()
        .map((item) =>
            ShopProductConfig.fromMap(Map<String, dynamic>.from(item)))
        .where((item) => item.productId.isNotEmpty)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return products;
  }
}

/// Known store package names (must match Play Console / App Store Connect).
abstract final class ShopStoreTargets {
  static const String androidPackageName = 'com.example.tarot_ai';
  static const String iosBundleId = 'com.tarotai';
}
