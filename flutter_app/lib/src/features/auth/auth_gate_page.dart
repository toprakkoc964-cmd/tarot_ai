import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_locale.dart';
import '../../core/localization_service.dart';
import '../readings/reading_home_page.dart';
import 'auth_service.dart';
import 'login_page.dart';
import 'onboarding_page.dart';
import 'register_page.dart';

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  final _authService = AuthService();
  bool _showRegister = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.notifier,
      builder: (context, _, __) => StreamBuilder<User?>(
        stream: _authService.authChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF1A1022),
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = authSnapshot.data;
          if (user == null) {
            return _showRegister
                ? RegisterPage(
                    authService: _authService,
                    onSwitchToLogin: () =>
                        setState(() => _showRegister = false),
                  )
                : LoginPage(
                    authService: _authService,
                    onSwitchToRegister: () =>
                        setState(() => _showRegister = true),
                  );
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, userDocSnapshot) {
              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFF1A1022),
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final data = userDocSnapshot.data?.data();
              final selectedLang = data?['settings']?['lang'];
              if (selectedLang is String && selectedLang != AppLocale.current) {
                LocalizationService.instance.setLanguage(selectedLang);
              }

              final profileComplete = data?['isProfileComplete'] == true;

              if (!profileComplete) {
                return OnboardingPage(authService: _authService, uid: user.uid);
              }

              return ReadingHomePage(authService: _authService, uid: user.uid);
            },
          );
        },
      ),
    );
  }
}
