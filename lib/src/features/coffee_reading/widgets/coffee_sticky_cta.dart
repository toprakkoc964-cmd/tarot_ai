import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';

class CoffeeStickyCta extends StatelessWidget {
  const CoffeeStickyCta({
    super.key,
    required this.onPressed,
    required this.isLoading,
    this.firstCoffeeFreeUsed = false,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final bool firstCoffeeFreeUsed;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.88),
            border: Border(
              top: BorderSide(
                color: AppColors.glassBorder.withValues(alpha: 0.7),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(24, 14, 24, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppTexts.t('coffeeReadyToAnalyze'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: AppColors.secondaryLavender.withValues(alpha: 0.84),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: onPressed == null ? 0.62 : 1,
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
                          color: AppColors.primaryPink.withValues(alpha: 0.34),
                          blurRadius: 24,
                          spreadRadius: -6,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onPressed,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isLoading)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onPrimary,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: AppColors.onPrimary,
                                  size: 19,
                                ),
                              const SizedBox(width: 9),
                              Flexible(
                                child: Text(
                                  AppTexts.t(
                                    isLoading
                                        ? 'coffeeMadamArisPreparing'
                                        : 'coffeeAskMadamAris',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.spaceGrotesk(
                                    color: AppColors.onPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.9,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppTexts.t(
                    firstCoffeeFreeUsed
                        ? 'coffeeCreditInfo'
                        : 'firstReadingFreeInfo',
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: AppColors.tertiaryGold.withValues(alpha: 0.88),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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
