import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/app_texts.dart';
import '../../core/localization_service.dart';
import '../../core/user_profile_store.dart';
import '../home/home_page.dart';
import '../splash/cosmic_splash_screen.dart';
import 'auth_profile_bootstrap.dart';
import 'auth_service.dart';
import 'login_page.dart';
import 'onboarding_flow_entry.dart';
import 'register_page.dart';
import 'user_profile_contract.dart';
import 'verify_email_page.dart';
import 'widgets/registration_portal_transition_overlay.dart';

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  static const Duration _authStateTimeout = Duration(seconds: 8);
  static const Duration _profileSnapshotTimeout = Duration(seconds: 8);

  final _authService = AuthService();
  final _onboardingCache = const OnboardingCompletionCache();
  bool _showRegister = false;
  String? _sessionCheckUid;
  Future<bool>? _sessionCheckFuture;
  String? _lastSyncedProfileLanguage;
  Stream<User?>? _authStream;
  String? _profileStreamUid;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _profileStream;
  final GlobalKey _onboardingKey = GlobalKey();
  final GlobalKey _splashKey = GlobalKey();

  Widget _buildLoading() {
    return CosmicSplashScreen(key: _splashKey);
  }

  Widget _buildAuthEntry() {
    if (_showRegister) {
      return RegisterPage(
        authService: _authService,
        onSwitchToLogin: () => setState(() => _showRegister = false),
      );
    }
    return LoginPage(
      authService: _authService,
      onSwitchToRegister: () => setState(() => _showRegister = true),
    );
  }

  Widget _buildLoginEntry() {
    return LoginPage(
      authService: _authService,
      onSwitchToRegister: () => setState(() => _showRegister = true),
    );
  }

  void _retryBootstrap() {
    debugPrint('[auth-gate] retry requested');
    _sessionCheckFuture = null;
    _sessionCheckUid = null;
    _profileStream = null;
    _profileStreamUid = null;
    if (mounted) setState(() {});
  }

  Widget _buildProfileRecoverableError(Object? error) {
    debugPrint(
      '[auth-gate] decision=retry reason=profile_unavailable_unknown_onboarding '
      'errorType=${error.runtimeType}',
    );
    return Scaffold(
      backgroundColor: const Color(0xFF17081C),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFFFFE792),
                  size: 42,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Bağlantı geçici olarak kurulamadı',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFFADCFF),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Profil durumunu doğrulayamadık. İnternet bağlantını kontrol edip tekrar deneyebilirsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFCDBDFF),
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _retryBootstrap,
                  child: Text(AppTexts.t('common.retry')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileUnavailableWithCache({
    required User user,
    required Object? error,
  }) {
    return FutureBuilder<bool>(
      future: _onboardingCache
          .isComplete(user.uid)
          .timeout(const Duration(seconds: 2), onTimeout: () => false),
      builder: (context, cacheSnapshot) {
        if (cacheSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }
        final decision = resolveAuthProfileDecision(
          documentExists: false,
          data: null,
          cachedOnboardingComplete: cacheSnapshot.data == true,
          error: error ?? TimeoutException('profile unavailable'),
        );
        if (decision.type == AuthProfileDecisionType.home) {
          debugPrint(
            '[auth-gate] decision=home reason=${decision.reason} '
            'errorType=${error.runtimeType}',
          );
          return HomePage(
            key: HomePage.rootKey,
            authService: _authService,
            uid: user.uid,
          );
        }
        return _buildProfileRecoverableError(error);
      },
    );
  }

  void _showLoginOnNextFrame() {
    if (!_showRegister) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showRegister = false);
    });
  }

  void _markDeletedAccountAndSignOut() {
    Future<void>.microtask(() async {
      await _authService.clearPostDeletionRedirect();
      await _authService.signOut(redirectToLogin: false);
    });
  }

  void _syncProfileLanguage(String? storedLanguage) {
    final raw = storedLanguage?.trim();
    if (raw == null || raw.isEmpty) return;
    final normalized = AppLanguage.normalize(raw);
    if (!AppLanguage.isSupported(normalized)) return;
    if (_lastSyncedProfileLanguage == normalized) return;
    _lastSyncedProfileLanguage = normalized;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(LocalizationService.instance.applyUserLanguage(normalized));
    });
  }

  Future<bool> _verifySession(User user) async {
    try {
      await user.reload().timeout(const Duration(seconds: 6));
      return FirebaseAuth.instance.currentUser != null;
    } on TimeoutException {
      // Ağ yavaş: UI'yı kilitleme, yerel oturuma güven ve devam et.
      debugPrint('[auth-gate] verify session timed out');
      return FirebaseAuth.instance.currentUser != null;
    } on FirebaseAuthException catch (e) {
      debugPrint('[auth-gate] verify session failed code=${e.code}');
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-user-token' ||
          e.code == 'user-disabled') {
        try {
          await _authService.signOut(redirectToLogin: false);
        } catch (_) {}
        return false;
      }
      // Diğer hatalarda oturumu düşürme; yerel oturumla devam et.
      return FirebaseAuth.instance.currentUser != null;
    } catch (e) {
      // Beklenmeyen (ör. ağ) hatada spinner'da takılma.
      debugPrint('[auth-gate] verify session error type=${e.runtimeType}');
      return FirebaseAuth.instance.currentUser != null;
    }
  }

  Future<bool> _sessionFutureFor(User user) {
    if (_sessionCheckFuture != null && _sessionCheckUid == user.uid) {
      return _sessionCheckFuture!;
    }
    _sessionCheckUid = user.uid;
    _sessionCheckFuture = _verifySession(user);
    return _sessionCheckFuture!;
  }

  Stream<User?> _authChangesWithTimeout() {
    return _authStream ??= _authService.authChanges().timeout(
      _authStateTimeout,
      onTimeout: (sink) {
        final cachedUser = FirebaseAuth.instance.currentUser;
        debugPrint(
          '[auth-gate] auth state restore timed out; '
          'cachedUser=${cachedUser != null}',
        );
        sink.add(cachedUser);
      },
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _profileSnapshots(String uid) {
    final cached = _profileStream;
    if (cached != null && _profileStreamUid == uid) {
      return cached;
    }
    _profileStreamUid = uid;
    return _profileStream = UserProfileStore.instance
        .watch(uid)
        .timeout(
          _profileSnapshotTimeout,
          onTimeout: (sink) {
            debugPrint('[auth-gate] profile snapshot timed out');
            sink.addError(TimeoutException('profile snapshot timed out'));
          },
        )
        .asBroadcastStream();
  }

  Widget _buildOnboardingEntry() {
    return OnboardingFlowEntry(key: _onboardingKey, authService: _authService);
  }

  @override
  void dispose() {
    _authService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _authService.registrationPortalActive,
      builder: (context, registrationPortalActive, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: _authService.registrationRedirectSuppressed,
          builder: (context, registrationRedirectSuppressed, __) {
            return ValueListenableBuilder<String?>(
              valueListenable: _authService.redirectIntent,
              builder: (context, redirectIntent, ___) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _authService.redirectIntentHydrated,
                  builder: (context, redirectIntentHydrated, ____) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _authService.socialProfileSyncInProgress,
                      builder: (context, socialProfileSyncInProgress, _____) {
                        return Stack(
                          children: [
                            StreamBuilder<User?>(
                              stream: _authChangesWithTimeout(),
                              builder: (context, authSnapshot) {
                                if (!redirectIntentHydrated) {
                                  return _buildLoading();
                                }
                                if (registrationRedirectSuppressed) {
                                  return _buildAuthEntry();
                                }

                                if (socialProfileSyncInProgress) {
                                  return _buildLoading();
                                }

                                if (authSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return _buildLoading();
                                }

                                final user = authSnapshot.data;
                                if (user == null) {
                                  debugPrint(
                                    '[auth-gate] auth state=signed_out',
                                  );
                                  if (redirectIntent ==
                                      AuthService.redirectIntentLogin) {
                                    _showLoginOnNextFrame();
                                    return _buildLoginEntry();
                                  }
                                  return _buildOnboardingEntry();
                                }
                                debugPrint('[auth-gate] auth state=signed_in');

                                return FutureBuilder<bool>(
                                  future: _sessionFutureFor(user),
                                  builder: (context, sessionSnapshot) {
                                    if (sessionSnapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return _buildLoading();
                                    }
                                    if (sessionSnapshot.data != true) {
                                      return _buildOnboardingEntry();
                                    }
                                    final verifiedUser =
                                        FirebaseAuth.instance.currentUser ??
                                        user;

                                    if (_authService.requiresEmailVerification(
                                      verifiedUser,
                                    )) {
                                      return VerifyEmailPage(
                                        authService: _authService,
                                        user: verifiedUser,
                                        onVerified: () {
                                          _sessionCheckFuture = null;
                                          _sessionCheckUid = null;
                                          if (mounted) setState(() {});
                                        },
                                        onChangeEmail: () {
                                          if (mounted) {
                                            setState(
                                              () => _showRegister = true,
                                            );
                                          }
                                        },
                                      );
                                    }

                                    return ValueListenableBuilder<bool>(
                                      valueListenable: _authService
                                          .accountDeletionInProgress,
                                      builder: (context, deletingAccount, _) {
                                        if (deletingAccount) {
                                          return _buildLoading();
                                        }

                                        return StreamBuilder<
                                          DocumentSnapshot<Map<String, dynamic>>
                                        >(
                                          stream: _profileSnapshots(user.uid),
                                          builder: (context, profileSnapshot) {
                                            if (profileSnapshot
                                                    .connectionState ==
                                                ConnectionState.waiting) {
                                              return _buildLoading();
                                            }

                                            if (profileSnapshot.hasError) {
                                              return _buildProfileUnavailableWithCache(
                                                user: user,
                                                error: profileSnapshot.error,
                                              );
                                            }

                                            final documentExists =
                                                profileSnapshot.data?.exists ==
                                                true;
                                            final data = profileSnapshot.data
                                                ?.data();
                                            if (!documentExists) {
                                              debugPrint(
                                                '[auth-gate] profile snapshot exists=false',
                                              );
                                              unawaited(
                                                _onboardingCache.clear(
                                                  user.uid,
                                                ),
                                              );
                                              debugPrint(
                                                '[auth-gate] decision=onboarding reason=profile_document_missing',
                                              );
                                              return _buildOnboardingEntry();
                                            }
                                            final storedLanguage =
                                                (data?[UserProfileContract
                                                            .language]
                                                        as String?)
                                                    ?.trim();
                                            _syncProfileLanguage(
                                              storedLanguage,
                                            );
                                            final accountStatus =
                                                data?[UserProfileContract
                                                        .accountStatus]
                                                    as String?;
                                            if (accountStatus ==
                                                UserProfileContract
                                                    .statusDeleted) {
                                              unawaited(
                                                _onboardingCache.clear(
                                                  user.uid,
                                                ),
                                              );
                                              _markDeletedAccountAndSignOut();
                                              return _buildLoading();
                                            }

                                            if (accountStatus ==
                                                    UserProfileContract
                                                        .statusPendingEmailVerification &&
                                                verifiedUser.emailVerified) {
                                              Future<void>.microtask(
                                                _authService
                                                    .markCurrentUserEmailVerified,
                                              );
                                              return _buildLoading();
                                            }

                                            if (accountStatus ==
                                                UserProfileContract
                                                    .statusPendingEmailVerification) {
                                              return VerifyEmailPage(
                                                authService: _authService,
                                                user: verifiedUser,
                                                onVerified: () {
                                                  _sessionCheckFuture = null;
                                                  _sessionCheckUid = null;
                                                  if (mounted) setState(() {});
                                                },
                                                onChangeEmail: () {
                                                  if (mounted) {
                                                    setState(
                                                      () =>
                                                          _showRegister = true,
                                                    );
                                                  }
                                                },
                                              );
                                            }

                                            final profileName =
                                                UserProfileContract.normalizeName(
                                                  ((data?[UserProfileContract
                                                                  .displayName]
                                                              as String?) ??
                                                          (data?[UserProfileContract
                                                                  .name]
                                                              as String?) ??
                                                          '')
                                                      .trim(),
                                                );
                                            final hasRequiredName =
                                                profileName.isNotEmpty;
                                            final hasRequiredBirthDate =
                                                ((data?[UserProfileContract
                                                                .birthDate]
                                                            as String?) ??
                                                        '')
                                                    .trim()
                                                    .isNotEmpty;
                                            final hasCompletionFlag =
                                                data?[UserProfileContract
                                                        .isProfileComplete] ==
                                                    true ||
                                                data?[UserProfileContract
                                                        .onboardingCompleted] ==
                                                    true ||
                                                accountStatus ==
                                                    UserProfileContract
                                                        .statusActive;
                                            final isProfileComplete =
                                                hasCompletionFlag ||
                                                (hasRequiredName &&
                                                    hasRequiredBirthDate);

                                            if (!isProfileComplete) {
                                              debugPrint(
                                                '[auth-gate] decision=onboarding '
                                                'reason=remote_profile_incomplete '
                                                'hasName=$hasRequiredName '
                                                'hasBirthDate=$hasRequiredBirthDate '
                                                'accountStatus=$accountStatus',
                                              );
                                              unawaited(
                                                _onboardingCache.clear(
                                                  user.uid,
                                                ),
                                              );
                                              return _buildOnboardingEntry();
                                            }

                                            unawaited(
                                              _onboardingCache.markComplete(
                                                user.uid,
                                              ),
                                            );
                                            debugPrint(
                                              '[auth-gate] decision=home reason=remote_profile_complete',
                                            );
                                            return HomePage(
                                              key: HomePage.rootKey,
                                              authService: _authService,
                                              uid: user.uid,
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                            if (registrationPortalActive)
                              const RegistrationPortalTransitionOverlay(),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
