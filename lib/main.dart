import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/core/app_check.dart';
import 'src/core/app_texts.dart';
import 'src/core/localization_service.dart';
import 'src/features/auth/auth_gate_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? bootstrapError;
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 12));
    await activateAppCheck(isDebug: kDebugMode)
        .timeout(const Duration(seconds: 12));
    await LocalizationService.instance.initialize();
  } catch (e) {
    bootstrapError = e.toString();
  }

  runApp(TarotAiApp(bootstrapError: bootstrapError));
}

class TarotAiApp extends StatelessWidget {
  const TarotAiApp({super.key, this.bootstrapError});

  final String? bootstrapError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppTexts.t('app.title'),
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1022),
        canvasColor: const Color(0xFF1A1022),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF690DAB),
          secondary: Color(0xFFD4AF37),
          surface: Color(0xFF1A1022),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1022),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: bootstrapError == null
          ? const AuthGatePage()
          : FirebaseSetupRequiredPage(error: bootstrapError!),
    );
  }
}

class FirebaseSetupRequiredPage extends StatelessWidget {
  const FirebaseSetupRequiredPage({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTexts.t('setup.firebase_title'),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(AppTexts.t('setup.firebase_body')),
            const SizedBox(height: 14),
            Text(
              error,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }
}
