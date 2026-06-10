import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../../../core/app_locale.dart';
import '../models/shop_product_catalog.dart';
import '../models/shop_product_config.dart';

class ShopConfigService {
  ShopConfigService();

  static const String remoteConfigKey = 'shop_config_v1';

  bool _initialized = false;
  ShopConfig? _cachedConfig;

  ShopConfig? get cachedConfig => _cachedConfig;

  Future<ShopConfig> fetchConfig() async {
    if (_cachedConfig != null) return SynchronousFuture(_cachedConfig!);

    final remoteConfig = FirebaseRemoteConfig.instance;
    try {
      if (!_initialized) {
        await remoteConfig.setConfigSettings(
          RemoteConfigSettings(
            fetchTimeout: const Duration(seconds: 10),
            minimumFetchInterval: kDebugMode
                ? Duration.zero
                : const Duration(hours: 1),
          ),
        );
        await remoteConfig.setDefaults(<String, dynamic>{
          remoteConfigKey: jsonEncode(_fallbackConfig),
        });
        _initialized = true;
      }

      await remoteConfig.fetchAndActivate();
      final raw = remoteConfig.getString(remoteConfigKey);
      final config = _decode(raw);
      _cachedConfig = config;
      return config;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ShopConfigService fallback: $e');
      }
      final fallback = ShopConfig.fromMap(_fallbackConfig);
      _cachedConfig = fallback;
      return fallback;
    }
  }

  void invalidate() {
    _cachedConfig = null;
  }

  String legalTermsUrl(ShopConfig config) {
    return config.legal.termsUrlFor(AppLocale.current);
  }

  String legalPrivacyUrl(ShopConfig config) {
    return config.legal.privacyUrlFor(AppLocale.current);
  }

  ShopConfig _decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return ShopConfig.fromMap(_fallbackConfig);
    final map = Map<String, dynamic>.from(decoded);
    final config = ShopConfig.fromMap(map);
    if (config.creditProducts.isEmpty && config.premiumProducts.isEmpty) {
      return ShopConfig.fromMap(_fallbackConfig);
    }
    return config;
  }
}

const Map<String, dynamic> _fallbackConfig = {
  'credits': [
    {
      'productId': ShopProductCatalog.credits50,
      'titleKey': 'creditsPack50',
      'subtitleKey': 'creditsPackSubtitle',
      'featureKeys': [
        'creditsPack50Feature1',
        'creditsPack50Feature2',
        'creditsPack50Feature3',
      ],
      'iconKey': 'token',
      'sortOrder': 10,
      'isActive': true,
      'isHighlighted': false,
    },
    {
      'productId': ShopProductCatalog.credits250,
      'titleKey': 'creditsPack250',
      'subtitleKey': 'creditsPackSubtitle',
      'featureKeys': [
        'creditsPack250Feature1',
        'creditsPack250Feature2',
        'creditsPack250Feature3',
      ],
      'badgeKey': 'premiumBadgePopular',
      'iconKey': 'moon',
      'sortOrder': 20,
      'isActive': true,
      'isHighlighted': true,
    },
    {
      'productId': ShopProductCatalog.credits1000,
      'titleKey': 'creditsPack1000',
      'subtitleKey': 'creditsPackSubtitle',
      'featureKeys': [
        'creditsPack1000Feature1',
        'creditsPack1000Feature2',
        'creditsPack1000Feature3',
      ],
      'iconKey': 'sun',
      'sortOrder': 30,
      'isActive': true,
      'isHighlighted': false,
    },
  ],
  'premium': [
    {
      'productId': ShopProductCatalog.premiumMonthly,
      'titleKey': 'premiumMonthlyTitle',
      'subtitleKey': 'premiumMonthlySubtitle',
      'featureKeys': [
        'premiumFeatureNoAds',
        'premiumFeatureBonusCredits',
        'premiumFeatureDeepReadings',
        'premiumFeaturePersonalizedExperience',
        'premiumFeaturePremiumAiDepth',
      ],
      'badgeKey': 'premiumBadgePopular',
      'iconKey': 'premium',
      'sortOrder': 10,
      'isActive': true,
      'isHighlighted': true,
    },
  ],
  'legal': {
    'termsUrl': {
      'default': 'https://tarotai.app/terms',
      'tr': 'https://tarotai.app/tr/terms',
      'en': 'https://tarotai.app/en/terms',
      'de': 'https://tarotai.app/de/terms',
    },
    'privacyUrl': {
      'default': 'https://tarotai.app/privacy',
      'tr': 'https://tarotai.app/tr/privacy',
      'en': 'https://tarotai.app/en/privacy',
      'de': 'https://tarotai.app/de/privacy',
    },
  },
};
