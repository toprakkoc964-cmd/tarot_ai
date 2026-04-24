import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'app_locale.dart';
import 'app_texts.dart';
import 'tarot_functions_client.dart';

typedef DailyCommentFetcher = Future<String> Function({
  required String birthDate,
  required String day,
  required String lang,
});

class FrequencyService {
  FrequencyService({DailyCommentFetcher? fetcher}) : _fetcher = fetcher;

  static const String keyLastFetchDate = 'last_fetch_date';
  static const String keyUserBirthDate = 'user_birth_date';
  static const String keyCommentLang = 'birth_frequency_comment_lang';

  static final FrequencyService instance = FrequencyService();

  final DailyCommentFetcher? _fetcher;

  Future<String> getDailyComment({
    required String? userBirthDate,
    String? lang,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final resolvedLang = _resolveLang(lang);
    final cachedCommentKey = _commentCacheKey(resolvedLang);

    final normalizedBirthDate = userBirthDate?.trim();
    if (normalizedBirthDate != null && normalizedBirthDate.isNotEmpty) {
      await prefs.setString(keyUserBirthDate, normalizedBirthDate);
    }

    final lastFetchDate = prefs.getString(keyLastFetchDate);
    final lastFetchLang = (prefs.getString(keyCommentLang) ?? '').trim();
    final cachedComment = (prefs.getString(cachedCommentKey) ?? '').trim();

    if (lastFetchDate == today &&
        lastFetchLang == resolvedLang &&
        cachedComment.isNotEmpty) {
      return cachedComment;
    }

    final effectiveBirthDate = (prefs.getString(keyUserBirthDate) ?? '').trim();
    if (effectiveBirthDate.isEmpty) {
      if (cachedComment.isNotEmpty) return cachedComment;
      return AppTexts.t('home.birth_frequency.unavailable_missing_birth');
    }

    try {
      final comment = _compactComment(
        ((await (_fetcher ?? _defaultFetcher)(
          birthDate: effectiveBirthDate,
          day: today,
          lang: resolvedLang,
        ))
            .trim()),
      );

      if (comment.isEmpty) {
        throw StateError('empty_comment');
      }

      await prefs.setString(cachedCommentKey, comment);
      await prefs.setString(keyLastFetchDate, today);
      await prefs.setString(keyCommentLang, resolvedLang);
      return comment;
    } catch (error, stackTrace) {
      String debugError = '$error';
      if (error is FirebaseFunctionsException) {
        final code = error.code;
        final message = error.message ?? '';
        debugError =
            'FirebaseFunctionsException(code: $code, message: $message)';
      }
      debugPrint('[FrequencyService] getDailyComment error: $debugError');
      debugPrint('$stackTrace');
      if (cachedComment.isNotEmpty) return cachedComment;
      return AppTexts.t('home.birth_frequency.unavailable_retry');
    }
  }

  Future<String> _defaultFetcher({
    required String birthDate,
    required String day,
    required String lang,
  }) async {
    final client = TarotFunctionsClient();
    return client.generateBirthFrequencyComment(
      birthDate: birthDate,
      day: day,
      lang: lang,
    );
  }

  String _resolveLang(String? lang) {
    final candidate = (lang ?? AppLocale.current).trim().toLowerCase();
    return candidate == 'en' ? 'en' : 'tr';
  }

  String _commentCacheKey(String lang) => 'cached_comment_$lang';

  String _compactComment(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return '';
    final sentenceParts = normalized.split(RegExp(r'(?<=[.!?])\s+'));
    final shortened = sentenceParts.take(2).join(' ').trim();
    final candidate = shortened.isNotEmpty ? shortened : normalized;
    if (candidate.length <= 120) return candidate;
    return '${candidate.substring(0, 117).trimRight()}...';
  }
}
