import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class CoffeeNeonConnectionPainter extends CustomPainter {
  CoffeeNeonConnectionPainter({
    required this.animation,
  }) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    final points = [
      Offset(size.width * 0.5, size.height * 0.18),
      Offset(size.width * 0.2, size.height * 0.74),
      Offset(size.width * 0.8, size.height * 0.74),
    ];
    final center = Offset(size.width * 0.5, size.height * 0.53);
    final pulse = 0.5 + (math.sin(progress * math.pi * 2) * 0.5);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = AppColors.primaryNeonPink.withValues(alpha: 0.08 + pulse * 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..color = AppColors.primaryPink.withValues(alpha: 0.34 + pulse * 0.18);

    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..close();

    canvas
      ..drawPath(path, glowPaint)
      ..drawPath(path, linePaint);

    for (final point in points) {
      canvas
        ..drawLine(point, center, glowPaint)
        ..drawLine(point, center, linePaint);
    }

    final sparklePaint = Paint()
      ..color = AppColors.tertiaryGold.withValues(alpha: 0.44 + pulse * 0.3);
    for (var index = 0; index < 9; index++) {
      final angle = ((index / 9) + progress) * math.pi * 2;
      final radius = size.shortestSide * (0.25 + (index % 3) * 0.055);
      final point = center +
          Offset(
            math.cos(angle) * radius,
            math.sin(angle) * radius,
          );
      canvas.drawCircle(point, index.isEven ? 1.8 : 1.1, sparklePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CoffeeNeonConnectionPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
