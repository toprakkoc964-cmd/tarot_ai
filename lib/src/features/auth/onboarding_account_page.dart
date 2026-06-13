import 'dart:math' as math;
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_locale.dart';
import '../../core/app_texts.dart';
import '../../core/auth_error_mapper.dart';
import 'auth_service.dart';
import 'legal_pages.dart';
import 'login_page.dart';
import 'onboarding_payload.dart';
import 'register_page.dart';
import 'user_profile_contract.dart';
import 'widgets/mystic_toast.dart';

class OnboardingAccountPage extends StatefulWidget {
  const OnboardingAccountPage({
    super.key,
    required this.authService,
    required this.uid,
    required this.name,
    required this.birthDate,
    required this.birthTime,
    required this.relationshipStatus,
    required this.lifeSpace,
    required this.interpretationTone,
    required this.focusAreas,
    required this.onComplete,
    this.onBack,
  });

  final AuthService authService;
  final String uid;
  final String name;
  final String birthDate;
  final String? birthTime;
  final String relationshipStatus;
  final String lifeSpace;
  final String interpretationTone;
  final List<String> focusAreas;
  final VoidCallback onComplete;
  final VoidCallback? onBack;

  @override
  State<OnboardingAccountPage> createState() => _OnboardingAccountPageState();
}

enum _AccountAction { apple, google, guest }

