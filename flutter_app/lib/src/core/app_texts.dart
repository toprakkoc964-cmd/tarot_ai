import 'localization_service.dart';

class AppTexts {
  static String t(String key) => LocalizationService.instance.t(key);
}
