import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_texts.dart';
import '../../core/auth_error_mapper.dart';
import '../../core/language_picker_button.dart';
import '../../core/localization_service.dart';
import 'auth_service.dart';

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
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailController.text.trim().isEmpty) {
      _showError(AppTexts.t('error.email_required'));
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showError(AppTexts.t('error.password_required'));
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (e) {
      _showError(mapAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError(AppTexts.t('error.email_required'));
      return;
    }

    try {
      await widget.authService.sendResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTexts.t('toast.reset_sent'))),
      );
    } catch (e) {
      _showError(mapAuthError(e));
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      await widget.authService.signInWithGoogle();
    } catch (e) {
      _showError(mapAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _loading = true);
    try {
      await widget.authService.signInWithApple();
    } catch (e) {
      _showError(mapAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    const bg = Color(0xFF1A1022);
    const violet = Color(0xFF690DAB);

    InputDecoration inputStyle(String hint) {
      return InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.spaceGrotesk(
            color: const Color(0xFF64748B),
            fontSize: 18,
            fontWeight: FontWeight.w500),
        filled: true,
        fillColor: const Color(0x1F690DAB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: gold.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: gold.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0x80FF00FF)),
        ),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: LocalizationService.instance.revision,
      builder: (context, _, __) {
        return Scaffold(
          backgroundColor: bg,
          body: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.25,
                colors: [Color(0xFF311044), bg],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: gold, width: 1.5),
                                image: const DecorationImage(
                                  image: NetworkImage(
                                      'https://lh3.googleusercontent.com/aida-public/AB6AXuCFEkC-QTKNNQTZbs9zbCcy7zRq51p7EVjMtU204W_tbGIhUkTqOlpksSV1XuYql69Y2uvK1ycoOcIV9jaJRZ4aPZsvYwTSu3uOfGVFtP25tF5DewS4NPlKWS-MzRkmP4OraYk7R6dDg8YDonYdPIC4S5FzADAJF_RXZzmBggefceSR6HH2M4ziLOsYs7qdV-GPvHZaYRnIVOAdHhWypkjI1-ueTjzaEbKEAUKIu-pK3_VL9UVPM1lasUZalWEllQ6LElSnPDCiHMte'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppTexts.t('auth.login.guide'),
                              style: GoogleFonts.spaceGrotesk(
                                  color: gold,
                                  fontSize: 11,
                                  letterSpacing: 1.7,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            LanguagePickerButton(
                              iconColor: const Color(0xFFFF00FF),
                              onSelected: (lang) async {
                                await LocalizationService.instance
                                    .setLanguage(lang);
                                if (mounted) setState(() {});
                              },
                            ),
                            const Icon(Icons.auto_awesome,
                                color: Color(0xFFFF00FF), size: 20),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 54),
                    Text(
                      AppTexts.t('auth.login.brand_title'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzel(
                          color: Colors.white,
                          fontSize: 44,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.7),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppTexts.t('auth.login.subtitle'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(
                          color: const Color(0xFF94A3B8), fontSize: 14),
                    ),
                    const SizedBox(height: 28),
                    _label(AppTexts.t('auth.login.email_label'), gold),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: inputStyle(AppTexts.t('auth.login.email_hint')),
                      style: GoogleFonts.spaceGrotesk(
                          color: const Color(0xFFE2E8F0), fontSize: 17),
                    ),
                    const SizedBox(height: 16),
                    _label(AppTexts.t('auth.login.password_label'), gold),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration:
                          inputStyle(AppTexts.t('auth.login.password_hint')),
                      style: GoogleFonts.spaceGrotesk(
                          color: const Color(0xFFE2E8F0), fontSize: 17),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _resetPassword,
                        child: Text(AppTexts.t('auth.login.forgot_password'),
                            style: GoogleFonts.spaceGrotesk(
                                color: gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x66FF00FF),
                              blurRadius: 24,
                              spreadRadius: 1)
                        ],
                      ),
                      child: FilledButton(
                        onPressed: _loading ? null : _signIn,
                        style: FilledButton.styleFrom(
                          backgroundColor: violet,
                          minimumSize: const Size.fromHeight(58),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Text(AppTexts.t('auth.login.submit'),
                                style: GoogleFonts.cinzel(
                                    color: Colors.white,
                                    fontSize: 18,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      AppTexts.t('auth.login.social_title'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(
                        color: const Color(0xFF94A3B8),
                        fontSize: 12,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
                          OutlinedButton.icon(
                            onPressed: _loading ? null : _signInWithApple,
                            icon: const Icon(Icons.apple),
                            label: Text(AppTexts.t('auth.login.apple_button')),
                          ),
                          const SizedBox(width: 10),
                        ],
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _signInWithGoogle,
                          icon: const Icon(Icons.g_mobiledata, size: 22),
                          label: Text(AppTexts.t('auth.login.google_button')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppTexts.t('auth.login.switch_prefix'),
                          style: GoogleFonts.spaceGrotesk(
                              color: const Color(0xFF94A3B8), fontSize: 16),
                        ),
                        InkWell(
                          onTap: widget.onSwitchToRegister,
                          child: Text(
                            AppTexts.t('auth.login.switch_action'),
                            style: GoogleFonts.spaceGrotesk(
                                color: const Color(0xFFFF00FF),
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _label(String text, Color gold) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          color: gold,
          fontSize: 12,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

