import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_locale.dart';

class LocalizationService {
  LocalizationService._();
  static final LocalizationService instance = LocalizationService._();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  final ValueNotifier<List<String>> supportedLanguages =
      ValueNotifier<List<String>>(
    const ['tr', 'en'],
  );

  final Map<String, Map<String, String>> _cache = {};

  static const Map<String, String> _fallbackEn = {
    'error.default': 'Something went wrong.',
    'error.name_required': 'Name is required.',
    'error.email_required': 'Email is required.',
    'error.password_required': 'Password is required.',
    'error.password_short': 'Password must be at least 6 characters.',
    'error.password_mismatch': 'Passwords do not match.',
    'error.accept_terms': 'Please accept terms to continue.',
    'error.profile_required': 'Please fill all required fields.',
    'error.cards_required': 'Please select at least one card.',
    'toast.reset_sent': 'Password reset email has been sent.',
    'toast.restore_pending': 'Connect purchase history for restore.',
    'auth.login.title': 'Login',
    'auth.login.button': 'Login',
    'auth.register.button': 'Create My Destiny',
    'common.logout': 'Logout',
    'common.restore': 'Restore',
    'common.select_language': 'Select language',
    'common.save_profile': 'Save Profile',
    'common.generate': 'Generate Reading',
    'common.loading': 'Loading...',
  };

  static const Map<String, String> _fallbackTr = {
    'error.default': 'Bir hata olustu.',
    'error.name_required': 'Isim alani zorunlu.',
    'error.email_required': 'E-posta alani zorunlu.',
    'error.password_required': 'Sifre alani zorunlu.',
    'error.password_short': 'Sifre en az 6 karakter olmali.',
    'error.password_mismatch': 'Sifreler eslesmiyor.',
    'error.accept_terms': 'Devam etmek icin kosullari kabul etmelisin.',
    'error.profile_required': 'Lutfen zorunlu alanlari doldur.',
    'error.cards_required': 'En az bir kart secmelisin.',
    'toast.reset_sent': 'Sifre sifirlama e-postasi gonderildi.',
    'toast.restore_pending': 'Restore icin satin alma gecmisi baglanmali.',
    'auth.login.title': 'Giris Yap',
    'auth.login.button': 'Giris Yap',
    'auth.register.button': 'Kaderimi Olustur',
    'common.logout': 'Cikis',
    'common.restore': 'Restore',
    'common.select_language': 'Dil sec',
    'common.save_profile': 'Profili Kaydet',
    'common.generate': 'Fal Uret',
    'common.loading': 'Yukleniyor...',
  };

  Future<void> initialize() async {
    await _loadSupportedLanguages();
    await setLanguage(AppLocale.current, notifyLocale: false);
  }

  Future<void> setLanguage(String lang, {bool notifyLocale = true}) async {
    if (notifyLocale) {
      AppLocale.set(lang);
    }
    if (!_cache.containsKey(lang)) {
      await _loadLanguage(lang);
    }
    revision.value++;
  }

  String t(String key) {
    final lang = AppLocale.current;
    final active = _cache[lang];
    if (active != null && active.containsKey(key)) return active[key]!;

    if (lang != 'en') {
      final en = _cache['en'];
      if (en != null && en.containsKey(key)) return en[key]!;
    }

    return _fallbackFor(lang)[key] ?? _fallbackEn[key] ?? key;
  }

  String nextLanguage() {
    final langs = supportedLanguages.value;
    if (langs.isEmpty) return 'en';
    final currentIdx = langs.indexOf(AppLocale.current);
    if (currentIdx < 0) return langs.first;
    return langs[(currentIdx + 1) % langs.length];
  }

  Future<void> _loadSupportedLanguages() async {
    try {
      final raw = await rootBundle.loadString('assets/locales/index.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final list = data['supportedLanguages'];
      if (list is List) {
        final langs = list
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (langs.isNotEmpty) {
          supportedLanguages.value = langs;
          return;
        }
      }
    } catch (_) {}
    supportedLanguages.value = const ['tr', 'en'];
  }

  Future<void> _loadLanguage(String lang) async {
    try {
      final raw = await rootBundle.loadString('assets/locales/$lang.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _cache[lang] = map.map((k, v) => MapEntry(k.toString(), v.toString()));
      return;
    } catch (_) {
      try {
        final fallbackRaw =
            await rootBundle.loadString('assets/locales/en.json');
        final fallback = jsonDecode(fallbackRaw) as Map<String, dynamic>;
        _cache[lang] =
            fallback.map((k, v) => MapEntry(k.toString(), v.toString()));
        return;
      } catch (_) {}
    }
    _cache[lang] = Map<String, String>.from(_fallbackFor(lang));
  }

  Map<String, String> _fallbackFor(String lang) {
    if (lang == 'tr') return _fallbackTr;
    return _fallbackEn;
  }
}
