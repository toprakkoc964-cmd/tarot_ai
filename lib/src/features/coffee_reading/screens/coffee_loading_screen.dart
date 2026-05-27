import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/coffee_loading_orb.dart';

class CoffeeLoadingScreen extends StatelessWidget {
  const CoffeeLoadingScreen({super.key});

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
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CoffeeLoadingOrb(),
                    const SizedBox(height: 26),
                    Text(
                      AppTexts.t('coffeeAnalyzingSymbols'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.newsreader(
                        color: AppColors.onSurface,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppTexts.t('coffeeAnalyzingSubtitle'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color:
                            AppColors.secondaryLavender.withValues(alpha: 0.82),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
