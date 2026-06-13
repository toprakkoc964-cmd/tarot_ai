import 'dart:convert';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/google_auth_config.dart';
import 'user_profile_contract.dart';

class VerificationResendLimitException implements Exception {
  const VerificationResendLimitException(
    this.code, {
    this.remainingSeconds = 0,
  });

  final String code;
  final int remainingSeconds;
}

class AuthService {
  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? _createGoogleSignIn() {
    _hydratePostDeletionRedirect();
  }

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final ValueNotifier<bool> accountDeletionInProgress = ValueNotifier(false);
  final ValueNotifier<bool> socialProfileSyncInProgress = ValueNotifier(false);
  final ValueNotifier<bool> forceLoginAfterAccountDeletion = ValueNotifier(
    false,
  );
  final ValueNotifier<bool> registrationPortalActive = ValueNotifier(false);
  final ValueNotifier<bool> registrationRedirectSuppressed = ValueNotifier(
    false,
  );
  final ValueNotifier<String?> registrationCompletedOnboardingUid =
      ValueNotifier(null);

  static const int verificationTtlHours = 24;
  static const int verificationResendCooldownSeconds = 60;
  static const int verificationMaxResendPerWindow = 5;
  static const Duration verificationResendWindow = Duration(hours: 24);
  static const String _postDeletionRedirectKey =
      'auth.post_deletion_redirect_to_login';

  bool _disposed = false;

