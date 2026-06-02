import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';
import '../models/coffee_image_pipeline_result.dart';
import '../models/coffee_photo_step.dart';
import 'coffee_loading_orb.dart';
import 'coffee_neon_connection_painter.dart';

class CoffeeLoadingTriangleRitual extends StatefulWidget {
  const CoffeeLoadingTriangleRitual({
    super.key,
    required this.photos,
  });

  final Map<CoffeePhotoStep, CoffeeImagePipelineResult> photos;

  @override
  State<CoffeeLoadingTriangleRitual> createState() =>
      _CoffeeLoadingTriangleRitualState();
}

class _CoffeeLoadingTriangleRitualState
    extends State<CoffeeLoadingTriangleRitual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: CoffeeNeonConnectionPainter(animation: _controller),
            ),
            Align(
              alignment: const Alignment(0, -0.78),
              child: _RitualPhoto(
                animation: _controller,
                step: CoffeePhotoStep.cupInside,
                photo: widget.photos[CoffeePhotoStep.cupInside],
              ),
            ),
            Align(
              alignment: const Alignment(-0.78, 0.72),
              child: _RitualPhoto(
                animation: _controller,
                step: CoffeePhotoStep.saucer,
                photo: widget.photos[CoffeePhotoStep.saucer],
                phaseOffset: 0.33,
              ),
            ),
            Align(
              alignment: const Alignment(0.78, 0.72),
              child: _RitualPhoto(
                animation: _controller,
                step: CoffeePhotoStep.cupSide,
                photo: widget.photos[CoffeePhotoStep.cupSide],
                phaseOffset: 0.66,
              ),
            ),
            const Align(
              alignment: Alignment(0, 0.08),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CoffeeLoadingOrb(size: 92),
                  Icon(
                    Icons.coffee_rounded,
                    color: AppColors.tertiaryGold,
                    size: 30,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RitualPhoto extends StatelessWidget {
  const _RitualPhoto({
    required this.animation,
    required this.step,
    required this.photo,
    this.phaseOffset = 0,
  });

  final Animation<double> animation;
  final CoffeePhotoStep step;
  final CoffeeImagePipelineResult? photo;
  final double phaseOffset;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primaryPink.withValues(alpha: 0.54),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryNeonPink.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: SizedBox.square(
                dimension: 78,
                child: photo == null
                    ? const ColoredBox(color: AppColors.surfaceHigh)
                    : Image.file(
                        photo!.compressedImage,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 104,
            child: Text(
              AppTexts.t(step.titleKey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: AppColors.secondaryLavender.withValues(alpha: 0.78),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.12,
              ),
            ),
          ),
        ],
      ),
      builder: (context, child) {
        final normalizedPhase = (animation.value + phaseOffset) % 1;
        final floatOffset = math.sin(normalizedPhase * math.pi * 2) * 5;
        final rotation = math.sin(normalizedPhase * math.pi * 2) * 0.018;

        return Transform.translate(
          offset: Offset(0, floatOffset),
          child: Transform.rotate(
            angle: rotation,
            child: child,
          ),
        );
      },
    );
  }
}
