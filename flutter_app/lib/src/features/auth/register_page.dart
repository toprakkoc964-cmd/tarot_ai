import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_texts.dart';
import '../../core/auth_error_mapper.dart';
import '../../core/language_picker_button.dart';
import '../../core/localization_service.dart';
import 'auth_service.dart';

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
  bool _acceptedTerms = false;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_nameController.text.trim().isEmpty) {
      _showError(AppTexts.t('error.name_required'));
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      _showError(AppTexts.t('error.email_required'));
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showError(AppTexts.t('error.password_required'));
      return;
    }
    if (_passwordController.text.length < 6) {
      _showError(AppTexts.t('error.password_short'));
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      _showError(AppTexts.t('error.password_mismatch'));
      return;
    }
    if (!_acceptedTerms) {
      _showError(AppTexts.t('error.accept_terms'));
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
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
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
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
                center: Alignment.topRight,
                radius: 1.15,
                colors: [Color(0xFF40104E), bg],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: widget.onSwitchToLogin,
                          borderRadius: BorderRadius.circular(28),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: gold.withValues(alpha: 0.25)),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new,
                                color: gold, size: 20),
                          ),
                        ),
                        Row(
                          children: [
                            LanguagePickerButton(
                              iconColor: const Color(0xFFFF00FF),
                              onSelected: (lang) async {
                                await LocalizationService.instance.setLanguage(lang);
                                if (mounted) setState(() {});
                              },
                            ),
                            Column(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: gold, width: 2),
                                    image: const DecorationImage(
                                      image: NetworkImage(
                                          'https://lh3.googleusercontent.com/aida-public/AB6AXuCFEkC-QTKNNQTZbs9zbCcy7zRq51p7EVjMtU204W_tbGIhUkTqOlpksSV1XuYql69Y2uvK1ycoOcIV9jaJRZ4aPZsvYwTSu3uOfGVFtP25tF5DewS4NPlKWS-MzRkmP4OraYk7R6dDg8YDonYdPIC4S5FzADAJF_RXZzmBggefceSR6HH2M4ziLOsYs7qdV-GPvHZaYRnIVOAdHhWypkjI1-ueTjzaEbKEAUKIu-pK3_VL9UVPM1lasUZalWEllQ6LElSnPDCiHMte'),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  AppTexts.t('auth.register.guide'),
                                  style: GoogleFonts.spaceGrotesk(
                                      color: gold,
                                      letterSpacing: 2,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Text(
                      AppTexts.t('auth.register.title'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cinzel(
                          color: gold,
                          fontSize: 27,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.7),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppTexts.t('auth.register.subtitle'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(
                          color: const Color(0xFF94A3B8), fontSize: 16),
                    ),
                    const SizedBox(height: 28),
                    _label(AppTexts.t('auth.register.name_label'), gold),
                    TextField(
                      controller: _nameController,
                      decoration: inputStyle(AppTexts.t('auth.register.name_hint')),
                    ),
                    const SizedBox(height: 16),
                    _label(AppTexts.t('auth.register.email_label'), gold),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          inputStyle(AppTexts.t('auth.register.email_hint')),
                    ),
                    const SizedBox(height: 16),
                    _label(AppTexts.t('auth.register.password_label'), gold),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration:
                          inputStyle(AppTexts.t('auth.register.password_hint')),
                    ),
                    const SizedBox(height: 16),
                    _label(AppTexts.t('auth.register.confirm_label'), gold),
                    TextField(
                      controller: _confirmController,
                      obscureText: true,
                      decoration:
                          inputStyle(AppTexts.t('auth.register.confirm_hint')),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acceptedTerms,
                          onChanged: (v) =>
                              setState(() => _acceptedTerms = v ?? false),
                          side: BorderSide(color: gold.withValues(alpha: 0.5)),
                          activeColor: violet,
                          checkColor: Colors.white,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _termsText(gold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x66FF00FF),
                              blurRadius: 24,
                              spreadRadius: 1)
                        ],
                      ),
                      child: FilledButton(
                        onPressed: _loading ? null : _register,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(62),
                          backgroundColor: violet,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Text(AppTexts.t('auth.register.button'),
                                style: GoogleFonts.cinzel(
                                    color: Colors.white,
                                    fontSize: 16.5,
                                    letterSpacing: 2)),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppTexts.t('auth.register.switch_prefix'),
                          style: GoogleFonts.spaceGrotesk(
                              color: const Color(0xFF94A3B8), fontSize: 17),
                        ),
                        InkWell(
                          onTap: widget.onSwitchToLogin,
                          child: Text(
                            AppTexts.t('auth.register.switch_action'),
                            style: GoogleFonts.spaceGrotesk(
                                color: const Color(0xFFFF00FF),
                                fontSize: 17,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _termsText(Color gold) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.spaceGrotesk(
          color: const Color(0xFF94A3B8),
          fontSize: 16,
        ),
        children: [
          TextSpan(text: AppTexts.t('auth.register.terms_prefix')),
          TextSpan(
            text: AppTexts.t('auth.register.terms_link'),
            style: TextStyle(color: gold),
          ),
          TextSpan(text: AppTexts.t('auth.register.terms_and')),
          TextSpan(
            text: AppTexts.t('auth.register.privacy_link'),
            style: TextStyle(color: gold),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, Color gold) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text,
          style: GoogleFonts.spaceGrotesk(
              color: gold,
              fontSize: 13,
              letterSpacing: 2,
              fontWeight: FontWeight.w700)),
    );
  }
}

