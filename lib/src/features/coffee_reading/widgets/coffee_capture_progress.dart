import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';
import '../models/coffee_image_pipeline_result.dart';
import '../models/coffee_photo_step.dart';

class CoffeeCaptureProgress extends StatelessWidget {
  const CoffeeCaptureProgress({
    super.key,
    required this.activeStep,
    required this.completedSteps,
  });

  final CoffeePhotoStep activeStep;
  final Map<CoffeePhotoStep, CoffeeImagePipelineResult> completedSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final step in CoffeePhotoStep.values) ...[
          Expanded(
            child: _ProgressStep(
              step: step,
              isActive: step == activeStep,
              result: completedSteps[step],
            ),
          ),
          if (step != CoffeePhotoStep.values.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.step,
    required this.isActive,
    required this.result,
  });

  final CoffeePhotoStep step;
  final bool isActive;
  final CoffeeImagePipelineResult? result;

  bool get _isDone => result != null;

  @override
  Widget build(BuildContext context) {
    final borderColor = _isDone
        ? AppColors.primaryPink.withValues(alpha: 0.72)
        : isActive
            ? AppColors.tertiaryGold.withValues(alpha: 0.72)
            : AppColors.glassBorder;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          _Thumbnail(
            imageFile: result?.compressedImage,
            step: step,
            isDone: _isDone,
          ),
          const SizedBox(height: 8),
          Text(
            AppTexts.t(step.titleKey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: _isDone
                  ? AppColors.primaryPink
                  : isActive
                      ? AppColors.tertiaryGold
                      : AppColors.secondaryLavender.withValues(alpha: 0.62),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.imageFile,
    required this.step,
    required this.isDone,
  });

  final File? imageFile;
  final CoffeePhotoStep step;
  final bool isDone;

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
                    if (isDone)
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryPink,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
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
