import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';
import '../auth_service.dart';
import 'mystic_primary_button.dart';
import 'mystic_text_field.dart';

Future<bool?> showForgotPasswordBottomSheet({
  required BuildContext context,
  required AuthService authService,
  required String initialEmail,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ForgotPasswordBottomSheet(
      authService: authService,
      initialEmail: initialEmail,
    ),
  );
}

class _ForgotPasswordBottomSheet extends StatefulWidget {
  const _ForgotPasswordBottomSheet({
    required this.authService,
    required this.initialEmail,
  });

  final AuthService authService;
  final String initialEmail;

  @override
  State<_ForgotPasswordBottomSheet> createState() =>
      _ForgotPasswordBottomSheetState();
}

class _ForgotPasswordBottomSheetState
    extends State<_ForgotPasswordBottomSheet> {
  late final TextEditingController _emailController;
  bool _loading = false;
  String? _emailError;
  String? _requestError;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  Future<void> _send() async {
    final email = _emailController.text.trim();
    final validationError = email.isEmpty
        ? AppTexts.t('auth.login.email_required')
        : !_isValidEmail(email)
        ? AppTexts.t('auth.login.invalid_email')
        : null;

    if (validationError != null) {
      setState(() => _emailError = validationError);
      return;
    }

    setState(() {
      _loading = true;
      _emailError = null;
      _requestError = null;
    });

    try {
      await widget.authService.sendResetEmail(email);
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found' ||
          error.code == 'invalid-recipient-email') {
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _requestError = AppTexts.t('auth.forgot_password.error');
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _requestError = AppTexts.t('auth.forgot_password.error');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.only(bottom: bottomInset),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryLavender.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppTexts.t('auth.forgot_password.title'),
                    style: GoogleFonts.cormorantGaramond(
                      color: AppColors.onSurface,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppTexts.t('auth.forgot_password.description'),
                    style: GoogleFonts.inter(
                      color: AppColors.secondaryLavender,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  MysticTextField(
                    controller: _emailController,
                    label: AppTexts.t('auth.login.email_label'),
                    hint: AppTexts.t('auth.forgot_password.email_hint'),
                    errorText: _emailError,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _send(),
                  ),
                  if (_requestError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _requestError!,
                      style: GoogleFonts.inter(
                        color: AppColors.primaryPink,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  MysticPrimaryButton(
                    label: AppTexts.t(
                      _loading
                          ? 'auth.forgot_password.sending'
                          : 'auth.forgot_password.send',
                    ),
                    loading: _loading,
                    onPressed: _loading ? null : _send,
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(
                        AppTexts.t('auth.forgot_password.cancel'),
                        style: GoogleFonts.inter(
                          color: AppColors.secondaryLavender,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
