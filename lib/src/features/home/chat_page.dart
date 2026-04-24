import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../readings/tarot_card_view.dart';

const _kBg = Color(0xFF17081C);
const _kPrimary = Color(0xFFFF5ED6);
const _kPrimaryContainer = Color(0xFFFF00D4);
const _kSecondary = Color(0xFFCDBDFF);
const _kTertiary = Color(0xFFFFE792);
const _kOnSurface = Color(0xFFFADCFF);
const _kGlass = Color(0x66361A41);

class KozmikBilgePage extends StatelessWidget {
  const KozmikBilgePage({
    super.key,
    required this.cardTitle,
    required this.cardImageUrl,
  });

  final String cardTitle;
  final String cardImageUrl;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          const _ChatBackground(),
          ListView(
            padding: EdgeInsets.fromLTRB(24, topPadding + 92, 24, 250),
            children: [
              _HeroTarotCard(
                cardTitle: cardTitle,
                cardImageUrl: cardImageUrl,
              ),
              SizedBox(height: 28),
              _ArisMessageBubble(cardTitle: cardTitle),
              SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: _MessageMeta(),
              ),
            ],
          ),
          const _ChatTopBar(),
          const _LockedInteractionArea(),
        ],
      ),
    );
  }
}

class _ChatTopBar extends StatelessWidget {
  const _ChatTopBar();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 12),
            decoration: BoxDecoration(
              color: _kBg.withValues(alpha: 0.82),
              boxShadow: [
                BoxShadow(
                  color: _kPrimary.withValues(alpha: 0.10),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: _kPrimary,
                    size: 24,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Kozmik Bilge Aris',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.newsreader(
                      fontSize: 22,
                      fontStyle: FontStyle.italic,
                      color: _kPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF361A41).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _kPrimary.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Text(
                    '250 Jeton',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: _kPrimary,
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

class _HeroTarotCard extends StatelessWidget {
  const _HeroTarotCard({
    required this.cardTitle,
    required this.cardImageUrl,
  });

  final String cardTitle;
  final String cardImageUrl;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 156,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kPrimary.withValues(alpha: 0.22),
                  blurRadius: 42,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
          Transform.rotate(
            angle: 0.04,
            child: SizedBox(
              width: 112,
              height: 176,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: TarotCardView(
                      imageUrl: cardImageUrl,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(13),
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          width: double.infinity,
                          color: Colors.black.withValues(alpha: 0.52),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            cardTitle,
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
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArisMessageBubble extends StatelessWidget {
  const _ArisMessageBubble({
    required this.cardTitle,
  });

  final String cardTitle;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
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
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _kGlass,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.zero,
                  topRight: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        height: 1.6,
                        fontWeight: FontWeight.w400,
                        color: _kOnSurface,
                      ),
                      children: [
                        const TextSpan(
                          text:
                              'Toprak, Kova burcunun enerjisi ve ',
                        ),
                        TextSpan(
                          text: cardTitle,
                          style: GoogleFonts.manrope(
                            color: _kPrimary,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
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
                      color: Colors.black.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        const _Waveform(),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _kPrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Sesli Rehberlik (50 Jeton)',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: _kPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
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

class _MessageMeta extends StatelessWidget {
  const _MessageMeta();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Aris • Simdi',
      style: GoogleFonts.spaceGrotesk(
        fontSize: 10,
        letterSpacing: 1.3,
        color: _kSecondary.withValues(alpha: 0.42),
      ),
    );
  }
}

class _LockedInteractionArea extends StatelessWidget {
  const _LockedInteractionArea();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: false,
        child: SizedBox(
          height: 260,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        _kBg,
                        _kBg.withValues(alpha: 0.92),
                        _kBg.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 112,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kPrimary, _kPrimaryContainer],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: _kPrimary.withValues(alpha: 0.40),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: Text(
                      'SOHBETI DERINLESTIR (50 JETON)',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 36,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF361A41).withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
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
                              color: _kSecondary.withValues(alpha: 0.60),
                            ),
                          ),
                          Icon(
                            Icons.lock_rounded,
                            color: _kSecondary.withValues(alpha: 0.36),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
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

class _ChatBackground extends StatelessWidget {
  const _ChatBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: _kBg,
                gradient: RadialGradient(
                  center: Alignment(0.2, -0.3),
                  radius: 1.1,
                  colors: [Color(0xFF26112E), _kBg],
                ),
              ),
            ),
            Positioned(
              top: 180,
              left: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kPrimary.withValues(alpha: 0.14),
                      blurRadius: 110,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 160,
              right: -90,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kSecondary.withValues(alpha: 0.12),
                      blurRadius: 110,
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

class _Waveform extends StatelessWidget {
  const _Waveform();

  @override
  Widget build(BuildContext context) {
    const heights = [12.0, 20.0, 30.0, 16.0, 24.0, 10.0, 18.0];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: heights
          .map(
            (height) => Container(
              width: 3,
              height: height,
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
