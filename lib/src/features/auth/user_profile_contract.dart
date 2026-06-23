import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileContract {
  const UserProfileContract._();

  static const String usersCollection = 'users';
  static const String guestsCollection = 'guests';

  static const String statusPendingEmailVerification =
      'pending_email_verification';
  static const String statusPendingOnboarding = 'pending_onboarding';
  static const String statusActive = 'active';
  static const String statusDeleted = 'deleted';

  static const String uid = 'uid';
  static const String email = 'email';
  static const String name = 'name';
  static const String displayName = 'displayName';
  static const String photoUrl = 'photoUrl';
  static const String profileSource = 'profileSource';
  static const String appleFullNameCapturedAt = 'appleFullNameCapturedAt';
  static const String provider = 'provider';
  static const String providers = 'providers';
  static const String providerVerified = 'providerVerified';
  static const String emailVerified = 'emailVerified';
  static const String emailVerifiedAt = 'emailVerifiedAt';
  static const String isGuest = 'isGuest';

  static const String birthDate = 'birthDate';
  static const String birthTime = 'birthTime';

  static const String relationshipStatus = 'relationshipStatus';
  static const String lifeSpace = 'lifeSpace';
  static const String interpretationTone = 'interpretationTone';
  static const String focusAreas = 'focusAreas';
  static const String personalizationEnabled = 'personalizationEnabled';

  static const String isProfileComplete = 'isProfileComplete';
  static const String onboardingCompleted = 'onboardingCompleted';
  static const String accountStatus = 'accountStatus';
  static const String cleanupEligible = 'cleanupEligible';
  static const String verificationEmailSentAt = 'verificationEmailSentAt';
  static const String verificationDeadlineAt = 'verificationDeadlineAt';
  static const String verificationResendCount = 'verificationResendCount';
  static const String verificationResendWindowStartedAt =
      'verificationResendWindowStartedAt';
  static const String lastVerificationResendAt = 'lastVerificationResendAt';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String wallet = 'wallet';
  static const String walletCredits = 'credits';
  static const String walletFirstCoffeeFreeUsed = 'firstCoffeeFreeUsed';
  static const String walletFirstPalmFreeUsed = 'firstPalmFreeUsed';
  static const String walletLastFreeDrawAt = 'lastFreeDrawAt';
  static const String fcmTokens = 'fcmTokens';
  static const String fcmTokenUpdatedAt = 'fcmTokenUpdatedAt';
  static const String timezone = 'timezone';
  static const String timezoneUpdatedAt = 'timezoneUpdatedAt';
  static const String language = 'language';
  static const String notificationPrefs = 'notificationPrefs';
  static const String legalConsent = 'legalConsent';
  static const String lastSeenAt = 'lastSeenAt';

  static const String guestLinkedProvider = 'linkedProvider';
  static const String guestStatus = 'status';
  static const String guestOnboardingSnapshot = 'onboardingSnapshot';
  static const String guestLinkedAt = 'linkedAt';

  static const int maxNameLength = 25;

  static String normalizeName(String raw) {
    final compact = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.isEmpty) return '';
    if (compact.length <= maxNameLength) return compact;
    return compact.substring(0, maxNameLength).trimRight();
  }
}

class UserProfileWrite {
  const UserProfileWrite({
    required this.uid,
    required this.email,
    required this.name,
    this.birthDate,
    this.birthTime,
    this.relationshipStatus,
    this.lifeSpace,
    this.interpretationTone,
    this.focusAreas,
    this.personalizationEnabled = true,
    this.legalConsent,
    required this.isProfileComplete,
    this.onboardingCompleted,
    this.accountStatus,
    this.emailVerified,
    this.provider,
    this.providers,
    this.providerVerified,
    this.isGuest,
    this.photoUrl,
    this.cleanupEligible,
    this.verificationEmailSentAt,
    this.verificationDeadlineAt,
    this.verificationResendCount,
    this.verificationResendWindowStartedAt,
    this.lastVerificationResendAt,
    this.includeCreatedAt = false,
  });

