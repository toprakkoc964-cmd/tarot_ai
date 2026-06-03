import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';

class MysticLegalCheckbox extends StatelessWidget {
  const MysticLegalCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onTermsPressed,
    required this.onPrivacyPressed,
    required this.onAiNoticePressed,
    this.errorText,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTermsPressed;
  final VoidCallback onPrivacyPressed;
  final VoidCallback onAiNoticePressed;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = GoogleFonts.inter(
      color: AppColors.secondaryLavender,
      fontSize: 12,
      height: 1.45,
    );

    return Semantics(
      checked: value,
      label: AppTexts.t('auth.register.terms_accept_text'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => onChanged(!value),
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 23,
                      height: 23,
                      decoration: BoxDecoration(
                        color: value
                            ? AppColors.primaryNeonPink
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: value
                              ? AppColors.primaryPink
                              : AppColors.tertiaryGold.withValues(alpha: 0.55),
                        ),
                        boxShadow: value
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryNeonPink.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
                      child: value
                          ? const Icon(
                              Icons.check_rounded,
                              size: 17,
                              color: AppColors.onPrimary,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _LegalLink(
                        label: AppTexts.t('auth.register.terms_link'),
                        onPressed: onTermsPressed,
                      ),
                      Text(
                        AppTexts.t('auth.register.terms_and'),
                        style: bodyStyle,
                      ),
                      _LegalLink(
                        label: AppTexts.t('auth.register.privacy_link'),
                        onPressed: onPrivacyPressed,
                      ),
                      Text(
                        AppTexts.t('auth.register.terms_accept_suffix'),
                        style: bodyStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (errorText != null) ...[
            const SizedBox(height: 3),
            Text(
              errorText!,
              style: GoogleFonts.inter(
                color: AppColors.primaryPink,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            AppTexts.t('auth.register.ai_disclaimer_short'),
            style: bodyStyle.copyWith(
              color: AppColors.secondaryLavender.withValues(alpha: 0.72),
              fontSize: 11,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _LegalLink(
              label: AppTexts.t('auth.register.ai_notice'),
              onPressed: onAiNoticePressed,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryPink,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: AppColors.primaryPink,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.primaryPink,
        ),
      ),
    );
  }
}
