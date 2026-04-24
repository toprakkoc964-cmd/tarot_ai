import 'dart:ui';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_locale.dart';
import '../../core/app_texts.dart';
import '../auth/user_profile_contract.dart';
import 'credit_page_models.dart';
import 'credit_remote_config_service.dart';

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
    required this.uid,
  });

  final double bottomInset;
  final String uid;

  static double topBarHeight(BuildContext context) {
    return MediaQuery.of(context).padding.top + 84;
  }

  @override
  State<CreditPage> createState() => _CreditPageState();
}

class _CreditPageState extends State<CreditPage> {
  int _selectedPackageIndex = 1;
  final ScrollController _perksScrollController = ScrollController();
  Timer? _autoScrollTimer;
  late Future<CreditPageData> _pageDataFuture;

  @override
  void initState() {
    super.initState();
    _pageDataFuture = CreditRemoteConfigService.instance.fetchPageData();
    AppLocale.notifier.addListener(_reloadRemoteDataForLocale);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startAutoScroll();
    });
  }

  void _reloadRemoteDataForLocale() {
    if (!mounted) return;
    setState(() {
      _pageDataFuture = CreditRemoteConfigService.instance.fetchPageData();
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
    AppLocale.notifier.removeListener(_reloadRemoteDataForLocale);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _CreditBackground(),
        FutureBuilder<CreditPageData>(
          future: _pageDataFuture,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData;
            final data = snapshot.data;

            return ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                CreditPage.topBarHeight(context) + 8,
                20,
                widget.bottomInset + 24,
              ),
              children: [
                if (loading)
                  const _CreditPageSkeleton()
                else if (data != null) ...[
                  _buildPerksSection(data),
                  const SizedBox(height: 24),
                  ...List.generate(data.packages.length, (index) {
                    final item = data.packages[index];
                    final iconColor = CreditRemoteConfigService.accentColorFor(
                      item.accentKey,
                    );

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == data.packages.length - 1 ? 0 : 14,
                      ),
                      child: _buildPackageCard(
                        index: index,
                        selectedIndex: _selectedPackageIndex,
                        coins: item.coins,
                        title: item.title,
                        price: item.price,
                        icon: CreditRemoteConfigService.iconFor(item.iconKey),
                        iconColor: iconColor,
                        features: item.features,
                        badge: item.badge,
                        isPopular: item.isPopular,
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  _buildCheckoutSection(data),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Center(
                      child: Text(
                        AppTexts.t('error.default'),
                        style: GoogleFonts.manrope(
                          color: _kOnSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _CreditTopBar(
            future: _pageDataFuture,
            uid: widget.uid,
          ),
        ),
      ],
    );
  }

  Widget _buildPerksSection(CreditPageData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.advantagesTitle,
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
                physics: const NeverScrollableScrollPhysics(),
                clipBehavior: Clip.none,
                padding: EdgeInsets.zero,
                itemCount: data.advantagesCards.isEmpty
                    ? 0
                    : data.advantagesCards.length * 200,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final perk =
                      data.advantagesCards[index % data.advantagesCards.length];
                  final color = CreditRemoteConfigService.accentColorFor(
                    perk.accentKey,
                  );
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
                              CreditRemoteConfigService.iconFor(perk.iconKey),
                              color: color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            perk.title,
                            maxLines: 2,
                            overflow: TextOverflow.fade,
                            style: GoogleFonts.newsreader(
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            perk.description,
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
    required int selectedIndex,
    required String coins,
    required String title,
    required String price,
    required IconData icon,
    required Color iconColor,
    required List<String> features,
    String? badge,
    bool isPopular = false,
  }) {
    final selected = selectedIndex == index;
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
                      if (isPopular && (badge?.trim().isNotEmpty ?? false))
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
                            badge!.toUpperCase(),
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

  Widget _buildCheckoutSection(CreditPageData data) {
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
                data.rechargeCta.toUpperCase(),
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
            data.restoreLabel.toUpperCase(),
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
                data.termsLabel.toUpperCase(),
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
                data.privacyLabel.toUpperCase(),
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Colors.white.withValues(alpha: 0.58),
                size: 20,
              ),
              const SizedBox(height: 8),
              Text(
                data.legalDisclaimer,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  height: 1.55,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CreditTopBar extends StatelessWidget {
  const _CreditTopBar({
    required this.future,
    required this.uid,
  });

  final Future<CreditPageData> future;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          color: _kBg.withValues(alpha: 0.6),
          padding: EdgeInsets.fromLTRB(20, topPadding + 10, 20, 12),
          child: FutureBuilder<CreditPageData>(
            future: future,
            builder: (context, snapshot) {
              final title =
                  snapshot.data?.title ?? AppTexts.t('home.credit.title');
              return Row(
                children: [
                  const Icon(Icons.star, color: _kPrimary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
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
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection(UserProfileContract.usersCollection)
                        .doc(uid)
                        .snapshots(),
                    builder: (context, walletSnapshot) {
                      final data = walletSnapshot.data?.data();
                      final wallet = Map<String, dynamic>.from(
                        data?[UserProfileContract.wallet] as Map? ?? const {},
                      );
                      final credits =
                          (wallet[UserProfileContract.walletCredits] as num?)
                              ?.toInt();
                      final creditsText = credits?.toString() ?? '--';

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF361A41).withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  AppTexts.t('home.credit.balance_label')
                                      .toUpperCase(),
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 8,
                                    letterSpacing: 1.2,
                                    color: _kSecondary.withValues(alpha: 0.72),
                                  ),
                                ),
                                Text(
                                  '$creditsText ${AppTexts.t('home.top.token_unit')}',
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
                      );
                    },
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

class _CreditPageSkeleton extends StatelessWidget {
  const _CreditPageSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonLine(width: 210, height: 28),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _SkeletonCard(height: 172, radius: 28)),
            SizedBox(width: 12),
            Expanded(child: _SkeletonCard(height: 172, radius: 28)),
          ],
        ),
        SizedBox(height: 24),
        _SkeletonCard(height: 116, radius: 34),
        SizedBox(height: 14),
        _SkeletonCard(height: 220, radius: 34),
        SizedBox(height: 24),
        _SkeletonCard(height: 64, radius: 999),
        SizedBox(height: 18),
        Center(child: _SkeletonLine(width: 180, height: 12)),
        SizedBox(height: 14),
        Center(child: _SkeletonLine(width: 220, height: 12)),
        SizedBox(height: 12),
        _SkeletonCard(height: 126, radius: 18),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({
    required this.height,
    required this.radius,
  });

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return _ShimmerBlock(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: _kGlassBg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return _ShimmerBlock(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _kGlassBg,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _ShimmerBlock extends StatefulWidget {
  const _ShimmerBlock({
    required this.child,
  });

  final Widget child;

  @override
  State<_ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<_ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final width = bounds.width <= 0 ? 1.0 : bounds.width;
            final shimmerX = (-1.2 + (_controller.value * 2.4)) * width;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white.withValues(alpha: 0.00),
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.00),
              ],
              stops: const [0.10, 0.35, 0.50, 0.65, 0.90],
              transform: _SlidingGradientTransform(shimmerX),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.slideX);

  final double slideX;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(slideX, 0, 0);
  }
}
