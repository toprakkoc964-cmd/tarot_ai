import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class FallingMysticSymbols extends StatefulWidget {
  const FallingMysticSymbols({super.key});

  @override
  State<FallingMysticSymbols> createState() => _FallingMysticSymbolsState();
}

class _FallingMysticSymbolsState extends State<FallingMysticSymbols>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
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
      child: CustomPaint(
        painter: _MysticSymbolsPainter(animation: _controller),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MysticSymbolsPainter extends CustomPainter {
  _MysticSymbolsPainter({required this.animation}) : super(repaint: animation);

  final Animation<double> animation;

  static const _symbols = <_SymbolSeed>[
    _SymbolSeed(0.08, 0.07, 0.11, _SymbolKind.star),
    _SymbolSeed(0.22, 0.38, 0.07, _SymbolKind.moon),
    _SymbolSeed(0.39, 0.19, 0.10, _SymbolKind.card),
    _SymbolSeed(0.57, 0.61, 0.08, _SymbolKind.sparkle),
    _SymbolSeed(0.76, 0.29, 0.12, _SymbolKind.cup),
    _SymbolSeed(0.91, 0.73, 0.09, _SymbolKind.star),
    _SymbolSeed(0.14, 0.82, 0.13, _SymbolKind.sparkle),
    _SymbolSeed(0.68, 0.91, 0.06, _SymbolKind.moon),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..color = AppColors.primaryPink.withValues(alpha: 0.16);

    for (final symbol in _symbols) {
      final progress = (symbol.startY + animation.value * symbol.speed) % 1.18;
      final center = Offset(symbol.x * size.width, progress * size.height);
      final radius = 8 + symbol.speed * 34;
      switch (symbol.kind) {
        case _SymbolKind.star:
          _drawStar(canvas, center, radius, paint);
        case _SymbolKind.moon:
          _drawMoon(canvas, center, radius, paint);
        case _SymbolKind.card:
          _drawCard(canvas, center, radius, paint);
        case _SymbolKind.cup:
          _drawCup(canvas, center, radius, paint);
        case _SymbolKind.sparkle:
          _drawSparkle(canvas, center, radius, paint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (var index = 0; index < 10; index++) {
      final angle = -math.pi / 2 + index * math.pi / 5;
      final length = index.isEven ? radius : radius * 0.42;
      final point = Offset(
        center.dx + math.cos(angle) * length,
        center.dy + math.sin(angle) * length,
      );
      index == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawMoon(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(center.dx + radius * 0.42, center.dy),
        radius: radius * 0.82,
      ),
      math.pi / 2,
      math.pi,
      false,
      paint,
    );
  }

  void _drawCard(Canvas canvas, Offset center, double radius, Paint paint) {
    final rect = Rect.fromCenter(
      center: center,
      width: radius * 1.25,
      height: radius * 1.8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      paint,
    );
    canvas.drawCircle(center, radius * 0.23, paint);
  }

  void _drawCup(Canvas canvas, Offset center, double radius, Paint paint) {
    final bowl = Rect.fromCenter(
      center: center,
      width: radius * 1.55,
      height: radius,
    );
    canvas.drawArc(bowl, 0, math.pi, false, paint);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx + radius, center.dy + 1),
        width: radius,
        height: radius * 0.82,
      ),
      -math.pi / 2,
      math.pi,
      false,
      paint,
    );
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MysticSymbolsPainter oldDelegate) => false;
}

enum _SymbolKind { star, moon, card, cup, sparkle }

class _SymbolSeed {
  const _SymbolSeed(this.x, this.startY, this.speed, this.kind);

  final double x;
  final double startY;
  final double speed;
  final _SymbolKind kind;
}
