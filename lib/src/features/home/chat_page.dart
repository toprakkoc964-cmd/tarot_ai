import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _kBg = Color(0xFF17081C);
const _kPrimary = Color(0xFFFF5ED6);
const _kSecondary = Color(0xFFCDBDFF);
const _kTertiary = Color(0xFFFFE792);
const _kOnSurface = Color(0xFFFADCFF);

class KozmikBilgePage extends StatelessWidget {
  const KozmikBilgePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          const _BackgroundGlows(),
          ListView(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 86,
              bottom: 220,
              left: 24,
              right: 24,
            ),
            children: [
              _buildTarotCard(),
              const SizedBox(height: 28),
              _buildChatBubble(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  'ARIS • SIMDI',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    letterSpacing: 1.6,
                    color: _kSecondary.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopBar(),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _LockedBottomArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildTarotCard() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 138,
            height: 208,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: _kPrimary.withValues(alpha: 0.2),
              boxShadow: [
                BoxShadow(
                  color: _kPrimary.withValues(alpha: 0.3),
                  blurRadius: 34,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          Container(
            width: 130,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kPrimary.withValues(alpha: 0.42)),
              image: const DecorationImage(
                image: NetworkImage(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuDutE47XiGTycmvPbZSf2JqRq3st4Itr6wUVLxRIVreig6S9B25YnrSY4Uwn0u9-o4hsGX0s_b4q81KpGE7uAt_lXFRxO9GvcZAZAtP9D64AhQGtIsFLSHstlkkL7NT5GnVlBxO7dvqVSGkOHFA8KOQWyPtc0b9EkXVfpByiluTgbMeTiTCoJQvc2-pZX_Z72jH85z9f6I-B_x6NzsYZueYRo34bBvKrFQt3jqnPkMFoIoKCoNg6gsbArhIun_QmLvtQ91LH7cT2pfj',
                ),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black45, BlendMode.darken),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(15),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      width: double.infinity,
                      color: Colors.black.withValues(alpha: 0.6),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Yildiz',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.newsreader(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: _kTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.95,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.zero,
            topRight: Radius.circular(24),
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF361A41).withValues(alpha: 0.4),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.zero,
                  topRight: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        height: 1.6,
                        fontWeight: FontWeight.w300,
                        color: _kOnSurface,
                      ),
                      children: [
                        const TextSpan(text: 'Toprak, Kova burcunun enerjisi ve '),
                        TextSpan(
                          text: 'Yildiz',
                          style: GoogleFonts.manrope(
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            color: _kPrimary,
                          ),
                        ),
                        const TextSpan(
                          text:
                              ' kartinin isigi bugun seninle. Bu kart, uzun suredir karanlikta kalan yollarinin aydinlanacagini fisildiyor...',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        const _WaveBars(),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _kPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'SESLI REHBERLIK (50 JETON)',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10,
                                  color: _kPrimary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.play_arrow_rounded,
                                color: _kPrimary,
                                size: 16,
                              ),
                            ],
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

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          color: _kBg.withValues(alpha: 0.8),
          padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded, color: _kPrimary),
              ),
              Expanded(
                child: Text(
                  'Kozmik Bilge Aris',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.newsreader(
                    fontSize: 24,
                    color: _kPrimary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF361A41).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: _kPrimary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  '250 JETON',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    letterSpacing: 1,
                    color: _kPrimary,
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

class _LockedBottomArea extends StatelessWidget {
  const _LockedBottomArea();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: Container(
        height: 255,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              _kBg,
              _kBg.withValues(alpha: 0.92),
              _kBg.withValues(alpha: 0),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kPrimary, Color(0xFFFF00D4)],
                  ),
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: [
                    BoxShadow(
                      color: _kPrimary.withValues(alpha: 0.45),
                      blurRadius: 26,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: Text(
                    'SOHBETI DERINLESTIR (50 JETON)',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF361A41).withValues(alpha: 0.32),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bilgeye bir soru fisilda...',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: _kSecondary.withValues(alpha: 0.65),
                          ),
                        ),
                        Icon(
                          Icons.lock_rounded,
                          color: _kSecondary.withValues(alpha: 0.4),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _BackgroundGlows extends StatelessWidget {
  const _BackgroundGlows();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 160,
          left: -80,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kPrimary.withValues(alpha: 0.1),
                  blurRadius: 100,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 200,
          right: -80,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kSecondary.withValues(alpha: 0.1),
                  blurRadius: 100,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WaveBars extends StatelessWidget {
  const _WaveBars();

  @override
  Widget build(BuildContext context) {
    const heights = [12.0, 20.0, 32.0, 16.0, 24.0, 10.0, 20.0];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: heights
          .map(
            (h) => Container(
              width: 3,
              height: h,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: _kPrimary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          )
          .toList(),
    );
  }
}
