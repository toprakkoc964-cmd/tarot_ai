import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_texts.dart';
import '../../core/auth_error_mapper.dart';
import '../../core/language_picker_button.dart';
import '../../core/localization_service.dart';
import '../../core/theme/app_colors.dart';
import 'auth_service.dart';
import 'legal_pages.dart';
import 'register_page.dart';
import 'widgets/forgot_password_bottom_sheet.dart';
import 'widgets/login_legal_footer.dart';
import 'widgets/mystic_primary_button.dart';
import 'widgets/mystic_social_button.dart';
import 'widgets/mystic_text_field.dart';
import 'widgets/mystic_toast.dart';

enum _LoginAction { email, google, apple }

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.authService,
    required this.onSwitchToRegister,
  });

  final AuthService authService;
  final VoidCallback onSwitchToRegister;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  _LoginAction? _activeAction;
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;

  bool get _isBusy => _activeAction != null;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  bool _validateCredentials() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final emailError = email.isEmpty
        ? AppTexts.t('auth.login.email_required')
        : !_isValidEmail(email)
        ? AppTexts.t('auth.login.invalid_email')
        : null;
    final passwordError = password.isEmpty
        ? AppTexts.t('auth.login.password_required')
        : password.length < 6
        ? AppTexts.t('auth.login.password_too_short')
        : null;

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
    return emailError == null && passwordError == null;
  }

  Future<void> _signIn() async {
    if (_isBusy || !_validateCredentials()) return;
    FocusScope.of(context).unfocus();
    setState(() => _activeAction = _LoginAction.email);

    try {
      debugPrint('[login] email sign-in started');
      await widget.authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      debugPrint('[login] email sign-in ok');
    } catch (error) {
      _logAuthError('email', error);
      _showError(mapAuthError(error));
    } finally {
      if (mounted) setState(() => _activeAction = null);
    }
  }

  Future<void> _resetPassword() async {
    if (_isBusy) return;
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();

    if (email.isEmpty || !_isValidEmail(email)) {
      final sent = await showForgotPasswordBottomSheet(
        context: context,
        authService: widget.authService,
        initialEmail: email,
      );
      if (sent == true && mounted) {
        MysticToast.showSuccess(
          context,
          AppTexts.t('auth.forgot_password.success'),
        );
      }
      return;
    }

    try {
      await widget.authService.sendResetEmail(email);
      if (mounted) {
        MysticToast.showSuccess(
          context,
          AppTexts.t('auth.forgot_password.success'),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found' ||
          error.code == 'invalid-recipient-email') {
        if (mounted) {
          MysticToast.showSuccess(
            context,
            AppTexts.t('auth.forgot_password.success'),
          );
        }
        return;
      }
      _showError(AppTexts.t('auth.forgot_password.error'));
    } catch (_) {
      _showError(AppTexts.t('auth.forgot_password.error'));
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isBusy) return;
    FocusScope.of(context).unfocus();
    setState(() => _activeAction = _LoginAction.google);
    try {
      debugPrint('[login] google sign-in started');
      final error = await widget.authService.signInWithGoogle();
      if (error != null) {
        _logAuthError('google', error);
        _showError(mapAuthError(error));
        return;
      }
      debugPrint('[login] google sign-in ok');
    } finally {
      if (mounted) setState(() => _activeAction = null);
    }
  }

  Future<void> _signInWithApple() async {
    if (_isBusy) return;
    FocusScope.of(context).unfocus();
    setState(() => _activeAction = _LoginAction.apple);
    try {
      debugPrint('[login] apple sign-in started');
      await widget.authService.signInWithApple();
      debugPrint('[login] apple sign-in ok');
    } catch (error) {
      _logAuthError('apple', error);
      _showError(mapAuthError(error));
    } finally {
      if (mounted) setState(() => _activeAction = null);
    }
  }

  void _logAuthError(String action, Object error) {
    if (error is FirebaseAuthException) {
      debugPrint(
        '[login] $action failed FirebaseAuthException '
        'code=${error.code} message=${error.message}',
      );
      return;
    }
    if (error is FirebaseException) {
      debugPrint(
        '[login] $action failed FirebaseException '
        'plugin=${error.plugin} code=${error.code} message=${error.message}',
      );
      return;
    }
    debugPrint('[login] $action failed $error');
  }

  void _showError(String message) {
    if (!mounted) return;
    MysticToast.showError(context, message);
  }

  void _openLegalPage(Widget page) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _openRegisterPage() {
    if (_isBusy) return;
    FocusScope.of(context).unfocus();
    debugPrint('[login] opening register page');
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RegisterPage(
          authService: widget.authService,
          onSwitchToLogin: () => Navigator.of(context).pop(),
        ),
      ),
    );
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
            onTap: () => FocusScope.of(context).unfocus(),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.cosmicGradientTop,
                    AppColors.background,
                    AppColors.background,
                  ],
                ),
              ),
              child: CustomPaint(
                painter: const _CosmicLoginBackgroundPainter(),
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: AnimatedPadding(
                          duration: const Duration(milliseconds: 180),
                          padding: EdgeInsets.only(
                            top: 14,
                            bottom: keyboardInset > 0 ? 18 : 26,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight:
                                  constraints.maxHeight -
                                  (keyboardInset > 0 ? 32 : 40),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildTopBar(),
                                const SizedBox(height: 28),
                                _buildHero(),
                                const SizedBox(height: 24),
                                _buildForm(),
                                const SizedBox(height: 22),
                                _buildSocialArea(),
                                const SizedBox(height: 18),
                                _buildRegisterLink(),
                                const SizedBox(height: 22),
                                LoginLegalFooter(
                                  onTermsPressed: () => _openLegalPage(
                                    const TermsOfServicePage(),
                                  ),
                                  onPrivacyPressed: () =>
                                      _openLegalPage(const PrivacyPolicyPage()),
                                  onAiNoticePressed: () =>
                                      _openLegalPage(const AiUsageNoticePage()),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
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
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.tertiaryGold.withValues(alpha: 0.85),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.tertiaryGold.withValues(alpha: 0.18),
                    blurRadius: 14,
                  ),
                ],
                image: const DecorationImage(
                  image: AssetImage('images/chatgpt_logo.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Text(
              AppTexts.t('auth.login.guide'),
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
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryNeonPink.withValues(alpha: 0.28),
                blurRadius: 28,
              ),
              BoxShadow(
                color: AppColors.tertiaryGold.withValues(alpha: 0.16),
                blurRadius: 42,
              ),
            ],
          ),
          child: Image.asset('images/chatgpt_logo.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 12),
        Text(
          AppTexts.t('auth.login.title'),
          textAlign: TextAlign.center,
          style: GoogleFonts.cormorantGaramond(
            color: AppColors.onSurface,
            fontSize: 38,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          AppTexts.t('auth.login.subtitle'),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: AppColors.secondaryLavender.withValues(alpha: 0.84),
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MysticTextField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            label: AppTexts.t('auth.login.email_label'),
            hint: AppTexts.t('auth.login.email_hint'),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            errorText: _emailError,
            onSubmitted: (_) => _passwordFocusNode.requestFocus(),
          ),
          const SizedBox(height: 15),
          MysticTextField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            label: AppTexts.t('auth.login.password_label'),
            hint: AppTexts.t('auth.login.password_hint'),
            textInputAction: TextInputAction.done,
            errorText: _passwordError,
            obscureText: _obscurePassword,
            enableSuggestions: false,
            suffixIcon: IconButton(
              tooltip: AppTexts.t(
                _obscurePassword
                    ? 'auth.login.show_password'
                    : 'auth.login.hide_password',
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.secondaryLavender,
              ),
            ),
            onSubmitted: (_) => _signIn(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isBusy ? null : _resetPassword,
              child: Text(
                AppTexts.t('auth.login.forgot_password'),
                style: GoogleFonts.inter(
                  color: AppColors.tertiaryGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          MysticPrimaryButton(
            label: AppTexts.t(
              _activeAction == _LoginAction.email
                  ? 'auth.login.submit_loading'
                  : 'auth.login.submit',
            ),
            loading: _activeAction == _LoginAction.email,
            onPressed: _isBusy ? null : _signIn,
          ),
        ],
      ),
    );
  }

  Widget _buildSocialArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppTexts.t('auth.login.social_title'),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: AppColors.secondaryLavender.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
          MysticSocialButton(
            icon: Icons.apple,
            label: AppTexts.t('auth.login.apple_continue'),
            loading: _activeAction == _LoginAction.apple,
            onPressed: _isBusy ? null : _signInWithApple,
          ),
          const SizedBox(height: 9),
        ],
        MysticSocialButton(
          icon: Icons.g_mobiledata_rounded,
          label: AppTexts.t('auth.login.google_continue'),
          loading: _activeAction == _LoginAction.google,
          onPressed: _isBusy ? null : _signInWithGoogle,
        ),
      ],
    );
  }

  Widget _buildRegisterLink() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 3,
      children: [
        Text(
          AppTexts.t('auth.login.switch_prefix'),
          style: GoogleFonts.inter(
            color: AppColors.secondaryLavender,
            fontSize: 13,
          ),
        ),
        TextButton(
          onPressed: _isBusy ? null : _openRegisterPage,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryPink,
            minimumSize: const Size(44, 44),
          ),
          child: Text(
            AppTexts.t('auth.login.switch_action'),
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

class _CosmicLoginBackgroundPainter extends CustomPainter {
  const _CosmicLoginBackgroundPainter();

  static const _stars = <Offset>[
    Offset(0.08, 0.14),
    Offset(0.18, 0.34),
    Offset(0.86, 0.13),
    Offset(0.73, 0.27),
    Offset(0.91, 0.47),
    Offset(0.11, 0.63),
    Offset(0.82, 0.72),
    Offset(0.26, 0.84),
    Offset(0.65, 0.92),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.primaryPink.withValues(alpha: 0.3);
    for (var index = 0; index < _stars.length; index++) {
      final star = _stars[index];
      canvas.drawCircle(
        Offset(star.dx * size.width, star.dy * size.height),
        index.isEven ? 1.5 : 1,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
