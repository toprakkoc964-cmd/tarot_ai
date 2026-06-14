import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_texts.dart';

class OnboardingCoffeeRitualPage extends StatefulWidget {
  const OnboardingCoffeeRitualPage({
    super.key,
    required this.name,
    required this.onCoffeeSealed,
    this.onBack,
  });

  final String name;
  final void Function(String coffeeTeaserKey) onCoffeeSealed;
  final VoidCallback? onBack;

  @override
  State<OnboardingCoffeeRitualPage> createState() =>
      _OnboardingCoffeeRitualPageState();
}

enum _CoffeeRitualPhase { drink, flipping, bridge }

class _OnboardingCoffeeRitualPageState extends State<OnboardingCoffeeRitualPage>
    with TickerProviderStateMixin {
  static const _bg = Color(0xFF17081C);
  static const _surface = Color(0xFF1E0C25);
  static const _primary = Color(0xFFFF5ED6);
  static const _primaryDeep = Color(0xFFFF00D4);
  static const _secondary = Color(0xFFCDBDFF);
  static const _onSurface = Color(0xFFFADCFF);
  static const _gold = Color(0xFFFFE792);
  static const _outline = Color(0xFF5B3C66);

  static const _teaserKeys = [
    'coffee_road',
    'coffee_bird',
    'coffee_heart',
    'coffee_fish',
  ];

  final math.Random _random = math.Random();
  late final AnimationController _holdController;
  late final AnimationController _capController;
  late final AnimationController _flipController;
  late final AnimationController _glowController;

  _CoffeeRitualPhase _phase = _CoffeeRitualPhase.drink;
  String? _coffeeTeaserKey;
  bool _releasedEarly = false;
  bool _busy = false;
  int _lastHapticStep = 0;

  @override
  void initState() {
    super.initState();
    _holdController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 2600),
          )
          ..addListener(_handleHoldProgress)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _completeHold();
            }
          });
    _capController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _holdController
      ..removeListener(_handleHoldProgress)
      ..dispose();
    _capController.dispose();
    _flipController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _handleHoldProgress() {
    final step = (_holdController.value * 4).floor();
    if (step > _lastHapticStep && step < 4) {
      _lastHapticStep = step;
      HapticFeedback.selectionClick();
    }
  }

  bool get _reduceMotion {
    final media = MediaQuery.maybeOf(context);
    return media?.disableAnimations ?? false;
  }

  void _startHold() {
    if (_phase != _CoffeeRitualPhase.drink || _busy) return;
    setState(() => _releasedEarly = false);
    _lastHapticStep = 0;
    if (_reduceMotion) {
      _holdController.value = 1;
      _completeHold();
      return;
    }
    _holdController.forward();
  }

  void _cancelHold() {
    if (_phase != _CoffeeRitualPhase.drink || _busy) return;
    if (_holdController.isCompleted) return;
    setState(() => _releasedEarly = true);
    _holdController.reverse();
  }

  Future<void> _completeHold() async {
    if (_busy || _phase != _CoffeeRitualPhase.drink) return;
    setState(() {
      _busy = true;
      _phase = _CoffeeRitualPhase.flipping;
    });
    _coffeeTeaserKey = _teaserKeys[_random.nextInt(_teaserKeys.length)];

    try {
      HapticFeedback.mediumImpact();
      if (_reduceMotion) {
        _capController.value = 1;
        _flipController.value = 1;
      } else {
        await _capController.forward(from: 0);
        if (!mounted) return;
        await _flipController.forward(from: 0);
      }
      HapticFeedback.lightImpact();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _phase = _CoffeeRitualPhase.bridge;
      });
    } finally {
      if (mounted && _phase != _CoffeeRitualPhase.bridge) {
        setState(() => _busy = false);
      }
    }
  }

  void _continue() {
    if (_phase != _CoffeeRitualPhase.bridge) return;
    widget.onCoffeeSealed(_coffeeTeaserKey ?? _teaserKeys.first);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            const Positioned.fill(child: _CoffeeRitualBackground()),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  22,
                  18,
                  22,
                  math.max(22, bottom + 10),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _header(),
                    Expanded(
                      child: Center(
                        child: _CoffeeRitualScene(
                          hold: _holdController,
                          cap: _capController,
                          flip: _flipController,
                          glow: _glowController,
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: _phase == _CoffeeRitualPhase.bridge
                          ? _BridgeButton(onTap: _continue)
                          : _HoldIntentionButton(
                              key: const ValueKey('holdButton'),
                              progress: _holdController,
                              glow: _glowController,
                              enabled: _phase == _CoffeeRitualPhase.drink,
                              onStart: _startHold,
                              onCancel: _cancelHold,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: Column(
        key: ValueKey(_phase.name + _releasedEarly.toString()),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _title(),
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              color: _onSurface,
              fontSize: _phase == _CoffeeRitualPhase.bridge ? 34 : 38,
              height: 1.08,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(color: _primary.withValues(alpha: 0.22), blurRadius: 16),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Text(
            _subtitle(),
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: _secondary.withValues(alpha: 0.88),
              fontSize: 15.5,
              height: 1.42,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _title() {
    return switch (_phase) {
      _CoffeeRitualPhase.drink => AppTexts.t('onboarding.coffee.title_intro'),
      _CoffeeRitualPhase.flipping => AppTexts.t(
        'onboarding.coffee.title_settle',
      ),
      _CoffeeRitualPhase.bridge => AppTexts.t('onboarding.coffee.bridge_title'),
    };
  }

  String _subtitle() {
    if (_phase == _CoffeeRitualPhase.drink && _releasedEarly) {
      return AppTexts.t('onboarding.coffee.release_hint');
    }
    return switch (_phase) {
      _CoffeeRitualPhase.drink => AppTexts.t(
        'onboarding.coffee.subtitle_intro',
      ),
      _CoffeeRitualPhase.flipping => AppTexts.t(
        'onboarding.coffee.subtitle_settle',
      ),
      _CoffeeRitualPhase.bridge => AppTexts.t(
        'onboarding.coffee.bridge_subtitle',
      ),
    };
  }
}

class _HoldIntentionButton extends StatelessWidget {
  const _HoldIntentionButton({
    super.key,
    required this.progress,
    required this.glow,
    required this.enabled,
    required this.onStart,
    required this.onCancel,
  });

  final Animation<double> progress;
  final Animation<double> glow;
  final bool enabled;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => onStart() : null,
      onTapUp: enabled ? (_) => onCancel() : null,
      onTapCancel: enabled ? onCancel : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([progress, glow]),
        builder: (context, _) {
          final pulse = Curves.easeInOut.transform(glow.value);
          return SizedBox(
            width: 150,
            height: 150,
            child: CustomPaint(
              painter: _HoldRingPainter(progress: progress.value),
              child: Center(
                child: Container(
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _OnboardingCoffeeRitualPageState._primary,
                        _OnboardingCoffeeRitualPageState._primaryDeep,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _OnboardingCoffeeRitualPageState._primaryDeep
                            .withValues(alpha: 0.34 + pulse * 0.18),
                        blurRadius: 22 + pulse * 22,
                        spreadRadius: 1 + pulse * 2,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    AppTexts.t('onboarding.coffee.hold_button'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BridgeButton extends StatelessWidget {
  const _BridgeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('bridgeButton'),
      width: double.infinity,
      height: 60,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            colors: [
              _OnboardingCoffeeRitualPageState._primary,
              _OnboardingCoffeeRitualPageState._primaryDeep,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: _OnboardingCoffeeRitualPageState._primary.withValues(
                alpha: 0.36,
              ),
              blurRadius: 26,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: onTap,
            child: Center(
              child: Text(
                AppTexts.t('onboarding.coffee.cta_continue'),
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoffeeRitualScene extends StatelessWidget {
  const _CoffeeRitualScene({
    required this.hold,
    required this.cap,
    required this.flip,
    required this.glow,
  });

  final Animation<double> hold;
  final Animation<double> cap;
  final Animation<double> flip;
  final Animation<double> glow;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([hold, cap, flip, glow]),
      builder: (context, _) {
        final capT = Curves.easeInOutCubic.transform(cap.value);
        final flipT = Curves.easeInOutCubic.transform(flip.value);
        final pulse = Curves.easeInOut.transform(glow.value);
        final coffeeLevel = lerpDouble(0.82, 0.0, hold.value)!;
        return RepaintBoundary(
          child: SizedBox(
            width: 310,
            height: 330,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 230 + pulse * 18,
                  height: 230 + pulse * 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _OnboardingCoffeeRitualPageState._primary.withValues(
                          alpha: 0.22 + pulse * 0.08,
                        ),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: math.pi * flipT,
                  alignment: Alignment.center,
                  child: CustomPaint(
                    size: const Size(260, 260),
                    painter: _CoffeeCupPainter(
                      coffeeLevel: coffeeLevel,
                      capProgress: capT,
                      flipProgress: flipT,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CoffeeCupPainter extends CustomPainter {
  const _CoffeeCupPainter({
    required this.coffeeLevel,
    required this.capProgress,
    required this.flipProgress,
  });

  final double coffeeLevel;
  final double capProgress;
  final double flipProgress;

  @override
  void paint(Canvas canvas, Size size) {
    // TODO(onboarding): Replace this painter with coffee_cup/coffee_fill/
    // coffee_saucer assets when final transparent PNGs are added.
    final center = Offset(size.width / 2, size.height / 2);
    final saucerY = lerpDouble(186, 102, capProgress)!;
    final cupY = center.dy - 16;

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, 216), width: 170, height: 30),
      shadow,
    );

    final saucerRect = Rect.fromCenter(
      center: Offset(center.dx, saucerY),
      width: 178,
      height: 40,
    );
    final saucerPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFBEEFF), Color(0xFFD8CAFF), Color(0xFFF6E4FF)],
      ).createShader(saucerRect);
    canvas.drawOval(saucerRect, saucerPaint);
    canvas.drawOval(
      saucerRect.deflate(8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF8E77AC).withValues(alpha: 0.54),
    );

    final bodyPath = Path()
      ..moveTo(center.dx - 62, cupY - 22)
      ..cubicTo(
        center.dx - 54,
        cupY + 70,
        center.dx - 42,
        cupY + 104,
        center.dx,
        cupY + 110,
      )
      ..cubicTo(
        center.dx + 42,
        cupY + 104,
        center.dx + 54,
        cupY + 70,
        center.dx + 62,
        cupY - 22,
      )
      ..close();
    final bodyRect = bodyPath.getBounds();
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5E6FF), Color(0xFFB29AFF), Color(0xFFFFB7E9)],
        ).createShader(bodyRect),
    );

    if (coffeeLevel > 0.01) {
      canvas.save();
      canvas.clipPath(bodyPath);
      final fillHeight = bodyRect.height * coffeeLevel.clamp(0.0, 1.0);
      final liquidTop = bodyRect.bottom - fillHeight;
      final liquidRect = Rect.fromLTRB(
        bodyRect.left + 8,
        liquidTop,
        bodyRect.right - 8,
        bodyRect.bottom,
      );
      canvas.drawRect(
        liquidRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A2410), Color(0xFF1F0D04)],
          ).createShader(liquidRect),
      );
      final surfaceRect = Rect.fromCenter(
        center: Offset(center.dx, liquidTop + 3),
        width: 106,
        height: 18,
      );
      canvas.drawOval(
        surfaceRect,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFF7C4A22), Color(0xFF2D1307)],
          ).createShader(surfaceRect),
      );
      canvas.restore();
    }

    canvas.drawPath(
      bodyPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xFFEAD9F6).withValues(alpha: 0.78),
    );

    final rimRect = Rect.fromCenter(
      center: Offset(center.dx, cupY - 24),
      width: 136,
      height: 46,
    );
    canvas.drawOval(
      rimRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFCDBDFF)],
        ).createShader(rimRect),
    );
    canvas.drawOval(
      rimRect.deflate(8),
      Paint()..color = _OnboardingCoffeeRitualPageState._surface,
    );

    if (coffeeLevel > 0.01) {
      final fillRect = Rect.fromCenter(
        center: Offset(center.dx, cupY - 24),
        width: 104,
        height: 28,
      );
      canvas.drawOval(
        fillRect,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFF7C4A22), Color(0xFF1F0D04)],
          ).createShader(fillRect),
      );
      for (var i = 0; i < 9; i++) {
        final angle = i * math.pi * 0.41 + coffeeLevel * 1.4;
        final radius = 18 + (i % 3) * 7;
        canvas.drawCircle(
          Offset(
            center.dx + math.cos(angle) * radius,
            cupY - 24 + math.sin(angle) * 6,
          ),
          1.6,
          Paint()
            ..color = _OnboardingCoffeeRitualPageState._gold.withValues(
              alpha: 0.28 * coffeeLevel,
            ),
        );
      }
    }

    final handlePath = Path()
      ..moveTo(center.dx + 58, cupY + 16)
      ..cubicTo(
        center.dx + 96,
        cupY + 14,
        center.dx + 98,
        cupY + 66,
        center.dx + 63,
        cupY + 68,
      )
      ..cubicTo(
        center.dx + 84,
        cupY + 58,
        center.dx + 82,
        cupY + 28,
        center.dx + 58,
        cupY + 30,
      );
    canvas.drawPath(
      handlePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFF7DEFF).withValues(alpha: 0.78),
    );
    canvas.drawPath(
      handlePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFBDAFDB).withValues(alpha: 0.56),
    );
  }

  @override
  bool shouldRepaint(covariant _CoffeeCupPainter oldDelegate) {
    return coffeeLevel != oldDelegate.coffeeLevel ||
        capProgress != oldDelegate.capProgress ||
        flipProgress != oldDelegate.flipProgress;
  }
}

