import 'user_profile_contract.dart';

class OnboardingPayload {
  const OnboardingPayload({
    required this.name,
    required this.birthDate,
    required this.privacyAccepted,
    required this.termsAccepted,
    required this.aiProcessingAccepted,
    this.lang,
    this.selectedPersonaId,
    this.birthTime,
    this.birthCity,
    this.occupation,
    this.relationshipStatus,
    this.lifeSpace,
    this.interpretationTone,
    this.focusAreas,
  });

  final String name;
  final String birthDate;
  final bool privacyAccepted;
  final bool termsAccepted;
  final bool aiProcessingAccepted;
  final String? lang;
  final String? selectedPersonaId;
  final String? birthTime;
  final String? birthCity;
  final String? occupation;
  final String? relationshipStatus;
  final String? lifeSpace;
  final String? interpretationTone;
  final List<String>? focusAreas;

  Map<String, dynamic> toJson() => {
    'name': name,
    'birthDate': birthDate,
    'privacyAccepted': privacyAccepted,
    'termsAccepted': termsAccepted,
    'aiProcessingAccepted': aiProcessingAccepted,
    if (lang != null) 'lang': lang,
    if (selectedPersonaId != null) 'selectedPersonaId': selectedPersonaId,
    if (birthTime != null) 'birthTime': birthTime,
    if (birthCity != null) 'birthCity': birthCity,
    if (occupation != null) 'occupation': occupation,
    if (relationshipStatus != null) 'relationshipStatus': relationshipStatus,
    if (lifeSpace != null) 'lifeSpace': lifeSpace,
    if (interpretationTone != null) 'interpretationTone': interpretationTone,
    if (focusAreas != null) 'focusAreas': focusAreas,
  };

  Map<String, dynamic> toUserDocumentMap({
    required String uid,
    required String email,
    required bool isProfileComplete,
    bool includeCreatedAt = false,
  }) {
    return UserProfileWrite(
      uid: uid,
      email: email,
      name: name,
      birthDate: birthDate,
      birthTime: birthTime,
      relationshipStatus: relationshipStatus,
      lifeSpace: lifeSpace,
      interpretationTone: interpretationTone,
      focusAreas: focusAreas,
      isProfileComplete: isProfileComplete,
      onboardingCompleted: isProfileComplete,
      accountStatus: isProfileComplete
          ? UserProfileContract.statusActive
          : UserProfileContract.statusPendingOnboarding,
      cleanupEligible: false,
      includeCreatedAt: includeCreatedAt,
    ).toMap();
  }
}
