import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';
import '../models/coffee_image_pipeline_result.dart';
import '../models/coffee_photo_step.dart';

class CoffeeCaptureCard extends StatelessWidget {
  const CoffeeCaptureCard({
    super.key,
    required this.step,
    required this.result,
    required this.isProcessing,
    required this.onAddPhoto,
  });

  final CoffeePhotoStep step;
  final CoffeeImagePipelineResult? result;
  final bool isProcessing;
  final VoidCallback onAddPhoto;

  @override
  Widget build(BuildContext context) {
    final isCompleted = result != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNeonPink.withValues(alpha: 0.14),
            blurRadius: 42,
            spreadRadius: -14,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryPink.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryPink.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    _iconForStep(step),
                    color: AppColors.primaryPink,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTexts.t(step.titleKey),
                        style: GoogleFonts.spaceGrotesk(
                          color: AppColors.tertiaryGold,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isCompleted
                            ? AppTexts.t('coffeeCaptureCompleted')
                            : AppTexts.t(step.descriptionKey),
                        style: GoogleFonts.manrope(
                          color: AppColors.secondaryLavender.withValues(
                            alpha: 0.86,
                          ),
                          height: 1.4,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (result != null) ...[
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.file(
                    result!.compressedImage,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              if (result!.validationResult.hasWarning) ...[
                const SizedBox(height: 12),
                Text(
                  AppTexts.t('coffeeWeakImageWarning'),
                  style: GoogleFonts.manrope(
                    color: AppColors.tertiaryGold.withValues(alpha: 0.86),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 26),
              AspectRatio(
                aspectRatio: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh.withValues(alpha: 0.54),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.secondaryLavender.withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _iconForStep(step),
                      color: AppColors.secondaryLavender.withValues(
                        alpha: 0.46,
                      ),
                      size: 58,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.primaryPink,
                      AppColors.primaryNeonPink,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPink.withValues(alpha: 0.28),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: isProcessing ? null : onAddPhoto,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isProcessing) ...[
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.onPrimary,
                              ),
                            ),
                          ] else ...[
                            Icon(
                              isCompleted
                                  ? Icons.refresh_rounded
                                  : Icons.add_a_photo_rounded,
                              color: AppColors.onPrimary,
                              size: 19,
                            ),
                          ],
                          const SizedBox(width: 10),
                          Text(
                            isCompleted
                                ? AppTexts.t('coffeeRetakePhoto')
                                : AppTexts.t('coffeeAddPhoto'),
                            style: GoogleFonts.spaceGrotesk(
                              color: AppColors.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForStep(CoffeePhotoStep step) {
    switch (step) {
      case CoffeePhotoStep.cupInside:
        return Icons.coffee_rounded;
      case CoffeePhotoStep.saucer:
        return Icons.trip_origin_rounded;
      case CoffeePhotoStep.cupSide:
        return Icons.local_cafe_rounded;
    }
  }
}
