import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_texts.dart';

class DrawnTarotCard {
  const DrawnTarotCard({
    required this.id,
    required this.roman,
    required this.nameKey,
    required this.symbol,
  });

  final String id;
  final String roman;
  final String nameKey;
  final String symbol;
}

const List<DrawnTarotCard> onboardingTarotCardPool = [
  DrawnTarotCard(
    id: 'the_star',
    roman: 'XVII',
    nameKey: 'onboarding.cards.the_star',
    symbol: '✦',
  ),
  DrawnTarotCard(
    id: 'the_sun',
    roman: 'XIX',
    nameKey: 'onboarding.cards.the_sun',
    symbol: '☀',
  ),
  DrawnTarotCard(
    id: 'the_world',
    roman: 'XXI',
    nameKey: 'onboarding.cards.the_world',
    symbol: '◎',
  ),
  DrawnTarotCard(
    id: 'wheel_of_fortune',
    roman: 'X',
    nameKey: 'onboarding.cards.wheel_of_fortune',
    symbol: '✺',
  ),
  DrawnTarotCard(
    id: 'ace_of_wands',
    roman: 'I',
    nameKey: 'onboarding.cards.ace_of_wands',
    symbol: '✧',
  ),
  DrawnTarotCard(
    id: 'ace_of_cups',
    roman: 'I',
    nameKey: 'onboarding.cards.ace_of_cups',
    symbol: '☽',
  ),
  DrawnTarotCard(
    id: 'the_lovers',
    roman: 'VI',
    nameKey: 'onboarding.cards.the_lovers',
    symbol: '♡',
  ),
  DrawnTarotCard(
    id: 'the_magician',
    roman: 'I',
    nameKey: 'onboarding.cards.the_magician',
    symbol: '✶',
  ),
];

class OnboardingTarotDrawPage extends StatefulWidget {
  const OnboardingTarotDrawPage({
    super.key,
    required this.name,
    required this.onCardDrawn,
    this.onBack,
  });

  final String name;
  final void Function(DrawnTarotCard card) onCardDrawn;
  final VoidCallback? onBack;

  @override
  State<OnboardingTarotDrawPage> createState() =>
      _OnboardingTarotDrawPageState();
}

