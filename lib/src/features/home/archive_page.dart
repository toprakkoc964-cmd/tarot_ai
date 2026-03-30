import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_texts.dart';

const _kBg = Color(0xFF17081C);
const _kPrimary = Color(0xFFFF5ED6);
const _kPrimaryContainer = Color(0xFFFF00D4);
const _kSecondary = Color(0xFFCDBDFF);
const _kOnSurface = Color(0xFFFADCFF);
const _kGlassBg = Color(0x66361A41);

class ArchivePage extends StatelessWidget {
  const ArchivePage({
    super.key,
    required this.bottomInset,
  });

  final double bottomInset;

  static double topBarHeight(BuildContext context) {
    return MediaQuery.of(context).padding.top + 88;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _ArchiveBackground(),
        ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            topBarHeight(context) + 16,
            20,
            bottomInset + 24,
          ),
          children: [
            const _ArchiveTabs(),
            const SizedBox(height: 24),
            _ArchiveEntryCard(
              date: AppTexts.t('home.archive.card1.date'),
              title: AppTexts.t('home.archive.card1.title'),
              description: AppTexts.t('home.archive.card1.description'),
              actionLabel: AppTexts.t('home.archive.card1.action'),
              primary: true,
            ),
            const SizedBox(height: 24),
            _ArchiveEntryCard(
              date: AppTexts.t('home.archive.card2.date'),
              title: AppTexts.t('home.archive.card2.title'),
              description: AppTexts.t('home.archive.card2.description'),
              actionLabel: AppTexts.t('home.archive.card2.action'),
              primary: false,
            ),
            const SizedBox(height: 24),
            const _ArchiveEndMark(),
          ],
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _ArchiveTopBar(),
        ),
      ],
    );
  }
}

class _ArchiveBackground extends StatelessWidget {
  const _ArchiveBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Container(color: _kBg),
            Positioned.fill(
              child: CustomPaint(
                painter: _DotGridPainter(),
              ),
            ),
            Positioned(
              top: 80,
              left: -140,
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kPrimary.withValues(alpha: 0.12),
                      blurRadius: 140,
                      spreadRadius: 40,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 120,
              right: -120,
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kSecondary.withValues(alpha: 0.12),
                      blurRadius: 140,
                      spreadRadius: 40,
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
}

class _ArchiveTopBar extends StatelessWidget {
  const _ArchiveTopBar();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          color: _kBg.withValues(alpha: 0.82),
          padding: EdgeInsets.only(top: topPadding + 12, bottom: 14),
          child: Column(
            children: [
              Text(
                AppTexts.t('home.archive.title'),
                style: GoogleFonts.newsreader(
                  fontSize: 42,
                  fontStyle: FontStyle.italic,
                  color: _kPrimary,
                  shadows: [
                    Shadow(
                      color: _kPrimary.withValues(alpha: 0.75),
                      blurRadius: 18,
                    ),
                    Shadow(
                      color: _kPrimary.withValues(alpha: 0.35),
                      blurRadius: 36,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Container(
                height: 1.6,
                width: 54,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      _kPrimary.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchiveTabs extends StatelessWidget {
  const _ArchiveTabs();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF2E1537).withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: _kPrimary.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: _kPrimary.withValues(alpha: 0.32),
                  blurRadius: 16,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              AppTexts.t('home.archive.tab.cards').toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.4,
                color: _kPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF1E0C25).withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(9999),
            ),
            alignment: Alignment.center,
            child: Text(
              AppTexts.t('home.archive.tab.chats').toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                letterSpacing: 2.2,
                color: _kSecondary.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArchiveEntryCard extends StatelessWidget {
  const _ArchiveEntryCard({
    required this.date,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.primary,
  });

  final String date;
  final String title;
  final String description;
  final String actionLabel;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final accent = primary ? _kPrimary : _kSecondary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: _kGlassBg,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: accent.withValues(alpha: 0.24)),
                  ),
                  child: Text(
                    date,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: accent.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 58, 24, 24),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.1),
                        border:
                            Border.all(color: accent.withValues(alpha: 0.35)),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.2),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: Icon(Icons.lock, color: accent, size: 42),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.newsreader(
                        fontSize: 42,
                        color: _kOnSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        height: 1.45,
                        color: _kOnSurface.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 26),
                    if (primary)
                      SizedBox(
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_kPrimary, _kPrimaryContainer],
                            ),
                            borderRadius: BorderRadius.circular(9999),
                            boxShadow: [
                              BoxShadow(
                                color: _kPrimary.withValues(alpha: 0.4),
                                blurRadius: 22,
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 17),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9999),
                              ),
                            ),
                            child: Text(
                              actionLabel.toUpperCase(),
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.3,
                                color: const Color(0xFF430036),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: Icon(
                            Icons.play_arrow_rounded,
                            color: _kSecondary,
                            size: 18,
                          ),
                          label: Text(
                            actionLabel.toUpperCase(),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.1,
                              color: _kSecondary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: _kSecondary.withValues(alpha: 0.35),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9999),
                            ),
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
    );
  }
}

class _ArchiveEndMark extends StatelessWidget {
  const _ArchiveEndMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 1.2,
          height: 96,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _kPrimary.withValues(alpha: 0.45),
                Colors.transparent,
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppTexts.t('home.archive.end_flow').toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            letterSpacing: 6,
            color: _kSecondary.withValues(alpha: 0.42),
          ),
        ),
      ],
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    const spacing = 42.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
