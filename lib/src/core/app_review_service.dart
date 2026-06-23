import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppReviewService {
  AppReviewService._();

  static final AppReviewService instance = AppReviewService._();

  static const String pendingAfterOnboardingKey =
      'app_review_pending_after_onboarding';
  static const String requestedAfterOnboardingKey =
      'app_review_requested_after_onboarding';
  static const MethodChannel _channel = MethodChannel('tarot_ai/app_review');

  Future<void> markPendingAfterOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(pendingAfterOnboardingKey, true);
  }

  Future<void> requestAfterOnboardingIfNeeded() async {
    if (!Platform.isIOS) return;
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(pendingAfterOnboardingKey) ?? false;
    final requested = prefs.getBool(requestedAfterOnboardingKey) ?? false;
    if (!pending || requested) return;

    await prefs.setBool(pendingAfterOnboardingKey, false);
    await prefs.setBool(requestedAfterOnboardingKey, true);
    try {
      await _channel.invokeMethod<bool>('requestReview');
    } catch (error) {
      if (kDebugMode) {
        debugPrint('app review request failed: $error');
      }
    }
  }
}
