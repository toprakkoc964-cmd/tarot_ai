import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_texts.dart';

class OnboardingStepThreeSection extends StatelessWidget {
  const OnboardingStepThreeSection({
    super.key,
    required this.selectedFocusAreas,
    required this.onToggleArea,
    required this.onSubmit,
    required this.loading,
  });

  final Set<String> selectedFocusAreas;
  final ValueChanged<String> onToggleArea;
  final VoidCallback onSubmit;
  final bool loading;

  static const _surface = Color(0xFF26112E);
  static const _primary = Color(0xFFFF5ED6);
  static const _primaryDeep = Color(0xFFFF00D4);
  static const _secondary = Color(0xFFCDBDFF);
  static const _gold = Color(0xFFFFE792);
  static const _surfaceHighest = Color(0xFF361A41);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            AppTexts.t('onboarding.step3.subtitle_new'),
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: _secondary.withValues(alpha: 0.84),
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 20),
        GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.95,
          children: [
            _focusCard('love', Icons.favorite,
                AppTexts.t('onboarding.step3.area.love')),
            _focusCard(
              'career',
              Icons.work_history,
              AppTexts.t('onboarding.step3.area.career'),
            ),
            _focusCard(
                'money', Icons.toll, AppTexts.t('onboarding.step3.area.money')),
            _focusCard(
              'spiritual',
              Icons.self_improvement,
              AppTexts.t('onboarding.step3.area.spiritual'),
            ),
            _focusCard('family', Icons.diversity_3,
                AppTexts.t('onboarding.step3.area.family')),
            _focusCard('general', Icons.all_inclusive,
                AppTexts.t('onboarding.step3.area.general')),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: GestureDetector(
              onTap: loading ? null : onSubmit,
              child: Container(
                height: 72,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient:
                      const LinearGradient(colors: [_primary, _primaryDeep]),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryDeep.withValues(alpha: 0.30),
                      blurRadius: 16,
                      spreadRadius: 0.0,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF430036),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppTexts.t('onboarding.step3.complete_profile'),
                            style: GoogleFonts.spaceGrotesk(
                              color: const Color(0xFF430036),
                              letterSpacing: 2.4,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.auto_awesome,
                              color: Color(0xFF430036), size: 20),
                        ],
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _focusCard(String id, IconData icon, String label) {
    final selected = selectedFocusAreas.contains(id);
    return GestureDetector(
      onTap: () => onToggleArea(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.25),
                    blurRadius: 30,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: selected
                    ? _primary.withValues(alpha: 0.10)
                    : _surface.withValues(alpha: 0.40),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: selected
                      ? _primary.withValues(alpha: 0.40)
                      : _surfaceHighest.withValues(alpha: 0.55),
                  width: 1,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (selected)
                    Container(color: _primary.withValues(alpha: 0.05)),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 38, color: selected ? _primary : _gold),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.spaceGrotesk(
                            color:
                                selected ? const Color(0xFFFADCFF) : _secondary,
                            letterSpacing: 2.8,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
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
