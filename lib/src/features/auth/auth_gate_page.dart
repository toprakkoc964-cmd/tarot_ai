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

  Future<bool> _verifySession(User user) async {
    try {
      await user.reload();
      return FirebaseAuth.instance.currentUser != null;
    } on FirebaseAuthException catch (e) {
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
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _authService.registrationPortalActive,
      builder: (context, registrationPortalActive, _) {
        return Stack(
          children: [
            ValueListenableBuilder<String>(
              valueListenable: AppLocale.notifier,
              builder: (context, _, __) {
                return StreamBuilder<User?>(
                  stream: _authService.authChanges(),
                  builder: (context, authSnapshot) {
                    if (authSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return _buildLoading();
                    }

                    final user = authSnapshot.data;
                    if (user == null) {
                      return _buildAuthEntry();
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

                        return ValueListenableBuilder<bool>(
                          valueListenable:
                              _authService.accountDeletionInProgress,
                          builder: (context, deletingAccount, _) {
                            if (deletingAccount) {
                              return _buildLoading();
                            }

                            return StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: FirebaseFirestore.instance
                                  .collection(
                                    UserProfileContract.usersCollection,
                                  )
                                  .doc(user.uid)
                                  .snapshots(),
                              builder: (context, profileSnapshot) {
                                if (profileSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return _buildLoading();
                                }

                                final data = profileSnapshot.data?.data();
                                final isProfileComplete =
                                    data?[UserProfileContract
                                        .isProfileComplete] ==
                                    true;

                                if (!isProfileComplete) {
                                  return OnboardingPage(
                                    authService: _authService,
                                    uid: user.uid,
                                  );
                                }

                                return HomePage(
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
  }
}
