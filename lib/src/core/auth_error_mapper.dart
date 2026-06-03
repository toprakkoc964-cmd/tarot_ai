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

  return AppTexts.t('auth.login.generic_error');
}

String mapRegisterError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return AppTexts.t('auth.register.email_in_use');
      case 'invalid-email':
        return AppTexts.t('auth.register.invalid_email');
      case 'weak-password':
        return AppTexts.t('auth.register.weak_password');
      case 'network-request-failed':
        return AppTexts.t('auth.register.network_error');
      case 'too-many-requests':
        return AppTexts.t('auth.register.too_many_requests');
      case 'operation-not-allowed':
        return AppTexts.t('auth.register.operation_not_allowed');
      case 'social-auth-cancelled':
        return AppTexts.t('error.social_cancelled');
      case 'apple-signin-not-supported':
        return AppTexts.t('error.apple_not_supported');
      case 'google-sign-in-config':
      case 'google-id-token-missing':
        return AppTexts.t('error.google_sign_in_config');
      default:
        return AppTexts.t('auth.register.generic_error');
    }
  }

  if (error is PlatformException) {
    final code = error.code.toLowerCase();
    final message = (error.message ?? '').toLowerCase();
    if (code.contains('network') || message.contains('network')) {
      return AppTexts.t('auth.register.network_error');
    }
  }

  return AppTexts.t('auth.register.generic_error');
}

String _mapFirebaseAuthError(FirebaseAuthException error) {
  switch (error.code) {
    case 'invalid-email':
      return AppTexts.t('auth.login.invalid_email');
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return AppTexts.t('auth.login.invalid_credentials');
    case 'email-already-in-use':
      return AppTexts.t('error.email_in_use');
    case 'weak-password':
      return AppTexts.t('auth.login.password_too_short');
    case 'network-request-failed':
      return AppTexts.t('auth.login.network_error');
    case 'too-many-requests':
      return AppTexts.t('auth.login.too_many_requests');
    case 'user-disabled':
      return AppTexts.t('auth.login.user_disabled');
    case 'social-auth-cancelled':
      return AppTexts.t('error.social_cancelled');
    case 'apple-signin-not-supported':
      return AppTexts.t('error.apple_not_supported');
    case 'google-sign-in-config':
    case 'google-id-token-missing':
      return AppTexts.t('error.google_sign_in_config');
    case 'google-sign-in-failed':
      return AppTexts.t('error.google_sign_in_failed');
    default:
      return AppTexts.t('auth.login.generic_error');
  }
}

String _mapPlatformError(PlatformException error) {
  final code = error.code.toLowerCase();
  final message = (error.message ?? '').toLowerCase();

  if (code.contains('network') || message.contains('network')) {
    return AppTexts.t('auth.login.network_error');
  }

  if (code == 'sign_in_failed' ||
      message.contains('apiexception: 10') ||
      message.contains('developer_error')) {
    return AppTexts.t('error.google_sign_in_config');
  }

  return AppTexts.t('auth.login.generic_error');
}
