import 'package:flutter/foundation.dart';

class AppLocale {
  static final ValueNotifier<String> notifier = ValueNotifier<String>('tr');

  static String get current => notifier.value;

  static void set(String lang) {
    if (lang.trim().isEmpty) return;
    notifier.value = lang;
  }
}
