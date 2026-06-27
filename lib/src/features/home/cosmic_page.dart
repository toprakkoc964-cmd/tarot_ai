import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/localization_service.dart';
import '../../core/app_texts.dart';
import '../coffee_reading/screens/coffee_capture_flow_screen.dart';
import '../palmistry/screens/palm_scanner_screen.dart';
import '../auth/user_profile_contract.dart';
import 'ai_chat_context.dart';
import 'chat_page.dart';
import 'credit_page.dart';
import 'home_palette.dart';

const _kCoffeeReadingCost = 20;
const _kPalmReadingCost = 20;

class CosmicPage extends StatelessWidget {
  const CosmicPage({super.key, required this.bottomInset, required this.uid});

  final double bottomInset;
  final String uid;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LocalizationService.instance.revision,
      builder: (context, _, __) => Stack(
        children: [
          const _CosmicBackground(),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 28),
              children: [
                _CosmicHeader(uid: uid),
                const SizedBox(height: 32),
                _CosmicPageTitle(),
                const SizedBox(height: 28),
                CosmicFeatureCard(
                  title: AppTexts.t('home.cosmic.palm.title'),
                  description: AppTexts.t('home.cosmic.palm.description'),
                  buttonText: AppTexts.t('home.cosmic.palm.button'),
                  icon: Icons.front_hand_rounded,
                  accentIcon: Icons.pan_tool_alt_rounded,
                  onTap: () => _openPalmScanner(context, uid),
                ),
                const SizedBox(height: 24),
                CosmicFeatureCard(
                  title: AppTexts.t('home.cosmic.coffee.title'),
                  description: AppTexts.t('home.cosmic.coffee.description'),
                  buttonText: AppTexts.t('home.cosmic.coffee.button'),
                  icon: Icons.local_cafe_rounded,
                  accentIcon: Icons.coffee_rounded,
                  onTap: () => _openCoffeeReading(context, uid),
                ),
                const SizedBox(height: 24),
                CosmicFeatureCard(
                  title: AppTexts.t('home.cosmic.numerology.title'),
                  description: AppTexts.t(
                    'home.cosmic.numerology.description',
                  ),
                  buttonText: AppTexts.t('home.cosmic.numerology.button'),
                  icon: Icons.auto_stories_rounded,
                  accentIcon: Icons.auto_awesome_rounded,
                  onTap: () => _openNumerologyReading(context, uid),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _openPalmScanner(
    BuildContext context,
    String uid,
  ) async {
    final canStart = await _ensureCredits(
      context,
      uid: uid,
      requiredCredits: _kPalmReadingCost,
    );
    if (!context.mounted || !canStart) return;

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) {
          return FadeTransition(
            opacity: animation,
            child: const PalmScannerScreen(),
          );
        },
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  static Future<void> _openCoffeeReading(
    BuildContext context,
    String uid,
  ) async {
    final canStart = await _ensureCredits(
      context,
      uid: uid,
      requiredCredits: _kCoffeeReadingCost,
    );
    if (!context.mounted || !canStart) return;

    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) {
          return FadeTransition(
            opacity: animation,
            child: CoffeeCaptureFlowScreen(uid: uid),
          );
        },
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  static Future<void> _openNumerologyReading(
    BuildContext context,
    String uid,
  ) async {
    final chatResult = await Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        pageBuilder: (_, animation, __) {
          return FadeTransition(
            opacity: animation,
            child: KozmikBilgePage(
              uid: uid,
              chatContext: AiChatContext.numerologyReadingMadamAris(),
            ),
          );
        },
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
    if (!context.mounted || chatResult != 'credits') return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CreditPage(
          bottomInset: MediaQuery.of(context).padding.bottom,
          uid: uid,
        ),
      ),
    );
  }

  static Future<bool> _ensureCredits(
    BuildContext context, {
    required String uid,
    required int requiredCredits,
  }) async {
    final credits = await _currentWalletCredits(uid);
    if (credits >= requiredCredits) return true;
    if (!context.mounted) return false;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(AppTexts.t('reading.gate.insufficient'))),
      );
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CreditPage(
          bottomInset: MediaQuery.of(context).padding.bottom,
          uid: uid,
        ),
      ),
    );
    return await _currentWalletCredits(uid) >= requiredCredits;
  }

  static Future<int> _currentWalletCredits(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(UserProfileContract.usersCollection)
        .doc(uid)
        .get();
    final data = snapshot.data();
    final wallet = Map<String, dynamic>.from(
      data?[UserProfileContract.wallet] as Map? ?? const {},
    );
    return (wallet[UserProfileContract.walletCredits] as num?)?.toInt() ?? 0;
  }
}

