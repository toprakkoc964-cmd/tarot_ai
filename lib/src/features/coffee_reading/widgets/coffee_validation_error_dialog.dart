import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';
import '../models/coffee_photo_step.dart';
import '../models/coffee_validation_result.dart';

class CoffeeValidationErrorDialog {
  static Future<bool?> show(
    BuildContext context, {
    required CoffeePhotoStep? step,
    required CoffeeValidationResult? validationResult,
    String? backendMessage,
  }) {
    final reason = validationResult?.failureReason;
    final title = AppTexts.t('coffeeValidationFailed');
    final message = backendMessage?.trim().isNotEmpty == true
        ? backendMessage!.trim()
        : reason != null
            ? AppTexts.t(reason.messageKey)
            : AppTexts.t('coffeeInvalidImageDetailed');

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.glassBorder),
          ),
          title: Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.manrope(
              color: AppColors.secondaryLavender,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(AppTexts.t('common.close')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(AppTexts.t('coffeeRetake')),
            ),
          ],
        );
      },
    );
  }
}
