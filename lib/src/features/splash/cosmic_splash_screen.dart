import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CosmicSplashScreen extends StatefulWidget {
  const CosmicSplashScreen({super.key});

  @override
  State<CosmicSplashScreen> createState() => _CosmicSplashScreenState();
}

class _CosmicSplashScreenState extends State<CosmicSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _loopController;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _fade = CurvedAnimation(parent: _introController, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _introController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    const softGold = Color(0xFFF3D98B);

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_introController, _loopController]),
        builder: (context, _) {
          return Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.25),
                radius: 1.2,
                colors: [
                  Color(0xFF34124A),
                  Color(0xFF1E0A2A),
                  Color(0xFF0C0410),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _StarfieldPainter(progress: _loopController.value),
                  ),
                ),
                Center(
                  child: FadeTransition(
                    opacity: _fade,
                    child: ScaleTransition(
                      scale: _scale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _GlowingMoon(
                            gold: softGold,
                            pulse: _loopController.value,
                          ),
                          const SizedBox(height: 28),
                          ShaderMask(
                            shaderCallback: (rect) => const LinearGradient(
                              colors: [softGold, gold, softGold],
                            ).createShader(rect),
                            child: Text(
                              'Tarot AI',
                              style: GoogleFonts.cinzelDecorative(
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Kartların sana fısıldıyor',
                            style: GoogleFonts.cinzel(
                              fontSize: 13,
                              letterSpacing: 3,
                              color: softGold.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 64,
                  child: FadeTransition(
                    opacity: _fade,
                    child: const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFD4AF37),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GlowingMoon extends StatelessWidget {
  const _GlowingMoon({required this.gold, required this.pulse});
  final Color gold;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final glow = 0.5 + 0.5 * math.sin(pulse * 2 * math.pi);
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: gold.withValues(alpha: 0.25 + 0.25 * glow),
            blurRadius: 40 + 20 * glow,
            spreadRadius: 4,
          ),
        ],
      ),
      child: CustomPaint(painter: _CrescentPainter(color: gold)),
    );
  }
}

class _CrescentPainter extends CustomPainter {
  _CrescentPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.42;
    final full = Path()..addOval(Rect.fromCircle(center: center, radius: r));
    final cut = Path()
      ..addOval(
        Rect.fromCircle(
          center: center.translate(r * 0.55, -r * 0.15),
          radius: r * 0.95,
        ),
      );
    final crescent = Path.combine(PathOperation.difference, full, cut);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, color.withValues(alpha: 0.75)],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawPath(crescent, paint);
  }

  @override
  bool shouldRepaint(covariant _CrescentPainter oldDelegate) => false;
}

class _StarfieldPainter extends CustomPainter {
  _StarfieldPainter({required this.progress});
  final double progress;
  static final math.Random _rand = math.Random(7);
  static final List<Offset> _points = List.generate(
    60,
    (_) => Offset(_rand.nextDouble(), _rand.nextDouble()),
  );
  static final List<double> _phase = List.generate(
    60,
    (_) => _rand.nextDouble(),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < _points.length; i++) {
      final tw = 0.5 + 0.5 * math.sin((progress + _phase[i]) * 2 * math.pi);
      paint.color = Colors.white.withValues(
        alpha: 0.12 + 0.5 * tw * (i.isEven ? 1 : 0.6),
      );
      final dx = _points[i].dx * size.width;
      final dy = _points[i].dy * size.height;
      canvas.drawCircle(Offset(dx, dy), i % 5 == 0 ? 1.6 : 1.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
