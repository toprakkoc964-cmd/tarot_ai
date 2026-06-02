import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import 'app_texts.dart';

String mapAuthError(Object error) {
  if (error is FirebaseAuthException) {
    return _mapFirebaseAuthError(error);
  }

  if (error is PlatformException) {
    return _mapPlatformError(error);
  }

  return AppTexts.t('error.default');
}

String _mapFirebaseAuthError(FirebaseAuthException error) {
  switch (error.code) {
    case 'invalid-email':
      return AppTexts.t('error.email_required');
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return AppTexts.t('error.invalid_credentials');
    case 'email-already-in-use':
      return AppTexts.t('error.email_in_use');
    case 'weak-password':
      return AppTexts.t('error.password_short');
    case 'network-request-failed':
      return AppTexts.t('error.network');
    case 'social-auth-cancelled':
      return AppTexts.t('error.social_cancelled');
    case 'apple-signin-not-supported':
      return AppTexts.t('error.apple_not_supported');
    case 'google-sign-in-config':
    case 'google-id-token-missing':
      return AppTexts.t('error.google_sign_in_config');
    case 'google-sign-in-failed':
      return error.message ?? AppTexts.t('error.google_sign_in_failed');
    default:
      return error.message ?? AppTexts.t('error.default');
  }
}

String _mapPlatformError(PlatformException error) {
  final code = error.code.toLowerCase();
  final message = (error.message ?? '').toLowerCase();

  if (code.contains('network') || message.contains('network')) {
    return AppTexts.t('error.network');
  }

  if (code == 'sign_in_failed' ||
      message.contains('apiexception: 10') ||
      message.contains('developer_error')) {
    return AppTexts.t('error.google_sign_in_config');
  }

  return error.message ?? AppTexts.t('error.default');
}
