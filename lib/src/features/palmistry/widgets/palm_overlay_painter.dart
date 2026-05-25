import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class PalmOverlayPainter extends CustomPainter {
  const PalmOverlayPainter({
    required this.isHandDetected,
  });

  final bool isHandDetected;

  @override
  void paint(Canvas canvas, Size size) {
    final activeColor = isHandDetected
        ? AppColors.primaryNeonPink
        : AppColors.secondaryLavender;
    final center = Offset(size.width / 2, size.height * 0.43);
    final palmWidth = size.width * 0.42;
    final palmHeight = size.height * 0.34;

    final glowPaint = Paint()
      ..color = activeColor.withValues(alpha: isHandDetected ? 0.24 : 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    final linePaint = Paint()
      ..color = activeColor.withValues(alpha: isHandDetected ? 0.88 : 0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final guidePaint = Paint()
      ..color = AppColors.tertiaryGold.withValues(alpha: 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final palmRect = Rect.fromCenter(
      center: center.translate(0, palmHeight * 0.16),
      width: palmWidth,
      height: palmHeight,
    );
    final palmPath = Path()
      ..moveTo(palmRect.left + palmWidth * 0.18, palmRect.top + 10)
      ..quadraticBezierTo(
        palmRect.left - 8,
        palmRect.top + palmHeight * 0.24,
        palmRect.left + palmWidth * 0.08,
        palmRect.center.dy,
      )
      ..quadraticBezierTo(
        palmRect.left + palmWidth * 0.16,
        palmRect.bottom + 16,
        palmRect.center.dx,
        palmRect.bottom + 12,
      )
      ..quadraticBezierTo(
        palmRect.right - palmWidth * 0.16,
        palmRect.bottom + 16,
        palmRect.right - palmWidth * 0.08,
        palmRect.center.dy,
      )
      ..quadraticBezierTo(
        palmRect.right + 8,
        palmRect.top + palmHeight * 0.24,
        palmRect.right - palmWidth * 0.18,
        palmRect.top + 10,
      );

    canvas.drawPath(palmPath, glowPaint);
    canvas.drawPath(palmPath, linePaint);

    final fingerWidth = palmWidth * 0.15;
    final fingerGap = palmWidth * 0.045;
    final fingerBottom = palmRect.top + 38;
    final heights = [
      palmHeight * 0.42,
      palmHeight * 0.58,
      palmHeight * 0.54,
      palmHeight * 0.44,
    ];
    final startX = center.dx - (fingerWidth * 2 + fingerGap * 1.5);
    for (var i = 0; i < 4; i++) {
      final left = startX + i * (fingerWidth + fingerGap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left,
          fingerBottom - heights[i],
          fingerWidth,
          heights[i],
        ),
        Radius.circular(fingerWidth),
      );
      canvas.drawRRect(rect, glowPaint);
      canvas.drawRRect(rect, linePaint);
    }

    final thumbPath = Path()
      ..moveTo(
          palmRect.left + palmWidth * 0.08, palmRect.top + palmHeight * 0.35)
      ..quadraticBezierTo(
        palmRect.left - palmWidth * 0.2,
        palmRect.top + palmHeight * 0.45,
        palmRect.left - palmWidth * 0.08,
        palmRect.top + palmHeight * 0.62,
      );
    canvas.drawPath(thumbPath, glowPaint);
    canvas.drawPath(thumbPath, linePaint);

    canvas.drawLine(
      Offset(palmRect.left + palmWidth * 0.18, palmRect.center.dy),
      Offset(palmRect.right - palmWidth * 0.18, palmRect.center.dy - 18),
      guidePaint,
    );
    canvas.drawLine(
      Offset(palmRect.left + palmWidth * 0.22, palmRect.center.dy + 34),
      Offset(palmRect.right - palmWidth * 0.2, palmRect.center.dy + 16),
      guidePaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: palmRect.center.translate(0, palmHeight * 0.2),
        width: palmWidth * 0.62,
        height: palmHeight * 0.38,
      ),
      3.35,
      2.2,
      false,
      guidePaint,
    );
  }

  @override
  bool shouldRepaint(covariant PalmOverlayPainter oldDelegate) {
    return oldDelegate.isHandDetected != isHandDetected;
  }
}
