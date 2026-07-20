import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_navigator.dart';
import '../../core/app_review_service.dart';
import '../../core/notification_service.dart';
import '../../../services/notification_service.dart' as local_notifications;
import 'auth_service.dart';
import 'onboarding_account_page.dart';
import 'onboarding_card_pick_page.dart';
import 'onboarding_coffee_ritual_page.dart';
import 'onboarding_focus_areas_page.dart';
import 'onboarding_name_birth_page.dart';
import 'onboarding_paywall_page.dart';
import 'onboarding_palm_scan_page.dart';
import 'onboarding_personalization_page.dart';
import 'onboarding_reveal_page.dart';
import 'onboarding_tarot_draw_page.dart' as tarot_draw;
import 'onboarding_welcome_page.dart';

class OnboardingFlowEntry extends StatefulWidget {
  const OnboardingFlowEntry({super.key, required this.authService});

  final AuthService authService;

  @override
  State<OnboardingFlowEntry> createState() => _OnboardingFlowEntryState();
}

class _OnboardingFlowEntryState extends State<OnboardingFlowEntry> {
  static const _permissionPromptSeenKey = 'notification_decision_made';

  OnboardingModality? _modality;
  String _name = '';
  String _birthDate = '';
  String? _birthTime;
  String? _relationshipStatus;
  String? _lifeSpace;
  String? _interpretationTone;
  List<String> _focusAreas = const [];
  bool _navBusy = false;
  Timer? _navRetryTimer;
  Future<void>? _guestSessionFuture;

  @override
  Widget build(BuildContext context) {
    return OnboardingWelcomePage(onStart: _openCardPick);
  }

  @override
  void dispose() {
    _navRetryTimer?.cancel();
    super.dispose();
  }

  Future<void> _ensureGuestSession() {
    if (FirebaseAuth.instance.currentUser != null) {
      return Future<void>.value();
    }
    return _guestSessionFuture ??= _createGuestSession();
  }

  Future<void> _createGuestSession() async {
    try {
      await widget.authService.signInAnonymously();
    } catch (error) {
      debugPrint('Anonymous onboarding sign-in skipped: $error');
    }
  }

  Future<void> _maybePromptNotificationPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool(_permissionPromptSeenKey) ?? false;
    if (alreadyPrompted || !mounted) return;
    final status = NotificationService.instance.permissionStatus.value;
    if (status != 'notDetermined' && status != 'unknown') return;

