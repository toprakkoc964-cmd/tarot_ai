import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_legal_urls.dart';
import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';

class ShopFooterLinks extends StatelessWidget {
  const ShopFooterLinks({
    super.key,
    required this.termsUrl,
    required this.privacyUrl,
    required this.onError,
  });

  final String termsUrl;
  final String privacyUrl;
  final VoidCallback onError;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          AppTexts.t('shopTermsAndPrivacyAgreement'),
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: AppColors.secondaryLavender.withValues(alpha: 0.74),
            fontSize: 11.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            _FooterLink(
              label: AppTexts.t('shopTermsOfUse'),
              url: termsUrl,
              onError: onError,
            ),
            _FooterLink(
              label: AppTexts.t('shopPrivacyPolicy'),
              url: privacyUrl,
              onError: onError,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          AppTexts.t('shopFooterLegalText'),
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: AppColors.secondaryLavender.withValues(alpha: 0.60),
            fontSize: 10.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({
    required this.label,
    required this.url,
    required this.onError,
  });

  final String label;
  final String url;
  final VoidCallback onError;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => _open(),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryPink,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.primaryPink.withValues(alpha: 0.72),
        ),
      ),
    );
  }

  Future<void> _open() async {
    final launched = await AppLegalUrls.launch(url);
    if (!launched) {
      onError();
    }
  }
}
