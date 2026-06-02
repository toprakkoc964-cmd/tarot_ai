import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/google_auth_config.dart';
import 'user_profile_contract.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? _createGoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final ValueNotifier<bool> accountDeletionInProgress = ValueNotifier(false);

  static GoogleSignIn _createGoogleSignIn() {
    return GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId:
          GoogleAuthConfig.hasWebClientId ? GoogleAuthConfig.webClientId : null,
    );
  }

  Stream<User?> authChanges() => _auth.authStateChanges();

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> sendResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Future<void> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'social-auth-cancelled',
          message: 'Google sign in cancelled.',
        );
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'google-id-token-missing',
          message:
              'Google ID token is missing. Add SHA-1 to Firebase, re-download google-services.json, and set GOOGLE_WEB_CLIENT_ID.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      final normalizedName =
          UserProfileContract.normalizeName(user?.displayName ?? '');
      if (user != null &&
          normalizedName.isNotEmpty &&
          normalizedName != (user.displayName ?? '').trim()) {
        await user.updateDisplayName(normalizedName);
      }
    } on FirebaseAuthException {
      rethrow;
    } on PlatformException catch (e) {
      throw _mapGooglePlatformException(e);
    }
  }

  FirebaseAuthException _mapGooglePlatformException(PlatformException error) {
    final code = error.code.toLowerCase();
    final message = (error.message ?? '').toLowerCase();

    if (code.contains('network') || message.contains('network')) {
      return FirebaseAuthException(
        code: 'network-request-failed',
        message: error.message,
      );
    }

    if (code == 'sign_in_failed' ||
        message.contains('apiexception: 10') ||
        message.contains('developer_error') ||
        message.contains('12500')) {
      return FirebaseAuthException(
        code: 'google-sign-in-config',
        message: error.message,
      );
    }

    return FirebaseAuthException(
      code: 'google-sign-in-failed',
      message: error.message ?? error.code,
    );
  }

  Future<void> signInWithApple() async {
    final isAvailable = await SignInWithApple.isAvailable();
    if (!isAvailable) {
      throw FirebaseAuthException(
        code: 'apple-signin-not-supported',
        message: 'Apple Sign-In is not available on this device.',
      );
    }

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName
      ],
    );

    final oauth = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    await _auth.signInWithCredential(oauth);
  }
}