class _OnboardingTarotDrawPageState extends State<OnboardingTarotDrawPage>
    with TickerProviderStateMixin {
  static const _bg = Color(0xFF17081C);
  static const _primary = Color(0xFFFF5ED6);
  static const _secondary = Color(0xFFCDBDFF);
  static const _onSurface = Color(0xFFFADCFF);
  static const _gold = Color(0xFFFFE792);

  final math.Random _random = math.Random();
  late final AnimationController _beltController;
  late final AnimationController _glowController;
  late final AnimationController _introController;
  late final AnimationController _starsController;

  DrawnTarotCard? _drawnCard;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _beltController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 11000),
    )..repeat();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _beltController.dispose();
    _glowController.dispose();
    _introController.dispose();
    _starsController.dispose();
    super.dispose();
  }

  void _drawCard() {
    if (_locked) return;
    final card =
        onboardingTarotCardPool[_random.nextInt(
          onboardingTarotCardPool.length,
        )];
    setState(() {
      _locked = true;
      _drawnCard = card;
    });
    _beltController.stop();
  }

  void _continue() {
    final card = _drawnCard;
    if (card == null) return;
    widget.onCardDrawn(card);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _TarotDrawBackground()),
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _starsController,
                builder: (context, _) => CustomPaint(
                  painter: _TarotDrawStarsPainter(_starsController.value),
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth * 0.33).clamp(
                  112.0,
                  146.0,
                );
                final cardHeight = cardWidth * 1.58;
                return Padding(
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
                            const Spacer(flex: 2),
                            _IntroFade(
                              controller: _introController,
                              child: _header(),
                            ),
                            const Spacer(flex: 2),
                            SizedBox(
                              height: math.max(250, cardHeight + 86),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 420),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                child: _drawnCard == null
                                    ? _FlowingBelt(
                                        key: const ValueKey('belt'),
                                        controller: _beltController,
                                        cardWidth: cardWidth,
                                        cardHeight: cardHeight,
                                        onTap: _drawCard,
                                      )
                                    : _ChosenClosedCard(
                                        key: const ValueKey('chosen'),
                                        controller: _glowController,
                                        cardWidth: cardWidth * 1.12,
                                        cardHeight: cardHeight * 1.12,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 320),
                              child: _drawnCard == null
                                  ? Text(
                                      AppTexts.t('onboarding.tarot_draw.hint'),
                                      key: const ValueKey('hint'),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.manrope(
                                        color: _secondary.withValues(
                                          alpha: 0.84,
                                        ),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : Text(
                                      _confirmationText(),
                                      key: const ValueKey('confirmation'),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.newsreader(
                                        color: _onSurface.withValues(
                                          alpha: 0.94,
                                        ),
                                        fontSize: 24,
                                        height: 1.16,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                            ),
                            const Spacer(flex: 2),
                          ],
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        child: _drawnCard == null
                            ? const SizedBox(height: 60)
                            : _ContinueButton(onTap: _continue),
                      ),
                    ],
                  ),
                );
              },
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
          onPressed: widget.onBack,
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: _secondary,
            size: 34,
          ),
        ),
        const Spacer(),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _gold.withValues(alpha: 0.44)),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.18),
                blurRadius: 20,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/onboarding/bilge_aris.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Column(
      children: [
        Text(
          AppTexts.t('onboarding.tarot_draw.title'),
          textAlign: TextAlign.center,
          style: GoogleFonts.newsreader(
            color: _onSurface,
            fontSize: 42,
            height: 1.05,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(color: _primary.withValues(alpha: 0.20), blurRadius: 16),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          AppTexts.t('onboarding.tarot_draw.subtitle'),
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: _secondary.withValues(alpha: 0.88),
            fontSize: 15.5,
            height: 1.42,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _confirmationText() {
    final name = widget.name.trim();
    final key = name.isEmpty
        ? 'onboarding.tarot_draw.confirmation_no_name'
        : 'onboarding.tarot_draw.confirmation';
    return AppTexts.t(key).replaceAll('{name}', name);
  }
}

class _FlowingBelt extends StatelessWidget {
  const _FlowingBelt({
    super.key,
    required this.controller,
    required this.cardWidth,
    required this.cardHeight,
    required this.onTap,
  });

  final AnimationController controller;
  final double cardWidth;
  final double cardHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final itemExtent = cardWidth + 18;
    final groupWidth = itemExtent * 8;
    return SizedBox(
      height: cardHeight + 18,
      child: ClipRect(
        child: ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0, 0.12, 0.88, 1],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final dx = -groupWidth * controller.value;
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  for (var copy = 0; copy < 3; copy++)
                    Transform.translate(
                      offset: Offset(dx + copy * groupWidth, 0),
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        minWidth: groupWidth,
                        maxWidth: groupWidth,
                        minHeight: cardHeight + 18,
                        maxHeight: cardHeight + 18,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(8, (index) {
                            final lift =
                                math.sin((controller.value * math.pi * 2) + index) *
                                6;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 9),
                              child: Transform.translate(
                                offset: Offset(0, lift),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: onTap,
                                  child: _ClosedTarotBack(
                                    width: cardWidth,
                                    height: cardHeight,
                                    glow: 0.32,
                                    shimmer:
                                        (controller.value + index * 0.12) % 1,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChosenClosedCard extends StatelessWidget {
  const _ChosenClosedCard({
    super.key,
    required this.controller,
    required this.cardWidth,
    required this.cardHeight,
  });

  final AnimationController controller;
  final double cardWidth;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(controller.value);
          return Transform.scale(
            scale: lerpDouble(1.0, 1.035, t)!,
            child: _ClosedTarotBack(
              width: cardWidth,
              height: cardHeight,
              glow: lerpDouble(0.34, 0.56, t)!,
              shimmer: controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _ClosedTarotBack extends StatelessWidget {
  const _ClosedTarotBack({
    required this.width,
    required this.height,
    required this.glow,
    required this.shimmer,
  });

  final double width;
  final double height;
  final double glow;
  final double shimmer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _OnboardingTarotDrawPalette.surfaceHigh,
            _OnboardingTarotDrawPalette.bg,
          ],
        ),
        border: Border.all(
          color: _OnboardingTarotDrawPalette.gold.withValues(alpha: 0.86),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _OnboardingTarotDrawPalette.primary.withValues(alpha: glow),
            blurRadius: 30,
            spreadRadius: 1.4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _OnboardingTarotDrawPalette.gold.withValues(
                      alpha: 0.22,
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: _OnboardingTarotDrawPalette.gold,
                    size: width * 0.30,
                  ),
                  SizedBox(height: height * 0.055),
                  Text(
                    'Tarot AI',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.newsreader(
                      color: _OnboardingTarotDrawPalette.onSurface,
                      fontSize: width * 0.16,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _TarotBackShimmerPainter(shimmer)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.onTap});

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
            colors: [
              _OnboardingTarotDrawPalette.primary,
              _OnboardingTarotDrawPalette.primaryDeep,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: _OnboardingTarotDrawPalette.primaryDeep.withValues(
                alpha: 0.34,
              ),
              blurRadius: 28,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Text(
          AppTexts.t('onboarding.tarot_draw.cta'),
          style: GoogleFonts.spaceGrotesk(
            color: _OnboardingTarotDrawPalette.ctaText,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.4,
          ),
        ),
      ),
    );
  }
}

class _IntroFade extends StatelessWidget {
  const _IntroFade({required this.controller, required this.child});

  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}

class _TarotDrawBackground extends StatelessWidget {
  const _TarotDrawBackground();

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
    );
  }
}

class _TarotDrawStarsPainter extends CustomPainter {
  const _TarotDrawStarsPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 70; i++) {
      final x = _fract(math.sin(i * 12.9898) * 43758.5453);
      final y = _fract(math.sin(i * 78.233) * 12731.731);
      final wave = 0.5 + 0.5 * math.sin(progress * math.pi * 2 + i * 0.61);
      paint.color =
          (i % 3 == 0
                  ? _OnboardingTarotDrawPalette.gold
                  : i % 3 == 1
                  ? _OnboardingTarotDrawPalette.primary
                  : _OnboardingTarotDrawPalette.secondary)
              .withValues(alpha: lerpDouble(0.18, 0.44, wave)!);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        0.8 + (i % 4) * 0.34,
        paint,
      );
    }
  }

  double _fract(double value) => value - value.floorToDouble();

  @override
  bool shouldRepaint(covariant _TarotDrawStarsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _TarotBackShimmerPainter extends CustomPainter {
  const _TarotBackShimmerPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final sweep = progress * 1.8 - 0.42;
    final centerX = size.width * sweep;
    final rect = Rect.fromLTWH(
      centerX - 28,
      -size.height * 0.15,
      56,
      size.height * 1.3,
    );
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          _OnboardingTarotDrawPalette.gold.withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.save();
    canvas.translate(centerX, size.height / 2);
    canvas.rotate(-0.46);
    canvas.translate(-centerX, -size.height / 2);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TarotBackShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _OnboardingTarotDrawPalette {
  const _OnboardingTarotDrawPalette._();

  static const bg = Color(0xFF17081C);
  static const surfaceHigh = Color(0xFF361A41);
  static const primary = Color(0xFFFF5ED6);
  static const primaryDeep = Color(0xFFFF00D4);
  static const secondary = Color(0xFFCDBDFF);
  static const onSurface = Color(0xFFFADCFF);
  static const gold = Color(0xFFFFE792);
  static const ctaText = Color(0xFF430036);
}
