import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_texts.dart';

const _kBg = Color(0xFF17081C);
const _kPrimary = Color(0xFFFF5ED6);
const _kPrimaryContainer = Color(0xFFFF00D4);
const _kSecondary = Color(0xFFCDBDFF);
const _kTertiary = Color(0xFFFFE792);
const _kGlassBg = Color(0x66361A41);
const _kOnSurface = Color(0xFFFADCFF);

class CreditPage extends StatefulWidget {
  const CreditPage({
    super.key,
    required this.bottomInset,
  });

  final double bottomInset;

  static double topBarHeight(BuildContext context) {
    return MediaQuery.of(context).padding.top + 84;
  }

  @override
  State<CreditPage> createState() => _CreditPageState();
}

class _CreditPageState extends State<CreditPage> {
  final List<Map<String, dynamic>> _perks = const [
    {
      'icon': Icons.mic_external_on,
      'titleKey': 'home.credit.perk.voice.title',
      'descKey': 'home.credit.perk.voice.desc',
      'color': _kPrimary,
    },
    {
      'icon': Icons.stars_rounded,
      'titleKey': 'home.credit.perk.personalized.title',
      'descKey': 'home.credit.perk.personalized.desc',
      'color': _kSecondary,
    },
    {
      'icon': Icons.auto_fix_high,
      'titleKey': 'home.credit.perk.clarity.title',
      'descKey': 'home.credit.perk.clarity.desc',
      'color': _kTertiary,
    },
  ];

