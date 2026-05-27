import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class CoffeeLoadingOrb extends StatefulWidget {
  const CoffeeLoadingOrb({super.key, this.size = 116});

  final double size;

  @override
  State<CoffeeLoadingOrb> createState() => _CoffeeLoadingOrbState();
}

class _CoffeeLoadingOrbState extends State<CoffeeLoadingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.square(widget.size),
            painter: _CoffeeLoadingOrbPainter(_controller.value),
          );
        },
      ),
    );
  }
}

class _CoffeeLoadingOrbPainter extends CustomPainter {
  const _CoffeeLoadingOrbPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final glowPaint = Paint()
      ..color = AppColors.primaryNeonPink.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(center, radius * 0.7, glowPaint);

    final basePaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          AppColors.surfaceHigh,
          AppColors.background,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, radius * 0.58, basePaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          AppColors.primaryPink,
          AppColors.tertiaryGold,
          AppColors.primaryNeonPink,
          AppColors.primaryPink,
        ],
      ).createShader(Offset.zero & size);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(progress * math.pi * 2);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.72),
      -math.pi / 2,
      math.pi * 1.45,
      false,
      ringPaint,
    );
    canvas.restore();

    final dotPaint = Paint()..color = AppColors.tertiaryGold;
    canvas.drawCircle(center, radius * 0.08, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _CoffeeLoadingOrbPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
