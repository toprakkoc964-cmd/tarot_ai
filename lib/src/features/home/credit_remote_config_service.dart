import 'dart:convert';
import 'dart:ui';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_locale.dart';
import '../../core/app_texts.dart';
import 'credit_page_models.dart';

class CreditRemoteConfigService {
  CreditRemoteConfigService._();

  static final CreditRemoteConfigService instance =
      CreditRemoteConfigService._();

  static const String _configKey = 'credit_page_data';
  final Map<String, CreditPageData> _memoryCache = <String, CreditPageData>{};
  final Map<String, Future<CreditPageData>> _inFlightRequests =
      <String, Future<CreditPageData>>{};
  bool _configInitialized = false;

  Future<CreditPageData> fetchPageData() async {
    final localeCode = _resolvedLocaleCode();
    final cached = _memoryCache[localeCode];
    if (cached != null) {
      return SynchronousFuture<CreditPageData>(cached);
    }

    final activeRequest = _inFlightRequests[localeCode];
    if (activeRequest != null) {
      return activeRequest;
    }

    final request = _fetchAndCachePageData(localeCode);
    _inFlightRequests[localeCode] = request;
    request.whenComplete(() {
      _inFlightRequests.remove(localeCode);
    });
    return request;
  }

  Future<CreditPageData> _fetchAndCachePageData(String localeCode) async {
    final remoteConfig = FirebaseRemoteConfig.instance;

    try {
      if (!_configInitialized) {
        await remoteConfig.setConfigSettings(
          RemoteConfigSettings(
            fetchTimeout: const Duration(seconds: 10),
            minimumFetchInterval:
                kDebugMode ? Duration.zero : const Duration(hours: 1),
          ),
        );
        await remoteConfig.setDefaults(<String, dynamic>{
          _configKey: jsonEncode(_fallbackPayload),
        });
        _configInitialized = true;
      }

      await remoteConfig.fetchAndActivate();
      final raw = remoteConfig.getString(_configKey);
      if (kDebugMode) {
        debugPrint(
          'CreditRemoteConfigService: locale=$localeCode key=$_configKey length=${raw.length}',
        );
      }
      final data = _decodePayload(raw, localeCode);
      _memoryCache[localeCode] = data;
      return data;
    } catch (_) {
      final fallback = _fallbackFor(localeCode);
      _memoryCache[localeCode] = fallback;
      return fallback;
    }
  }

  void invalidate({String? localeCode}) {
    if (localeCode == null) {
      _memoryCache.clear();
      _inFlightRequests.clear();
      return;
    }
    _memoryCache.remove(localeCode);
    _inFlightRequests.remove(localeCode);
  }

