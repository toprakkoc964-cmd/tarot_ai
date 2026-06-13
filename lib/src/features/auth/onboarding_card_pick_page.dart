import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_texts.dart';

enum OnboardingModality { tarot, coffee, palm }

class OnboardingCardPickPage extends StatefulWidget {
  const OnboardingCardPickPage({super.key, required this.onModalityChosen});

  final void Function(OnboardingModality modality) onModalityChosen;

  @override
  State<OnboardingCardPickPage> createState() => _OnboardingCardPickPageState();
}

class _OnboardingCardPickPageState extends State<OnboardingCardPickPage>
    with TickerProviderStateMixin {
  static const Color _bg = Color(0xFF17081C);
  static const Color _primary = Color(0xFFFF5ED6);
  static const Color _secondary = Color(0xFFCDBDFF);
  static const Color _onSurface = Color(0xFFFADCFF);

  final math.Random _random = math.Random();

  late final AnimationController _introController;
  late final AnimationController _starsController;
  late final AnimationController _floatController;
  late final AnimationController _glowController;
  late final AnimationController _zodiacController;
  late final AnimationController _haloController;
  late final AnimationController _shimmerController;
  late final AnimationController _shootingStarController;
  late final AnimationController _flipController;

  int? _selectedIndex;
  OnboardingModality? _selectedModality;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6500),
    )..repeat(reverse: true);
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _zodiacController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _haloController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat(reverse: true);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat();
    _shootingStarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    )..repeat();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
  }

  @override
  void dispose() {
    _introController.dispose();
    _starsController.dispose();
    _floatController.dispose();
    _glowController.dispose();
    _zodiacController.dispose();
    _haloController.dispose();
    _shimmerController.dispose();
    _shootingStarController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _selectCard(int index) async {
    if (_locked) return;
    final modality = OnboardingModality
        .values[_random.nextInt(OnboardingModality.values.length)];
    setState(() {
      _locked = true;
      _selectedIndex = index;
      _selectedModality = modality;
    });
    await _flipController.forward(from: 0);
    if (!mounted) return;
    widget.onModalityChosen(modality);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _CardPickBackground()),
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _starsController,
                  _shootingStarController,
                ]),
                builder: (context, _) {
                  return CustomPaint(
                    painter: _TwinkleStarsPainter(
                      progress: _starsController.value,
                      shootingProgress: _shootingStarController.value,
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  left: 14,
                  top: 8,
                  child: IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: _secondary,
                      size: 34,
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final horizontalPadding = 22.0;
                    final availableWidth =
                        constraints.maxWidth - horizontalPadding * 2;
                    final preferredWidth = (constraints.maxWidth * 0.36).clamp(
                      118.0,
                      158.0,
                    );
                    final maxByFan = availableWidth / (1 + 2 * 0.82);
                    final maxByHeight = math.max(
                      108.0,
                      (constraints.maxHeight * 0.34) / 1.6,
                    );
                    final cardWidth = math.min(
                      preferredWidth,
                      math.min(maxByFan, maxByHeight),
                    );
                    final cardHeight = cardWidth * 1.6;
                    final sceneHeight = cardHeight + 116;
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        64,
                        horizontalPadding,
                        math.max(24, bottomInset + 18),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              constraints.maxHeight -
                              64 -
                              math.max(24, bottomInset + 18),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _IntroReveal(
                              controller: _introController,
                              interval: const Interval(0.0, 0.36),
                              slideY: 14,
                              child: Text(
                                AppTexts.t('onboarding.card_pick.title'),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.newsreader(
                                  color: _onSurface,
                                  fontSize: 40,
                                  height: 1.05,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0,
                                  shadows: [
                                    Shadow(
                                      color: _primary.withValues(alpha: 0.20),
                                      blurRadius: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _IntroReveal(
                              controller: _introController,
                              interval: const Interval(0.14, 0.48),
                              slideY: 12,
                              child: Text(
                                AppTexts.t('onboarding.card_pick.subtitle'),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.manrope(
                                  color: _secondary.withValues(alpha: 0.86),
                                  fontSize: 16,
                                  height: 1.42,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            SizedBox(
                              height: constraints.maxHeight < 700 ? 28 : 46,
                            ),
                            _IntroReveal(
                              controller: _introController,
                              interval: const Interval(0.26, 0.76),
                              scaleBegin: 0.94,
                              child: SizedBox(
                                height: sceneHeight,
                                child: _CardPickStage(
                                  cardWidth: cardWidth,
                                  cardHeight: cardHeight,
                                  selectedIndex: _selectedIndex,
                                  selectedModality: _selectedModality,
                                  locked: _locked,
                                  floatController: _floatController,
                                  glowController: _glowController,
                                  flipController: _flipController,
                                  zodiacController: _zodiacController,
                                  haloController: _haloController,
                                  shimmerController: _shimmerController,
                                  onCardTap: _selectCard,
                                ),
                              ),
                            ),
                            AnimatedOpacity(
                              opacity: _locked ? 0 : 1,
                              duration: const Duration(milliseconds: 260),
                              child: Text(
                                AppTexts.t('onboarding.card_pick.hint'),
                                style: GoogleFonts.manrope(
                                  color: _secondary.withValues(alpha: 0.80),
                                  fontSize: 14,
                                  height: 1.2,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardPickBackground extends StatelessWidget {
  const _CardPickBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.86),
          radius: 1.18,
          colors: [
            _OnboardingCardPickColors.bg2,
            _OnboardingCardPickColors.bg,
            Color(0xFF0D0411),
          ],
          stops: [0, 0.62, 1],
        ),
      ),
    );
  }
}

class _CardPickStage extends StatelessWidget {
  const _CardPickStage({
    required this.cardWidth,
    required this.cardHeight,
    required this.selectedIndex,
    required this.selectedModality,
    required this.locked,
    required this.floatController,
    required this.glowController,
    required this.flipController,
    required this.zodiacController,
    required this.haloController,
    required this.shimmerController,
    required this.onCardTap,
  });

  final double cardWidth;
  final double cardHeight;
  final int? selectedIndex;
  final OnboardingModality? selectedModality;
  final bool locked;
  final AnimationController floatController;
  final AnimationController glowController;
  final AnimationController flipController;
  final AnimationController zodiacController;
  final AnimationController haloController;
  final AnimationController shimmerController;
  final ValueChanged<int> onCardTap;

  @override
  Widget build(BuildContext context) {
    final fanOffset = cardWidth * 0.82;
    final zodiacSize = (cardWidth * 2.92).clamp(280.0, 380.0);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: zodiacController,
            builder: (context, _) {
              return Transform.rotate(
                angle: zodiacController.value * math.pi * 2,
                child: CustomPaint(
                  size: Size.square(zodiacSize),
                  painter: const _ZodiacWheelPainter(),
                ),
              );
            },
          ),
        ),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: haloController,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(haloController.value);
              return Transform.scale(
                scale: lerpDouble(0.92, 1.06, t)!,
                child: Container(
                  width: zodiacSize * 0.84,
                  height: zodiacSize * 0.58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _OnboardingCardPickColors.primary.withValues(
                          alpha: lerpDouble(0.14, 0.28, t)!,
                        ),
                        blurRadius: lerpDouble(44, 70, t)!,
                        spreadRadius: lerpDouble(8, 18, t)!,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _PickCard(
          index: 0,
          selectedIndex: selectedIndex,
          selectedModality: selectedModality,
          locked: locked,
          angle: -14 * math.pi / 180,
          xOffset: -fanOffset,
          baseY: 14,
          phase: 0.00,
          width: cardWidth,
          height: cardHeight,
          floatController: floatController,
          glowController: glowController,
          shimmerController: shimmerController,
          flipController: flipController,
          onTap: () => onCardTap(0),
        ),
        _PickCard(
          index: 2,
          selectedIndex: selectedIndex,
          selectedModality: selectedModality,
          locked: locked,
          angle: 14 * math.pi / 180,
          xOffset: fanOffset,
          baseY: 14,
          phase: math.pi * 1.36,
          width: cardWidth,
          height: cardHeight,
          floatController: floatController,
          glowController: glowController,
          shimmerController: shimmerController,
          flipController: flipController,
          onTap: () => onCardTap(2),
        ),
        _PickCard(
          index: 1,
          selectedIndex: selectedIndex,
          selectedModality: selectedModality,
          locked: locked,
          angle: 0,
          xOffset: 0,
          baseY: -16,
          phase: math.pi * 0.68,
          width: cardWidth,
          height: cardHeight,
          floatController: floatController,
          glowController: glowController,
          shimmerController: shimmerController,
          flipController: flipController,
          highlighted: true,
          onTap: () => onCardTap(1),
        ),
      ],
    );
  }
}

class _PickCard extends StatelessWidget {
  const _PickCard({
    required this.index,
    required this.selectedIndex,
    required this.selectedModality,
    required this.locked,
    required this.angle,
    required this.xOffset,
    required this.baseY,
    required this.phase,
    required this.width,
    required this.height,
    required this.floatController,
    required this.glowController,
    required this.shimmerController,
    required this.flipController,
    required this.onTap,
    this.highlighted = false,
  });

  final int index;
  final int? selectedIndex;
  final OnboardingModality? selectedModality;
  final bool locked;
  final double angle;
  final double xOffset;
  final double baseY;
  final double phase;
  final double width;
  final double height;
  final AnimationController floatController;
  final AnimationController glowController;
  final AnimationController shimmerController;
  final AnimationController flipController;
  final VoidCallback onTap;
  final bool highlighted;

  bool get _isSelected => selectedIndex == index;
  bool get _isDimmed => locked && !_isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        floatController,
        glowController,
        shimmerController,
        flipController,
      ]),
      builder: (context, _) {
        final bob = math.sin(floatController.value * math.pi * 2 + phase) * 4;
        final glowT = Curves.easeInOut.transform(glowController.value);
        final flip = _isSelected ? flipController.value : 0.0;
        final flipAngle = flip * math.pi;
        final showFront = _isSelected && flipAngle > math.pi / 2;
        final opacity = _isDimmed ? 0.32 : 1.0;
        final blur = _isDimmed ? 2.0 : 0.0;
        return Transform.translate(
          offset: Offset(xOffset, baseY + bob),
          child: Transform.rotate(
            angle: angle,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: locked ? null : onTap,
              child: AnimatedOpacity(
                opacity: opacity,
                duration: const Duration(milliseconds: 240),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0018)
                      ..rotateY(flipAngle),
                    child: showFront
                        ? Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(math.pi),
                            child: _CardFace(
                              width: width,
                              height: height,
                              modality:
                                  selectedModality ?? OnboardingModality.tarot,
                            ),
                          )
                        : _CardBack(
                            width: width,
                            height: height,
                            highlighted: highlighted,
                            glowValue: glowT,
                            shimmerValue: shimmerController.value,
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({
    required this.width,
    required this.height,
    required this.highlighted,
    required this.glowValue,
    required this.shimmerValue,
  });

  final double width;
  final double height;
  final bool highlighted;
  final double glowValue;
  final double shimmerValue;

  @override
  Widget build(BuildContext context) {
    final glowAlpha = highlighted
        ? lerpDouble(0.32, 0.50, glowValue)!
        : lerpDouble(0.24, 0.38, glowValue)!;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _OnboardingCardPickColors.surfaceHigh,
            _OnboardingCardPickColors.bg,
          ],
        ),
        border: Border.all(
          color: _OnboardingCardPickColors.gold.withValues(alpha: 0.82),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _OnboardingCardPickColors.primary.withValues(
              alpha: glowAlpha,
            ),
            blurRadius: highlighted ? 30 : 26,
            spreadRadius: highlighted ? 1.4 : 0.6,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _OnboardingCardPickColors.gold.withValues(
                      alpha: 0.20,
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
                    color: _OnboardingCardPickColors.gold,
                    size: width * 0.29,
                  ),
                  SizedBox(height: height * 0.055),
                  Text(
                    'Tarot AI',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.newsreader(
                      color: _OnboardingCardPickColors.onSurface,
                      fontSize: width * 0.16,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CardShimmerPainter(progress: shimmerValue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.width,
    required this.height,
    required this.modality,
  });

  final double width;
  final double height;
  final OnboardingModality modality;

  @override
  Widget build(BuildContext context) {
    final data = _ModalityCopy.from(modality);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A2056), _OnboardingCardPickColors.bg],
        ),
        border: Border.all(
          color: _OnboardingCardPickColors.gold.withValues(alpha: 0.84),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _OnboardingCardPickColors.primary.withValues(alpha: 0.40),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: width * 0.10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: width * 0.42,
              height: width * 0.42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _OnboardingCardPickColors.primary.withValues(
                  alpha: 0.16,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _OnboardingCardPickColors.primary.withValues(
                      alpha: 0.38,
                    ),
                    blurRadius: 26,
                  ),
                ],
              ),
              child: Icon(
                data.icon,
                color: _OnboardingCardPickColors.primary,
                size: math.min(56, width * 0.36),
              ),
            ),
            SizedBox(height: height * 0.08),
            Text(
              AppTexts.t(data.titleKey),
              textAlign: TextAlign.center,
              style: GoogleFonts.newsreader(
                color: _OnboardingCardPickColors.onSurface,
                fontSize: 23,
                height: 1.04,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: height * 0.035),
            Text(
              AppTexts.t(data.descKey),
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: _OnboardingCardPickColors.secondary.withValues(
                  alpha: 0.86,
                ),
                fontSize: 13,
                height: 1.22,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: height * 0.07),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _OnboardingCardPickColors.gold.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _OnboardingCardPickColors.gold.withValues(alpha: 0.48),
                ),
              ),
              child: Text(
                AppTexts.t(data.personaKey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  color: _OnboardingCardPickColors.gold,
                  fontSize: 11,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModalityCopy {
  const _ModalityCopy({
    required this.icon,
    required this.titleKey,
    required this.descKey,
    required this.personaKey,
  });

  final IconData icon;
  final String titleKey;
  final String descKey;
  final String personaKey;

  static _ModalityCopy from(OnboardingModality modality) {
    return switch (modality) {
      OnboardingModality.tarot => const _ModalityCopy(
        icon: Icons.style_rounded,
        titleKey: 'onboarding.card_pick.tarot_title',
        descKey: 'onboarding.card_pick.tarot_desc',
        personaKey: 'onboarding.card_pick.tarot_persona',
      ),
      OnboardingModality.coffee => const _ModalityCopy(
        icon: Icons.coffee_rounded,
        titleKey: 'onboarding.card_pick.coffee_title',
        descKey: 'onboarding.card_pick.coffee_desc',
        personaKey: 'onboarding.card_pick.coffee_persona',
      ),
      OnboardingModality.palm => const _ModalityCopy(
        icon: Icons.back_hand_rounded,
        titleKey: 'onboarding.card_pick.palm_title',
        descKey: 'onboarding.card_pick.palm_desc',
        personaKey: 'onboarding.card_pick.palm_persona',
      ),
    };
  }
}

class _IntroReveal extends StatelessWidget {
  const _IntroReveal({
    required this.controller,
    required this.interval,
    required this.child,
    this.slideY = 0,
    this.scaleBegin = 1,
  });

  final AnimationController controller;
  final Interval interval;
  final Widget child;
  final double slideY;
  final double scaleBegin;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(
          interval.transform(controller.value.clamp(0.0, 1.0)),
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, slideY * (1 - t)),
            child: Transform.scale(
              scale: lerpDouble(scaleBegin, 1, t)!,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _TwinkleStarsPainter extends CustomPainter {
  _TwinkleStarsPainter({
    required this.progress,
    required this.shootingProgress,
  });

  final double progress;
  final double shootingProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 80; i++) {
      final x = _fract(math.sin(i * 12.9898) * 43758.5453);
      final y = _fract(math.sin(i * 78.233) * 12731.731);
      final r = 0.7 + _fract(math.sin(i * 19.19) * 913.13) * 1.7;
      final wave = 0.5 + 0.5 * math.sin(progress * math.pi * 2 + i * 0.61);
      final alpha = lerpDouble(0.25, 0.50, wave)!;
      paint.color =
          (i % 3 == 0
                  ? _OnboardingCardPickColors.gold
                  : i % 3 == 1
                  ? _OnboardingCardPickColors.primary
                  : _OnboardingCardPickColors.secondary)
              .withValues(alpha: alpha);
      canvas.drawCircle(Offset(x * size.width, y * size.height), r, paint);
    }

    final cometWindow = shootingProgress < 0.28
        ? Curves.easeInOutCubic.transform(shootingProgress / 0.28)
        : null;
    if (cometWindow != null) {
      final start = Offset(
        lerpDouble(-size.width * 0.12, size.width * 0.92, cometWindow)!,
        lerpDouble(size.height * 0.13, size.height * 0.25, cometWindow)!,
      );
      final end = start.translate(-72, -18);
      final cometPaint = Paint()
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            _OnboardingCardPickColors.gold.withValues(alpha: 0.72),
            Colors.white.withValues(alpha: 0.80),
          ],
        ).createShader(Rect.fromPoints(end, start));
      canvas.drawLine(end, start, cometPaint);
      paint.color = Colors.white.withValues(alpha: 0.72);
      canvas.drawCircle(start, 1.8, paint);
    }
  }

  double _fract(double value) => value - value.floorToDouble();

  @override
  bool shouldRepaint(covariant _TwinkleStarsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.shootingProgress != shootingProgress;
  }
}

class _ZodiacWheelPainter extends CustomPainter {
  const _ZodiacWheelPainter();

  static const _symbols = [
    '♈',
    '♉',
    '♊',
    '♋',
    '♌',
    '♍',
    '♎',
    '♏',
    '♐',
    '♑',
    '♒',
    '♓',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.43;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = _OnboardingCardPickColors.gold.withValues(alpha: 0.13);
    canvas.drawCircle(center, radius, ringPaint);

    for (var i = 0; i < _symbols.length; i++) {
      final angle = -math.pi / 2 + (math.pi * 2 * i / _symbols.length);
      final offset = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      final painter = TextPainter(
        text: TextSpan(
          text: _symbols[i],
          style: GoogleFonts.newsreader(
            color: _OnboardingCardPickColors.gold.withValues(alpha: 0.22),
            fontSize: size.shortestSide * 0.055,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        offset - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CardShimmerPainter extends CustomPainter {
  _CardShimmerPainter({required this.progress});

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
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          _OnboardingCardPickColors.gold.withValues(alpha: 0.02),
          _OnboardingCardPickColors.gold.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.16),
          Colors.transparent,
        ],
        stops: const [0, 0.30, 0.50, 0.58, 1],
      ).createShader(rect);
    canvas.save();
    canvas.translate(centerX, size.height / 2);
    canvas.rotate(-0.42);
    canvas.translate(-centerX, -size.height / 2);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CardShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _OnboardingCardPickColors {
  const _OnboardingCardPickColors._();

  static const bg = Color(0xFF17081C);
  static const bg2 = Color(0xFF2E1537);
  static const surfaceHigh = Color(0xFF361A41);
  static const primary = Color(0xFFFF5ED6);
  static const secondary = Color(0xFFCDBDFF);
  static const onSurface = Color(0xFFFADCFF);
  static const gold = Color(0xFFFFE792);
}