  final String uid;
  final String email;
  final String name;
  final String? birthDate;
  final String? birthTime;
  final String? relationshipStatus;
  final String? lifeSpace;
  final String? interpretationTone;
  final List<String>? focusAreas;
  final bool personalizationEnabled;
  final UserLegalConsent? legalConsent;
  final bool isProfileComplete;
  final bool? onboardingCompleted;
  final String? accountStatus;
  final bool? emailVerified;
  final String? provider;
  final List<String>? providers;
  final bool? providerVerified;
  final bool? isGuest;
  final String? photoUrl;
  final bool? cleanupEligible;
  final Object? verificationEmailSentAt;
  final Object? verificationDeadlineAt;
  final int? verificationResendCount;
  final Object? verificationResendWindowStartedAt;
  final Object? lastVerificationResendAt;
  final bool includeCreatedAt;

  Map<String, dynamic> toMap() {
    final safeName = UserProfileContract.normalizeName(name);
    return <String, dynamic>{
      UserProfileContract.uid: uid,
      UserProfileContract.email: email,
      UserProfileContract.name: safeName,
      if (birthDate != null) UserProfileContract.birthDate: birthDate,
      if (birthTime != null) UserProfileContract.birthTime: birthTime,
      if (relationshipStatus != null)
        UserProfileContract.relationshipStatus: relationshipStatus,
      if (lifeSpace != null) UserProfileContract.lifeSpace: lifeSpace,
      if (interpretationTone != null)
        UserProfileContract.interpretationTone: interpretationTone,
      if (focusAreas != null) UserProfileContract.focusAreas: focusAreas,
      UserProfileContract.personalizationEnabled: personalizationEnabled,
      if (legalConsent != null)
        UserProfileContract.legalConsent: legalConsent!.toMap(),
      UserProfileContract.isProfileComplete: isProfileComplete,
      UserProfileContract.onboardingCompleted:
          onboardingCompleted ?? isProfileComplete,
      if (accountStatus != null)
        UserProfileContract.accountStatus: accountStatus,
      if (emailVerified != null)
        UserProfileContract.emailVerified: emailVerified,
      if (provider != null) UserProfileContract.provider: provider,
      if (providers != null) UserProfileContract.providers: providers,
      if (providerVerified != null)
        UserProfileContract.providerVerified: providerVerified,
      if (isGuest != null) UserProfileContract.isGuest: isGuest,
      if (photoUrl != null) UserProfileContract.photoUrl: photoUrl,
      if (cleanupEligible != null)
        UserProfileContract.cleanupEligible: cleanupEligible,
      if (verificationEmailSentAt != null)
        UserProfileContract.verificationEmailSentAt: verificationEmailSentAt,
      if (verificationDeadlineAt != null)
        UserProfileContract.verificationDeadlineAt: verificationDeadlineAt,
      if (verificationResendCount != null)
        UserProfileContract.verificationResendCount: verificationResendCount,
      if (verificationResendWindowStartedAt != null)
        UserProfileContract.verificationResendWindowStartedAt:
            verificationResendWindowStartedAt,
      if (lastVerificationResendAt != null)
        UserProfileContract.lastVerificationResendAt: lastVerificationResendAt,
      if (includeCreatedAt)
        UserProfileContract.createdAt: FieldValue.serverTimestamp(),
      UserProfileContract.updatedAt: FieldValue.serverTimestamp(),
    };
  }
}

class UserLegalConsent {
  const UserLegalConsent();

  static const String currentVersion = '2026-06-01';

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'termsAccepted': true,
      'privacyAccepted': true,
      'aiDisclaimerAccepted': true,
      'termsVersion': currentVersion,
      'privacyVersion': currentVersion,
      'aiDisclaimerVersion': currentVersion,
      'acceptedAt': FieldValue.serverTimestamp(),
    };
  }
}