class _CosmicHeader extends StatelessWidget {
  const _CosmicHeader({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(UserProfileContract.usersCollection)
              .doc(uid)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            final wallet = Map<String, dynamic>.from(
              data?[UserProfileContract.wallet] as Map? ?? const {},
            );
            final credits = (wallet[UserProfileContract.walletCredits] as num?)
                ?.toInt();
            final creditsText = credits?.toString() ?? '--';

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: HomePalette.surfaceContainerHigh.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: HomePalette.primary.withValues(alpha: 0.24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: HomePalette.primary.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.payments_rounded,
                    color: HomePalette.tertiary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$creditsText ${AppTexts.t('home.top.token_unit')}',
                    style: GoogleFonts.spaceGrotesk(
                      color: HomePalette.tertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CosmicPageTitle extends StatelessWidget {
  const _CosmicPageTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppTexts.t('home.cosmic.eyebrow'),
          style: GoogleFonts.spaceGrotesk(
            color: HomePalette.secondary,
            fontSize: 13,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppTexts.t('home.cosmic.title'),
          style: GoogleFonts.newsreader(
            color: HomePalette.primary,
            fontSize: 42,
            height: 1.02,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            shadows: [
              Shadow(
                color: HomePalette.primary.withValues(alpha: 0.42),
                blurRadius: 18,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppTexts.t('home.cosmic.subtitle'),
          style: GoogleFonts.manrope(
            color: HomePalette.secondary.withValues(alpha: 0.88),
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class CosmicFeatureCard extends StatelessWidget {
  const CosmicFeatureCard({
    super.key,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.icon,
    required this.accentIcon,
    required this.onTap,
  });

  final String title;
  final String description;
  final String buttonText;
  final IconData icon;
  final IconData accentIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: HomePalette.glassBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: HomePalette.glassBorder),
            boxShadow: [
              BoxShadow(
                color: HomePalette.primaryContainer.withValues(alpha: 0.16),
                blurRadius: 34,
                spreadRadius: -12,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CosmicFeatureVisual(icon: accentIcon),
              Container(
                color: HomePalette.surfaceContainerHigh.withValues(alpha: 0.92),
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.newsreader(
                        color: HomePalette.onSurface,
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: GoogleFonts.manrope(
                        color: HomePalette.secondary.withValues(alpha: 0.92),
                        fontSize: 14,
                        height: 1.48,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 22),
                    CosmicButton(text: buttonText, icon: icon, onTap: onTap),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CosmicButton extends StatelessWidget {
  const CosmicButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HomePalette.primary, HomePalette.primaryContainer],
        ),
        boxShadow: [
          BoxShadow(
            color: HomePalette.primary.withValues(alpha: 0.32),
            blurRadius: 22,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: HomePalette.onPrimary, size: 20),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      color: HomePalette.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CosmicFeatureVisual extends StatelessWidget {
  const _CosmicFeatureVisual({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.35,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  HomePalette.cosmicGradientTop,
                  HomePalette.surfaceContainerHigh,
                ],
              ),
            ),
          ),
          CustomPaint(painter: _ConstellationPainter()),
          Center(
            child: Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: HomePalette.tertiary.withValues(alpha: 0.38),
                ),
                boxShadow: [
                  BoxShadow(
                    color: HomePalette.primary.withValues(alpha: 0.24),
                    blurRadius: 34,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: HomePalette.tertiary,
                size: 58,
                shadows: [
                  Shadow(
                    color: HomePalette.tertiary.withValues(alpha: 0.6),
                    blurRadius: 18,
                  ),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  HomePalette.surfaceContainerHigh.withValues(alpha: 0.95),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CosmicBackground extends StatelessWidget {
  const _CosmicBackground();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              HomePalette.background,
              HomePalette.cosmicGradientMid,
              HomePalette.background,
            ],
          ),
        ),
      ),
    );
  }
}

class _ConstellationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pointPaint = Paint()
      ..color = HomePalette.secondary.withValues(alpha: 0.26)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = HomePalette.secondary.withValues(alpha: 0.12)
      ..strokeWidth = 1;

    final points = <Offset>[
      Offset(size.width * 0.18, size.height * 0.22),
      Offset(size.width * 0.36, size.height * 0.33),
      Offset(size.width * 0.55, size.height * 0.2),
      Offset(size.width * 0.72, size.height * 0.36),
      Offset(size.width * 0.82, size.height * 0.18),
      Offset(size.width * 0.24, size.height * 0.64),
      Offset(size.width * 0.48, size.height * 0.72),
      Offset(size.width * 0.76, size.height * 0.62),
    ];

    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], linePaint);
    }
    for (final point in points) {
      canvas.drawCircle(point, 2.5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
