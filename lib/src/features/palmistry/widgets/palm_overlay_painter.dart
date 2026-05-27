import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/palm_detection_result.dart';

class PalmOverlayPainter extends CustomPainter {
  const PalmOverlayPainter({
    required this.detectionState,
    required this.readinessProgress,
    required this.pulseValue,
  });

  final PalmDetectionState detectionState;
  final double readinessProgress;
  final double pulseValue;

  @override
  void paint(Canvas canvas, Size size) {
    final activeColor = switch (detectionState) {
      PalmDetectionState.validHand => AppColors.primaryNeonPink,
      PalmDetectionState.possibleHand => AppColors.primaryPink,
      PalmDetectionState.partialHand => AppColors.tertiaryGold,
      PalmDetectionState.noHand => AppColors.secondaryLavender,
    };
    final isReady = detectionState == PalmDetectionState.validHand;
    final possiblePulse =
        detectionState == PalmDetectionState.possibleHand ? pulseValue : 0.0;
    final center = Offset(size.width / 2, size.height * 0.43);
    final palmWidth = size.width * 0.42;
    final palmHeight = size.height * 0.34;

    final glowPaint = Paint()
      ..color = activeColor.withValues(
        alpha: isReady ? 0.24 : 0.14 + possiblePulse * 0.1,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9 + possiblePulse * 2
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        18 + possiblePulse * 6,
      );
    final linePaint = Paint()
      ..color = activeColor.withValues(
        alpha: isReady ? 0.88 : 0.62 + possiblePulse * 0.14,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final guidePaint = Paint()
      ..color = AppColors.tertiaryGold.withValues(alpha: 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final bracketPaint = Paint()
      ..color = activeColor.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
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

    _drawTargetBrackets(canvas, size, palmRect.inflate(palmWidth * 0.24),
        bracketPaint, activeColor);
    _drawReadinessTicks(canvas, size, activeColor);
  }

  void _drawTargetBrackets(
    Canvas canvas,
    Size size,
    Rect target,
    Paint paint,
    Color color,
  ) {
    final bracket = size.shortestSide * 0.055;
    final glow = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    void drawCorner(Offset origin, double xDirection, double yDirection) {
      final horizontal = Offset(origin.dx + bracket * xDirection, origin.dy);
      final vertical = Offset(origin.dx, origin.dy + bracket * yDirection);
      canvas.drawLine(origin, horizontal, glow);
      canvas.drawLine(origin, vertical, glow);
      canvas.drawLine(origin, horizontal, paint);
      canvas.drawLine(origin, vertical, paint);
    }

    drawCorner(target.topLeft, 1, 1);
    drawCorner(target.topRight, -1, 1);
    drawCorner(target.bottomLeft, 1, -1);
    drawCorner(target.bottomRight, -1, -1);
  }

  void _drawReadinessTicks(Canvas canvas, Size size, Color color) {
    final tickCount = 3;
    final activeTicks = (readinessProgress * tickCount).round();
    final tickWidth = size.width * 0.08;
    final tickGap = size.width * 0.025;
    final totalWidth = tickWidth * tickCount + tickGap * (tickCount - 1);
    final startX = (size.width - totalWidth) / 2;
    final y = size.height * 0.88;
    final inactivePaint = Paint()
      ..color = AppColors.secondaryLavender.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final activePaint = Paint()
      ..color = color.withValues(alpha: 0.86)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < tickCount; i++) {
      final x = startX + i * (tickWidth + tickGap);
      canvas.drawLine(Offset(x, y), Offset(x + tickWidth, y), inactivePaint);
      if (i < activeTicks) {
        canvas.drawLine(Offset(x, y), Offset(x + tickWidth, y), activePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PalmOverlayPainter oldDelegate) {
    return oldDelegate.detectionState != detectionState ||
        oldDelegate.readinessProgress != readinessProgress ||
        oldDelegate.pulseValue != pulseValue;
  }
}
