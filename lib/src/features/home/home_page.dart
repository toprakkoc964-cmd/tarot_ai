import 'dart:ui';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'archive_page.dart';
import 'chat_page.dart';
import 'credit_page.dart';
import 'profile_page.dart';
import '../auth/auth_service.dart';
import '../auth/user_profile_contract.dart';
import '../../core/app_texts.dart';
import '../../core/frequency_service.dart';

// ─── Design Tokens ───────────────────────────────────────────────
const _kBg = Color(0xFF17081C);
const _kPrimary = Color(0xFFFF5ED6);
const _kPrimaryContainer = Color(0xFFFF00D4);
const _kSecondary = Color(0xFFCDBDFF);
const _kTertiary = Color(0xFFFFE792);
const _kOnSurface = Color(0xFFFADCFF);
const _kSurfaceContainerHigh = Color(0xFF2E1537);
const _kOnPrimary = Color(0xFF430036);
const _kGlassBg = Color(0x66361A41); // rgba(54,26,65,0.4)
const _kGlassBorder = Color(0x26CDBDFF); // rgba(205,189,255,0.15)

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.authService,
    required this.uid,
  });

  final AuthService authService;
  final String uid;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _navIndex = 0;
  bool _flashNotification = false;
  int? _flashNavIndex;

  Future<void> _onNotificationTap() async {
    setState(() => _flashNotification = true);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _NotificationsPage(),
      ),
    );

    if (!mounted) return;
    setState(() => _flashNotification = false);
  }

  void _onNavTap(int i) {
    setState(() {
      if (i == 0 || i == 1 || i == 2 || i == 3) {
        _navIndex = i;
      }
      _flashNavIndex = i;
    });
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _flashNavIndex = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isArchivePage = _navIndex == 1;
    final isCreditPage = _navIndex == 2;
    final isProfilePage = _navIndex == 3;
    final topBarHeight = _TopBar.estimatedHeight(context);
    final bottomBarHeight = _BottomNavBar.estimatedHeight(context);

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // ── Nebula background ──
          if (!isArchivePage && !isCreditPage && !isProfilePage)
            const _NebulaBackground(),
          if (isArchivePage) ArchivePage(bottomInset: bottomBarHeight),
          if (isCreditPage) CreditPage(bottomInset: bottomBarHeight),
          if (isProfilePage)
            ProfilePage(
              bottomInset: bottomBarHeight,
              authService: widget.authService,
              uid: widget.uid,
            ),

          // ── Scrollable content ──
          if (!isArchivePage && !isCreditPage && !isProfilePage)
            CustomScrollView(
              slivers: [
                // Top padding for fixed header
                SliverToBoxAdapter(child: SizedBox(height: topBarHeight + 12)),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── Hero Section ──
                      const _HeroSection(),
                      const SizedBox(height: 24),

                      // ── Identity Module ──
                      _IdentityModule(uid: widget.uid),

                      // Bottom padding for nav bar
                      SizedBox(height: bottomBarHeight + 20),
                    ]),
                  ),
                ),
              ],
            ),
          // ── Fixed Top Bars ──
          if (!isArchivePage && !isCreditPage && !isProfilePage)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopBar(
                authService: widget.authService,
                flashNotification: _flashNotification,
                onNotificationTap: () {
                  _onNotificationTap();
                },
              ),
            ),
          // ── Fixed BottomNavBar ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomNavBar(
              currentIndex: _navIndex,
              flashIndex: _flashNavIndex,
              onTap: _onNavTap,
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// NEBULA BACKGROUND
// ═════════════════════════════════════════════════════════════════
class _NebulaBackground extends StatelessWidget {
  const _NebulaBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.6, -0.4),
                    radius: 0.8,
                    colors: [
                      _kPrimary.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.6, 0.4),
                    radius: 0.8,
                    colors: [
                      _kSecondary.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// TOP APP BAR
// ═════════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.authService,
    required this.flashNotification,
    required this.onNotificationTap,
  });
  final AuthService authService;
  final bool flashNotification;
  final VoidCallback onNotificationTap;

  static double estimatedHeight(BuildContext context) {
    return MediaQuery.of(context).padding.top + 64;
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: _kBg.withValues(alpha: 0.80),
          padding: EdgeInsets.only(
            top: topPadding + 10,
            bottom: 10,
            left: 20,
            right: 20,
          ),
          child: Row(
            children: [
              // Jeton bölümü (sol)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _kSurfaceContainerHigh.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(
                    color: _kPrimary.withValues(alpha: 0.22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _kPrimary.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.payments_rounded, color: _kPrimary, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '250 ${AppTexts.t('home.top.token_unit')}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        letterSpacing: 1.1,
                        color: _kTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Bildirim (sağ)
              GestureDetector(
                onTap: onNotificationTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _kSurfaceContainerHigh.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                      color: (flashNotification ? _kTertiary : _kSecondary)
                          .withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: flashNotification ? _kTertiary : _kPrimary,
                    size: 20,
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

// ═════════════════════════════════════════════════════════════════
// HERO SECTION — TAROT REVEAL
// ═════════════════════════════════════════════════════════════════
class _HeroSection extends StatefulWidget {
  const _HeroSection();

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection>
    with SingleTickerProviderStateMixin {
  static const _cards = [
    (
      'home.card.star.title',
      'home.card.star.name',
      'XVII',
      'home.card.star.subtitle',
      Icons.auto_awesome
    ),
    (
      'home.card.sun.title',
      'home.card.sun.name',
      'XIX',
      'home.card.sun.subtitle',
      Icons.wb_sunny_rounded
    ),
    (
      'home.card.moon.title',
      'home.card.moon.name',
      'XVIII',
      'home.card.moon.subtitle',
      Icons.nightlight_round
    ),
    (
      'home.card.world.title',
      'home.card.world.name',
      'XXI',
      'home.card.world.subtitle',
      Icons.public_rounded
    ),
  ];

  late final AnimationController _drawController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  int _cardIndex = 0;
  bool _isDrawing = false;
  bool _hasDailyDrawRight = true;

  Future<void> _drawCard() async {
    if (_isDrawing || !_hasDailyDrawRight) return;
    setState(() => _isDrawing = true);
    await _drawController.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _cardIndex = (_cardIndex + 1) % _cards.length;
      _isDrawing = false;
      _hasDailyDrawRight = false;
    });
  }

  Future<void> _openCosmicChat() async {
    if (_isDrawing) return;
    if (_hasDailyDrawRight) {
      await _drawCard();
      if (!mounted) return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const KozmikBilgePage(),
      ),
    );
  }

  @override
  void dispose() {
    _drawController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (titleKey, cardNameKey, roman, subtitleKey, icon) =
        _cards[_cardIndex];
    final title = AppTexts.t(titleKey);
    final cardName = AppTexts.t(cardNameKey);
    final subtitle = AppTexts.t(subtitleKey);
    final drawBadgeText = _hasDailyDrawRight
        ? AppTexts.t('home.daily_draw.available')
        : AppTexts.t('home.daily_draw.used');
    final ctaText = _isDrawing
        ? AppTexts.t('home.cta.drawing')
        : (_hasDailyDrawRight
            ? AppTexts.t('home.cta.draw_now')
            : AppTexts.t('home.cta.draw_locked'));

    return _GlassCard(
      borderRadius: 32,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: _kPrimary.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    drawBadgeText,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      letterSpacing: 2,
                      color: _kPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Guide label
                Text(
                  AppTexts.t('home.daily_guide_label'),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    letterSpacing: 3,
                    color: _kSecondary.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),

                // Headline
                Text(
                  title,
                  style: GoogleFonts.newsreader(
                    fontSize: 38,
                    fontStyle: FontStyle.italic,
                    color: _kOnSurface,
                  ),
                ),
                const SizedBox(height: 24),

                // Holographic Tarot Card
                AnimatedBuilder(
                  animation: _drawController,
                  builder: (context, child) {
                    final t = _drawController.value;
                    final lift = -20 * math.sin(t * math.pi);
                    final scale = 1 + (0.08 * math.sin(t * math.pi));
                    final spin = 0.025 * math.sin(t * math.pi * 2);
                    return Transform.translate(
                      offset: Offset(0, lift),
                      child: Transform.rotate(
                        angle: spin,
                        child: Transform.scale(
                          scale: scale,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: _TarotCard(
                    title: cardName,
                    roman: roman,
                    icon: icon,
                    drawProgress: _drawController,
                  ),
                ),
                const SizedBox(height: 24),

                // Subtitle
                Text(
                  '"$subtitle"',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: _kSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // CTA Button
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
                          color: _kPrimaryContainer.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _openCosmicChat,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9999),
                        ),
                      ),
                      child: Text(
                        ctaText,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          color: _kOnPrimary,
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
}

// ═════════════════════════════════════════════════════════════════
// HOLOGRAPHIC TAROT CARD
// ═════════════════════════════════════════════════════════════════
class _TarotCard extends StatefulWidget {
  const _TarotCard({
    required this.title,
    required this.roman,
    required this.icon,
    required this.drawProgress,
  });

  final String title;
  final String roman;
  final IconData icon;
  final Animation<double> drawProgress;

  @override
  State<_TarotCard> createState() => _TarotCardState();
}

class _TarotCardState extends State<_TarotCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final phase = _controller.value * math.pi * 2;
        final lift = math.sin(phase) * 4.5;
        final drawT = widget.drawProgress.value;
        final glowPulse =
            0.22 + ((math.sin(phase) + 1) / 2) * 0.16 + (drawT * 0.2);

        return Transform.translate(
          offset: Offset(0, lift),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow behind
              Container(
                width: 192 * 0.75,
                height: 288 * 0.75,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _kPrimary.withValues(alpha: glowPulse),
                  boxShadow: [
                    BoxShadow(
                      color: _kPrimary.withValues(alpha: glowPulse),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
              // Card
              Container(
                width: 192,
                height: 288,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kSurfaceContainerHigh, _kBg],
                  ),
                  border: Border.all(color: _kGlassBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Gold foil border inside
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _kTertiary.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),
                    // Content
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.icon,
                            size: 56,
                            color: _kTertiary,
                          ),
                          const SizedBox(height: 16),
                          // Divider
                          Container(
                            width: 120,
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  _kTertiary.withValues(alpha: 0.4),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.title,
                            style: GoogleFonts.newsreader(
                              fontSize: 20,
                              fontStyle: FontStyle.italic,
                              color: _kOnSurface.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Roman numeral
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          widget.roman,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            letterSpacing: 3,
                            color: _kTertiary.withValues(alpha: 0.6),
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
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// IDENTITY MODULE
// ═════════════════════════════════════════════════════════════════
class _IdentityModule extends StatelessWidget {
  const _IdentityModule({required this.uid});

  final String uid;
  static final Map<String, Future<String>> _dailyCommentFutureCache =
      <String, Future<String>>{};

  DateTime? _parseBirthDate(dynamic raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateTime(y, m, d);
  }

  String _formatBirthDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')} • ${date.month.toString().padLeft(2, '0')} • ${date.year}';
  }

  String _zodiacTr(DateTime date) {
    final m = date.month;
    final d = date.day;
    if ((m == 3 && d >= 21) || (m == 4 && d <= 19)) return 'Koc Burcu';
    if ((m == 4 && d >= 20) || (m == 5 && d <= 20)) return 'Boga Burcu';
    if ((m == 5 && d >= 21) || (m == 6 && d <= 20)) return 'Ikizler Burcu';
    if ((m == 6 && d >= 21) || (m == 7 && d <= 22)) return 'Yengec Burcu';
    if ((m == 7 && d >= 23) || (m == 8 && d <= 22)) return 'Aslan Burcu';
    if ((m == 8 && d >= 23) || (m == 9 && d <= 22)) return 'Basak Burcu';
    if ((m == 9 && d >= 23) || (m == 10 && d <= 22)) return 'Terazi Burcu';
    if ((m == 10 && d >= 23) || (m == 11 && d <= 21)) return 'Akrep Burcu';
    if ((m == 11 && d >= 22) || (m == 12 && d <= 21)) return 'Yay Burcu';
    if ((m == 12 && d >= 22) || (m == 1 && d <= 19)) return 'Oglak Burcu';
    if ((m == 1 && d >= 20) || (m == 2 && d <= 18)) return 'Kova Burcu';
    return 'Balik Burcu';
  }

  Future<String> _dailyCommentFuture(String? storedBirthDate) {
    final key = (storedBirthDate ?? '').trim();
    return _dailyCommentFutureCache.putIfAbsent(
      key,
      () => FrequencyService.instance.getDailyComment(userBirthDate: key),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(UserProfileContract.usersCollection)
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final storedBirthDate = data?[UserProfileContract.birthDate] as String?;
        final birthDate = _parseBirthDate(storedBirthDate);
        final birthDateText =
            birthDate != null ? _formatBirthDate(birthDate) : '—';
        final zodiacText = birthDate != null
            ? _zodiacTr(birthDate)
            : AppTexts.t('home.birth_frequency.sign');

        return _GlassCard(
          borderRadius: 24,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppTexts.t('home.birth_frequency.title'),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        letterSpacing: 3,
                        color: _kSecondary.withValues(alpha: 0.5),
                      ),
                    ),
                    Icon(
                      Icons.cyclone,
                      color: _kTertiary.withValues(alpha: 0.4),
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          birthDateText,
                          style: GoogleFonts.newsreader(
                            fontSize: 24,
                            color: _kOnSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          zodiacText,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            color: _kTertiary,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.flare, color: _kPrimary, size: 30),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: _kSecondary.withValues(alpha: 0.1), height: 1),
                const SizedBox(height: 16),
                FutureBuilder<String>(
                  future: _dailyCommentFuture(storedBirthDate),
                  builder: (context, commentSnapshot) {
                    String bodyText;
                    if (commentSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      bodyText = 'Gunluk yorum hazirlaniyor...';
                    } else {
                      final dynamicComment =
                          (commentSnapshot.data ?? '').trim();
                      bodyText = dynamicComment.isNotEmpty
                          ? dynamicComment
                          : 'Bugunluk yorum su an alinamiyor. Lutfen tekrar dene.';
                    }
                    return RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text:
                                AppTexts.t('home.birth_frequency.reading.lead'),
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              color: const Color(0xFFFFA4DF),
                              height: 1.6,
                            ),
                          ),
                          TextSpan(
                            text: bodyText,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              color: _kOnSurface.withValues(alpha: 0.8),
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// BOTTOM NAV BAR
// ═════════════════════════════════════════════════════════════════
class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.flashIndex,
  });
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int? flashIndex;

  static double estimatedHeight(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return bottomPadding + 84;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final items = [
      (Icons.blur_circular_rounded, AppTexts.t('home.tab.ritual')),
      (Icons.description_outlined, AppTexts.t('home.tab.archive')),
      (Icons.payments_outlined, AppTexts.t('home.tab.credit')),
      (Icons.person_outline, AppTexts.t('home.tab.profile')),
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: BoxDecoration(
            color: _kBg.withValues(alpha: 0.4),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
            border: Border(
              top: BorderSide(
                color: _kSecondary.withValues(alpha: 0.1),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withValues(alpha: 0.08),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            top: 10,
            bottom: bottomPadding + 10,
            left: 20,
            right: 20,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final (icon, label) = items[i];
              final active = i == currentIndex;
              final isFlashing = flashIndex == i;
              final activeColor = _kTertiary;
              final flashColor = _kTertiary.withValues(alpha: 0.95);
              final inactiveColor = _kSecondary.withValues(alpha: 0.6);
              final iconColor = isFlashing
                  ? flashColor
                  : (active ? activeColor : inactiveColor);
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      active
                          ? (i == 0 ? Icons.blur_circular_rounded : icon)
                          : icon,
                      size: 24,
                      color: iconColor,
                      shadows: (active || isFlashing)
                          ? [
                              Shadow(
                                color: (isFlashing ? flashColor : activeColor)
                                    .withValues(alpha: 0.65),
                                blurRadius: isFlashing ? 16 : 12,
                              ),
                            ]
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label.toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kOnSurface),
        title: Text(
          AppTexts.t('home.notifications.title'),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            letterSpacing: 1.2,
            color: _kOnSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: Text(
          AppTexts.t('home.notifications.empty'),
          style: GoogleFonts.manrope(
            fontSize: 15,
            color: _kSecondary.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// GLASS CARD (shared)
// ═════════════════════════════════════════════════════════════════
class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.borderRadius = 24,
  });

  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: _kGlassBg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: _kGlassBorder),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withValues(alpha: 0.05),
                blurRadius: 40,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
