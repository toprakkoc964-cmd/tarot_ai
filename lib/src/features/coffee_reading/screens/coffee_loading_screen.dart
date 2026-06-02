import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';
import '../models/coffee_image_pipeline_result.dart';
import '../models/coffee_photo_step.dart';
import '../widgets/coffee_loading_triangle_ritual.dart';

class CoffeeLoadingScreen extends StatefulWidget {
  const CoffeeLoadingScreen({
    super.key,
    required this.photos,
  });

  final Map<CoffeePhotoStep, CoffeeImagePipelineResult> photos;

  @override
  State<CoffeeLoadingScreen> createState() => _CoffeeLoadingScreenState();
}

class _CoffeeLoadingScreenState extends State<CoffeeLoadingScreen> {
  late final Timer _phaseTimer;
  var _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _phaseTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _phaseTimer.cancel();
    super.dispose();
  }

  String get _titleKey {
    if (_elapsedSeconds < 2) return 'coffeeLoadingPhaseValidationTitle';
    if (_elapsedSeconds < 4) return 'coffeeLoadingPhaseCombiningTitle';
    if (_elapsedSeconds < 9) return 'coffeeLoadingPhaseReadingTitle';
    return 'coffeeLoadingPhaseLongWaitTitle';
  }

  String get _subtitleKey {
    if (_elapsedSeconds < 2) return 'coffeeLoadingPhaseValidationSubtitle';
    if (_elapsedSeconds < 4) return 'coffeeLoadingPhaseCombiningSubtitle';
    if (_elapsedSeconds < 9) return 'coffeeLoadingPhaseReadingSubtitle';
    return 'coffeeLoadingPhaseLongWaitSubtitle';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.1, -0.3),
                  radius: 1.05,
                  colors: [
                    AppColors.cosmicGradientTop,
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 52,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppTexts.t('coffeeLoadingTriangleTitle'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.spaceGrotesk(
                            color: AppColors.tertiaryGold,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppTexts.t('coffeeLoadingTriangleSubtitle'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.manrope(
                            color: AppColors.secondaryLavender.withValues(
                              alpha: 0.72,
                            ),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 390),
                          child: CoffeeLoadingTriangleRitual(
                            photos: widget.photos,
                          ),
                        ),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 360),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.12),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            key: ValueKey(_titleKey),
                            children: [
                              Text(
                                AppTexts.t(_titleKey),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.newsreader(
                                  color: AppColors.onSurface,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                AppTexts.t(_subtitleKey),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.manrope(
                                  color: AppColors.secondaryLavender
                                      .withValues(alpha: 0.82),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
