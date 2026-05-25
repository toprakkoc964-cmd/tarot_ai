import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class ScannerLaserPainter extends CustomPainter {
  const ScannerLaserPainter({
    required this.progress,
  });

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress.clamp(0.0, 1.0);
    final glowPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Colors.transparent,
          AppColors.primaryNeonPink,
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, y - 28, size.width, 56))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    final linePaint = Paint()
      ..color = AppColors.primaryPink.withValues(alpha: 0.92)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    canvas.drawRect(Rect.fromLTWH(0, y - 26, size.width, 52), glowPaint);
    canvas.drawLine(
      Offset(size.width * 0.12, y),
      Offset(size.width * 0.88, y),
      linePaint,
    );

    final sparklePaint = Paint()
      ..color = AppColors.tertiaryGold.withValues(alpha: 0.78)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 8; i++) {
      final x = size.width * (0.16 + i * 0.1);
      final offsetY = y + (i.isEven ? -12 : 12);
      canvas.drawCircle(Offset(x, offsetY), 1.6, sparklePaint);
    }
  }

  @override
  bool shouldRepaint(covariant ScannerLaserPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
