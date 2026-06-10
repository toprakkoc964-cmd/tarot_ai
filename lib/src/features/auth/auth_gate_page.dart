import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_locale.dart';
import '../home/home_page.dart';
import 'auth_service.dart';
import 'login_page.dart';
import 'onboarding_page.dart';
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
  final _authService = AuthService();
  bool _showRegister = false;
  String? _sessionCheckUid;
  Future<bool>? _sessionCheckFuture;

  Widget _buildLoading() {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

  void _showLoginOnNextFrame() {
    if (!_showRegister) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showRegister = false);
    });
  }

  void _markDeletedAccountAndSignOut() {
    Future<void>.microtask(() async {
      await _authService.markPostDeletionRedirectPending();
      await _authService.signOut();
    });
  }

  Future<bool> _verifySession(User user) async {
    try {
      await user.reload();
      return FirebaseAuth.instance.currentUser != null;
    } on FirebaseAuthException catch (e) {
      debugPrint('🍎 VERIFY_SESSION_FAILED code=${e.code} msg=${e.message}');
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-user-token' ||
          e.code == 'user-disabled') {
        try {
          await _authService.signOut();
        } catch (_) {}
        return false;
      }
      rethrow;
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
              valueListenable: _authService.registrationCompletedOnboardingUid,
              builder: (context, registrationCompletedOnboardingUid, ___) {
                return ValueListenableBuilder<bool>(
                  valueListenable: _authService.forceLoginAfterAccountDeletion,
                  builder: (context, forceLoginAfterAccountDeletion, ____) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: _authService.socialProfileSyncInProgress,
                      builder: (context, socialProfileSyncInProgress, _____) {
                        return Stack(
                          children: [
                            ValueListenableBuilder<String>(
                              valueListenable: AppLocale.notifier,
                              builder: (context, _, __) {
                                return StreamBuilder<User?>(
                                  stream: _authService.authChanges(),
                                  builder: (context, authSnapshot) {
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
                                    if (forceLoginAfterAccountDeletion) {
                                      _showLoginOnNextFrame();
                                      if (user != null) {
                                        Future<void>.microtask(
                                          _authService.signOut,
                                        );
                                        return _buildLoading();
                                      }
                                      Future<void>.microtask(() async {
                                        await _authService
                                            .clearPostDeletionRedirect();
                                      });
                                      return _buildLoginEntry();
                                    }

                                    if (user == null) {
                                      return _buildAuthEntry();
                                    }

                                    if (registrationCompletedOnboardingUid ==
                                        user.uid) {
                                      return OnboardingPage(
                                        key: ValueKey('onboarding_${user.uid}'),
                                        authService: _authService,
                                        uid: user.uid,
                                      );
                                    }

                                    return FutureBuilder<bool>(
                                      future: _sessionFutureFor(user),
                                      builder: (context, sessionSnapshot) {
                                        if (sessionSnapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return _buildLoading();
                                        }
                                        if (sessionSnapshot.data != true) {
                                          return _buildAuthEntry();
                                        }
                                        final verifiedUser =
                                            FirebaseAuth.instance.currentUser ??
                                            user;

                                        if (_authService
                                            .requiresEmailVerification(
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
                                              DocumentSnapshot<
                                                Map<String, dynamic>
                                              >
                                            >(
                                              stream: FirebaseFirestore.instance
                                                  .collection(
                                                    UserProfileContract
                                                        .usersCollection,
                                                  )
                                                  .doc(user.uid)
                                                  .snapshots(),
                                              builder: (context, profileSnapshot) {
                                                if (profileSnapshot
                                                        .connectionState ==
                                                    ConnectionState.waiting) {
                                                  return _buildLoading();
                                                }

                                                final data = profileSnapshot
                                                    .data
                                                    ?.data();
                                                final accountStatus =
                                                    data?[UserProfileContract
                                                            .accountStatus]
                                                        as String?;
                                                if (accountStatus ==
                                                    UserProfileContract
                                                        .statusDeleted) {
                                                  _markDeletedAccountAndSignOut();
                                                  return _buildLoading();
                                                }

                                                if (accountStatus ==
                                                        UserProfileContract
                                                            .statusPendingEmailVerification &&
                                                    verifiedUser
                                                        .emailVerified) {
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
                                                      _sessionCheckFuture =
                                                          null;
                                                      _sessionCheckUid = null;
                                                      if (mounted) {
                                                        setState(() {});
                                                      }
                                                    },
                                                    onChangeEmail: () {
                                                      if (mounted) {
                                                        setState(
                                                          () => _showRegister =
                                                              true,
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
                                                final isProfileComplete =
                                                    hasRequiredName &&
                                                    hasRequiredBirthDate &&
                                                    (data?[UserProfileContract
                                                                .isProfileComplete] ==
                                                            true ||
                                                        data?[UserProfileContract
                                                                .onboardingCompleted] ==
                                                            true ||
                                                        accountStatus ==
                                                            UserProfileContract
                                                                .statusActive);

                                                if (!isProfileComplete) {
                                                  return OnboardingPage(
                                                    key: ValueKey(
                                                      'onboarding_${user.uid}',
                                                    ),
                                                    authService: _authService,
                                                    uid: user.uid,
                                                  );
                                                }

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
