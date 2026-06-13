import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'services/notification_service.dart' as local_notifications;
import 'src/core/app_check.dart';
import 'src/core/app_locale.dart';
import 'src/core/app_navigator.dart';
import 'src/core/app_texts.dart';
import 'src/core/di/service_locator.dart';
import 'src/core/localization_service.dart';
import 'src/core/notification_service.dart' as fcm_notifications;
import 'src/features/auth/auth_service.dart';
import 'src/features/auth/auth_gate_page.dart';
import 'src/features/auth/onboarding_account_page.dart';
import 'src/features/auth/onboarding_card_pick_page.dart';
import 'src/features/auth/onboarding_coffee_ritual_page.dart';
import 'src/features/auth/onboarding_focus_areas_page.dart';
import 'src/features/auth/onboarding_name_birth_page.dart';
import 'src/features/auth/onboarding_paywall_page.dart';
import 'src/features/auth/onboarding_palm_scan_page.dart';
import 'src/features/auth/onboarding_personalization_page.dart';
import 'src/features/auth/onboarding_reveal_page.dart';
import 'src/features/auth/onboarding_tarot_draw_page.dart' as tarot_draw;
import 'src/features/auth/onboarding_welcome_page.dart';
import 'src/features/readings/tarot_service.dart';
import 'src/features/shop/services/purchase_service.dart';

const bool _showOnboardingWelcomePreview = bool.fromEnvironment(
  'SHOW_ONBOARDING_WELCOME_PREVIEW',
);

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
    final firebaseError = await _runRequiredBootstrapTask(
      'Firebase',
      () => Firebase.initializeApp(),
    );
    if (firebaseError != null) return firebaseError;
    await _runOptionalBootstrapTask(
      'App Check',
      () => activateAppCheck(isDebug: kDebugMode),
      timeout: const Duration(seconds: 12),
    );
    await _runOptionalBootstrapTask(
      'FCM notifications',
      () => fcm_notifications.NotificationService.instance.initialize(),
    );
    await _runOptionalBootstrapTask(
      'Local notifications',
      () => local_notifications.NotificationService.instance.init(),
    );
    final localizationError = await _runRequiredBootstrapTask(
      'Localization',
      () => LocalizationService.instance.initialize(),
    );
    if (localizationError != null) return localizationError;
    _startTarotImagePreloadInBackground();
    await _runOptionalBootstrapTask(
      'Purchase service',
      () => getIt<PurchaseService>().initialize(),
    );
    return null;
  } catch (e, st) {
    debugPrint('Bootstrap failed: $e');
    debugPrintStack(stackTrace: st);
    return e.toString();
  }
}

Future<String?> _runRequiredBootstrapTask(
  String name,
  Future<void> Function() task,
) async {
  try {
    final completed = await _runBootstrapTaskWithTimeout(
      task,
      const Duration(seconds: 12),
    );
    if (!completed) {
      return '$name bootstrap timed out';
    }
    return null;
  } catch (e) {
    return e.toString();
  }
}

Future<void> _runOptionalBootstrapTask(
  String name,
  Future<void> Function() task, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  try {
    final completed = await _runBootstrapTaskWithTimeout(task, timeout);
    if (!completed) {
      debugPrint('Optional bootstrap task skipped ($name): timed out');
    }
  } catch (e, st) {
    debugPrint('Optional bootstrap task skipped ($name): $e');
    if (kDebugMode && name != 'App Check') {
      debugPrintStack(stackTrace: st);
    }
  }
}

Future<bool> _runBootstrapTaskWithTimeout(
  Future<void> Function() task,
  Duration timeout,
) async {
  final completer = Completer<bool>();

  unawaited(() async {
    try {
      await task();
      if (!completer.isCompleted) {
        completer.complete(true);
      }
    } catch (e, st) {
      if (!completer.isCompleted) {
        completer.completeError(e, st);
      }
    }
  }());

  unawaited(Future<void>.delayed(timeout, () {
    if (!completer.isCompleted) {
      completer.complete(false);
    }
  }));

  return completer.future;
}

void _startTarotImagePreloadInBackground() {
  TarotService.ensureLocalAssetsCached();
}

