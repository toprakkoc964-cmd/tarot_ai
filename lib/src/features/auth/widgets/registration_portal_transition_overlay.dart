import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';

class RegistrationPortalTransitionOverlay extends StatefulWidget {
  const RegistrationPortalTransitionOverlay({super.key});

  @override
  State<RegistrationPortalTransitionOverlay> createState() =>
      _RegistrationPortalTransitionOverlayState();
}

class _RegistrationPortalTransitionOverlayState
    extends State<RegistrationPortalTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: FadeTransition(
          opacity: curved,
          child: ColoredBox(
            color: AppColors.background.withValues(alpha: 0.9),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RepaintBoundary(
                    child: SizedBox(
                      width: 180,
                      height: 180,
                      child: CustomPaint(
                        painter: _CosmicVortexPainter(animation: _controller),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppTexts.t('auth.register.portal_title'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cormorantGaramond(
                      color: AppColors.onSurface,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    AppTexts.t('auth.register.portal_subtitle'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: AppColors.secondaryLavender,
                      fontSize: 13,
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

class _CosmicVortexPainter extends CustomPainter {
  _CosmicVortexPainter({required this.animation}) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var index = 0; index < 5; index++) {
      final progress = (animation.value + index * 0.16) % 1;
      final radius = 18 + progress * 66;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 - progress
        ..color =
            (index.isEven ? AppColors.primaryNeonPink : AppColors.tertiaryGold)
                .withValues(alpha: 0.72 - progress * 0.52);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        animation.value * math.pi * 2 + index,
        math.pi * 1.35,
        false,
        paint,
      );
    }

    final corePaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          AppColors.onSurface,
          AppColors.primaryPink,
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 34));
    canvas.drawCircle(center, 34, corePaint);
  }

  @override
  bool shouldRepaint(covariant _CosmicVortexPainter oldDelegate) => false;
}
