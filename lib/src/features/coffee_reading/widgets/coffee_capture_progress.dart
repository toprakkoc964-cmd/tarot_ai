import 'package:flutter/material.dart';

import '../models/coffee_image_pipeline_result.dart';
import '../models/coffee_photo_step.dart';
import 'coffee_step_thumbnail_card.dart';

class CoffeeCaptureProgress extends StatelessWidget {
  const CoffeeCaptureProgress({
    super.key,
    required this.activeStep,
    required this.completedSteps,
    required this.retrySteps,
    required this.onStepTap,
  });

  final CoffeePhotoStep activeStep;
  final Map<CoffeePhotoStep, CoffeeImagePipelineResult> completedSteps;
  final Set<CoffeePhotoStep> retrySteps;
  final ValueChanged<CoffeePhotoStep> onStepTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final compact = constraints.maxWidth < 340;
        final width = compact
            ? 112.0
            : (constraints.maxWidth - (gap * 2)) /
                CoffeePhotoStep.values.length;

        final cards = [
          for (final step in CoffeePhotoStep.values) ...[
            SizedBox(
              width: width,
              child: CoffeeStepThumbnailCard(
                step: step,
                result: completedSteps[step],
                isActive: step == activeStep,
                needsRetry: retrySteps.contains(step),
                onTap: () => onStepTap(step),
              ),
            ),
            if (step != CoffeePhotoStep.values.last) const SizedBox(width: gap),
          ],
        ];

        if (compact) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(children: cards),
          );
        }
        return Row(children: cards);
      },
    );
  }
}
