import 'package:url_launcher/url_launcher.dart';

import 'app_locale.dart';

class AppLegalUrls {
  const AppLegalUrls._();

  static const _terms = <String, String>{
    'default': 'https://tarotai.app/terms',
    'tr': 'https://tarotai.app/tr/terms',
    'en': 'https://tarotai.app/en/terms',
    'de': 'https://tarotai.app/de/terms',
  };

  static const _privacy = <String, String>{
    'default': 'https://tarotai.app/privacy',
    'tr': 'https://tarotai.app/tr/privacy',
    'en': 'https://tarotai.app/en/privacy',
    'de': 'https://tarotai.app/de/privacy',
  };

  static const _aiNotice = <String, String>{
    'default': 'https://tarotai.app/ai-notice',
    'tr': 'https://tarotai.app/tr/ai-notice',
    'en': 'https://tarotai.app/en/ai-notice',
    'de': 'https://tarotai.app/de/ai-notice',
  };

  static String get terms => _forLanguage(_terms);
  static String get privacy => _forLanguage(_privacy);
  static String get aiNotice => _forLanguage(_aiNotice);

  static String _forLanguage(Map<String, String> urls) {
    return urls[AppLocale.current] ?? urls['default']!;
  }

  static Future<bool> launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
