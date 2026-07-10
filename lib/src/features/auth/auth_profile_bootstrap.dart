import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_profile_contract.dart';

enum AuthProfileDecisionType { home, onboarding, retry }

class AuthProfileDecision {
  const AuthProfileDecision(this.type, this.reason);

  final AuthProfileDecisionType type;
  final String reason;
}

class OnboardingCompletionCache {
  const OnboardingCompletionCache();

  static String keyFor(String uid) => 'auth.onboarding_complete.$uid';

  Future<bool> isComplete(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyFor(uid)) ?? false;
  }

  Future<void> markComplete(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyFor(uid), true);
  }

  Future<void> clear(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyFor(uid));
  }
}

bool userProfileDataIsComplete(Map<String, dynamic>? data) {
  if (data == null) return false;
  final accountStatus = data[UserProfileContract.accountStatus] as String?;
  if (data[UserProfileContract.isProfileComplete] == true ||
      data[UserProfileContract.onboardingCompleted] == true ||
      accountStatus == UserProfileContract.statusActive) {
    return true;
  }

  final profileName = UserProfileContract.normalizeName(
    ((data[UserProfileContract.displayName] as String?) ??
            (data[UserProfileContract.name] as String?) ??
            '')
        .trim(),
  );
  final birthDate = ((data[UserProfileContract.birthDate] as String?) ?? '')
      .trim();
  return profileName.isNotEmpty && birthDate.isNotEmpty;
}

AuthProfileDecision resolveAuthProfileDecision({
  required bool documentExists,
  required Map<String, dynamic>? data,
  required bool cachedOnboardingComplete,
  Object? error,
}) {
  if (error != null) {
    if (cachedOnboardingComplete && profileErrorAllowsLocalFallback(error)) {
      return const AuthProfileDecision(
        AuthProfileDecisionType.home,
        'profile_unavailable_local_onboarding_complete',
      );
    }
    return const AuthProfileDecision(
      AuthProfileDecisionType.retry,
      'profile_unavailable_unknown_onboarding',
    );
  }

  if (!documentExists) {
    return const AuthProfileDecision(
      AuthProfileDecisionType.onboarding,
      'profile_document_missing',
    );
  }

  if (userProfileDataIsComplete(data)) {
    return const AuthProfileDecision(
      AuthProfileDecisionType.home,
      'remote_profile_complete',
    );
  }

  return const AuthProfileDecision(
    AuthProfileDecisionType.onboarding,
    'remote_profile_incomplete',
  );
}

bool profileErrorAllowsLocalFallback(Object error) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return false;
  }
  return true;
}