  int _selectedPackageIndex = 1;
  final ScrollController _perksScrollController = ScrollController();
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startAutoScroll();
    });
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!_perksScrollController.hasClients) return;
      final max = _perksScrollController.position.maxScrollExtent;
      final current = _perksScrollController.position.pixels;
      const delta = 0.8;
      if (current >= max) {
        _perksScrollController.jumpTo(0);
      } else {
        _perksScrollController.jumpTo(current + delta);
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _perksScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _CreditBackground(),
        ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            CreditPage.topBarHeight(context) + 8,
            20,
            widget.bottomInset + 24,
          ),
          children: [
            _buildPerksSection(),
            const SizedBox(height: 24),
            _buildPackageCard(
              index: 0,
              coins: AppTexts.t('home.credit.package.50.coins'),
              title: AppTexts.t('home.credit.package.50.title'),
              price: AppTexts.t('home.credit.package.50.price'),
              icon: Icons.star_rounded,
              iconColor: _kSecondary,
              features: [
                AppTexts.t('home.credit.package.50.feature1'),
                AppTexts.t('home.credit.package.50.feature2'),
                AppTexts.t('home.credit.package.50.feature3'),
              ],
            ),
            const SizedBox(height: 14),
            _buildPackageCard(
              index: 1,
              coins: AppTexts.t('home.credit.package.250.coins'),
              title: AppTexts.t('home.credit.package.250.title'),
              price: AppTexts.t('home.credit.package.250.price'),
              icon: Icons.dark_mode_rounded,
              iconColor: _kPrimary,
              isPopular: true,
              features: [
                AppTexts.t('home.credit.package.250.feature1'),
                AppTexts.t('home.credit.package.250.feature2'),
                AppTexts.t('home.credit.package.250.feature3'),
              ],
            ),
            const SizedBox(height: 14),
            _buildPackageCard(
              index: 2,
              coins: AppTexts.t('home.credit.package.1000.coins'),
              title: AppTexts.t('home.credit.package.1000.title'),
              price: AppTexts.t('home.credit.package.1000.price'),
              icon: Icons.light_mode_rounded,
              iconColor: _kTertiary,
              features: [
                AppTexts.t('home.credit.package.1000.feature1'),
                AppTexts.t('home.credit.package.1000.feature2'),
                AppTexts.t('home.credit.package.1000.feature3'),
              ],
            ),
            const SizedBox(height: 24),
            _buildCheckoutSection(),
          ],
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _CreditTopBar(),
        ),
      ],
    );
  }

  Widget _buildPerksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppTexts.t('home.credit.perks.title'),
          style: GoogleFonts.newsreader(
            fontSize: 24,
            fontStyle: FontStyle.italic,
            color: _kOnSurface,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 12) / 2;
            return SizedBox(
              height: 172,
              child: ListView.separated(
                controller: _perksScrollController,
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: EdgeInsets.zero,
                itemCount: 600,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final perk = _perks[index % _perks.length];
                  final color = perk['color'] as Color;
                  return SizedBox(
                    width: cardWidth,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _kGlassBg,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              perk['icon'] as IconData,
                              color: color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            AppTexts.t(perk['titleKey'] as String),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.newsreader(
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppTexts.t(perk['descKey'] as String),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 10.8,
                              height: 1.35,
                              color: _kOnSurface.withValues(alpha: 0.78),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPackageCard({
    required int index,
    required String coins,
    required String title,
    required String price,
    required IconData icon,
    required Color iconColor,
    required List<String> features,
    bool isPopular = false,
  }) {
    final selected = _selectedPackageIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPackageIndex = selected ? -1 : index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: selected
              ? _kBg.withValues(alpha: 0.72)
              : const Color(0xFF361A41).withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(34),
          border: Border.all(
            color: selected
                ? _kPrimary.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.8 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _kPrimary.withValues(alpha: 0.25),
                    blurRadius: 28,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? iconColor : const Color(0xFF2E1537),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? Colors.white : iconColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isPopular)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _kPrimary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(
                              color: _kPrimary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            AppTexts.t('home.credit.package.250.badge')
                                .toUpperCase(),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.3,
                              color: _kPrimary,
                            ),
                          ),
                        ),
                      Text(
                        coins,
                        style: GoogleFonts.newsreader(
                          fontSize: selected ? 20 : 16,
                          fontStyle: FontStyle.italic,
                          color: _kOnSurface,
                        ),
                      ),
                      Text(
                        title.toUpperCase(),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          letterSpacing: 2,
                          color: iconColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  price,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: selected ? 22 : 18,
                    color: _kTertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Column(
                        children: [
                          Divider(
                            color: Colors.white.withValues(alpha: 0.1),
                            height: 1,
                          ),
                          const SizedBox(height: 16),
                          ...features.map(
                            (f) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: _kTertiary,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    f,
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      color:
                                          _kOnSurface.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutSection() {
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kPrimary, _kPrimaryContainer],
            ),
            borderRadius: BorderRadius.circular(9999),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withValues(alpha: 0.4),
                blurRadius: 22,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
            child: Center(
              child: Text(
                AppTexts.t('home.credit.cta.recharge').toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () {},
          child: Text(
            AppTexts.t('home.credit.restore').toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              letterSpacing: 2.4,
              color: _kOnSurface.withValues(alpha: 0.45),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {},
              child: Text(
                AppTexts.t('home.credit.terms').toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  letterSpacing: 1.8,
                  color: _kOnSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
            Text(
              '•',
              style: TextStyle(color: _kOnSurface.withValues(alpha: 0.35)),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                AppTexts.t('home.credit.privacy').toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  letterSpacing: 1.8,
                  color: _kOnSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          AppTexts.t('home.credit.legal_disclaimer'),
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 11,
            height: 1.4,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}

class _CreditTopBar extends StatelessWidget {
  const _CreditTopBar();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          color: _kBg.withValues(alpha: 0.6),
          padding: EdgeInsets.fromLTRB(20, topPadding + 10, 20, 12),
          child: Row(
            children: [
              const Icon(Icons.star, color: _kPrimary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppTexts.t('home.credit.title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.newsreader(
                    fontSize: 22,
                    fontStyle: FontStyle.italic,
                    color: _kPrimary,
                    shadows: [
                      Shadow(
                        color: _kPrimary.withValues(alpha: 0.55),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF361A41).withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(9999),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppTexts.t('home.credit.balance_label').toUpperCase(),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 8,
                            letterSpacing: 1.2,
                            color: _kSecondary.withValues(alpha: 0.72),
                          ),
                        ),
                        Text(
                          AppTexts.t('home.credit.balance_value'),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _kOnSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [_kTertiary, Color(0xFFEFC900)],
                        ),
                      ),
                      child: const Icon(
                        Icons.generating_tokens_rounded,
                        color: Color(0xFF655400),
                        size: 16,
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

class _CreditBackground extends StatelessWidget {
  const _CreditBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF17081C), Color(0xFF26112E)],
            ),
          ),
        ),
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kPrimary.withValues(alpha: 0.15),
                  blurRadius: 150,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          right: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _kSecondary.withValues(alpha: 0.15),
                  blurRadius: 150,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
