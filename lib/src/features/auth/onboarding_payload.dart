class OnboardingPayload {
  const OnboardingPayload({
    required this.name,
    required this.birthDate,
    required this.occupation,
    required this.privacyAccepted,
    required this.termsAccepted,
    required this.aiProcessingAccepted,
    this.lang,
    this.selectedPersonaId,
    this.birthTime,
    this.birthCity,
  });

  final String name;
  final String birthDate;
  final String occupation;
  final bool privacyAccepted;
  final bool termsAccepted;
  final bool aiProcessingAccepted;
  final String? lang;
  final String? selectedPersonaId;
  final String? birthTime;
  final String? birthCity;

  Map<String, dynamic> toJson() => {
        'name': name,
        'birthDate': birthDate,
        'occupation': occupation,
        'privacyAccepted': privacyAccepted,
        'termsAccepted': termsAccepted,
        'aiProcessingAccepted': aiProcessingAccepted,
        if (lang != null) 'lang': lang,
        if (selectedPersonaId != null) 'selectedPersonaId': selectedPersonaId,
        if (birthTime != null) 'birthTime': birthTime,
        if (birthCity != null) 'birthCity': birthCity,
      };
}