  CreditPageData _decodePayload(String raw, String localeCode) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return _fallbackFor(localeCode);
      }

      final langMap = decoded[localeCode] ?? decoded['tr'] ?? decoded['en'];

      if (langMap is! Map<String, dynamic>) {
        return _fallbackFor(localeCode);
      }

      final data = CreditPageData.fromMap(langMap, localeCode);
      return _mergeWithFallback(data, localeCode);
    } catch (_) {
      return _fallbackFor(localeCode);
    }
  }

  CreditPageData _mergeWithFallback(CreditPageData data, String localeCode) {
    final fallback = _fallbackFor(localeCode);

    final advantages = data.advantagesCards.isEmpty
        ? fallback.advantagesCards
        : data.advantagesCards;
    final packages = data.packages.isEmpty ? fallback.packages : data.packages;

    return CreditPageData(
      localeCode: data.localeCode,
      title: data.title.isEmpty ? fallback.title : data.title,
      advantagesTitle: data.advantagesTitle.isEmpty
          ? fallback.advantagesTitle
          : data.advantagesTitle,
      rechargeCta:
          data.rechargeCta.isEmpty ? fallback.rechargeCta : data.rechargeCta,
      restoreLabel:
          data.restoreLabel.isEmpty ? fallback.restoreLabel : data.restoreLabel,
      termsLabel:
          data.termsLabel.isEmpty ? fallback.termsLabel : data.termsLabel,
      privacyLabel:
          data.privacyLabel.isEmpty ? fallback.privacyLabel : data.privacyLabel,
      legalDisclaimer: data.legalDisclaimer.isEmpty
          ? fallback.legalDisclaimer
          : data.legalDisclaimer,
      advantagesCards: advantages,
      packages: packages,
    );
  }

  CreditPageData _fallbackFor(String localeCode) {
    final langMap = Map<String, dynamic>.from(
      (_fallbackPayload[localeCode] ??
          _fallbackPayload['tr'] ??
          _fallbackPayload['en']) as Map,
    );
    return CreditPageData.fromMap(langMap, localeCode);
  }

  String _resolvedLocaleCode() {
    final current = AppLocale.current.trim().toLowerCase();
    if (current == 'tr' || current == 'en') return current;

    final deviceCode =
        PlatformDispatcher.instance.locale.languageCode.trim().toLowerCase();
    if (deviceCode == 'tr' || deviceCode == 'en') return deviceCode;
    return 'tr';
  }

  static IconData iconFor(String iconKey) {
    switch (iconKey.trim().toLowerCase()) {
      case 'mic':
      case 'mic_external_on':
        return Icons.mic_external_on;
      case 'stars':
      case 'sparkles':
      case 'personalized':
        return Icons.stars_rounded;
      case 'wand':
      case 'auto_fix_high':
        return Icons.auto_fix_high;
      case 'dark_mode':
      case 'moon':
        return Icons.dark_mode_rounded;
      case 'light_mode':
      case 'sun':
        return Icons.light_mode_rounded;
      case 'token':
      case 'wallet':
      case 'generating_tokens':
        return Icons.generating_tokens_rounded;
      case 'workspace_premium':
        return Icons.workspace_premium_rounded;
      case 'play':
      case 'play_arrow':
        return Icons.play_arrow_rounded;
      case 'voice':
        return Icons.record_voice_over_rounded;
      case 'video':
        return Icons.videocam_rounded;
      case 'chat':
        return Icons.forum_rounded;
      case 'star':
      default:
        return Icons.star_rounded;
    }
  }

  static Color accentColorFor(String accentKey) {
    switch (accentKey.trim().toLowerCase()) {
      case 'secondary':
        return const Color(0xFFCDBDFF);
      case 'tertiary':
      case 'gold':
        return const Color(0xFFFFE792);
      case 'primary':
      default:
        return const Color(0xFFFF5ED6);
    }
  }
}

