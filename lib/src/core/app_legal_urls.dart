import 'package:url_launcher/url_launcher.dart';

class AppLegalUrls {
  const AppLegalUrls._();

  static const String terms = 'https://tarot.liveblog365.com/terms/';
  static const String privacy = 'https://tarot.liveblog365.com/privacy/';
  static const String aiNotice = 'https://tarot.liveblog365.com/ai-notice/';

  static Future<bool> launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
