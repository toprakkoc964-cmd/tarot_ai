import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarot_ai/src/features/auth/auth_profile_bootstrap.dart';
import 'package:tarot_ai/src/features/auth/user_profile_contract.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('complete remote profile routes to home', () {
    final decision = resolveAuthProfileDecision(
      documentExists: true,
      data: const {
        UserProfileContract.isProfileComplete: true,
        UserProfileContract.accountStatus: UserProfileContract.statusActive,
      },
      cachedOnboardingComplete: false,
    );

    expect(decision.type, AuthProfileDecisionType.home);
    expect(decision.reason, 'remote_profile_complete');
  });

  test('remote profile with required name and birth date routes to home', () {
    final decision = resolveAuthProfileDecision(
      documentExists: true,
      data: const {
        UserProfileContract.name: 'Toprak',
        UserProfileContract.birthDate: '1992-01-01',
      },
      cachedOnboardingComplete: false,
    );

    expect(decision.type, AuthProfileDecisionType.home);
  });

  test('incomplete remote profile routes to onboarding', () {
    final decision = resolveAuthProfileDecision(
      documentExists: true,
      data: const {UserProfileContract.name: 'Toprak'},
      cachedOnboardingComplete: true,
    );

    expect(decision.type, AuthProfileDecisionType.onboarding);
    expect(decision.reason, 'remote_profile_incomplete');
  });

  test('missing profile document routes to onboarding', () {
    final decision = resolveAuthProfileDecision(
      documentExists: false,
      data: null,
      cachedOnboardingComplete: true,
    );

    expect(decision.type, AuthProfileDecisionType.onboarding);
    expect(decision.reason, 'profile_document_missing');
  });

  test('profile timeout with local completion cache routes to home', () {
    final decision = resolveAuthProfileDecision(
      documentExists: false,
      data: null,
      cachedOnboardingComplete: true,
      error: TimeoutException('profile timeout'),
    );

    expect(decision.type, AuthProfileDecisionType.home);
    expect(decision.reason, 'profile_unavailable_local_onboarding_complete');
  });

  test('profile timeout without local completion cache routes to retry', () {
    final decision = resolveAuthProfileDecision(
      documentExists: false,
      data: null,
      cachedOnboardingComplete: false,
      error: TimeoutException('profile timeout'),
    );

    expect(decision.type, AuthProfileDecisionType.retry);
    expect(decision.reason, 'profile_unavailable_unknown_onboarding');
  });

  test('permission denied without local completion cache routes to retry', () {
    final decision = resolveAuthProfileDecision(
      documentExists: false,
      data: null,
      cachedOnboardingComplete: false,
      error: FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      ),
    );

    expect(decision.type, AuthProfileDecisionType.retry);
  });

  test(
    'permission denied with local completion cache still routes to retry',
    () {
      final decision = resolveAuthProfileDecision(
        documentExists: false,
        data: null,
        cachedOnboardingComplete: true,
        error: FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      );

      expect(decision.type, AuthProfileDecisionType.retry);
      expect(decision.reason, 'profile_unavailable_unknown_onboarding');
    },
  );

  test('onboarding completion cache is scoped per uid', () async {
    const cache = OnboardingCompletionCache();

    await cache.markComplete('uid-a');

    expect(await cache.isComplete('uid-a'), isTrue);
    expect(await cache.isComplete('uid-b'), isFalse);

    await cache.clear('uid-a');
    expect(await cache.isComplete('uid-a'), isFalse);
  });
}
