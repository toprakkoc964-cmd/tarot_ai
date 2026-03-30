import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import 'tarot_functions_client.dart';

typedef DailyCommentFetcher = Future<String> Function({
  required String birthDate,
  required String day,
});

class FrequencyService {
  FrequencyService({DailyCommentFetcher? fetcher}) : _fetcher = fetcher;

  static const String keyLastFetchDate = 'last_fetch_date';
  static const String keyCachedComment = 'cached_comment';
  static const String keyUserBirthDate = 'user_birth_date';

  static final FrequencyService instance = FrequencyService();

  final DailyCommentFetcher? _fetcher;

  Future<String> getDailyComment({required String? userBirthDate}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final normalizedBirthDate = userBirthDate?.trim();
    if (normalizedBirthDate != null && normalizedBirthDate.isNotEmpty) {
      await prefs.setString(keyUserBirthDate, normalizedBirthDate);
    }

    final lastFetchDate = prefs.getString(keyLastFetchDate);
    final cachedComment = (prefs.getString(keyCachedComment) ?? '').trim();

    if (lastFetchDate == today && cachedComment.isNotEmpty) {
      return cachedComment;
    }

    final effectiveBirthDate = (prefs.getString(keyUserBirthDate) ?? '').trim();
    if (effectiveBirthDate.isEmpty) {
      if (cachedComment.isNotEmpty) return cachedComment;
      return 'Dogum tarihin kayitli olmadigi icin bugunluk yorum olusturulamadi.';
    }

    try {
      final comment = ((await (_fetcher ?? _defaultFetcher)(
        birthDate: effectiveBirthDate,
        day: today,
      ))
          .trim());

      if (comment.isEmpty) {
        throw StateError('empty_comment');
      }

      await prefs.setString(keyCachedComment, comment);
      await prefs.setString(keyLastFetchDate, today);
      return comment;
    } catch (error, stackTrace) {
      debugPrint('[FrequencyService] getDailyComment error: $error');
      debugPrint('$stackTrace');
      if (cachedComment.isNotEmpty) return cachedComment;
      return 'Bugunluk yorum su an alinamiyor. Lutfen tekrar dene.';
    }
  }

  Future<String> _defaultFetcher({
    required String birthDate,
    required String day,
  }) async {
    final client = TarotFunctionsClient();
    return client.generateBirthFrequencyComment(
      birthDate: birthDate,
      day: day,
    );
  }
}