  static GoogleSignIn _createGoogleSignIn() {
    return GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId: GoogleAuthConfig.hasWebClientId
          ? GoogleAuthConfig.webClientId
          : null,
    );
  }

  Stream<User?> authChanges() => _auth.authStateChanges();

  Future<void> signInAnonymously() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      return;
    }
    await _auth.signInAnonymously();
  }

  Future<UserCredential> linkWithCredential(AuthCredential credential) async {
    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.isAnonymous) {
      try {
        return await currentUser.linkWithCredential(credential);
      } on FirebaseAuthException catch (error) {
        if (error.code == 'credential-already-in-use' ||
            error.code == 'email-already-in-use' ||
            error.code == 'provider-already-linked') {
          return _auth.signInWithCredential(credential);
        }
        rethrow;
      }
    }
    return _auth.signInWithCredential(credential);
  }

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.sendEmailVerification();
    return credential;
  }

  void dispose() {
    _disposed = true;
    accountDeletionInProgress.dispose();
    socialProfileSyncInProgress.dispose();
    forceLoginAfterAccountDeletion.dispose();
    registrationPortalActive.dispose();
    registrationRedirectSuppressed.dispose();
    registrationCompletedOnboardingUid.dispose();
  }

  Future<void> sendResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    registrationCompletedOnboardingUid.value = null;
    registrationRedirectSuppressed.value = false;
    registrationPortalActive.value = false;
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  Future<void> markPostDeletionRedirectPending() async {
    if (!_disposed) {
      forceLoginAfterAccountDeletion.value = true;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_postDeletionRedirectKey, true);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Post deletion redirect marker could not be saved: $error');
      }
    }
  }

  Future<void> clearPostDeletionRedirect() async {
    if (!_disposed) {
      forceLoginAfterAccountDeletion.value = false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_postDeletionRedirectKey);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Post deletion redirect marker could not be cleared: $error',
        );
      }
    }
  }

  Future<void> _hydratePostDeletionRedirect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shouldForceLogin = prefs.getBool(_postDeletionRedirectKey) ?? false;
      if (!_disposed && shouldForceLogin) {
        forceLoginAfterAccountDeletion.value = true;
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Post deletion redirect marker could not be read: $error');
      }
    }
  }

  Future<void> signInWithGoogle() async {
    socialProfileSyncInProgress.value = true;
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
      final normalizedName = UserProfileContract.normalizeName(
        user?.displayName ?? '',
      );
      if (user != null &&
          normalizedName.isNotEmpty &&
          normalizedName != (user.displayName ?? '').trim()) {
        await user.updateDisplayName(normalizedName);
      }
      if (user != null) {
        await upsertSocialUserProfile(
          user: user,
          providerId: 'google.com',
          displayNameSource: normalizedName.isNotEmpty ? 'google' : null,
          emailSource: (user.email ?? '').trim().isNotEmpty ? 'google' : null,
          photoUrlSource: (user.photoURL ?? '').trim().isNotEmpty
              ? 'google'
              : null,
        );
      }
    } on FirebaseAuthException {
      rethrow;
    } on PlatformException catch (e) {
      throw _mapGooglePlatformException(e);
    } finally {
      socialProfileSyncInProgress.value = false;
    }
  }

  Future<void> linkOrSignInWithGoogle() async {
    socialProfileSyncInProgress.value = true;
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
      final result = await linkWithCredential(credential);
      final user = result.user;
      final normalizedName = UserProfileContract.normalizeName(
        user?.displayName ?? '',
      );
      if (user != null &&
          normalizedName.isNotEmpty &&
          normalizedName != (user.displayName ?? '').trim()) {
        await user.updateDisplayName(normalizedName);
      }
      if (user != null) {
        await upsertSocialUserProfile(
          user: user,
          providerId: 'google.com',
          displayNameSource: normalizedName.isNotEmpty ? 'google' : null,
          emailSource: (user.email ?? '').trim().isNotEmpty ? 'google' : null,
          photoUrlSource: (user.photoURL ?? '').trim().isNotEmpty
              ? 'google'
              : null,
        );
      }
    } on FirebaseAuthException {
      rethrow;
    } on PlatformException catch (e) {
      throw _mapGooglePlatformException(e);
    } finally {
      socialProfileSyncInProgress.value = false;
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
    socialProfileSyncInProgress.value = true;
    try {
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        throw FirebaseAuthException(
          code: 'apple-signin-not-supported',
          message: 'Apple Sign-In is not available on this device.',
        );
      }

      // Firebase requires Apple idToken + rawNonce, and accepts the
      // authorization code as the Apple access token for this sign-in.
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      debugPrint(
        '🍎 APPLE_CREDENTIAL idToken=${appleCredential.identityToken != null} '
        'authCode=${appleCredential.authorizationCode.isNotEmpty} '
        'nonceLen=${rawNonce.length}',
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'apple-id-token-missing',
          message: 'Apple identity token is missing.',
        );
      }

      final oauth = OAuthProvider('apple.com').credential(
        idToken: idToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      UserCredential result;
      try {
        result = await _auth.signInWithCredential(oauth);
      } on FirebaseAuthException catch (e) {
        debugPrint('🍎 APPLE_SIGNIN_FAILED code=${e.code} msg=${e.message}');
        rethrow;
      } catch (e) {
        debugPrint('🍎 APPLE_SIGNIN_FAILED_OTHER: $e');
        rethrow;
      }
      final user = result.user;
      debugPrint(
        '🍎 APPLE_SIGNIN_OK uid=${user?.uid} '
        'isNew=${result.additionalUserInfo?.isNewUser}',
      );
      if (user != null) {
        await _registerAppleAuthorization(appleCredential.authorizationCode);
        final appleName = UserProfileContract.normalizeName(
          [
            appleCredential.givenName,
            appleCredential.familyName,
          ].whereType<String>().map((part) => part.trim()).join(' '),
        );
        if (kDebugMode) {
          debugPrint(
            'Apple Sign-In full name received: ${appleName.isNotEmpty}',
          );
        }
        if (appleName.isNotEmpty && (user.displayName ?? '').trim().isEmpty) {
          await user.updateDisplayName(appleName);
          await user.reload();
        }
        await upsertSocialUserProfile(
          user: _auth.currentUser ?? user,
          providerId: 'apple.com',
          fallbackName: appleName,
          forcePendingOnboarding: result.additionalUserInfo?.isNewUser == true,
          displayNameSource: appleName.isNotEmpty
              ? 'apple_first_authorization'
              : null,
          emailSource:
              ((_auth.currentUser ?? user).email ?? '').trim().isNotEmpty
              ? 'apple'
              : null,
          appleFullNameCaptured: appleName.isNotEmpty,
        );
      }
    } finally {
      socialProfileSyncInProgress.value = false;
    }
  }

  Future<void> linkOrSignInWithApple() async {
    socialProfileSyncInProgress.value = true;
    try {
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        throw FirebaseAuthException(
          code: 'apple-signin-not-supported',
          message: 'Apple Sign-In is not available on this device.',
        );
      }

      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final idToken = appleCredential.identityToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'apple-id-token-missing',
          message: 'Apple identity token is missing.',
        );
      }

      final oauth = OAuthProvider('apple.com').credential(
        idToken: idToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );
      final result = await linkWithCredential(oauth);
      final user = result.user;
      if (user != null) {
        await _registerAppleAuthorization(appleCredential.authorizationCode);
        final appleName = UserProfileContract.normalizeName(
          [
            appleCredential.givenName,
            appleCredential.familyName,
          ].whereType<String>().map((part) => part.trim()).join(' '),
        );
        if (appleName.isNotEmpty && (user.displayName ?? '').trim().isEmpty) {
          await user.updateDisplayName(appleName);
          await user.reload();
        }
        await upsertSocialUserProfile(
          user: _auth.currentUser ?? user,
          providerId: 'apple.com',
          fallbackName: appleName,
          forcePendingOnboarding: false,
          displayNameSource: appleName.isNotEmpty
              ? 'apple_first_authorization'
              : null,
          emailSource:
              ((_auth.currentUser ?? user).email ?? '').trim().isNotEmpty
              ? 'apple'
              : null,
          appleFullNameCaptured: appleName.isNotEmpty,
        );
      }
    } finally {
      socialProfileSyncInProgress.value = false;
    }
  }

  Future<void> _registerAppleAuthorization(String authorizationCode) async {
    final normalizedCode = authorizationCode.trim();
    if (normalizedCode.isEmpty) return;

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('registerAppleAuthorization');
      await callable.call(<String, dynamic>{
        'authorizationCode': normalizedCode,
      });
      if (kDebugMode) {
        debugPrint('Apple auth register succeeded');
      }
    } catch (error) {
      if (kDebugMode) {
        if (error is FirebaseFunctionsException) {
          debugPrint(
            'Apple auth register failed code=${error.code} '
            'msg=${error.message} details=${error.details}',
          );
        } else {
          debugPrint('Apple authorization register skipped: $error');
        }
      }
      // Do not block sign-in. If this best-effort registration fails, the
      // existing onboarding name fallback still keeps the account usable.
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = math.Random.secure();
    return List<String>.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  bool requiresEmailVerification(User user) {
    final providerIds = user.providerData
        .map((provider) => provider.providerId)
        .toSet();
    final hasSocialProvider =
        providerIds.contains('google.com') || providerIds.contains('apple.com');
    final hasPasswordProvider = providerIds.contains('password');
    return hasPasswordProvider && !hasSocialProvider && !user.emailVerified;
  }

  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified == true;
  }

  Future<void> markCurrentUserEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection(UserProfileContract.usersCollection)
        .doc(user.uid)
        .set({
          UserProfileContract.emailVerified: true,
          UserProfileContract.emailVerifiedAt: FieldValue.serverTimestamp(),
          UserProfileContract.accountStatus:
              UserProfileContract.statusPendingOnboarding,
          UserProfileContract.cleanupEligible: false,
          UserProfileContract.updatedAt: FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> deleteCurrentUserCompletely() async {
    final callable = FirebaseFunctions.instanceFor(
      region: 'us-central1',
    ).httpsCallable('deleteCurrentUserCompletely');
    final response = await callable.call(<String, dynamic>{'confirm': true});
    if (kDebugMode) {
      debugPrint('Account deletion completed: ${response.data}');
    }
  }

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'missing-user');
    }
    final userRef = FirebaseFirestore.instance
        .collection(UserProfileContract.usersCollection)
        .doc(user.uid);
    final now = DateTime.now();

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final data = snap.data() ?? const <String, dynamic>{};
      final lastSent = _timestampToDate(
        data[UserProfileContract.lastVerificationResendAt] ??
            data[UserProfileContract.verificationEmailSentAt],
      );
      if (lastSent != null) {
        final elapsed = now.difference(lastSent).inSeconds;
        if (elapsed < verificationResendCooldownSeconds) {
          throw VerificationResendLimitException(
            'cooldown',
            remainingSeconds: verificationResendCooldownSeconds - elapsed,
          );
        }
      }

      final windowStartedAt = _timestampToDate(
        data[UserProfileContract.verificationResendWindowStartedAt],
      );
      final isSameWindow =
          windowStartedAt != null &&
          now.difference(windowStartedAt) < verificationResendWindow;
      final currentCount = isSameWindow
          ? (data[UserProfileContract.verificationResendCount] as num?)
                    ?.toInt() ??
                0
          : 0;
      if (currentCount >= verificationMaxResendPerWindow) {
        throw const VerificationResendLimitException('daily-limit');
      }

      tx.set(userRef, {
        UserProfileContract.verificationResendWindowStartedAt: isSameWindow
            ? data[UserProfileContract.verificationResendWindowStartedAt]
            : FieldValue.serverTimestamp(),
        UserProfileContract.verificationResendCount: currentCount + 1,
        UserProfileContract.lastVerificationResendAt:
            FieldValue.serverTimestamp(),
        UserProfileContract.updatedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    await user.sendEmailVerification();
  }

  Future<void> upsertSocialUserProfile({
    required User user,
    required String providerId,
    String fallbackName = '',
    String? displayNameSource,
    String? emailSource,
    String? photoUrlSource,
    bool forcePendingOnboarding = false,
    bool appleFullNameCaptured = false,
  }) async {
    final userDocRef = FirebaseFirestore.instance
        .collection(UserProfileContract.usersCollection)
        .doc(user.uid);
    final existing = await userDocRef.get();
    final existingData = existing.data() ?? const <String, dynamic>{};
    final existingComplete =
        existingData[UserProfileContract.isProfileComplete] == true ||
        existingData[UserProfileContract.onboardingCompleted] == true;
    final existingBirthDate =
        (existingData[UserProfileContract.birthDate] as String?)?.trim() ?? '';
    final existingDisplayName = UserProfileContract.normalizeName(
      (existingData[UserProfileContract.displayName] as String?) ?? '',
    );
    final existingName = UserProfileContract.normalizeName(
      (existingData[UserProfileContract.name] as String?) ?? '',
    );
    final existingResolvedName = existingDisplayName.isNotEmpty
        ? existingDisplayName
        : existingName;
    final incomingName = UserProfileContract.normalizeName(
      fallbackName.isNotEmpty ? fallbackName : user.displayName ?? '',
    );
    final resolvedName = UserProfileContract.normalizeName(
      existingResolvedName.isNotEmpty ? existingResolvedName : incomingName,
    );
    final hasRequiredName = resolvedName.isNotEmpty;
    final hasRequiredBirthDate = existingBirthDate.isNotEmpty;
    final canKeepProfileComplete =
        !forcePendingOnboarding &&
        existingComplete &&
        hasRequiredName &&
        hasRequiredBirthDate;
    final incomingEmail = (user.email ?? '').trim();
    final incomingPhotoUrl = (user.photoURL ?? '').trim();
    final shouldWriteIncomingName =
        incomingName.isNotEmpty && existingResolvedName.isEmpty;
    final shouldWriteProfileSource =
        displayNameSource != null && shouldWriteIncomingName ||
        emailSource != null && incomingEmail.isNotEmpty ||
        photoUrlSource != null && incomingPhotoUrl.isNotEmpty;
    final providerIds =
        user.providerData
            .map((provider) => provider.providerId)
            .where((id) => id.isNotEmpty)
            .toSet()
          ..add(providerId);

    await userDocRef.set({
      UserProfileContract.uid: user.uid,
      if (incomingEmail.isNotEmpty) UserProfileContract.email: incomingEmail,
      if (resolvedName.isNotEmpty) UserProfileContract.name: resolvedName,
      if (resolvedName.isNotEmpty)
        UserProfileContract.displayName: resolvedName,
      if (shouldWriteProfileSource)
        UserProfileContract.profileSource: <String, dynamic>{
          if (displayNameSource != null && shouldWriteIncomingName)
            UserProfileContract.displayName: displayNameSource,
          if (emailSource != null && incomingEmail.isNotEmpty)
            UserProfileContract.email: emailSource,
          if (photoUrlSource != null && incomingPhotoUrl.isNotEmpty)
            UserProfileContract.photoUrl: photoUrlSource,
        },
      if (appleFullNameCaptured && shouldWriteIncomingName)
        UserProfileContract.appleFullNameCapturedAt:
            FieldValue.serverTimestamp(),
      if (incomingPhotoUrl.isNotEmpty)
        UserProfileContract.photoUrl: incomingPhotoUrl,
      UserProfileContract.provider: providerId,
      UserProfileContract.providers: providerIds.toList(growable: false),
      UserProfileContract.emailVerified: true,
      UserProfileContract.providerVerified: true,
      UserProfileContract.cleanupEligible: false,
      UserProfileContract.accountStatus: canKeepProfileComplete
          ? UserProfileContract.statusActive
          : UserProfileContract.statusPendingOnboarding,
      UserProfileContract.onboardingCompleted: canKeepProfileComplete,
      UserProfileContract.isProfileComplete: canKeepProfileComplete,
      if (!existing.exists)
        UserProfileContract.createdAt: FieldValue.serverTimestamp(),
      UserProfileContract.updatedAt: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  DateTime? _timestampToDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
