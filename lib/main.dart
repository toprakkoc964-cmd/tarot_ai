import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'services/notification_service.dart' as local_notifications;
import 'src/core/app_check.dart';
import 'src/core/app_texts.dart';
import 'src/core/di/service_locator.dart';
import 'src/core/localization_service.dart';
import 'src/core/notification_service.dart' as fcm_notifications;
import 'src/features/auth/auth_gate_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await setupServiceLocator();
  runApp(const TarotAiApp());
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await LocalizationService.instance.initialize();
  await local_notifications.NotificationService.instance
      .initializeForBackgroundMessages();
  await local_notifications.NotificationService.instance
      .showNotificationFromRemoteMessage(message);
}

Future<String?> _bootstrapApp() async {
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 12));
    await fcm_notifications.NotificationService.instance
        .initialize()
        .timeout(const Duration(seconds: 12));
    await local_notifications.NotificationService.instance
        .init()
        .timeout(const Duration(seconds: 12));
    await activateAppCheck(isDebug: kDebugMode)
        .timeout(const Duration(seconds: 12));
    await LocalizationService.instance
        .initialize()
        .timeout(const Duration(seconds: 12));
    return null;
  } catch (e, st) {
    debugPrint('Bootstrap failed: $e');
    debugPrintStack(stackTrace: st);
    return e.toString();
  }
}

class TarotAiApp extends StatelessWidget {
  const TarotAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppTexts.t('app.title'),
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF17081C),
        canvasColor: const Color(0xFF17081C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF690DAB),
          secondary: Color(0xFFD4AF37),
          surface: Color(0xFF17081C),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF17081C),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const AppBootstrapPage(),
    );
  }
}

class AppBootstrapPage extends StatefulWidget {
  const AppBootstrapPage({super.key});

  @override
  State<AppBootstrapPage> createState() => _AppBootstrapPageState();
}

class _AppBootstrapPageState extends State<AppBootstrapPage> {
  late final Future<String?> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrapApp();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppStartupLoadingPage();
        }

        final bootstrapError = snapshot.data;
        if (bootstrapError != null) {
          return FirebaseSetupRequiredPage(error: bootstrapError);
        }

        return const AuthGatePage();
      },
    );
  }
}

class AppStartupLoadingPage extends StatelessWidget {
  const AppStartupLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF17081C),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
      ),
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
