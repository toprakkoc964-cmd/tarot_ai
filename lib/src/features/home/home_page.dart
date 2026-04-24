import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'archive_page.dart';
import 'chat_page.dart';
import 'credit_page.dart';
import 'profile_page.dart';
import '../auth/auth_service.dart';
import '../auth/user_profile_contract.dart';
import '../../core/app_locale.dart';
import '../../core/notification_service.dart';
import '../../core/app_texts.dart';
import '../../core/frequency_service.dart';
import '../../core/tarot_functions_client.dart';
import '../../core/widgets/cosmic_permission_dialog.dart';
import '../readings/tarot_card_view.dart';
import '../readings/tarot_service.dart';
import '../../../services/notification_service.dart' as local_notifications;

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
const _kPaidDrawCost = 5;

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
  static const _permissionPromptSeenKey = 'notification_decision_made';
  int _navIndex = 0;
  bool _flashNotification = false;
  int? _flashNavIndex;

  @override
  void initState() {
    super.initState();
    _scheduleNotificationQueues();
  }

  Future<void> _scheduleNotificationQueues() async {
    await local_notifications.NotificationService.instance
        .scheduleMorningNotifications();
    await local_notifications.NotificationService.instance
        .scheduleMiddayReminders();
  }

  Future<void> _maybePromptNotificationPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool(_permissionPromptSeenKey) ?? false;
    if (alreadyPrompted || !mounted) return;

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return CosmicPermissionDialog(
          onDecline: () async {
            Navigator.of(dialogContext).pop();
            await prefs.setBool(_permissionPromptSeenKey, true);
          },
          onAllow: () async {
            Navigator.of(dialogContext).pop();
            await prefs.setBool(_permissionPromptSeenKey, true);
            await local_notifications.NotificationService.instance
                .requestPermissions();
            await NotificationService.instance.requestNotificationPermissions();
          },
        );
      },
    );
  }

  Future<void> _onNotificationTap() async {
    setState(() => _flashNotification = true);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    await NotificationService.instance.reloadInbox();
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
          if (isCreditPage)
            CreditPage(
              bottomInset: bottomBarHeight,
              uid: widget.uid,
            ),
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
                      _HeroSection(
                        uid: widget.uid,
                        authService: widget.authService,
                      ),
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
                uid: widget.uid,
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
    required this.uid,
    required this.flashNotification,
    required this.onNotificationTap,
  });
  final AuthService authService;
  final String uid;
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
                  final credits =
                      (wallet[UserProfileContract.walletCredits] as num?)
                          ?.toInt();
                  final creditsText = credits?.toString() ?? '--';

                  return Container(
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
                        Icon(Icons.payments_rounded,
                            color: _kPrimary, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          '$creditsText ${AppTexts.t('home.top.token_unit')}',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            letterSpacing: 1.1,
                            color: _kTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
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
  const _HeroSection({
    required this.uid,
    required this.authService,
  });

  final String uid;
  final AuthService authService;

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection>
    with TickerProviderStateMixin {
  static const _loopItemCount = 100000;
  static const _initialLoopPage = _loopItemCount ~/ 2;
  static const List<String> _cardNames = <String>[
    'the_fool',
    'the_magician',
    'the_high_priestess',
    'the_empress',
    'the_emperor',
    'the_hierophant',
    'the_lovers',
    'the_chariot',
    'strength',
    'the_hermit',
    'the_wheel_of_fortune',
    'justice',
    'the_hanged_man',
    'death',
    'temperance',
    'the_devil',
    'the_tower',
    'the_star',
    'the_moon',
    'the_sun',
    'judgement',
    'the_world',
  ];

  late final AnimationController _flipController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  late final AnimationController _ritualAuraController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();
  late final PageController _pageController = PageController(
    viewportFraction: 0.5,
    initialPage: _initialLoopPage,
  );
  Timer? _carouselTimer;
  int _currentLoopPage = _initialLoopPage;
  int? _selectedCardIndex;
  bool _ritualMode = false;
  bool _ritualIntroActive = false;
  bool _ritualIntroExpanded = false;
  bool _ritualCarouselVisible = false;
  bool _selectionLocked = false;
  bool _isLoadingCard = false;
  bool _isDrawRequestInFlight = false;
  final _functionsClient = TarotFunctionsClient();
  final _tarotService = TarotService();
  late final DocumentReference<Map<String, dynamic>> _userDoc =
      FirebaseFirestore.instance
          .collection(UserProfileContract.usersCollection)
          .doc(widget.uid);
  DrawnTarotCard? _drawnCard;

  String _drawBadgeText({
    required bool isLoading,
    required int credits,
  }) {
    if (isLoading) return AppTexts.t('common.loading');
    if (credits >= _kPaidDrawCost) {
      return AppTexts.t('home.daily_draw.paid_available');
    }
    return AppTexts.t('home.daily_draw.insufficient');
  }

  String _ctaText({
    required bool isLoading,
    required int credits,
  }) {
    if (_selectionLocked || _isLoadingCard || _isDrawRequestInFlight) {
      return 'Kart aciliyor...';
    }
    if (_ritualMode) {
      return 'Kartini sec';
    }
    if (isLoading) return AppTexts.t('common.loading');
    if (credits >= _kPaidDrawCost) {
      return AppTexts.t('home.cta.draw_with_credits');
    }
    return AppTexts.t('home.cta.insufficient_credits');
  }

  @override
  void initState() {
    super.initState();
    if (_cardNames.length != 22) {
      throw StateError('Hero section card list must contain 22 cards.');
    }
  }

  Future<bool> _consumeDrawRight() async {
    try {
      await _functionsClient.consumeHomeCardDraw();
      return true;
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'failed-precondition') return false;
      return false;
    } catch (_) {
      return false;
    }
  }

  void _startCarousel() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (!mounted || _selectionLocked || !_pageController.hasClients) return;
      final nextPage = _currentLoopPage + 1;
      _currentLoopPage = nextPage;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopCarousel() {
    _carouselTimer?.cancel();
  }

  int _cardIndexForLoopPage(int loopPage) {
    final fallbackIndex = math.Random().nextInt(_cardNames.length);
    final normalized = loopPage % _cardNames.length;
    if (normalized < 0 || normalized >= _cardNames.length) {
      return fallbackIndex;
    }
    return normalized;
  }

  String _displayNameForIndex(int index) {
    final safeIndex = (index >= 0 && index < _cardNames.length)
        ? index
        : math.Random().nextInt(_cardNames.length);
    return TarotService.majorArcana[safeIndex].displayName;
  }

  Future<void> _resetSelection() async {
    _flipController.reset();
    if (!mounted) return;
    setState(() {
      _ritualMode = false;
      _ritualIntroActive = false;
      _ritualIntroExpanded = false;
      _ritualCarouselVisible = false;
      _selectionLocked = false;
      _selectedCardIndex = null;
      _drawnCard = null;
      _isLoadingCard = false;
    });
  }

  Future<void> _startRitual({required bool canDraw}) async {
    if (_ritualMode || _isDrawRequestInFlight || _selectionLocked) return;
    if (!canDraw) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppTexts.t('home.cta.insufficient_credits_message')),
        ),
      );
      return;
    }

    setState(() => _isDrawRequestInFlight = true);
    try {
      final consumed = await _consumeDrawRight();
      if (!consumed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppTexts.t('home.cta.insufficient_credits_message')),
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _ritualMode = true;
        _ritualIntroActive = true;
        _ritualIntroExpanded = false;
        _ritualCarouselVisible = false;
        _selectionLocked = false;
        _selectedCardIndex = null;
        _drawnCard = null;
      });
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (!mounted) return;
      setState(() {
        _ritualIntroExpanded = true;
      });

      await Future<void>.delayed(const Duration(milliseconds: 420));
      if (!mounted) return;
      setState(() {
        _ritualCarouselVisible = true;
      });
      _startCarousel();

      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      setState(() {
        _ritualIntroActive = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isDrawRequestInFlight = false);
      }
    }
  }

  Future<void> _handleCardTap({
    required int loopPage,
  }) async {
    if (_selectionLocked || _isDrawRequestInFlight || _isLoadingCard) return;
    if (!_ritualMode) return;

    final homePageState = context.findAncestorStateOfType<_HomePageState>();
    try {
      _stopCarousel();
      final selectedCardIndex = _cardIndexForLoopPage(loopPage);
      final imageFuture = _tarotService.getCardByIndex(selectedCardIndex);

      if (_pageController.hasClients) {
        await _pageController.animateToPage(
          loopPage,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }

      if (!mounted) return;
      setState(() {
        _selectionLocked = true;
        _selectedCardIndex = selectedCardIndex;
        _isLoadingCard = true;
      });

      await _flipController.forward(from: 0);
      final selectedCard = await imageFuture;
      if (!mounted) return;
      setState(() {
        _drawnCard = selectedCard;
        _isLoadingCard = false;
      });

      final languageCode = _resolveDeviceLanguageCode();
      final drawnCardName = selectedCard.card.displayName;
      await local_notifications.NotificationService.instance.onDailyCardDrawn(
        drawnCardName,
        languageCode,
      );
      await homePageState?._maybePromptNotificationPermission();
      if (!mounted) return;

      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => KozmikBilgePage(
            cardTitle: selectedCard.card.displayName,
            cardImageUrl: selectedCard.imageUrl,
          ),
        ),
      );
      await _resetSelection();
    } catch (error) {
      debugPrint('Tarot ritual draw failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gorsel yuklenemedi'),
        ),
      );
      await _resetSelection();
    } finally {
      if (mounted) {
        setState(() {
          _isDrawRequestInFlight = false;
          _isLoadingCard = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    _flipController.dispose();
    _ritualAuraController.dispose();
    super.dispose();
  }

  String _resolveDeviceLanguageCode() {
    final current = AppLocale.current.trim().toLowerCase();
    if (current == 'tr' || current == 'en') return current;
    final localeCode =
        Localizations.localeOf(context).languageCode.trim().toLowerCase();
    return localeCode == 'tr' ? 'tr' : 'en';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userDoc.snapshots(),
      builder: (context, snapshot) {
        final isLoading = !snapshot.hasData;
        final data = snapshot.data?.data();
        final wallet = Map<String, dynamic>.from(
          data?[UserProfileContract.wallet] as Map? ?? const {},
        );
        final credits =
            (wallet[UserProfileContract.walletCredits] as num?)?.toInt() ?? 0;
        final canDraw = !isLoading &&
            !_isLoadingCard &&
            !_isDrawRequestInFlight &&
            credits >= _kPaidDrawCost;
        final drawBadgeText = _drawBadgeText(
          isLoading: isLoading,
          credits: credits,
        );
        final ctaText = _ctaText(
          isLoading: isLoading,
          credits: credits,
        );
        final selectedIndex = _selectedCardIndex ??
            _cardIndexForLoopPage(
              _currentLoopPage,
            );
        final headline = _selectionLocked
            ? _displayNameForIndex(selectedIndex)
            : 'Gunun Rehberi';
        final subtitle = _ritualMode && _ritualCarouselVisible
            ? 'Dolasimdaki kartlardan birini sec ve bugunun rehberligini aciga cikar.'
            : '';
        final canTapCarousel = _ritualMode &&
            _ritualCarouselVisible &&
            !_selectionLocked &&
            !_isLoadingCard;
        final ritualStageHeight = _ritualMode ? 470.0 : 316.0;

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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _kPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(
                          color: _kPrimary.withValues(alpha: 0.2),
                        ),
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
                      headline,
                      style: GoogleFonts.newsreader(
                        fontSize: 34,
                        fontStyle: FontStyle.italic,
                        color: _kOnSurface,
                      ),
                    ),
                    const SizedBox(height: 24),

                    AnimatedContainer(
                      duration: const Duration(milliseconds: 520),
                      curve: Curves.easeOutCubic,
                      height: ritualStageHeight,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_ritualMode)
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: _RitualOrbitBand(
                                animation: _ritualAuraController,
                              ),
                            ),
                          if (_ritualMode)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: _RitualOrbitBand(
                                animation: _ritualAuraController,
                                reverse: true,
                              ),
                            ),
                          if (!_ritualMode)
                            const _IdleGuideCard()
                          else
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  top: 54,
                                  bottom: 54,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 320),
                                    curve: Curves.easeOutCubic,
                                    opacity: _ritualCarouselVisible ? 1 : 0,
                                    child: IgnorePointer(
                                      ignoring: !canTapCarousel,
                                      child: Opacity(
                                        opacity: _selectionLocked ? 0.16 : 1,
                                        child: PageView.builder(
                                          controller: _pageController,
                                          itemCount: _loopItemCount,
                                          padEnds: false,
                                          onPageChanged: (value) {
                                            _currentLoopPage = value;
                                          },
                                          itemBuilder: (context, loopIndex) {
                                            final cardIndex =
                                                _cardIndexForLoopPage(
                                              loopIndex,
                                            );
                                            return GestureDetector(
                                              onTap: () => _handleCardTap(
                                                loopPage: loopIndex,
                                              ),
                                              behavior: HitTestBehavior.opaque,
                                              child: AnimatedBuilder(
                                                animation: _pageController,
                                                builder: (context, _) {
                                                  final page = _pageController
                                                          .hasClients
                                                      ? (_pageController.page ??
                                                          _pageController
                                                              .initialPage
                                                              .toDouble())
                                                      : _initialLoopPage
                                                          .toDouble();
                                                  final distance =
                                                      (page - loopIndex).abs();
                                                  final scale = (1 -
                                                          (distance * 0.025)
                                                              .clamp(
                                                            0.0,
                                                            0.06,
                                                          ))
                                                      .toDouble();
                                                  final opacity = (1 -
                                                          (distance * 0.08)
                                                              .clamp(
                                                            0.0,
                                                            0.14,
                                                          ))
                                                      .toDouble();
                                                  return Transform.scale(
                                                    scale: scale,
                                                    child: Opacity(
                                                      opacity: opacity,
                                                      child: _GuideCardBack(
                                                        cardName:
                                                            _displayNameForIndex(
                                                          cardIndex,
                                                        ),
                                                        width: double.infinity,
                                                        height: 352,
                                                        margin: EdgeInsets.zero,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                  opacity: _ritualIntroActive ? 1 : 0,
                                  child: IgnorePointer(
                                    ignoring: true,
                                    child: AnimatedScale(
                                      duration:
                                          const Duration(milliseconds: 520),
                                      curve: Curves.easeOutCubic,
                                      scale: _ritualIntroExpanded ? 1.38 : 1,
                                      child: AnimatedSlide(
                                        duration:
                                            const Duration(milliseconds: 520),
                                        curve: Curves.easeOutCubic,
                                        offset: _ritualIntroExpanded
                                            ? const Offset(0, -0.08)
                                            : Offset.zero,
                                        child: const _IdleGuideCard(
                                          compactGlow: false,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (_selectionLocked && _selectedCardIndex != null)
                            _SelectedGuideCard(
                              title: _displayNameForIndex(_selectedCardIndex!),
                              imageUrl: _drawnCard?.imageUrl,
                              isLoading: _isLoadingCard,
                              flipAnimation: _flipController,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Subtitle
                    Visibility(
                      visible: subtitle.isNotEmpty,
                      maintainSize: false,
                      maintainAnimation: false,
                      maintainState: false,
                      child: Text(
                        '"$subtitle"',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: _kSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // CTA Button
                    Visibility(
                      visible: !_ritualMode,
                      maintainSize: false,
                      maintainAnimation: false,
                      maintainState: false,
                      child: _HeroCtaButton(
                        canDraw: canDraw,
                        ctaText: ctaText,
                        onPressed: () => _startRitual(canDraw: canDraw),
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

class _HeroCtaButton extends StatelessWidget {
  const _HeroCtaButton({
    required this.canDraw,
    required this.ctaText,
    required this.onPressed,
  });

  final bool canDraw;
  final String ctaText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
          onPressed: canDraw ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledForegroundColor: _kOnPrimary.withValues(alpha: 0.6),
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
              color: _kOnPrimary.withValues(alpha: canDraw ? 1 : 0.65),
            ),
          ),
        ),
      ),
    );
  }
}

class _RitualOrbitBand extends StatelessWidget {
  const _RitualOrbitBand({
    required this.animation,
    this.reverse = false,
  });

  final Animation<double> animation;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final phase = (reverse ? -1 : 1) * animation.value * math.pi * 2;
          final drift = math.sin(phase) * 34;
          final glow = 0.4 + (math.cos(phase).abs() * 0.32);

          return Transform.rotate(
            angle: reverse ? math.pi : 0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 244,
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        _kPrimaryContainer.withValues(alpha: 0.18),
                        _kPrimary.withValues(alpha: 0.58),
                        _kPrimaryContainer.withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(drift, 0),
                  child: Container(
                    width: 76,
                    height: 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: _kPrimary.withValues(alpha: glow),
                      boxShadow: [
                        BoxShadow(
                          color: _kPrimaryContainer.withValues(alpha: glow),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(-drift * 0.85, 0),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: _kPrimaryContainer.withValues(alpha: 0.72),
                    size: 18,
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

class _GuideCardBack extends StatelessWidget {
  const _GuideCardBack({
    required this.cardName,
    this.width = 144,
    this.height = 220,
    this.margin = const EdgeInsets.symmetric(horizontal: 8),
  });

  final String cardName;
  final double width;
  final double height;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kSurfaceContainerHigh, _kBg],
        ),
        border: Border.all(color: _kGlassBorder),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _kTertiary.withValues(alpha: 0.18),
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
                  color: _kTertiary,
                  size: 38,
                ),
                const SizedBox(height: 12),
                Text(
                  'Tarot AI',
                  style: GoogleFonts.newsreader(
                    fontSize: 20,
                    fontStyle: FontStyle.italic,
                    color: _kOnSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    cardName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      letterSpacing: 1.4,
                      color: _kSecondary.withValues(alpha: 0.75),
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

class _IdleGuideCard extends StatelessWidget {
  const _IdleGuideCard({
    this.compactGlow = true,
  });

  final bool compactGlow;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: compactGlow ? 156 : 192,
          height: compactGlow ? 236 : 288,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withValues(alpha: compactGlow ? 0.18 : 0.28),
                blurRadius: compactGlow ? 42 : 56,
                spreadRadius: compactGlow ? 4 : 8,
              ),
            ],
          ),
        ),
        _GuideCardBack(
          cardName: 'Gunun Rehberi',
          width: 192,
          height: 288,
          margin: EdgeInsets.zero,
        ),
      ],
    );
  }
}

class _SelectedGuideCard extends StatelessWidget {
  const _SelectedGuideCard({
    required this.title,
    required this.imageUrl,
    required this.isLoading,
    required this.flipAnimation,
  });

  final String title;
  final String? imageUrl;
  final bool isLoading;
  final Animation<double> flipAnimation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: flipAnimation,
      builder: (context, child) {
        final angle = flipAnimation.value * math.pi;
        final isFront = angle >= math.pi / 2;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          child: isFront
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: _SelectedGuideCardFace(
                    title: title,
                    imageUrl: imageUrl,
                    isLoading: isLoading,
                  ),
                )
              : Transform.scale(
                  scale: 1 + (flipAnimation.value * 0.14),
                  child: _GuideCardBack(cardName: title),
                ),
        );
      },
    );
  }
}

class _SelectedGuideCardFace extends StatelessWidget {
  const _SelectedGuideCardFace({
    required this.title,
    required this.imageUrl,
    required this.isLoading,
  });

  final String title;
  final String? imageUrl;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 320,
      child: Stack(
        children: [
          Positioned.fill(
            child: (imageUrl?.trim().isNotEmpty ?? false)
                ? TarotCardView(
                    imageUrl: imageUrl!,
                    borderRadius: BorderRadius.circular(18),
                  )
                : Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: _kSurfaceContainerHigh,
                      boxShadow: [
                        BoxShadow(
                          color: _kPrimary.withValues(alpha: 0.26),
                          blurRadius: 32,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: isLoading
                          ? const CircularProgressIndicator(
                              color: _kTertiary,
                            )
                          : const Icon(
                              Icons.auto_awesome,
                              color: _kTertiary,
                              size: 42,
                            ),
                    ),
                  ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.newsreader(
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      color: _kOnSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// IDENTITY MODULE
// ═════════════════════════════════════════════════════════════════
class _IdentityModule extends StatefulWidget {
  const _IdentityModule({required this.uid});

  final String uid;

  @override
  State<_IdentityModule> createState() => _IdentityModuleState();
}

class _IdentityModuleState extends State<_IdentityModule> {
  String _commentKey = '';
  Future<String>? _commentFuture;

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

  String _zodiacEn(DateTime date) {
    final m = date.month;
    final d = date.day;
    if ((m == 3 && d >= 21) || (m == 4 && d <= 19)) return 'Aries';
    if ((m == 4 && d >= 20) || (m == 5 && d <= 20)) return 'Taurus';
    if ((m == 5 && d >= 21) || (m == 6 && d <= 20)) return 'Gemini';
    if ((m == 6 && d >= 21) || (m == 7 && d <= 22)) return 'Cancer';
    if ((m == 7 && d >= 23) || (m == 8 && d <= 22)) return 'Leo';
    if ((m == 8 && d >= 23) || (m == 9 && d <= 22)) return 'Virgo';
    if ((m == 9 && d >= 23) || (m == 10 && d <= 22)) return 'Libra';
    if ((m == 10 && d >= 23) || (m == 11 && d <= 21)) return 'Scorpio';
    if ((m == 11 && d >= 22) || (m == 12 && d <= 21)) return 'Sagittarius';
    if ((m == 12 && d >= 22) || (m == 1 && d <= 19)) return 'Capricorn';
    if ((m == 1 && d >= 20) || (m == 2 && d <= 18)) return 'Aquarius';
    return 'Pisces';
  }

  Future<String> _dailyCommentFuture(String? storedBirthDate) {
    final key = (storedBirthDate ?? '').trim();
    final localeAwareKey = '$key|${AppLocale.current}';
    if (_commentFuture == null || localeAwareKey != _commentKey) {
      _commentKey = localeAwareKey;
      _commentFuture = FrequencyService.instance.getDailyComment(
        userBirthDate: key,
        lang: AppLocale.current,
      );
    }
    return _commentFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(UserProfileContract.usersCollection)
          .doc(widget.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final storedBirthDate = data?[UserProfileContract.birthDate] as String?;
        final birthDate = _parseBirthDate(storedBirthDate);
        final birthDateText =
            birthDate != null ? _formatBirthDate(birthDate) : '—';
        final currentLang = AppLocale.current == 'en' ? 'en' : 'tr';
        final zodiacText = birthDate != null
            ? (currentLang == 'en'
                ? _zodiacEn(birthDate)
                : _zodiacTr(birthDate))
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
                      bodyText =
                          AppTexts.t('home.birth_frequency.loading_comment');
                    } else {
                      final dynamicComment =
                          (commentSnapshot.data ?? '').trim();
                      bodyText = dynamicComment.isNotEmpty
                          ? dynamicComment
                          : AppTexts.t(
                              'home.birth_frequency.unavailable_retry',
                            );
                    }
                    return Text(
                      bodyText,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        color: _kOnSurface.withValues(alpha: 0.8),
                        height: 1.6,
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
      body: ValueListenableBuilder<List<AppNotificationItem>>(
        valueListenable: NotificationService.instance.inbox,
        builder: (context, notifications, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (notifications.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Center(
                    child: Text(
                      AppTexts.t('home.notifications.empty'),
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        color: _kSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
              for (final item in notifications) ...[
                _NotificationListCard(item: item),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _NotificationListCard extends StatelessWidget {
  const _NotificationListCard({required this.item});

  final AppNotificationItem item;

  @override
  Widget build(BuildContext context) {
    final timestamp = '${item.receivedAt.day.toString().padLeft(2, '0')}.'
        '${item.receivedAt.month.toString().padLeft(2, '0')}.'
        '${item.receivedAt.year}  '
        '${item.receivedAt.hour.toString().padLeft(2, '0')}:'
        '${item.receivedAt.minute.toString().padLeft(2, '0')}';

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: _kTertiary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      color: _kOnSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.body,
              style: GoogleFonts.manrope(
                fontSize: 14,
                height: 1.45,
                color: _kSecondary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${item.source.toUpperCase()}  •  $timestamp',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                letterSpacing: 1.1,
                color: _kSecondary.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