    await prefs.setBool(_permissionPromptSeenKey, true);
    await local_notifications.NotificationService.instance.requestPermissions();
    await NotificationService.instance.requestNotificationPermissions();
  }

  bool _beginNav({VoidCallback? retry}) {
    if (_navBusy) {
      if (retry != null && _navRetryTimer == null) {
        _navRetryTimer = Timer(const Duration(milliseconds: 520), () {
          _navRetryTimer = null;
          if (mounted) retry();
        });
      }
      return false;
    }
    _navBusy = true;
    Future.delayed(const Duration(milliseconds: 500), () {
      _navBusy = false;
    });
    return true;
  }

  void _openCardPick() {
    if (!_beginNav()) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnboardingCardPickPage(
          onModalityChosen: (modality) {
            _modality = modality;
            _openSelectedRitual();
          },
        ),
      ),
    );
  }

  void _openSelectedRitual() {
    final modality = _modality ?? OnboardingModality.tarot;
    if (modality == OnboardingModality.tarot) {
      _openTarotDraw();
      return;
    }
    if (modality == OnboardingModality.palm) {
      _openPalmScan();
      return;
    }
    _openCoffeeRitual(modality);
  }

  void _openTarotDraw({bool replace = false, bool retryIfBusy = true}) {
    if (!_beginNav(
      retry: retryIfBusy
          ? () => _openTarotDraw(replace: replace, retryIfBusy: false)
          : null,
    )) {
      return;
    }
    final route = MaterialPageRoute<void>(
      builder: (_) => tarot_draw.OnboardingTarotDrawPage(
        name: _name,
        onCardDrawn: (card) {
          _openNameBirth();
        },
      ),
    );
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  void _openPalmScan({bool retryIfBusy = true}) {
    if (!_beginNav(
      retry: retryIfBusy ? () => _openPalmScan(retryIfBusy: false) : null,
    )) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnboardingPalmScanPage(
          name: _name,
          onBack: () => Navigator.of(context).pop(),
          onPalmCaptured: (palmTeaserKey) {
            _openNameBirth();
          },
          onModalitySwitch: (newModality) {
            _modality = newModality;
            if (newModality == OnboardingModality.tarot) {
              _openTarotDraw(replace: true);
              return;
            }
            _openCoffeeRitual(newModality, replace: true);
          },
        ),
      ),
    );
  }

  void _openCoffeeRitual(
    OnboardingModality modality, {
    bool replace = false,
    bool retryIfBusy = true,
  }) {
    if (!_beginNav(
      retry: retryIfBusy
          ? () => _openCoffeeRitual(
              modality,
              replace: replace,
              retryIfBusy: false,
            )
          : null,
    )) {
      return;
    }
    final route = MaterialPageRoute<void>(
      builder: (_) => OnboardingCoffeeRitualPage(
        name: _name,
        onCoffeeSealed: (coffeeTeaserKey) {
          _openNameBirth();
        },
      ),
    );
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  void _openNameBirth({bool retryIfBusy = true}) {
    if (!_beginNav(
      retry: retryIfBusy ? () => _openNameBirth(retryIfBusy: false) : null,
    )) {
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'onboarding';
    final navigator = _navigator();
    if (navigator == null) {
      debugPrint(
        '[onboarding-flow] name/birth navigation skipped: no navigator',
      );
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => OnboardingNameBirthPage(
          authService: widget.authService,
          uid: uid,
          onContinue: ({required name, required birthDate, birthTime}) {
            _name = name;
            _birthDate = birthDate;
            _birthTime = birthTime;
            _openPersonalization();
          },
        ),
      ),
    );
  }

  void _openPersonalization({bool retryIfBusy = true}) {
    if (!_beginNav(
      retry: retryIfBusy
          ? () => _openPersonalization(retryIfBusy: false)
          : null,
    )) {
      return;
    }
    final navigator = _navigator();
    if (navigator == null) {
      debugPrint(
        '[onboarding-flow] personalization navigation skipped: no navigator',
      );
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => OnboardingPersonalizationPage(
          initialRelationshipStatus: _relationshipStatus,
          initialLifeSpace: _lifeSpace,
          initialInterpretationTone: _interpretationTone,
          onContinue:
              ({
                required relationshipStatus,
                required lifeSpace,
                required interpretationTone,
              }) {
                _relationshipStatus = relationshipStatus;
                _lifeSpace = lifeSpace;
                _interpretationTone = interpretationTone;
                _openFocusAreas();
              },
        ),
      ),
    );
  }

  void _openFocusAreas({bool retryIfBusy = true}) {
    if (!_beginNav(
      retry: retryIfBusy ? () => _openFocusAreas(retryIfBusy: false) : null,
    )) {
      return;
    }
    final navigator = _navigator();
    if (navigator == null) {
      debugPrint('[onboarding-flow] focus navigation skipped: no navigator');
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => OnboardingFocusAreasPage(
          initialFocusAreas: _focusAreas,
          onContinue: ({required focusAreas}) {
            _focusAreas = focusAreas;
            _openReveal();
          },
        ),
      ),
    );
  }

  void _openReveal({bool retryIfBusy = true}) {
    if (!_beginNav(
      retry: retryIfBusy ? () => _openReveal(retryIfBusy: false) : null,
    )) {
      return;
    }
    final navigator = _navigator();
    if (navigator == null) {
      debugPrint('[onboarding-flow] reveal navigation skipped: no navigator');
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => OnboardingRevealPage(
          modality: _modality ?? OnboardingModality.tarot,
          name: _name,
          birthDate: _birthDate,
          focusAreas: _focusAreas.toSet(),
          interpretationTone: _interpretationTone ?? 'soft',
          onContinue: () async {
            await _ensureGuestSession();
            await _maybePromptNotificationPermission();
            _openPaywall();
          },
        ),
      ),
    );
  }

  void _openPaywall({bool retryIfBusy = true}) {
    if (!_beginNav(
      retry: retryIfBusy ? () => _openPaywall(retryIfBusy: false) : null,
    )) {
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'onboarding';
    final navigator = _navigator();
    if (navigator == null) {
      debugPrint('[onboarding-flow] paywall navigation skipped: no navigator');
      return;
    }
    debugPrint('[onboarding-flow] opening paywall uid=$uid');
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => OnboardingPaywallPage(
          uid: uid,
          onClose: () => _openAccount(replace: true),
          onContinue: () => _openAccount(replace: true),
          nextPageBuilder: (_) => _buildAccountPage(uid),
        ),
      ),
    );
  }

  void _openAccount({bool replace = false, bool retryIfBusy = true}) {
    if (!_beginNav(
      retry: retryIfBusy
          ? () => _openAccount(replace: replace, retryIfBusy: false)
          : null,
    )) {
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'onboarding';
    debugPrint(
      '[onboarding-flow] opening account uid=$uid replace=$replace '
      'mounted=$mounted',
    );
    final route = MaterialPageRoute<void>(
      builder: (_) => _buildAccountPage(uid),
    );
    final navigator = _navigator();
    if (navigator == null) {
      debugPrint('[onboarding-flow] account navigation skipped: no navigator');
      return;
    }
    if (replace) {
      navigator.pushReplacement(route);
    } else {
      navigator.push(route);
    }
  }

  NavigatorState? _navigator() {
    return appNavigatorKey.currentState ??
        (mounted ? Navigator.of(context) : null);
  }

  Widget _buildAccountPage(String uid) {
    return OnboardingAccountPage(
      authService: widget.authService,
      uid: uid,
      name: _name,
      birthDate: _birthDate,
      birthTime: _birthTime,
      relationshipStatus: _relationshipStatus ?? 'single',
      lifeSpace: _lifeSpace ?? 'other',
      interpretationTone: _interpretationTone ?? 'soft',
      focusAreas: _focusAreas,
      onComplete: _finishOnboarding,
      autoCompleteAuthenticatedUser: true,
      preventBack: true,
    );
  }

  void _finishOnboarding() {
    debugPrint('[onboarding-flow] account complete; returning to app root');
    unawaited(AppReviewService.instance.markPendingAfterOnboarding());
    final navigator = appNavigatorKey.currentState;
    if (navigator != null) {
      navigator.popUntil((route) => route.isFirst);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