class _OnboardingAccountPageState extends State<OnboardingAccountPage>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFF17081C);
  static const _surface = Color(0xFF1E0C25);
  static const _surfaceHigh = Color(0xFF361A41);
  static const _primary = Color(0xFFFF5ED6);
  static const _primaryDeep = Color(0xFFFF00D4);
  static const _secondary = Color(0xFFCDBDFF);
  static const _onSurface = Color(0xFFFADCFF);
  static const _gold = Color(0xFFFFE792);
  static const _outline = Color(0xFF5B3C66);
  static const _ctaText = Color(0xFF430036);

  late final AnimationController _glowController;
  _AccountAction? _activeAction;

  bool get _busy => _activeAction != null;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _continueAsGuest() async {
    if (_busy) return;
    setState(() => _activeAction = _AccountAction.guest);
    try {
      await widget.authService.signInAnonymously();
      await _finalizeOnboarding();
    } catch (error) {
      _showError(mapAuthError(error));
    } finally {
      if (mounted) setState(() => _activeAction = null);
    }
  }

  Future<void> _continueWithGoogle() async {
    if (_busy) return;
    setState(() => _activeAction = _AccountAction.google);
    try {
      await widget.authService.signInAnonymously();
      await widget.authService.linkOrSignInWithGoogle();
      await _finalizeOnboarding();
    } catch (error) {
      _showError(mapAuthError(error));
    } finally {
      if (mounted) setState(() => _activeAction = null);
    }
  }

  Future<void> _continueWithApple() async {
    if (_busy) return;
    setState(() => _activeAction = _AccountAction.apple);
    try {
      await widget.authService.signInAnonymously();
      await widget.authService.linkOrSignInWithApple();
      await _finalizeOnboarding();
    } catch (error) {
      _showError(mapAuthError(error));
    } finally {
      if (mounted) setState(() => _activeAction = null);
    }
  }

  Future<void> _finalizeOnboarding() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'missing-user');
    }
    final userDocRef = FirebaseFirestore.instance
        .collection(UserProfileContract.usersCollection)
        .doc(user.uid);
    final existingDoc = await userDocRef.get();
    final existingEmail =
        (existingDoc.data()?[UserProfileContract.email] as String?)?.trim() ??
        '';
    final email = (user.email ?? '').trim().isNotEmpty
        ? user.email!.trim()
        : existingEmail;
    final payload = OnboardingPayload(
      name: UserProfileContract.normalizeName(widget.name),
      birthDate: widget.birthDate,
      privacyAccepted: true,
      termsAccepted: true,
      aiProcessingAccepted: true,
      lang: AppLocale.current,
      selectedPersonaId: 'aris',
      birthTime: widget.birthTime,
      relationshipStatus: widget.relationshipStatus,
      lifeSpace: widget.lifeSpace,
      interpretationTone: widget.interpretationTone,
      focusAreas: widget.focusAreas,
    );
    final map = payload.toUserDocumentMap(
      uid: user.uid,
      email: email,
      isProfileComplete: true,
      includeCreatedAt: !existingDoc.exists,
    );
    map[UserProfileContract.legalConsent] = const UserLegalConsent().toMap();
    if (user.isAnonymous) {
      map[UserProfileContract.provider] = 'anonymous';
      map[UserProfileContract.providers] = const ['anonymous'];
      map[UserProfileContract.providerVerified] = false;
      map[UserProfileContract.emailVerified] = false;
    }
    await userDocRef.set(map, SetOptions(merge: true));
    if (!mounted) return;
    widget.onComplete();
  }

  void _showError(String message) {
    if (!mounted) return;
    MysticToast.showError(context, message);
  }

  void _openLegal(Widget page) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));
  }

  void _openRegister() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RegisterPage(
          authService: widget.authService,
          onSwitchToLogin: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => LoginPage(
                  authService: widget.authService,
                  onSwitchToRegister: () => Navigator.of(context).pop(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openLogin() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LoginPage(
          authService: widget.authService,
          onSwitchToRegister: _openRegister,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _AccountBackground()),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                10,
                22,
                math.max(18, bottom + 8),
              ),
              child: Column(
                children: [
                  _topBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 22),
                          _hero(),
                          const SizedBox(height: 22),
                          _consentBox(),
                          const SizedBox(height: 18),
                          _actions(),
                          const SizedBox(height: 18),
                          _emailLinks(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        if (widget.onBack != null)
          IconButton(
            onPressed: _busy ? null : widget.onBack,
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: _secondary,
              size: 34,
            ),
          )
        else
          const SizedBox(width: 48),
        const Spacer(),
      ],
    );
  }

  Widget _hero() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            return Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [_primary, _gold]),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(
                      alpha: 0.28 + _glowController.value * 0.16,
                    ),
                    blurRadius: 34,
                    spreadRadius: 1,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(2),
              child: child,
            );
          },
          child: ClipOval(
            child: Image.asset(
              'assets/onboarding/madam_aris.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: _surfaceHigh,
                child: Icon(Icons.auto_awesome_rounded, color: _gold, size: 44),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          AppTexts.t('onboarding.account.title'),
          textAlign: TextAlign.center,
          style: GoogleFonts.newsreader(
            color: _onSurface,
            fontSize: 42,
            height: 1.04,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(color: _primary.withValues(alpha: 0.28), blurRadius: 18),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppTexts.t('onboarding.account.subtitle'),
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: _secondary.withValues(alpha: 0.86),
            fontSize: 15.5,
            height: 1.42,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _consentBox() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _outline.withValues(alpha: 0.46)),
          ),
          child: Column(
            children: [
              Text(
                AppTexts.t('onboarding.account.consent'),
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: _secondary.withValues(alpha: 0.84),
                  fontSize: 12.5,
                  height: 1.42,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: [
                  _legalLink(
                    AppTexts.t('shopTermsOfUse'),
                    () => _openLegal(const TermsOfServicePage()),
                  ),
                  _legalLink(
                    AppTexts.t('shopPrivacyPolicy'),
                    () => _openLegal(const PrivacyPolicyPage()),
                  ),
                  _legalLink(
                    AppTexts.t('legal.ai_notice.title'),
                    () => _openLegal(const AiUsageNoticePage()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legalLink(String label, VoidCallback onTap) {
    return TextButton(
      onPressed: _busy ? null : onTap,
      style: TextButton.styleFrom(
        foregroundColor: _primary,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _actions() {
    return Column(
      children: [
        _actionButton(
          label: AppTexts.t('onboarding.account.apple'),
          icon: Icons.apple_rounded,
          action: _AccountAction.apple,
          primary: true,
          onTap: _continueWithApple,
        ),
        const SizedBox(height: 12),
        _actionButton(
          label: AppTexts.t('onboarding.account.google'),
          icon: Icons.g_mobiledata_rounded,
          action: _AccountAction.google,
          onTap: _continueWithGoogle,
        ),
        const SizedBox(height: 12),
        _actionButton(
          label: AppTexts.t('onboarding.account.guest'),
          icon: Icons.person_outline_rounded,
          action: _AccountAction.guest,
          onTap: _continueAsGuest,
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required _AccountAction action,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    final loading = _activeAction == action;
    final enabled = !_busy || loading;
    return GestureDetector(
      onTap: enabled && !loading ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: enabled ? 1 : 0.58,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            gradient: primary
                ? const LinearGradient(colors: [_primary, _primaryDeep])
                : null,
            color: primary ? null : _surfaceHigh.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: primary
                  ? _primary.withValues(alpha: 0.52)
                  : _outline.withValues(alpha: 0.58),
            ),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: _primaryDeep.withValues(alpha: 0.28),
                      blurRadius: 22,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _ctaText,
                  ),
                )
              else
                Icon(icon, color: primary ? _ctaText : _gold, size: 26),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  color: primary ? _ctaText : _onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emailLinks() {
    return Column(
      children: [
        TextButton(
          onPressed: _busy ? null : _openRegister,
          child: Text(AppTexts.t('onboarding.account.email_register')),
        ),
        TextButton(
          onPressed: _busy ? null : _openLogin,
          child: Text(AppTexts.t('onboarding.account.login')),
        ),
      ],
    );
  }
}

class _AccountBackground extends StatelessWidget {
  const _AccountBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.22,
          colors: [Color(0xFF32133B), Color(0xFF17081C), Color(0xFF120516)],
          stops: [0, 0.62, 1],
        ),
      ),
      child: CustomPaint(painter: _AccountStarsPainter()),
    );
  }
}

class _AccountStarsPainter extends CustomPainter {
  const _AccountStarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 30; i++) {
      paint.color =
          (i.isEven
                  ? _OnboardingAccountPalette.gold
                  : _OnboardingAccountPalette.secondary)
              .withValues(alpha: i % 5 == 0 ? 0.36 : 0.18);
      canvas.drawCircle(
        Offset((i * 89.0) % size.width, (i * 131.0) % size.height),
        i % 6 == 0 ? 1.8 : 1.0,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OnboardingAccountPalette {
  const _OnboardingAccountPalette._();

  static const gold = Color(0xFFFFE792);
  static const secondary = Color(0xFFCDBDFF);
}
