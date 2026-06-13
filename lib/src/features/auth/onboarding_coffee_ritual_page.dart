import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
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

enum _CoffeeRitualPhase { intro, drank, flipping, sealed }

class _OnboardingCoffeeRitualPageState extends State<OnboardingCoffeeRitualPage>
    with TickerProviderStateMixin {
  static const _bg = Color(0xFF17081C);
  static const _primary = Color(0xFFFF5ED6);
  static const _secondary = Color(0xFFCDBDFF);
  static const _onSurface = Color(0xFFFADCFF);

  static const _teaserKeys = [
    'coffee_road',
    'coffee_bird',
    'coffee_heart',
    'coffee_fish',
  ];

  final math.Random _random = math.Random();
  late final AnimationController _steamController;
  late final AnimationController _drinkController;
  late final AnimationController _flipController;
  late final AnimationController _settleController;
  late final AnimationController _haloController;

  _CoffeeRitualPhase _phase = _CoffeeRitualPhase.intro;
  String? _coffeeTeaserKey;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _steamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
    _drinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _haloController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _steamController.dispose();
    _drinkController.dispose();
    _flipController.dispose();
    _settleController.dispose();
    _haloController.dispose();
    super.dispose();
  }

  Future<void> _handleCta() async {
    if (_busy) return;
    if (_phase == _CoffeeRitualPhase.sealed) {
      widget.onCoffeeSealed(_coffeeTeaserKey ?? _teaserKeys.first);
      return;
    }
    setState(() => _busy = true);
    try {
      if (_phase == _CoffeeRitualPhase.intro) {
        _steamController.stop();
        await _drinkController.forward(from: 0);
        if (!mounted) return;
        setState(() => _phase = _CoffeeRitualPhase.drank);
        return;
      }
      if (_phase == _CoffeeRitualPhase.drank) {
        setState(() => _phase = _CoffeeRitualPhase.flipping);
        await _flipController.forward(from: 0);
        await _settleController.forward(from: 0);
        _coffeeTeaserKey = _teaserKeys[_random.nextInt(_teaserKeys.length)];
        if (!mounted) return;
        setState(() => _phase = _CoffeeRitualPhase.sealed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _CoffeeBackground()),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                10,
                22,
                math.max(18, bottom + 8),
              ),
              child: Column(
                children: [
                  _topBar(),
                  Expanded(
                    child: Column(
                      children: [
                        const Spacer(),
                        _header(),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 310,
                          child: _CoffeeScene(
                            phase: _phase,
                            steamController: _steamController,
                            drinkController: _drinkController,
                            flipController: _flipController,
                            settleController: _settleController,
                            haloController: _haloController,
                          ),
                        ),
                        const SizedBox(height: 18),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          child: _phase == _CoffeeRitualPhase.sealed
                              ? Text(
                                  _confirmationText(),
                                  key: const ValueKey('sealedText'),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.newsreader(
                                    color: _onSurface.withValues(alpha: 0.94),
                                    fontSize: 23,
                                    height: 1.18,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : const SizedBox(
                                  key: ValueKey('emptyText'),
                                  height: 56,
                                ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  _PrimaryButton(label: _ctaLabel(), onTap: _handleCta),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        IconButton(
          onPressed: _busy ? null : widget.onBack,
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: _secondary,
            size: 34,
          ),
        ),
        const Spacer(),
        _MadamAvatar(size: 44),
      ],
    );
  }

  Widget _header() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      child: Column(
        key: ValueKey(_phase),
        children: [
          Text(
            _title(),
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              color: _onSurface,
              fontSize: 40,
              height: 1.05,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(color: _primary.withValues(alpha: 0.22), blurRadius: 16),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
      _CoffeeRitualPhase.intro => AppTexts.t('onboarding.coffee.title_intro'),
      _CoffeeRitualPhase.drank => AppTexts.t('onboarding.coffee.title_drank'),
      _CoffeeRitualPhase.flipping => AppTexts.t(
        'onboarding.coffee.title_settle',
      ),
      _CoffeeRitualPhase.sealed => AppTexts.t('onboarding.coffee.title_sealed'),
    };
  }

  String _subtitle() {
    return switch (_phase) {
      _CoffeeRitualPhase.intro => AppTexts.t(
        'onboarding.coffee.subtitle_intro',
      ),
      _CoffeeRitualPhase.drank => AppTexts.t(
        'onboarding.coffee.subtitle_drank',
      ),
      _CoffeeRitualPhase.flipping => AppTexts.t(
        'onboarding.coffee.subtitle_settle',
      ),
      _CoffeeRitualPhase.sealed => AppTexts.t(
        'onboarding.coffee.subtitle_sealed',
      ),
    };
  }

  String _ctaLabel() {
    if (_busy && _phase == _CoffeeRitualPhase.flipping) {
      return AppTexts.t('onboarding.coffee.cta_wait');
    }
    return switch (_phase) {
      _CoffeeRitualPhase.intro => AppTexts.t('onboarding.coffee.cta_drink'),
      _CoffeeRitualPhase.drank => AppTexts.t('onboarding.coffee.cta_flip'),
      _CoffeeRitualPhase.flipping => AppTexts.t('onboarding.coffee.cta_wait'),
      _CoffeeRitualPhase.sealed => AppTexts.t('onboarding.coffee.cta_continue'),
    };
  }

  String _confirmationText() {
    final name = widget.name.trim();
    final key = name.isEmpty
        ? 'onboarding.coffee.confirm_no_name'
        : 'onboarding.coffee.confirm';
    return AppTexts.t(key).replaceAll('{name}', name);
  }
}

class _CoffeeScene extends StatelessWidget {
  const _CoffeeScene({
    required this.phase,
    required this.steamController,
    required this.drinkController,
    required this.flipController,
    required this.settleController,
    required this.haloController,
  });

  final _CoffeeRitualPhase phase;
  final AnimationController steamController;
  final AnimationController drinkController;
  final AnimationController flipController;
  final AnimationController settleController;
  final AnimationController haloController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        steamController,
        drinkController,
        flipController,
        settleController,
        haloController,
      ]),
      builder: (context, _) {
        final flipT = Curves.easeInOutCubic.transform(flipController.value);
        final sealed = phase == _CoffeeRitualPhase.sealed;
        final flipping = phase == _CoffeeRitualPhase.flipping;
        final cupY = flipping
            ? lerpDouble(0, -58, math.sin(flipT * math.pi))!
            : 0.0;
        final cupAngle = (flipping || sealed)
            ? lerpDouble(0, math.pi, flipT)!
            : 0.0;
        final haloT = Curves.easeInOut.transform(haloController.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: 34,
              child: CustomPaint(
                size: const Size(240, 90),
                painter: _SaucerPainter(),
              ),
            ),
            if (sealed || flipping)
              Positioned(
                bottom: 80,
                child: Opacity(
                  opacity: sealed ? 1 : settleController.value,
                  child: Transform.rotate(
                    angle: settleController.value * math.pi * 2,
                    child: CustomPaint(
                      size: const Size(190, 120),
                      painter: _TelveSwirlPainter(
                        progress: settleController.value,
                        sealed: sealed,
                        halo: haloT,
                      ),
                    ),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(0, cupY),
              child: Transform.rotate(
                angle: cupAngle,
                child: CustomPaint(
                  size: const Size(190, 170),
                  painter: _CupPainter(
                    coffeeLevel: 1 - drinkController.value,
                    steamProgress: steamController.value,
                    showSteam:
                        phase == _CoffeeRitualPhase.intro &&
                        drinkController.value < 0.18,
                    inverted: sealed || flipping,
                    wobble:
                        math.sin(drinkController.value * math.pi * 8) *
                        (phase == _CoffeeRitualPhase.intro ? 0.025 : 0),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CupPainter extends CustomPainter {
  const _CupPainter({
    required this.coffeeLevel,
    required this.steamProgress,
    required this.showSteam,
    required this.inverted,
    required this.wobble,
  });

  final double coffeeLevel;
  final double steamProgress;
  final bool showSteam;
  final bool inverted;
  final double wobble;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(wobble);
    canvas.translate(-size.width / 2, -size.height / 2);

    final cupRect = Rect.fromLTWH(36, 44, 118, 86);
    final cupBody = RRect.fromRectAndCorners(
      cupRect,
      bottomLeft: const Radius.circular(34),
      bottomRight: const Radius.circular(34),
      topLeft: const Radius.circular(22),
      topRight: const Radius.circular(22),
    );
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF7FB), Color(0xFFDCC9E6), Color(0xFF8F6AA2)],
      ).createShader(cupRect);
    canvas.drawRRect(cupBody, bodyPaint);

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = _CoffeePalette.gold.withValues(alpha: 0.92);
    final rimRect = Rect.fromLTWH(34, 36, 122, 30);
    canvas.drawOval(rimRect, rimPaint);

    final coffeePaint = Paint()
      ..color = const Color(0xFF3A1711).withValues(alpha: 0.92);
    if (!inverted && coffeeLevel > 0.05) {
      final levelHeight = 22 * coffeeLevel.clamp(0.0, 1.0);
      final coffeeRect = Rect.fromLTWH(
        42,
        43 + (22 - levelHeight),
        106,
        math.max(3, levelHeight),
      );
      canvas.drawOval(coffeeRect, coffeePaint);
    }

    final handlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFF7FB), Color(0xFFB897CA)],
      ).createShader(Rect.fromLTWH(134, 58, 46, 58));
    canvas.drawArc(
      Rect.fromLTWH(132, 58, 46, 58),
      -math.pi / 2,
      math.pi,
      false,
      handlePaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(137, 66, 28, 40),
      -math.pi / 2,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = _CoffeePalette.bg,
    );

    final glossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.26)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(Rect.fromLTWH(58, 58, 28, 54), glossPaint);

    if (showSteam) {
      final steamPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = _CoffeePalette.secondary.withValues(alpha: 0.46);
      for (var i = 0; i < 3; i++) {
        final x = 72.0 + i * 22;
        final shift = math.sin(steamProgress * math.pi * 2 + i) * 8;
        final path = Path()
          ..moveTo(x, 24)
          ..cubicTo(x - 18 + shift, 10, x + 18 - shift, -8, x + shift, -24);
        canvas.drawPath(path, steamPaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CupPainter oldDelegate) {
    return oldDelegate.coffeeLevel != coffeeLevel ||
        oldDelegate.steamProgress != steamProgress ||
        oldDelegate.showSteam != showSteam ||
        oldDelegate.inverted != inverted ||
        oldDelegate.wobble != wobble;
  }
}

class _SaucerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawOval(rect.deflate(16).translate(0, 12), shadowPaint);
    final saucerPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFEEDDF5), Color(0xFF9D79B4), Color(0xFFFFE792)],
      ).createShader(rect);
    canvas.drawOval(rect.deflate(14), saucerPaint);
    canvas.drawOval(
      rect.deflate(34),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _CoffeePalette.gold.withValues(alpha: 0.64),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TelveSwirlPainter extends CustomPainter {
  const _TelveSwirlPainter({
    required this.progress,
    required this.sealed,
    required this.halo,
  });

  final double progress;
  final bool sealed;
  final double halo;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = _CoffeePalette.gold.withValues(
        alpha: sealed ? 0.42 + halo * 0.24 : 0.18,
      );
    canvas.drawCircle(
      center,
      size.shortestSide * (0.30 + halo * 0.04),
      haloPaint,
    );

    final markPaint = Paint()
      ..color = const Color(0xFF4A2119).withValues(alpha: sealed ? 0.46 : 0.24);
    for (var i = 0; i < 16; i++) {
      final angle = i * 0.9 + progress * math.pi * 2;
      final radius = 18.0 + (i % 5) * 8.0;
      canvas.drawOval(
        Rect.fromCenter(
          center: center + Offset(math.cos(angle), math.sin(angle)) * radius,
          width: 4 + (i % 3).toDouble(),
          height: 2.5,
        ),
        markPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TelveSwirlPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.sealed != sealed ||
        oldDelegate.halo != halo;
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [_CoffeePalette.primary, _CoffeePalette.primaryDeep],
          ),
          boxShadow: [
            BoxShadow(
              color: _CoffeePalette.primaryDeep.withValues(alpha: 0.34),
              blurRadius: 28,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            color: _CoffeePalette.ctaText,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
          ),
        ),
      ),
    );
  }
}

class _MadamAvatar extends StatelessWidget {
  const _MadamAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [_CoffeePalette.primary, _CoffeePalette.gold],
        ),
        boxShadow: [
          BoxShadow(
            color: _CoffeePalette.primary.withValues(alpha: 0.26),
            blurRadius: 26,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/onboarding/madam_aris.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _CoffeeBackground extends StatelessWidget {
  const _CoffeeBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.18, -0.78),
          radius: 1.22,
          colors: [Color(0xFF32133B), Color(0xFF17081C), Color(0xFF0D0411)],
          stops: [0, 0.62, 1],
        ),
      ),
      child: CustomPaint(painter: _CoffeeStarsPainter()),
    );
  }
}

class _CoffeeStarsPainter extends CustomPainter {
  const _CoffeeStarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 58; i++) {
      final x = _fract(math.sin(i * 12.9898) * 43758.5453);
      final y = _fract(math.sin(i * 78.233) * 12731.731);
      paint.color =
          (i % 3 == 0
                  ? _CoffeePalette.gold
                  : i % 3 == 1
                  ? _CoffeePalette.primary
                  : _CoffeePalette.secondary)
              .withValues(alpha: i % 5 == 0 ? 0.34 : 0.16);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        i % 6 == 0 ? 1.8 : 1.0,
        paint,
      );
    }
  }

  double _fract(double value) => value - value.floorToDouble();

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CoffeePalette {
  const _CoffeePalette._();

  static const bg = Color(0xFF17081C);
  static const primary = Color(0xFFFF5ED6);
  static const primaryDeep = Color(0xFFFF00D4);
  static const secondary = Color(0xFFCDBDFF);
  static const gold = Color(0xFFFFE792);
  static const ctaText = Color(0xFF430036);
}
