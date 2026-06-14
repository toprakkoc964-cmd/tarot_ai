import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_legal_urls.dart';
import '../../core/app_texts.dart';
import '../../core/auth_error_mapper.dart';
import '../../core/language_picker_button.dart';
import '../../core/localization_service.dart';
import '../../core/theme/app_colors.dart';
import 'auth_service.dart';
import 'legal_pages.dart';
import 'user_profile_contract.dart';
import 'verify_email_page.dart';
import 'widgets/falling_mystic_symbols.dart';
import 'widgets/mystic_legal_checkbox.dart';
import 'widgets/mystic_primary_button.dart';
import 'widgets/registration_portal_transition_overlay.dart';
import 'widgets/mystic_register_text_field.dart';
import 'widgets/mystic_toast.dart';

enum RegisterSubmitState {
  idle,
  validating,
  submitting,
  successAnimating,
  navigating,
  error,
}

const _registrationPortalDuration = Duration(milliseconds: 1500);
const _registerSubmitCooldown = Duration(milliseconds: 1400);
const _blockedEmailDomains = <String>{
  '10minutemail.com',
  'guerrillamail.com',
  'mailinator.com',
  'tempmail.com',
  'temp-mail.org',
  'yopmail.com',
};

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.authService,
    required this.onSwitchToLogin,
  });

  final AuthService authService;
  final VoidCallback onSwitchToLogin;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();

  RegisterSubmitState _submitState = RegisterSubmitState.idle;
  bool _acceptedTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmationError;
  String? _termsError;
  DateTime? _lastSubmitAttemptAt;

  bool get _isBusy =>
      _submitState == RegisterSubmitState.validating ||
      _submitState == RegisterSubmitState.submitting ||
      _submitState == RegisterSubmitState.successAnimating ||
      _submitState == RegisterSubmitState.navigating;

  bool get _isSubmitting => _submitState == RegisterSubmitState.submitting;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  bool _validateForm() {
    if (mounted) {
      setState(() => _submitState = RegisterSubmitState.validating);
    }

    final name = UserProfileContract.normalizeName(_nameController.text);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmation = _confirmController.text;

    final nameError = name.isEmpty
        ? AppTexts.t('auth.register.name_required')
        : name.length < 2
        ? AppTexts.t('auth.register.name_too_short')
        : null;
    final emailError = email.isEmpty
        ? AppTexts.t('auth.register.email_required')
        : !_isValidEmail(email)
        ? AppTexts.t('auth.register.invalid_email')
        : _isDisposableEmail(email)
        ? AppTexts.t('auth.register.disposable_email')
        : null;
    final passwordError = password.isEmpty
        ? AppTexts.t('auth.register.password_required')
        : password.length < 6
        ? AppTexts.t('auth.register.password_too_short')
        : null;
    final confirmationError = confirmation.isEmpty
        ? AppTexts.t('auth.register.confirm_required')
        : password != confirmation
        ? AppTexts.t('auth.register.passwords_not_match')
        : null;
    final termsError = !_acceptedTerms
        ? AppTexts.t('auth.register.terms_required')
        : null;

    final isValid =
        nameError == null &&
        emailError == null &&
        passwordError == null &&
        confirmationError == null &&
        termsError == null;

    setState(() {
      _nameError = nameError;
      _emailError = emailError;
      _passwordError = passwordError;
      _confirmationError = confirmationError;
      _termsError = termsError;
      _submitState = isValid
          ? RegisterSubmitState.idle
          : RegisterSubmitState.error;
    });

    return isValid;
  }

  Future<void> _register() async {
    final now = DateTime.now();
    final lastAttempt = _lastSubmitAttemptAt;
    if (_isBusy ||
        (lastAttempt != null &&
            now.difference(lastAttempt) < _registerSubmitCooldown)) {
      return;
    }
    _lastSubmitAttemptAt = now;
    if (!_validateForm()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitState = RegisterSubmitState.submitting);
    widget.authService.registrationRedirectSuppressed.value = true;
    var createdAccount = false;

    try {
      final name = UserProfileContract.normalizeName(_nameController.text);
      final email = _emailController.text.trim();
      final credential = await widget.authService.register(
        email: email,
        password: _passwordController.text,
      );

      final user = credential.user ?? FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw FirebaseAuthException(code: 'user-missing-after-register');
      }
      createdAccount = true;

      await _persistProfile(
        user: user,
        fallbackEmail: email,
        fallbackName: name,
      );

      if (mounted) {
        setState(() => _submitState = RegisterSubmitState.successAnimating);
      }
      await _playPortalTransition();

      if (mounted) {
        setState(() => _submitState = RegisterSubmitState.navigating);
      }
      if (mounted) {
        _openVerifyEmailPage(user);
      }
      _releaseRegistrationTransitionGuards();
    } catch (error) {
      widget.authService.registrationPortalActive.value = false;
      if ((createdAccount || FirebaseAuth.instance.currentUser != null) &&
          FirebaseAuth.instance.currentUser != null) {
        try {
          await widget.authService.deleteCurrentUserCompletely();
        } catch (_) {
          // Avoid masking the original registration failure.
        }
        try {
          await widget.authService.signOut();
        } catch (_) {}
      }
      widget.authService.registrationRedirectSuppressed.value = false;
      if (!mounted) return;
      setState(() => _submitState = RegisterSubmitState.error);
      _showError(mapRegisterError(error));
    }
  }

  bool _isDisposableEmail(String email) {
    final domain = email.split('@').last.trim().toLowerCase();
    return _blockedEmailDomains.contains(domain);
  }

  Future<void> _persistProfile({
    required User user,
    String fallbackName = '',
    String fallbackEmail = '',
  }) async {
    final userDocRef = FirebaseFirestore.instance
        .collection(UserProfileContract.usersCollection)
        .doc(user.uid);
    final existing = await userDocRef.get();
    final existingData = existing.data();
    final existingName = UserProfileContract.normalizeName(
      (existingData?[UserProfileContract.name] as String?) ?? '',
    );
    final resolvedName = UserProfileContract.normalizeName(
      fallbackName.isNotEmpty
          ? fallbackName
          : existingName.isNotEmpty
          ? existingName
          : user.displayName ?? '',
    );
    final resolvedEmail = user.email?.trim().isNotEmpty == true
        ? user.email!.trim()
        : fallbackEmail;

    await userDocRef.set(
      UserProfileWrite(
        uid: user.uid,
        email: resolvedEmail,
        name: resolvedName,
        legalConsent: const UserLegalConsent(),
        isProfileComplete: false,
        onboardingCompleted: false,
        accountStatus: UserProfileContract.statusPendingEmailVerification,
        emailVerified: user.emailVerified,
        provider: 'password',
        providers: const ['password'],
        providerVerified: false,
        cleanupEligible: true,
        verificationEmailSentAt: FieldValue.serverTimestamp(),
        verificationDeadlineAt: Timestamp.fromDate(
          DateTime.now().add(
            const Duration(hours: AuthService.verificationTtlHours),
          ),
        ),
        verificationResendCount: 0,
        verificationResendWindowStartedAt: FieldValue.serverTimestamp(),
        includeCreatedAt: !existing.exists,
      ).toMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> _playPortalTransition() async {
    widget.authService.registrationPortalActive.value = true;
    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 650));
    await HapticFeedback.selectionClick();
    await Future<void>.delayed(
      _registrationPortalDuration - const Duration(milliseconds: 650),
    );
    widget.authService.registrationPortalActive.value = false;
  }

  void _openVerifyEmailPage(User user) {
    final navigator = Navigator.of(context, rootNavigator: true);
    debugPrint('[register] opening verify email page uid=${user.uid}');
    unawaited(
      navigator.pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) => VerifyEmailPage(
            authService: widget.authService,
            user: user,
            onVerified: () {
              Navigator.of(
                context,
                rootNavigator: true,
              ).popUntil((route) => route.isFirst);
            },
            onChangeEmail: () {
              Navigator.of(
                context,
                rootNavigator: true,
              ).pushReplacement<void, void>(
                MaterialPageRoute<void>(
                  builder: (_) => RegisterPage(
                    authService: widget.authService,
                    onSwitchToLogin: widget.onSwitchToLogin,
                  ),
                ),
              );
            },
          ),
        ),
        (route) => route.isFirst,
      ),
    );
  }

  void _releaseRegistrationTransitionGuards() {
    widget.authService.registrationPortalActive.value = false;
    widget.authService.registrationRedirectSuppressed.value = false;
  }

  Future<void> _openLegal(String url, Widget fallbackPage) async {
    if (_isBusy) return;
    try {
      if (await AppLegalUrls.launch(url)) return;
    } catch (_) {
      // Fall back to the bundled legal page so review links remain available.
    }

    if (!mounted) return;
    MysticToast.showError(
      context,
      AppTexts.t('auth.register.legal_link_error'),
    );
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => fallbackPage));
  }

  void _showError(String message) {
    if (!mounted) return;
    MysticToast.showError(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LocalizationService.instance.revision,
      builder: (context, _, __) {
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: AppColors.background,
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Stack(
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topRight,
                      radius: 1.24,
                      colors: [
                        AppColors.cosmicGradientTop,
                        AppColors.background,
                      ],
                    ),
                  ),
                  child: SizedBox.expand(),
                ),
                const FallingMysticSymbols(),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: AnimatedPadding(
                          duration: const Duration(milliseconds: 180),
                          padding: EdgeInsets.only(
                            top: 12,
                            bottom: keyboardInset > 0 ? 18 : 26,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight:
                                  constraints.maxHeight -
                                  (keyboardInset > 0 ? 30 : 38),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildTopBar(),
                                const SizedBox(height: 16),
                                _buildHero(),
                                const SizedBox(height: 20),
                                _buildForm(),
                                const SizedBox(height: 16),
                                _buildLegalArea(),
                                const SizedBox(height: 18),
                                MysticPrimaryButton(
                                  label: AppTexts.t(
                                    _isSubmitting
                                        ? 'auth.register.button_loading'
                                        : 'auth.register.button',
                                  ),
                                  loading: _isSubmitting,
                                  onPressed: _isBusy ? null : _register,
                                ),
                                const SizedBox(height: 12),
                                _buildLoginLink(),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_submitState == RegisterSubmitState.successAnimating ||
                    _submitState == RegisterSubmitState.navigating)
                  const RegistrationPortalTransitionOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: AppTexts.t('auth.register.switch_action'),
          onPressed: _isBusy ? null : widget.onSwitchToLogin,
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.tertiaryGold,
            size: 20,
          ),
        ),
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.tertiaryGold),
                image: const DecorationImage(
                  image: AssetImage('images/chatgpt_logo.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AppTexts.t('auth.register.guide'),
              style: GoogleFonts.inter(
                color: AppColors.tertiaryGold,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        LanguagePickerButton(
          iconColor: AppColors.primaryPink,
          onSelected: (lang) async {
            await LocalizationService.instance.setLanguage(lang);
            if (mounted) setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Column(
      children: [
        const Icon(
          Icons.auto_awesome_rounded,
          color: AppColors.primaryPink,
          size: 24,
        ),
        const SizedBox(height: 5),
        Text(
          AppTexts.t('auth.register.title'),
          textAlign: TextAlign.center,
          style: GoogleFonts.cormorantGaramond(
            color: AppColors.onSurface,
            fontSize: 38,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          AppTexts.t('auth.register.subtitle'),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: AppColors.secondaryLavender,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        MysticRegisterTextField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          label: AppTexts.t('auth.register.name_label'),
          hint: AppTexts.t('auth.register.name_hint'),
          errorText: _nameError,
          textInputAction: TextInputAction.next,
          maxLength: UserProfileContract.maxNameLength,
          enabled: !_isBusy,
          onSubmitted: (_) => _emailFocusNode.requestFocus(),
        ),
        const SizedBox(height: 10),
        MysticRegisterTextField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          label: AppTexts.t('auth.register.email_label'),
          hint: AppTexts.t('auth.register.email_hint'),
          errorText: _emailError,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          enabled: !_isBusy,
          onSubmitted: (_) => _passwordFocusNode.requestFocus(),
        ),
        const SizedBox(height: 10),
        MysticRegisterTextField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          label: AppTexts.t('auth.register.password_label'),
          hint: AppTexts.t('auth.register.password_hint'),
          errorText: _passwordError,
          obscureText: _obscurePassword,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          enabled: !_isBusy,
          suffixIcon: _passwordToggle(
            obscure: _obscurePassword,
            onPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
          ),
          onSubmitted: (_) => _confirmFocusNode.requestFocus(),
        ),
        const SizedBox(height: 10),
        MysticRegisterTextField(
          controller: _confirmController,
          focusNode: _confirmFocusNode,
          label: AppTexts.t('auth.register.confirm_label'),
          hint: AppTexts.t('auth.register.confirm_hint'),
          errorText: _confirmationError,
          obscureText: _obscureConfirmation,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          enabled: !_isBusy,
          suffixIcon: _passwordToggle(
            obscure: _obscureConfirmation,
            onPressed: () {
              setState(() => _obscureConfirmation = !_obscureConfirmation);
            },
          ),
          onSubmitted: (_) => _register(),
        ),
      ],
    );
  }

  Widget _passwordToggle({
    required bool obscure,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: AppTexts.t(
        obscure ? 'auth.register.show_password' : 'auth.register.hide_password',
      ),
      onPressed: _isBusy ? null : onPressed,
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: AppColors.secondaryLavender,
      ),
    );
  }

  Widget _buildLegalArea() {
    return MysticLegalCheckbox(
      value: _acceptedTerms,
      errorText: _termsError,
      onChanged: (value) {
        if (_isBusy) return;
        setState(() {
          _acceptedTerms = value;
          if (value) _termsError = null;
        });
      },
      onTermsPressed: () =>
          _openLegal(AppLegalUrls.terms, const TermsOfServicePage()),
      onPrivacyPressed: () =>
          _openLegal(AppLegalUrls.privacy, const PrivacyPolicyPage()),
      onAiNoticePressed: () =>
          _openLegal(AppLegalUrls.aiNotice, const AiUsageNoticePage()),
    );
  }

  Widget _buildLoginLink() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 3,
      children: [
        Text(
          AppTexts.t('auth.register.switch_prefix'),
          style: GoogleFonts.inter(
            color: AppColors.secondaryLavender,
            fontSize: 13,
          ),
        ),
        TextButton(
          onPressed: _isBusy ? null : widget.onSwitchToLogin,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryPink,
            minimumSize: const Size(44, 44),
          ),
          child: Text(
            AppTexts.t('auth.register.switch_action'),
            style: GoogleFonts.inter(
              color: AppColors.primaryPink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
