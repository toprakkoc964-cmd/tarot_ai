import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';

class LoginLegalFooter extends StatelessWidget {
  const LoginLegalFooter({
    super.key,
    required this.onTermsPressed,
    required this.onPrivacyPressed,
    required this.onAiNoticePressed,
  });

  final VoidCallback onTermsPressed;
  final VoidCallback onPrivacyPressed;
  final VoidCallback onAiNoticePressed;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = GoogleFonts.inter(
      color: AppColors.secondaryLavender.withValues(alpha: 0.72),
      fontSize: 11,
      height: 1.45,
    );

    return Column(
      children: [
        Text(
          AppTexts.t('auth.login.legal_prefix'),
          textAlign: TextAlign.center,
          style: bodyStyle,
        ),
        const SizedBox(height: 3),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 2,
          children: [
            _FooterLink(
              label: AppTexts.t('auth.login.legal_terms'),
              onPressed: onTermsPressed,
            ),
            Text('·', style: bodyStyle),
            _FooterLink(
              label: AppTexts.t('auth.login.legal_privacy'),
              onPressed: onPrivacyPressed,
            ),
            Text('·', style: bodyStyle),
            _FooterLink(
              label: AppTexts.t('auth.login.legal_ai_notice'),
              onPressed: onAiNoticePressed,
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          AppTexts.t('auth.login.legal_suffix'),
          textAlign: TextAlign.center,
          style: bodyStyle,
        ),
        const SizedBox(height: 10),
        Text(
          AppTexts.t('auth.login.ai_disclaimer_short'),
          textAlign: TextAlign.center,
          style: bodyStyle.copyWith(
            color: AppColors.secondaryLavender.withValues(alpha: 0.58),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryPink,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 5),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.primaryPink,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primaryPink,
          ),
        ),
      ),
    );
  }
}