final Map<String, dynamic> _fallbackPayload = {
  'tr': {
    'title': AppTexts.t('home.credit.title'),
    'advantages_title': AppTexts.t('home.credit.perks.title'),
    'recharge_cta': AppTexts.t('home.credit.cta.recharge'),
    'restore_label': AppTexts.t('home.credit.restore'),
    'terms_label': AppTexts.t('home.credit.terms'),
    'privacy_label': AppTexts.t('home.credit.privacy'),
    'legal_disclaimer': AppTexts.t('home.credit.legal_disclaimer'),
    'advantages_cards': [
      {
        'icon_key': 'mic_external_on',
        'title': AppTexts.t('home.credit.perk.voice.title'),
        'description': AppTexts.t('home.credit.perk.voice.desc'),
        'accent': 'primary',
      },
      {
        'icon_key': 'stars',
        'title': AppTexts.t('home.credit.perk.personalized.title'),
        'description': AppTexts.t('home.credit.perk.personalized.desc'),
        'accent': 'secondary',
      },
      {
        'icon_key': 'wand',
        'title': AppTexts.t('home.credit.perk.clarity.title'),
        'description': AppTexts.t('home.credit.perk.clarity.desc'),
        'accent': 'tertiary',
      },
    ],
    'packages': [
      {
        'coins': AppTexts.t('home.credit.package.50.coins'),
        'title': AppTexts.t('home.credit.package.50.title'),
        'price': AppTexts.t('home.credit.package.50.price'),
        'icon_key': 'star',
        'accent': 'secondary',
        'is_popular': false,
        'features': [
          AppTexts.t('home.credit.package.50.feature1'),
          AppTexts.t('home.credit.package.50.feature2'),
          AppTexts.t('home.credit.package.50.feature3'),
        ],
      },
      {
        'coins': AppTexts.t('home.credit.package.250.coins'),
        'title': AppTexts.t('home.credit.package.250.title'),
        'price': AppTexts.t('home.credit.package.250.price'),
        'icon_key': 'dark_mode',
        'accent': 'primary',
        'badge': AppTexts.t('home.credit.package.250.badge'),
        'is_popular': true,
        'features': [
          AppTexts.t('home.credit.package.250.feature1'),
          AppTexts.t('home.credit.package.250.feature2'),
          AppTexts.t('home.credit.package.250.feature3'),
        ],
      },
      {
        'coins': AppTexts.t('home.credit.package.1000.coins'),
        'title': AppTexts.t('home.credit.package.1000.title'),
        'price': AppTexts.t('home.credit.package.1000.price'),
        'icon_key': 'light_mode',
        'accent': 'tertiary',
        'is_popular': false,
        'features': [
          AppTexts.t('home.credit.package.1000.feature1'),
          AppTexts.t('home.credit.package.1000.feature2'),
          AppTexts.t('home.credit.package.1000.feature3'),
        ],
      },
    ],
  },
  'en': {
    'title': 'Cosmic Wallet',
    'advantages_title': 'Cosmic Perks',
    'recharge_cta': 'Recharge Energy',
    'restore_label': 'Restore Purchases',
    'terms_label': 'Terms of Use',
    'privacy_label': 'Privacy Policy',
    'legal_disclaimer':
        'Legal Notice: This application is for entertainment and personal exploration only. AI-generated interpretations are not definitive and do not replace professional advice (medical, legal, financial, etc.). Accuracy or realization of content is not guaranteed. Results may vary from person to person. Please evaluate this information with common sense.',
    'advantages_cards': [
      {
        'icon_key': 'mic_external_on',
        'title': 'Voice Guidance',
        'description':
            'Do not only see the cards, feel the sage voice in your ears.',
        'accent': 'primary',
      },
      {
        'icon_key': 'stars',
        'title': 'Personalized',
        'description': 'A deep frequency tailored to your birth chart.',
        'accent': 'secondary',
      },
      {
        'icon_key': 'wand',
        'title': 'Mental Clarity',
        'description': 'Remove limits and illuminate with deeper questions.',
        'accent': 'tertiary',
      },
    ],
    'packages': [
      {
        'coins': '50 Tokens',
        'title': 'Star Pack',
        'price': '₺49.99',
        'icon_key': 'star',
        'accent': 'secondary',
        'is_popular': false,
        'features': [
          '5 Voice Readings',
          '2 Deep Chats',
          'Standard Analysis',
        ],
      },
      {
        'coins': '250 Tokens',
        'title': 'Cosmic Choice',
        'price': '₺199.99',
        'icon_key': 'dark_mode',
        'accent': 'primary',
        'badge': 'Cosmic Choice',
        'is_popular': true,
        'features': [
          '25 Voice Readings',
          '10 Video Sessions',
          '20 Deep Chats',
        ],
      },
      {
        'coins': '1000 Tokens',
        'title': 'Sun Pack',
        'price': '₺699.99',
        'icon_key': 'light_mode',
        'accent': 'tertiary',
        'is_popular': false,
        'features': [
          'Unlimited Voice Readings',
          'Unlimited Video Sessions',
          'VIP Priority',
        ],
      },
    ],
  },
};