class _HoldRingPainter extends CustomPainter {
  const _HoldRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 9;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = _OnboardingCoffeeRitualPageState._outline.withValues(
        alpha: 0.62,
      );
    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          _OnboardingCoffeeRitualPageState._gold,
          _OnboardingCoffeeRitualPageState._primary,
          _OnboardingCoffeeRitualPageState._gold,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _HoldRingPainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}

class _CoffeeRitualBackground extends StatelessWidget {
  const _CoffeeRitualBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.35),
          radius: 1.15,
          colors: [Color(0xFF361A41), Color(0xFF17081C), Color(0xFF0B0410)],
          stops: [0, 0.56, 1],
        ),
      ),
      child: CustomPaint(painter: _CoffeeStarsPainter()),
    );
  }
}

class _CoffeeStarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    const points = [
      Offset(0.12, 0.14),
      Offset(0.2, 0.31),
      Offset(0.82, 0.17),
      Offset(0.74, 0.35),
      Offset(0.18, 0.72),
      Offset(0.86, 0.68),
      Offset(0.5, 0.08),
      Offset(0.43, 0.84),
    ];
    for (var i = 0; i < points.length; i++) {
      paint.color =
          (i.isEven
                  ? _OnboardingCoffeeRitualPageState._gold
                  : _OnboardingCoffeeRitualPageState._primary)
              .withValues(alpha: 0.22);
      canvas.drawCircle(
        Offset(points[i].dx * size.width, points[i].dy * size.height),
        i.isEven ? 2.2 : 1.6,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