class TarotAiApp extends StatelessWidget {
  const TarotAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LocalizationService.instance.revision,
      builder: (context, _, __) {
        return ValueListenableBuilder<String>(
          valueListenable: AppLocale.notifier,
          builder: (context, localeCode, ___) {
            return MaterialApp(
              navigatorKey: appNavigatorKey,
              debugShowCheckedModeBanner: false,
              locale: Locale(localeCode),
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
          },
        );
      },
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

        if (_showOnboardingWelcomePreview) {
          return OnboardingWelcomePage(
            onStart: () {
              unawaited(
                AuthService().signInAnonymously().catchError((Object error) {
                  debugPrint('Anonymous preview sign-in skipped: $error');
                }),
              );
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => OnboardingCardPickPage(
                    onModalityChosen: (modality) {
                      if (modality == OnboardingModality.tarot) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => tarot_draw.OnboardingTarotDrawPage(
                              name: '',
                              onBack: () => Navigator.of(context).pop(),
                              onCardDrawn: (card) {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        _OnboardingNameBirthPreviewPage(
                                          modality: modality,
                                          drawnTarotCard: card,
                                        ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                        return;
                      }
                      if (modality == OnboardingModality.palm) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => OnboardingPalmScanPage(
                              name: '',
                              onBack: () => Navigator.of(context).pop(),
                              onPalmCaptured: (palmTeaserKey) {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        _OnboardingNameBirthPreviewPage(
                                          modality: modality,
                                          palmTeaserKey: palmTeaserKey,
                                        ),
                                  ),
                                );
                              },
                              onModalitySwitch: (newModality) {
                                if (newModality == OnboardingModality.tarot) {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          tarot_draw.OnboardingTarotDrawPage(
                                            name: '',
                                            onBack: () =>
                                                Navigator.of(context).pop(),
                                            onCardDrawn: (card) {
                                              Navigator.of(context).push(
                                                MaterialPageRoute<void>(
                                                  builder: (_) =>
                                                      _OnboardingNameBirthPreviewPage(
                                                        modality: newModality,
                                                        drawnTarotCard: card,
                                                      ),
                                                ),
                                              );
                                            },
                                          ),
                                    ),
                                  );
                                  return;
                                }
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute<void>(
                                    builder: (_) => OnboardingCoffeeRitualPage(
                                      name: '',
                                      onBack: () => Navigator.of(context).pop(),
                                      onCoffeeSealed: (coffeeTeaserKey) {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                _OnboardingNameBirthPreviewPage(
                                                  modality: newModality,
                                                  coffeeTeaserKey:
                                                      coffeeTeaserKey,
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                        return;
                      }
                      if (modality == OnboardingModality.coffee) {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => OnboardingCoffeeRitualPage(
                              name: '',
                              onBack: () => Navigator.of(context).pop(),
                              onCoffeeSealed: (coffeeTeaserKey) {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        _OnboardingNameBirthPreviewPage(
                                          modality: modality,
                                          coffeeTeaserKey: coffeeTeaserKey,
                                        ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _OnboardingModalityPlaceholderPage(
                            modality: modality,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        }

        return const AuthGatePage();
      },
    );
  }
}

class _OnboardingModalityPlaceholderPage extends StatelessWidget {
  const _OnboardingModalityPlaceholderPage({required this.modality});

  final OnboardingModality modality;

  @override
  Widget build(BuildContext context) {
    final label = switch (modality) {
      OnboardingModality.tarot => AppTexts.t(
        'onboarding.card_pick.tarot_title',
      ),
      OnboardingModality.coffee => AppTexts.t(
        'onboarding.card_pick.coffee_title',
      ),
      OnboardingModality.palm => AppTexts.t('onboarding.card_pick.palm_title'),
    };
    return Scaffold(
      backgroundColor: const Color(0xFF17081C),
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFADCFF),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          _OnboardingNameBirthPreviewPage(modality: modality),
                    ),
                  );
                },
                child: Text(AppTexts.t('onboarding.cta_continue')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingNameBirthPreviewPage extends StatelessWidget {
  const _OnboardingNameBirthPreviewPage({
    required this.modality,
    this.drawnTarotCard,
    this.palmTeaserKey,
    this.coffeeTeaserKey,
  });

  final OnboardingModality modality;
  final tarot_draw.DrawnTarotCard? drawnTarotCard;
  final String? palmTeaserKey;
  final String? coffeeTeaserKey;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'preview';
    return OnboardingNameBirthPage(
      authService: AuthService(),
      uid: uid,
      onBack: () => Navigator.of(context).pop(),
      onContinue: ({required name, required birthDate, birthTime}) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _OnboardingPersonalizationPreviewPage(
              modality: modality,
              name: name,
              birthDate: birthDate,
              birthTime: birthTime,
              drawnTarotCard: drawnTarotCard,
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingPersonalizationPreviewPage extends StatefulWidget {
  const _OnboardingPersonalizationPreviewPage({
    required this.modality,
    required this.name,
    required this.birthDate,
    required this.birthTime,
    required this.drawnTarotCard,
  });

  final OnboardingModality modality;
  final String name;
  final String birthDate;
  final String? birthTime;
  final tarot_draw.DrawnTarotCard? drawnTarotCard;

  @override
  State<_OnboardingPersonalizationPreviewPage> createState() =>
      _OnboardingPersonalizationPreviewPageState();
}

class _OnboardingPersonalizationPreviewPageState
    extends State<_OnboardingPersonalizationPreviewPage> {
  String? _relationshipStatus;
  String? _lifeSpace;
  String? _interpretationTone;

  @override
  Widget build(BuildContext context) {
    return OnboardingPersonalizationPage(
      initialRelationshipStatus: _relationshipStatus,
      initialLifeSpace: _lifeSpace,
      initialInterpretationTone: _interpretationTone,
      onBack: () => Navigator.of(context).pop(),
      onContinue:
          ({
            required relationshipStatus,
            required lifeSpace,
            required interpretationTone,
          }) {
            setState(() {
              _relationshipStatus = relationshipStatus;
              _lifeSpace = lifeSpace;
              _interpretationTone = interpretationTone;
            });
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _OnboardingFocusAreasPreviewPage(
                  modality: widget.modality,
                  name: widget.name,
                  birthDate: widget.birthDate,
                  birthTime: widget.birthTime,
                  drawnTarotCard: widget.drawnTarotCard,
                  relationshipStatus: relationshipStatus,
                  lifeSpace: lifeSpace,
                  interpretationTone: interpretationTone,
                ),
              ),
            );
          },
    );
  }
}

class _OnboardingFocusAreasPreviewPage extends StatefulWidget {
  const _OnboardingFocusAreasPreviewPage({
    required this.modality,
    required this.name,
    required this.birthDate,
    required this.birthTime,
    required this.drawnTarotCard,
    required this.relationshipStatus,
    required this.lifeSpace,
    required this.interpretationTone,
  });

  final OnboardingModality modality;
  final String name;
  final String birthDate;
  final String? birthTime;
  final tarot_draw.DrawnTarotCard? drawnTarotCard;
  final String relationshipStatus;
  final String lifeSpace;
  final String interpretationTone;

  @override
  State<_OnboardingFocusAreasPreviewPage> createState() =>
      _OnboardingFocusAreasPreviewPageState();
}

class _OnboardingFocusAreasPreviewPageState
    extends State<_OnboardingFocusAreasPreviewPage> {
  List<String> _focusAreas = const [];

  @override
  Widget build(BuildContext context) {
    return OnboardingFocusAreasPage(
      initialFocusAreas: _focusAreas,
      onBack: () => Navigator.of(context).pop(),
      onContinue: ({required focusAreas}) {
        setState(() => _focusAreas = focusAreas);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OnboardingRevealPage(
              modality: widget.modality,
              name: widget.name,
              birthDate: widget.birthDate,
              focusAreas: focusAreas.toSet(),
              interpretationTone: widget.interpretationTone,
              onBack: () => Navigator.of(context).pop(),
              onContinue: () async {
                try {
                  await AuthService().signInAnonymously();
                } catch (error) {
                  debugPrint('Anonymous paywall sign-in skipped: $error');
                }
                if (!context.mounted) return;
                final uid = FirebaseAuth.instance.currentUser?.uid ?? 'preview';
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => OnboardingPaywallPage(
                      uid: uid,
                      onClose: () => _openAccountPage(context, focusAreas),
                      onContinue: () => _openAccountPage(context, focusAreas),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _openAccountPage(BuildContext context, List<String> focusAreas) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'preview';
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnboardingAccountPage(
          authService: AuthService(),
          uid: uid,
          name: widget.name,
          birthDate: widget.birthDate,
          birthTime: widget.birthTime,
          relationshipStatus: widget.relationshipStatus,
          lifeSpace: widget.lifeSpace,
          interpretationTone: widget.interpretationTone,
          focusAreas: focusAreas,
          onBack: () => Navigator.of(context).pop(),
          onComplete: () => _openCollectedPreview(context, focusAreas),
        ),
      ),
    );
  }

  void _openCollectedPreview(BuildContext context, List<String> focusAreas) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _OnboardingCollectedPreviewPage(
          name: widget.name,
          birthDate: widget.birthDate,
          birthTime: widget.birthTime,
          relationshipStatus: widget.relationshipStatus,
          lifeSpace: widget.lifeSpace,
          interpretationTone: widget.interpretationTone,
          focusAreas: focusAreas,
        ),
      ),
    );
  }
}

class _OnboardingCollectedPreviewPage extends StatelessWidget {
  const _OnboardingCollectedPreviewPage({
    required this.name,
    required this.birthDate,
    required this.birthTime,
    required this.relationshipStatus,
    required this.lifeSpace,
    required this.interpretationTone,
    required this.focusAreas,
  });

  final String name;
  final String birthDate;
  final String? birthTime;
  final String relationshipStatus;
  final String lifeSpace;
  final String interpretationTone;
  final List<String> focusAreas;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17081C),
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            [
              name,
              birthDate,
              if (birthTime != null) birthTime,
              relationshipStatus,
              lifeSpace,
              interpretationTone,
              focusAreas.join(', '),
            ].join('\n'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFADCFF),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class AppStartupLoadingPage extends StatelessWidget {
  const AppStartupLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF17081C),
      body: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
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
