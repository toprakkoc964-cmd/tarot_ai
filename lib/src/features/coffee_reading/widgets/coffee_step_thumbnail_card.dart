import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';
import '../models/coffee_image_pipeline_result.dart';
import '../models/coffee_photo_step.dart';

class CoffeeStepThumbnailCard extends StatelessWidget {
  const CoffeeStepThumbnailCard({
    super.key,
    required this.step,
    required this.result,
    required this.isActive,
    required this.needsRetry,
    required this.onTap,
  });

  final CoffeePhotoStep step;
  final CoffeeImagePipelineResult? result;
  final bool isActive;
  final bool needsRetry;
  final VoidCallback onTap;

  bool get _isDone => result != null && !needsRetry;

  @override
  Widget build(BuildContext context) {
    final borderColor = needsRetry
        ? AppColors.tertiaryGold.withValues(alpha: 0.76)
        : isActive
            ? AppColors.primaryPink.withValues(alpha: 0.9)
            : _isDone
                ? AppColors.primaryPink.withValues(alpha: 0.48)
                : AppColors.glassBorder;

    return AnimatedScale(
      duration: const Duration(milliseconds: 220),
      scale: isActive ? 1.03 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: AppColors.glassBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primaryNeonPink.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: -8,
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  _Thumbnail(
                    imageFile: result?.compressedImage,
                    step: step,
                    needsRetry: needsRetry,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppTexts.t(step.titleKey),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      color: needsRetry
                          ? AppColors.tertiaryGold
                          : isActive
                              ? AppColors.primaryPink
                              : _isDone
                                  ? AppColors.onSurface
                                  : AppColors.secondaryLavender.withValues(
                                      alpha: 0.62,
                                    ),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                      height: 1.15,
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

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.imageFile,
    required this.step,
    required this.needsRetry,
  });

  final File? imageFile;
  final CoffeePhotoStep step;
  final bool needsRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh.withValues(alpha: 0.86),
          ),
          child: imageFile == null
              ? Icon(
                  _iconForStep(step),
                  color: AppColors.secondaryLavender.withValues(alpha: 0.72),
                  size: 26,
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      imageFile!,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.low,
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: needsRetry
                              ? AppColors.tertiaryGold
                              : AppColors.primaryPink,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          needsRetry
                              ? Icons.priority_high_rounded
                              : Icons.check_rounded,
                          color: AppColors.onPrimary,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  IconData _iconForStep(CoffeePhotoStep step) {
    switch (step) {
      case CoffeePhotoStep.cupInside:
        return Icons.coffee_rounded;
      case CoffeePhotoStep.saucer:
        return Icons.radio_button_unchecked_rounded;
      case CoffeePhotoStep.cupSide:
        return Icons.local_cafe_rounded;
    }
  }
}
