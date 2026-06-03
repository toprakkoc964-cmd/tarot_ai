import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';

enum MysticToastTone { error, success }

class MysticToast {
  const MysticToast._();

  static void showError(BuildContext context, String message) {
    _show(context, message, MysticToastTone.error);
  }

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, MysticToastTone.success);
  }

  static void _show(
    BuildContext context,
    String message,
    MysticToastTone tone,
  ) {
    final isError = tone == MysticToastTone.error;
    final accent = isError ? AppColors.primaryPink : AppColors.tertiaryGold;
    final title = AppTexts.t(
      isError ? 'toast.error_title' : 'toast.success_title',
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          content: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.55)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.17),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: accent,
                    size: 21,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          message,
                          style: GoogleFonts.inter(
                            color: AppColors.onSurface,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}
