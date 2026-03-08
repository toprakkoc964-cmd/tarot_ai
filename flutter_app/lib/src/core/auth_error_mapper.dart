import 'package:firebase_auth/firebase_auth.dart';

import 'app_texts.dart';

String mapAuthError(Object error) {
  if (error is! FirebaseAuthException) {
    return AppTexts.t('error.default');
  }

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
    default:
      return error.message ?? AppTexts.t('error.default');
  }
}
