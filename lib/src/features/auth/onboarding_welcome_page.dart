import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_texts.dart';

class OnboardingWelcomePage extends StatefulWidget {
  const OnboardingWelcomePage({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  State<OnboardingWelcomePage> createState() => _OnboardingWelcomePageState();
}

class _OnboardingWelcomePageState extends State<OnboardingWelcomePage>
    with TickerProviderStateMixin {
  static const Color _bg = Color(0xFF17081C);
  static const Color _primary = Color(0xFFFF5ED6);
  static const Color _secondary = Color(0xFFCDBDFF);
  static const Color _onSurface = Color(0xFFFADCFF);

  late final AnimationController _introController;
  late final AnimationController _ctaPulseController;
  late final AnimationController _cardGlowController;
  late final AnimationController _particleController;
  late final AnimationController _backgroundController;
  late final AnimationController _brandController;
  late final AnimationController _ornamentController;
  late final AnimationController _titleShimmerController;
  late final AnimationController _cardFloatController;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
    _ctaPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);
    _cardGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 13000),
    )..repeat();
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 20000),
    )..repeat(reverse: true);
    _brandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _ornamentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _titleShimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..repeat();
    _cardFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _introController.dispose();
    _ctaPulseController.dispose();
    _cardGlowController.dispose();
    _particleController.dispose();
    _backgroundController.dispose();
    _brandController.dispose();
    _ornamentController.dispose();
    _titleShimmerController.dispose();
    _cardFloatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(
                  _backgroundController.value,
                );
                return Transform.translate(
                  offset: Offset(lerpDouble(-4, 4, t)!, lerpDouble(-6, 5, t)!),
                  child: Transform.scale(
                    scale: lerpDouble(1.0, 1.06, t)!,
                    child: Image.asset(
                      'assets/onboarding/welcome_bg.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    _bg.withValues(alpha: 0.10),
                    _bg.withValues(alpha: 0.78),
                  ],
                  stops: const [0, 0.58, 1],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _FloatingParticlesPainter(
                      progress: _particleController.value,
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    math.max(22, bottomInset + 18),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          constraints.maxHeight -
                          math.max(22, bottomInset + 18) -
                          20,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _IntroReveal(
                          controller: _introController,
                          interval: const Interval(0.00, 0.30),
                          slideY: -12,
                          child: _BrandMark(controller: _brandController),
                        ),
                        const SizedBox(height: 24),
                        _Ornament(controller: _ornamentController),
                        const SizedBox(height: 14),
                        _PersonaCards(
                          introController: _introController,
                          glowController: _cardGlowController,
                          floatController: _cardFloatController,
                        ),
                        const SizedBox(height: 20),
                        _Ornament(controller: _ornamentController, phase: 0.42),
                        const SizedBox(height: 30),
                        _IntroReveal(
                          controller: _introController,
                          interval: const Interval(0.56, 0.80),
                          slideY: 14,
                          child: _TitleShimmer(
                            controller: _titleShimmerController,
                            child: Text(
                              AppTexts.t('onboarding.welcome.title'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.newsreader(
                                color: _onSurface,
                                fontSize: 32,
                                height: 1.15,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0,
                                shadows: [
                                  Shadow(
                                    color: _primary.withValues(alpha: 0.25),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _IntroReveal(
                          controller: _introController,
                          interval: const Interval(0.66, 0.88),
                          slideY: 12,
                          child: Text(
                            AppTexts.t('onboarding.welcome.subtitle'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              color: _secondary.withValues(alpha: 0.85),
                              fontSize: 15,
                              height: 1.42,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        _IntroReveal(
                          controller: _introController,
                          interval: const Interval(0.76, 1.00),
                          slideY: 14,
                          child: _StartButton(
                            controller: _ctaPulseController,
                            onTap: widget.onStart,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(controller.value);
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.scale(
                scale: lerpDouble(1, 1.05, t)!,
                child: CustomPaint(
                  size: const Size(64, 48),
                  painter: _CrescentBrandPainter(
                    pulse: t,
                    sparkle: (math.sin(controller.value * math.pi * 2) + 1) / 2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ARIS',
                style: GoogleFonts.newsreader(
                  color: _OnboardingWelcomeColors.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 8,
                  shadows: [
                    Shadow(
                      color: _OnboardingWelcomeColors.gold.withValues(
                        alpha: lerpDouble(0.25, 0.45, t)!,
                      ),
                      blurRadius: lerpDouble(14, 22, t)!,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Ornament extends StatelessWidget {
  const _Ornament({required this.controller, this.phase = 0});

  final AnimationController controller;
  final double phase;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final wave =
            (math.sin((controller.value + phase) * math.pi * 2) + 1) / 2;
        final opacity = lerpDouble(0.50, 1.0, wave)!;
        final color = _OnboardingWelcomeColors.gold.withValues(
          alpha: 0.70 * opacity,
        );
        return SizedBox(
          height: 18,
          child: Opacity(
            opacity: opacity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dot(color),
                _line(color),
                Icon(Icons.nightlight_round, color: color, size: 14),
                _line(color),
                _dot(color),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 3.5,
      height: 3.5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _line(Color color) {
    return Container(
      width: 54,
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, color, Colors.transparent],
        ),
      ),
    );
  }
}

class _PersonaCards extends StatelessWidget {
  const _PersonaCards({
    required this.introController,
    required this.glowController,
    required this.floatController,
  });

  final AnimationController introController;
  final AnimationController glowController;
  final AnimationController floatController;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _IntroReveal(
            controller: introController,
            interval: const Interval(0.16, 0.54),
            scaleBegin: 0.92,
            child: _FloatingCardShell(
              controller: floatController,
              phase: 0,
              child: _PersonaCard(
                glowController: glowController,
                name: 'Bilge Aris',
                role: AppTexts.t('onboarding.welcome.persona_bilge_role'),
                assetPath: 'assets/onboarding/bilge_aris.png',
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _IntroReveal(
            controller: introController,
            interval: const Interval(0.25, 0.64),
            scaleBegin: 0.92,
            child: _FloatingCardShell(
              controller: floatController,
              phase: math.pi,
              child: _PersonaCard(
                glowController: glowController,
                name: 'Madam Aris',
                role: AppTexts.t('onboarding.welcome.persona_madam_role'),
                assetPath: 'assets/onboarding/madam_aris.png',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FloatingCardShell extends StatelessWidget {
  const _FloatingCardShell({
    required this.controller,
    required this.phase,
    required this.child,
  });

  final AnimationController controller;
  final double phase;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final wave = math.sin(controller.value * math.pi * 2 + phase);
        return Transform.translate(offset: Offset(0, wave * 4), child: child);
      },
    );
  }
}

class _PersonaCard extends StatelessWidget {
  const _PersonaCard({
    required this.glowController,
    required this.name,
    required this.role,
    required this.assetPath,
  });

  final AnimationController glowController;
  final String name;
  final String role;
  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowController,
      builder: (context, child) {
        final eased = Curves.easeInOut.transform(glowController.value);
        final glow = lerpDouble(0.25, 0.45, eased)!;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: _OnboardingWelcomeColors.primary.withValues(alpha: glow),
                blurRadius: lerpDouble(18, 28, eased)!,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _OnboardingWelcomeColors.primary,
              _OnboardingWelcomeColors.gold,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: AspectRatio(
              aspectRatio: 0.72,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    assetPath,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (context, error, stackTrace) {
                      return const _PersonaPlaceholder();
                    },
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: const Alignment(0, 0.20),
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          _OnboardingWelcomeColors.bg.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 14,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            name,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.newsreader(
                              color: Colors.white,
                              fontSize: 19,
                              height: 1,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _OnboardingWelcomeColors.gold.withValues(
                                alpha: 0.45,
                              ),
                            ),
                          ),
                          child: Text(
                            role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.spaceGrotesk(
                              color: _OnboardingWelcomeColors.secondary,
                              fontSize: 12,
                              height: 1,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonaPlaceholder extends StatelessWidget {
  const _PersonaPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _OnboardingWelcomeColors.surfaceHigh,
            _OnboardingWelcomeColors.bg,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.auto_awesome,
          color: _OnboardingWelcomeColors.gold,
          size: 40,
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.controller, required this.onTap});

  final AnimationController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(controller.value);
        return Transform.scale(
          scale: lerpDouble(1, 1.025, t)!,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: lerpDouble(0.94, 1.06, t)!,
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _OnboardingWelcomeColors.gold.withValues(
                        alpha: lerpDouble(0.24, 0.52, t)!,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _OnboardingWelcomeColors.primary.withValues(
                          alpha: lerpDouble(0.18, 0.38, t)!,
                        ),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: _OnboardingWelcomeColors.primary.withValues(
                        alpha: lerpDouble(0.30, 0.45, t)!,
                      ),
                      blurRadius: lerpDouble(20, 28, t)!,
                      spreadRadius: lerpDouble(0, 1.5, t)!,
                    ),
                  ],
                ),
                child: child,
              ),
            ],
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(32),
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: onTap,
          child: Ink(
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: const LinearGradient(
                colors: [
                  _OnboardingWelcomeColors.primary,
                  _OnboardingWelcomeColors.primaryDeep,
                ],
              ),
            ),
            child: Center(
              child: Text(
                AppTexts.t('onboarding.welcome.cta_start'),
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  shadows: const [
                    Shadow(
                      color: Color(0x66000000),
                      blurRadius: 8,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

class _TitleShimmer extends StatelessWidget {
  const _TitleShimmer({required this.controller, required this.child});

  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final sweep = controller.value * 2.2 - 0.6;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                _OnboardingWelcomeColors.onSurface.withValues(alpha: 0.92),
                _OnboardingWelcomeColors.onSurface.withValues(alpha: 0.95),
                _OnboardingWelcomeColors.gold.withValues(alpha: 0.82),
                Colors.white.withValues(alpha: 0.96),
                _OnboardingWelcomeColors.onSurface.withValues(alpha: 0.92),
              ],
              stops: [
                (sweep - 0.26).clamp(0.0, 1.0),
                (sweep - 0.10).clamp(0.0, 1.0),
                sweep.clamp(0.0, 1.0),
                (sweep + 0.08).clamp(0.0, 1.0),
                (sweep + 0.24).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class _CrescentBrandPainter extends CustomPainter {
  _CrescentBrandPainter({required this.pulse, required this.sparkle});

  final double pulse;
  final double sparkle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.44, size.height * 0.52);
    final moonPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          _OnboardingWelcomeColors.gold,
          Color(0xFFFFB6F0),
          _OnboardingWelcomeColors.secondary,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawCircle(center, 19, moonPaint);

    final cutPaint = Paint()
      ..color = _OnboardingWelcomeColors.bg.withValues(alpha: 0.92);
    canvas.drawCircle(center + const Offset(8, -3), 18, cutPaint);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lerpDouble(0.8, 1.15, pulse)!
      ..color = _OnboardingWelcomeColors.gold.withValues(
        alpha: lerpDouble(0.35, 0.62, pulse)!,
      );
    canvas.drawCircle(center, 22, ringPaint);

    final sparklePaint = Paint()
      ..color = _OnboardingWelcomeColors.onSurface.withValues(
        alpha: lerpDouble(0.40, 1.0, sparkle)!,
      );
    for (final star in const [
      Offset(39, 15),
      Offset(48, 22),
      Offset(40, 31),
      Offset(53, 12),
    ]) {
      _drawDiamond(canvas, star, star.dx > 50 ? 2.2 : 3.2, sparklePaint);
    }
  }

  void _drawDiamond(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CrescentBrandPainter oldDelegate) {
    return oldDelegate.pulse != pulse || oldDelegate.sparkle != sparkle;
  }
}

class _FloatingParticlesPainter extends CustomPainter {
  _FloatingParticlesPainter({required this.progress});

  final double progress;

  static const List<_ParticleSeed> _particles = [
    _ParticleSeed(0.08, 0.12, 1.3, 0.10, 0),
    _ParticleSeed(0.16, 0.72, 2.1, 0.18, 1),
    _ParticleSeed(0.24, 0.38, 1.6, 0.14, 2),
    _ParticleSeed(0.31, 0.86, 2.5, 0.20, 0),
    _ParticleSeed(0.39, 0.22, 1.4, 0.17, 1),
    _ParticleSeed(0.46, 0.60, 2.7, 0.22, 2),
    _ParticleSeed(0.53, 0.08, 1.2, 0.12, 0),
    _ParticleSeed(0.61, 0.75, 2.0, 0.16, 1),
    _ParticleSeed(0.69, 0.46, 1.8, 0.19, 2),
    _ParticleSeed(0.78, 0.16, 2.4, 0.21, 0),
    _ParticleSeed(0.86, 0.66, 1.5, 0.15, 1),
    _ParticleSeed(0.93, 0.31, 2.2, 0.18, 2),
    _ParticleSeed(0.12, 0.50, 1.1, 0.11, 2),
    _ParticleSeed(0.21, 0.94, 2.8, 0.23, 0),
    _ParticleSeed(0.35, 0.04, 1.7, 0.13, 1),
    _ParticleSeed(0.58, 0.92, 1.9, 0.16, 2),
    _ParticleSeed(0.73, 0.83, 1.3, 0.12, 0),
    _ParticleSeed(0.88, 0.05, 2.6, 0.19, 1),
    _ParticleSeed(0.05, 0.84, 1.6, 0.15, 2),
    _ParticleSeed(0.66, 0.28, 2.1, 0.18, 0),
    _ParticleSeed(0.43, 0.79, 1.4, 0.14, 1),
    _ParticleSeed(0.96, 0.58, 1.9, 0.17, 2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      final local = (progress + p.x * 0.37 + p.y * 0.13) % 1;
      final y = ((p.y - local * 1.18) % 1.12) * size.height;
      final sway = math.sin((local * math.pi * 2) + i * 0.73) * 10;
      final x = p.x * size.width + sway;
      final twinkle =
          0.5 + 0.5 * math.sin((local * math.pi * 2.0) + p.x * math.pi * 3);
      final color = switch (p.colorIndex) {
        0 => _OnboardingWelcomeColors.gold,
        1 => _OnboardingWelcomeColors.primary,
        _ => _OnboardingWelcomeColors.secondary,
      };
      paint.color = color.withValues(
        alpha: (p.alpha + twinkle * 0.26).clamp(0.20, 0.60),
      );
      canvas.drawCircle(Offset(x, y), p.radius, paint);
      paint.color = color.withValues(alpha: 0.08 + twinkle * 0.08);
      canvas.drawCircle(Offset(x, y), p.radius * 3.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ParticleSeed {
  const _ParticleSeed(this.x, this.y, this.radius, this.alpha, this.colorIndex);

  final double x;
  final double y;
  final double radius;
  final double alpha;
  final int colorIndex;
}

class _OnboardingWelcomeColors {
  const _OnboardingWelcomeColors._();

  static const bg = Color(0xFF17081C);
  static const surfaceHigh = Color(0xFF361A41);
  static const primary = Color(0xFFFF5ED6);
  static const primaryDeep = Color(0xFFFF00D4);
  static const secondary = Color(0xFFCDBDFF);
  static const onSurface = Color(0xFFFADCFF);
  static const gold = Color(0xFFFFE792);
}
