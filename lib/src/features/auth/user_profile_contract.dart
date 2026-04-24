import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileContract {
  const UserProfileContract._();

  static const String usersCollection = 'users';

  static const String uid = 'uid';
  static const String email = 'email';
  static const String name = 'name';

  static const String birthDate = 'birthDate';
  static const String birthTime = 'birthTime';

  static const String relationshipStatus = 'relationshipStatus';
  static const String lifeSpace = 'lifeSpace';
  static const String interpretationTone = 'interpretationTone';
  static const String focusAreas = 'focusAreas';

  static const String isProfileComplete = 'isProfileComplete';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String wallet = 'wallet';
  static const String walletCredits = 'credits';
  static const String walletLastFreeDrawAt = 'lastFreeDrawAt';
  static const String fcmTokens = 'fcmTokens';
  static const String fcmTokenUpdatedAt = 'fcmTokenUpdatedAt';

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
    required this.isProfileComplete,
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
  final bool isProfileComplete;
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
      UserProfileContract.isProfileComplete: isProfileComplete,
      if (includeCreatedAt)
        UserProfileContract.createdAt: FieldValue.serverTimestamp(),
      UserProfileContract.updatedAt: FieldValue.serverTimestamp(),
    };
  }
}
