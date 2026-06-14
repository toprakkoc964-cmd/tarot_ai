import 'package:flutter/widgets.dart';

import 'app_locale.dart';
import 'localization_service.dart';

class AppLanguage {
  AppLanguage._();

  static const Set<String> uiSupportedFallback = {'tr', 'en', 'de', 'fr', 'es'};

  static const Set<String> aiSupported = {
    'tr',
    'en',
    'de',
    'es',
    'fr',
    'it',
    'pt',
  };

  static List<String> get supported =>
      LocalizationService.instance.supportedLanguages.value;

  static Set<String> get supportedUiLanguages {
    final loaded = supported
        .map(normalize)
        .where((code) => code.trim().isNotEmpty)
        .toSet();
    return {...uiSupportedFallback, ...loaded};
  }

  static bool isSupported(String? code) {
    final normalized = normalize(code);
    return supported.contains(normalized);
  }

  static String normalize(String? code) {
    final raw = (code ?? '').trim().toLowerCase();
    if (raw.isEmpty) return 'en';
    return raw.split(RegExp('[-_]')).first;
  }

  /// UI + AI icin aktif dil (kullanici secimi oncelikli).
  static String get current => forAi();

  static String forAi() {
    final appLang = normalize(AppLocale.current);
    if (aiSupported.contains(appLang)) return appLang;
    return 'en';
  }

  static String deviceDefault() {
    final supportedCodes = supportedUiLanguages;
    final locales = WidgetsBinding.instance.platformDispatcher.locales;
    for (final locale in locales) {
      final code = normalize(locale.languageCode);
      if (supportedCodes.contains(code)) return code;
    }

    final fallbackCode = normalize(
      WidgetsBinding.instance.platformDispatcher.locale.languageCode,
    );
    if (supportedCodes.contains(fallbackCode)) return fallbackCode;
    return 'en';
  }

  static String displayName(String code) {
    switch (normalize(code)) {
      case 'tr':
        return 'Turkce';
      case 'en':
        return 'English';
      case 'de':
        return 'Deutsch';
      case 'fr':
        return 'Francais';
      case 'es':
        return 'Espanol';
      case 'it':
        return 'Italiano';
      case 'pt':
        return 'Portugues';
      default:
        return normalize(code).toUpperCase();
    }
  }
}
