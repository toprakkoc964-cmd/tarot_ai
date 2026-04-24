import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NotificationTranslator {
  static Future<String> getTranslation(
      String langCode, String type, String field,
      {Map<String, String> args = const {}}) async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/translations/$langCode.json',
      );
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;

      if (jsonMap.containsKey(type) &&
          jsonMap[type] is Map<String, dynamic> &&
          (jsonMap[type] as Map<String, dynamic>).containsKey(field)) {
        var translated =
            (jsonMap[type] as Map<String, dynamic>)[field].toString();
        for (final entry in args.entries) {
          translated = translated.replaceAll('{{${entry.key}}}', entry.value);
        }
        return translated;
      }
      return '';
    } catch (e) {
      debugPrint('Translation file read error: $e');
      return 'Cosmic Message ✨';
    }
  }
}
