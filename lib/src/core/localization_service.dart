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
    'error.social_cancelled': 'Sign in was cancelled.',
    'error.apple_not_supported':
        'Apple Sign-In is not supported on this device.',
    'toast.reset_sent': 'Password reset email has been sent.',
    'toast.restore_pending': 'Connect purchase history for restore.',
    'auth.login.title': 'Login',
    'auth.login.button': 'Login',
    'auth.login.social_title': 'OR CONTINUE WITH',
    'auth.login.apple_button': 'Apple',
    'auth.login.google_button': 'Google',
    'auth.register.button': 'Create My Destiny',
    'legal.terms.title': 'Terms of Service',
    'legal.privacy.title': 'Privacy Policy',
    'legal.last_updated': 'Last updated: March 10, 2026',
    'legal.view_terms': 'View Terms of Service',
    'legal.view_privacy': 'View Privacy Policy',
    'onboarding.hero_title': 'COSMIC\nPROFILE',
    'onboarding.hero_subtitle':
        'These details are collected once so the cards can know you better.',
    'onboarding.name_label_upper': 'NAME',
    'onboarding.name_hint': 'Your name in the language of the stars...',
    'onboarding.birth_section_title': 'BIRTH DATE & TIME',
    'onboarding.birth_date_placeholder': '12 Mar 1994',
    'onboarding.birth_time_placeholder': '14:45',
    'onboarding.dial_caption': 'Turn the dial to set your birth moment',
    'onboarding.cta_continue': 'CONTINUE',
    'onboarding.footer': 'Your data is as safe as the stars.',
    'onboarding.step': 'Step',
    'onboarding.step1.title': 'Core Details',
    'onboarding.step1.subtitle': 'Tell us about your base profile.',
    'onboarding.step2.title': 'Cosmic Preferences',
    'onboarding.step2.subtitle': 'Add optional birth and language details.',
    'onboarding.step3.title': 'Consent & Confirm',
    'onboarding.step3.subtitle': 'Accept policies and save your profile.',
    'onboarding.step3.subtitle_new':
        'Select the key areas where you want guidance and sharpen your destiny map.',
    'onboarding.step3.area.love': 'LOVE',
    'onboarding.step3.area.career': 'CAREER',
    'onboarding.step3.area.money': 'MONEY',
    'onboarding.step3.area.spiritual': 'SPIRITUAL GROWTH',
    'onboarding.step3.area.family': 'FAMILY',
    'onboarding.step3.area.general': 'GENERAL',
    'onboarding.step3.complete_profile': 'COMPLETE PROFILE',
    'onboarding.step3.footer': 'YOUR DATA IS PROTECTED WITH COSMIC ENCRYPTION.',
    'home.top.token_unit': 'TOKENS',
    'home.daily_draw.available': 'You have 1 free card draw today',
    'home.daily_draw.used': 'Your daily card draw is used',
    'home.daily_draw.paid_available': 'Each card draw costs 5 tokens',
    'home.daily_draw.insufficient': 'You need 5 tokens to draw a card',
    'home.daily_guide_label': 'DAILY GUIDE',
    'home.cta.draw_now': 'DRAW NOW (FREE)',
    'home.cta.drawing': 'DRAWING...',
    'home.cta.draw_locked': 'COME BACK TOMORROW',
    'home.cta.draw_with_credits': 'DRAW WITH 5 TOKENS',
    'home.cta.insufficient_credits': 'NEED 5 TOKENS',
    'home.cta.insufficient_credits_message':
        'You need at least 5 tokens to draw a card.',
    'home.card.star.title': 'Star Card',
    'home.card.star.name': 'The Star',
    'home.card.star.subtitle': 'Hope & Inspiration',
    'home.card.sun.title': 'Sun Card',
    'home.card.sun.name': 'The Sun',
    'home.card.sun.subtitle': 'Joy & Clarity',
    'home.card.moon.title': 'Moon Card',
    'home.card.moon.name': 'The Moon',
    'home.card.moon.subtitle': 'Intuition & Depth',
    'home.card.world.title': 'World Card',
    'home.card.world.name': 'The World',
    'home.card.world.subtitle': 'Completion & Flow',
    'home.birth_frequency.title': 'YOUR BIRTH FREQUENCY',
    'home.birth_frequency.sign': 'Aquarius',
    'home.birth_frequency.reading.lead':
        'You are strong in communication today. ',
    'home.birth_frequency.reading.body':
        'Mental clarity opens space for you, trust your intuition.',
    'home.birth_frequency.loading_comment':
        'Your daily insight is being prepared...',
    'home.birth_frequency.unavailable_retry':
        "Today's insight is unavailable right now. Please try again.",
    'home.birth_frequency.unavailable_missing_birth':
        'A daily insight could not be created because your birth date is missing.',
    'home.tab.ritual': 'Ritual',
    'home.tab.archive': 'Archive',
    'home.tab.credit': 'Credit',
    'home.tab.profile': 'Profile',
    'home.profile.title': 'Cosmic Profile',
    'home.notifications.title': 'Notifications',
    'home.notifications.empty': 'You have no notifications yet.',
    'home.archive.title': 'Cosmic Archive',
    'home.archive.tab.cards': 'Cards',
    'home.archive.tab.chats': 'Chats',
    'home.archive.card1.date': '14 MAY, 22:15',
    'home.archive.card1.title': 'Moon Cycle Prophecy',
    'home.archive.card1.description':
        'Mysterious messages whispered to your soul by changes in the sky.',
    'home.archive.card1.action': 'Illuminate the Moment',
    'home.archive.card2.date': '12 MAY, 03:42',
    'home.archive.card2.title': 'Future Reflections',
    'home.archive.card2.description':
        'Unlock new possibilities in your star map.',
    'home.archive.card2.action': 'Unlock with Ad',
    'home.archive.end_flow': 'Endless Flow',
    'home.credit.title': 'Cosmic Wallet',
    'home.credit.balance_label': 'Balance',
    'home.credit.balance_value': '120 Tokens',
    'home.credit.perks.title': 'Cosmic Perks',
    'home.credit.perk.voice.title': 'Voice Guidance',
    'home.credit.perk.voice.desc':
        'Do not only see the cards, feel the sage voice in your ears.',
    'home.credit.perk.personalized.title': 'Personalized',
    'home.credit.perk.personalized.desc':
        'A deep frequency tailored to your birth chart.',
    'home.credit.perk.clarity.title': 'Mental Clarity',
    'home.credit.perk.clarity.desc':
        'Remove limits and illuminate with deeper questions.',
    'home.credit.package.50.coins': '50 Tokens',
    'home.credit.package.50.title': 'Star Pack',
    'home.credit.package.50.price': '₺49.99',
    'home.credit.package.50.feature1': '5 Voice Readings',
    'home.credit.package.50.feature2': '2 Deep Chats',
    'home.credit.package.50.feature3': 'Standard Analysis',
    'home.credit.package.250.coins': '250 Tokens',
    'home.credit.package.250.title': 'Cosmic Choice',
    'home.credit.package.250.badge': 'Cosmic Choice',
    'home.credit.package.250.price': '₺199.99',
    'home.credit.package.250.feature1': '25 Voice Readings',
    'home.credit.package.250.feature2': '10 Video Sessions',
    'home.credit.package.250.feature3': '20 Deep Chats',
    'home.credit.package.1000.coins': '1000 Tokens',
    'home.credit.package.1000.title': 'Sun Pack',
    'home.credit.package.1000.price': '₺699.99',
    'home.credit.package.1000.feature1': 'Unlimited Voice Readings',
    'home.credit.package.1000.feature2': 'Unlimited Video Sessions',
    'home.credit.package.1000.feature3': 'VIP Priority',
    'home.credit.cta.recharge': 'Recharge Energy',
    'home.credit.restore': 'Restore Purchases',
    'home.credit.terms': 'Terms of Use',
    'home.credit.privacy': 'Privacy Policy',
    'home.credit.legal_disclaimer':
        'Legal Notice: This application is for entertainment and personal exploration only. AI-generated interpretations are not definitive and do not replace professional advice (medical, legal, financial, etc.). Accuracy or realization of content is not guaranteed. Results may vary from person to person. Please evaluate this information with common sense.',
    'common.logout': 'Logout',
    'common.restore': 'Restore',
    'common.select_language': 'Select language',
    'common.back': 'Back',
    'common.next': 'Next',
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
    'error.social_cancelled': 'Giris islemi iptal edildi.',
    'error.apple_not_supported': 'Bu cihazda Apple girisi desteklenmiyor.',
    'toast.reset_sent': 'Sifre sifirlama e-postasi gonderildi.',
    'toast.restore_pending': 'Restore icin satin alma gecmisi baglanmali.',
    'auth.login.title': 'Giris Yap',
    'auth.login.button': 'Giris Yap',
    'auth.login.social_title': 'VEYA SUNUNLA DEVAM ET',
    'auth.login.apple_button': 'Apple',
    'auth.login.google_button': 'Google',
    'auth.register.button': 'Kaderimi Olustur',
    'legal.terms.title': 'Kullanim Kosullari',
    'legal.privacy.title': 'Gizlilik Politikasi',
    'legal.last_updated': 'Son guncelleme: 10 Mart 2026',
    'legal.view_terms': 'Kullanim Kosullarini Gor',
    'legal.view_privacy': 'Gizlilik Politikasini Gor',
    'onboarding.hero_title': 'KOZMIK\nPROFIL',
    'onboarding.hero_subtitle':
        'Bu bilgiler yalnizca bir kez alinir. Kartlar seni daha iyi tanisin.',
    'onboarding.name_label_upper': 'ADIN',
    'onboarding.name_hint': 'Goklerin diliyle ismin...',
    'onboarding.birth_section_title': 'DOGUM TARIHI & SAATI',
    'onboarding.birth_date_placeholder': '12 Mart 1994',
    'onboarding.birth_time_placeholder': '14:45',
    'onboarding.dial_caption': 'Kadrani cevirerek dogum anini secin',
    'onboarding.cta_continue': 'DEVAM ET',
    'onboarding.footer': 'Verilerin yildizlar kadar guvende.',
    'onboarding.step': 'Adim',
    'onboarding.step1.title': 'Temel Bilgiler',
    'onboarding.step1.subtitle':
        'Profilini olusturmak icin zorunlu alanlari doldur.',
    'onboarding.step2.title': 'Kisisel Tercihler',
    'onboarding.step2.subtitle': 'Dogum ve dil tercihlerini ekleyebilirsin.',
    'onboarding.step3.title': 'Onay ve Kayit',
    'onboarding.step3.subtitle': 'Onay kutularini isaretleyip profili kaydet.',
    'onboarding.step3.subtitle_new':
        'Rehberlik almak istedigin temel alanlari secerek kaderinin haritasini netlestir.',
    'onboarding.step3.area.love': 'ASK',
    'onboarding.step3.area.career': 'KARIYER',
    'onboarding.step3.area.money': 'PARA',
    'onboarding.step3.area.spiritual': 'RUHSAL GELISIM',
    'onboarding.step3.area.family': 'AILE',
    'onboarding.step3.area.general': 'GENEL',
    'onboarding.step3.complete_profile': 'PROFILI TAMAMLA',
    'onboarding.step3.footer': 'VERILERIN KOZMIK SIFRELEME ILE KORUNUR.',
    'home.top.token_unit': 'JETON',
    'home.daily_draw.available': 'Bugun 1 Kart Cekim Hakkin Var',
    'home.daily_draw.used': 'Gunluk kart hakkin kullanildi',
    'home.daily_draw.paid_available': 'Her kart cekimi 5 jeton',
    'home.daily_draw.insufficient': 'Kart cekmek icin 5 jeton gerekli',
    'home.daily_guide_label': 'GUNUN REHBERI',
    'home.cta.draw_now': 'HEMEN CEK (UCRETSIZ)',
    'home.cta.drawing': 'CEKILIYOR...',
    'home.cta.draw_locked': 'YARIN TEKRAR GEL',
    'home.cta.draw_with_credits': '5 JETONLA CEK',
    'home.cta.insufficient_credits': '5 JETON GEREKLI',
    'home.cta.insufficient_credits_message':
        'Kart cekmek icin en az 5 jeton gerekli.',
    'home.card.star.title': 'Yildiz Karti',
    'home.card.star.name': 'The Star',
    'home.card.star.subtitle': 'Umut & Ilham',
    'home.card.sun.title': 'Gunes Karti',
    'home.card.sun.name': 'The Sun',
    'home.card.sun.subtitle': 'Nese & Netlik',
    'home.card.moon.title': 'Ay Karti',
    'home.card.moon.name': 'The Moon',
    'home.card.moon.subtitle': 'Sezgi & Derinlik',
    'home.card.world.title': 'Dunya Karti',
    'home.card.world.name': 'The World',
    'home.card.world.subtitle': 'Tamamlanma & Akis',
    'home.birth_frequency.title': 'DOGUM FREKANSINI',
    'home.birth_frequency.sign': 'Kova Burcu',
    'home.birth_frequency.reading.lead': 'Bugun iletisimde guclusun. ',
    'home.birth_frequency.reading.body':
        'Zihinsel berraklik sana alan aciyor, sezgilerine guvenmekten cekinme.',
    'home.birth_frequency.loading_comment': 'Gunluk yorumun hazirlaniyor...',
    'home.birth_frequency.unavailable_retry':
        'Bugunluk yorum su an alinamiyor. Lutfen tekrar dene.',
    'home.birth_frequency.unavailable_missing_birth':
        'Dogum tarihin kayitli olmadigi icin bugunluk yorum olusturulamadi.',
    'home.tab.ritual': 'Rituel',
    'home.tab.archive': 'Arsiv',
    'home.tab.credit': 'Kredi',
    'home.tab.profile': 'Profil',
    'home.profile.title': 'Kozmik Profil',
    'home.notifications.title': 'Kozmik Bildirimler',
    'home.notifications.empty': 'Henuz bildirimin yok.',
    'home.archive.title': 'Kozmik Arsiv',
    'home.archive.tab.cards': 'Kartlar',
    'home.archive.tab.chats': 'Sohbetler',
    'home.archive.card1.date': '14 MAYIS, 22:15',
    'home.archive.card1.title': 'Ay Dongusu Kehaneti',
    'home.archive.card1.description':
        'Gokyuzundeki degisimlerin ruhuna fisildadigi gizemli mesajlar.',
    'home.archive.card1.action': 'Aniyi Aydinlat',
    'home.archive.card2.date': '12 MAYIS, 03:42',
    'home.archive.card2.title': 'Gelecek Yansimalari',
    'home.archive.card2.description':
        'Yildiz haritandaki yeni olasiliklarin kilidini ac.',
    'home.archive.card2.action': 'Reklamla Ac',
    'home.archive.end_flow': 'Sonsuz Akis',
    'home.credit.title': 'Kozmik Cuzdan',
    'home.credit.balance_label': 'Bakiyen',
    'home.credit.balance_value': '120 Jeton',
    'home.credit.perks.title': 'Kozmik Ayricaliklar',
    'home.credit.perk.voice.title': 'Sesli Rehberlik',
    'home.credit.perk.voice.desc':
        'Sadece kartlari gorme, bilge sesi kulaklarinda hisset.',
    'home.credit.perk.personalized.title': 'Kisisellestirilmis',
    'home.credit.perk.personalized.desc':
        'Dogum haritana ozel, sana ozgu derin frekans.',
    'home.credit.perk.clarity.title': 'Zihinsel Aciklik',
    'home.credit.perk.clarity.desc':
        'Sinirlari kaldir; derinlesen sorularla aydinlan.',
    'home.credit.package.50.coins': '50 Jeton',
    'home.credit.package.50.title': 'Yildiz Paketi',
    'home.credit.package.50.price': '₺49,99',
    'home.credit.package.50.feature1': '5 Sesli Yorum',
    'home.credit.package.50.feature2': '2 Derin Sohbet',
    'home.credit.package.50.feature3': 'Standart Analiz',
    'home.credit.package.250.coins': '250 Jeton',
    'home.credit.package.250.title': 'Kozmik Tercih',
    'home.credit.package.250.badge': 'Kozmik Tercih',
    'home.credit.package.250.price': '₺199,99',
    'home.credit.package.250.feature1': '25 Sesli Yorum',
    'home.credit.package.250.feature2': '10 Goruntulu Gorusme',
    'home.credit.package.250.feature3': '20 Derin Sohbet',
    'home.credit.package.1000.coins': '1000 Jeton',
    'home.credit.package.1000.title': 'Gunes Paketi',
    'home.credit.package.1000.price': '₺699,99',
    'home.credit.package.1000.feature1': 'Sinirsiz Sesli Yorum',
    'home.credit.package.1000.feature2': 'Sinirsiz Goruntulu',
    'home.credit.package.1000.feature3': 'VIP Oncelik',
    'home.credit.cta.recharge': 'Enerjiyi Yukle',
    'home.credit.restore': 'Satin Alimlari Geri Yukle',
    'home.credit.terms': 'Terms of Use',
    'home.credit.privacy': 'Privacy Policy',
    'home.credit.legal_disclaimer':
        'Yasal Uyari: Bu uygulama yalnizca eglence ve kisisel kesif amaclidir. AI tarafindan olusturulan yorumlar kesinlik tasimaz ve profesyonel tavsiye (tibbi, yasal, finansal vb.) yerine gecmez. Iceriklerin dogrulugu veya gerceklesecegi garanti edilmez. Sonuclar kisiden kisiye degisebilir. Lutfen bu bilgileri sagduyu ile degerlendirin.',
    'common.logout': 'Cikis',
    'common.restore': 'Restore',
    'common.select_language': 'Dil sec',
    'common.back': 'Geri',
    'common.next': 'Ileri',
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
