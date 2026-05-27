import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';

class RestorePurchasesButton extends StatelessWidget {
  const RestorePurchasesButton({
    super.key,
    required this.onPressed,
    required this.isRestoring,
  });

  final VoidCallback? onPressed;
  final bool isRestoring;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: isRestoring ? null : onPressed,
      icon: isRestoring
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.secondaryLavender,
              ),
            )
          : const Icon(Icons.restore_rounded),
      label: Text(
        isRestoring
            ? AppTexts.t('shopRestoreInProgress')
            : AppTexts.t('shopRestorePurchases'),
      ),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.secondaryLavender,
        textStyle: GoogleFonts.spaceGrotesk(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
