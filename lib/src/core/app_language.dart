import 'app_locale.dart';
import 'localization_service.dart';

class AppLanguage {
  AppLanguage._();

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
