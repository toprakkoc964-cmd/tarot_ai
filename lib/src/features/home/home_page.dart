import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'aris_session_service.dart';
import 'chat_page.dart';
import 'cosmic_page.dart';
import 'credit_page.dart';
import 'messages_page.dart';
import 'home_palette.dart';
import 'profile_page.dart';
import '../auth/auth_service.dart';
import '../auth/user_profile_contract.dart';
import '../../core/ads/app_ad_reward_service.dart';
import '../../core/ads/app_ad_service.dart';
import '../../core/app_review_service.dart';
import '../../core/app_locale.dart';
import '../../core/app_language.dart';
import '../../core/notification_service.dart';
import '../../core/notification_router.dart';
import '../../core/app_texts.dart';
import '../../core/frequency_service.dart';
import '../../core/tarot_functions_client.dart';
import '../../core/widgets/inline_ad_banner.dart';
import '../readings/tarot_card_view.dart';
import '../readings/tarot_service.dart';
import '../auth/widgets/mystic_toast.dart';
import '../../../services/notification_service.dart' as local_notifications;

// ─── Design Tokens ───────────────────────────────────────────────
const _kBg = HomePalette.background;
const _kPrimary = HomePalette.primary;
const _kPrimaryContainer = HomePalette.primaryContainer;
const _kSecondary = HomePalette.secondary;
const _kTertiary = HomePalette.tertiary;
const _kOnSurface = HomePalette.onSurface;
const _kSurfaceContainerHigh = HomePalette.surfaceContainerHigh;
const _kOnPrimary = HomePalette.onPrimary;
const _kGlassBg = HomePalette.glassBg;
const _kGlassBorder = HomePalette.glassBorder;
const _kPaidDrawCost = 5;

enum _SpreadType {
  single(1, 'single'),
  three(3, 'three'),
  five(5, 'five'),
  seven(7, 'seven');

  const _SpreadType(this.cardCount, this.key);

  final int cardCount;
  final String key;

  int get baseCost => cardCount * _kPaidDrawCost;

  int get cost => baseCost;

  int effectiveCost({required bool freeSingleAvailable}) {
    if (this == _SpreadType.single && freeSingleAvailable) return 0;
    return baseCost;
  }

  String get shortLabel => AppTexts.t('tarot.spread.$key');

  String get name => AppTexts.t('tarot.spread.name.$key');

  List<String> get positions {
    return switch (this) {
      _SpreadType.single => [AppTexts.t('tarot.spread.position.message')],
      _SpreadType.three => [
        AppTexts.t('tarot.spread.position.past'),
        AppTexts.t('tarot.spread.position.now'),
        AppTexts.t('tarot.spread.position.future'),
      ],
      _SpreadType.five => [
        AppTexts.t('tarot.spread.position.situation'),
        AppTexts.t('tarot.spread.position.obstacle'),
        AppTexts.t('tarot.spread.position.advice'),
        AppTexts.t('tarot.spread.position.pastInfluence'),
        AppTexts.t('tarot.spread.position.possibleOutcome'),
      ],
      _SpreadType.seven => [
        AppTexts.t('tarot.spread.position.you'),
        AppTexts.t('tarot.spread.position.obstacle'),
        AppTexts.t('tarot.spread.position.conscious'),
        AppTexts.t('tarot.spread.position.subconscious'),
        AppTexts.t('tarot.spread.position.past'),
        AppTexts.t('tarot.spread.position.nearFuture'),
        AppTexts.t('tarot.spread.position.result'),
      ],
    };
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.authService, required this.uid});

  final AuthService authService;
  final String uid;

  static final GlobalKey<_HomePageState> _homeKey = GlobalKey<_HomePageState>();

  static Key get rootKey => _homeKey;

  static bool openTab(int index) {
    final state = _homeKey.currentState;
    if (state == null) return false;
    state._onNavTap(index);
    return true;
  }

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _navIndex = 0;
  bool _flashNotification = false;
  bool _flashMessages = false;
  bool _flashReward = false;
  int? _flashNavIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(AppReviewService.instance.requestAfterOnboardingIfNeeded());
      unawaited(_claimDailyGiftIfAvailable());
      unawaited(_ensureNotificationPermissionIfNeeded());
    });
  }

  Future<void> _ensureNotificationPermissionIfNeeded() async {
    final status = NotificationService.instance.permissionStatus.value;
    if (status != 'notDetermined' && status != 'unknown') return;
    await local_notifications.NotificationService.instance.requestPermissions();
    await NotificationService.instance.requestNotificationPermissions();
  }

  Future<void> _claimDailyGiftIfAvailable() async {
    try {
      final result = await AppAdRewardService.instance.claimDailyLoginReward();
      if (!mounted || !result.granted) return;

      final amount = '${result.grantedCredits}';
      MysticToast.showSuccess(
        context,
        AppTexts.t('ads.daily_gift.toast').replaceAll('{amount}', amount),
        dedupeKey: 'daily-gift-${result.claimDay ?? amount}',
      );
      unawaited(
        local_notifications.NotificationService.instance
            .showWalletRewardNotification(
              title: AppTexts.t('ads.daily_gift.notification_title'),
              body: AppTexts.t(
                'ads.daily_gift.notification_body',
              ).replaceAll('{amount}', amount),
            ),
      );
    } catch (error) {
      debugPrint('Daily login reward skipped: $error');
    }
  }

  Future<void> _onNotificationTap() async {
    setState(() => _flashNotification = true);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    await local_notifications.NotificationService.instance
        .syncDeliveredScheduledNotificationsToInbox();
    if (!mounted) return;
    await NotificationService.instance.reloadInbox();
    if (!mounted) return;
    await AppAdService.instance.maybeShowPageTransitionInterstitial();
    if (!mounted) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const _NotificationsPage()));

    if (!mounted) return;
    setState(() => _flashNotification = false);
  }

  Future<void> _onMessagesTap() async {
    setState(() => _flashMessages = true);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;

    final bottomInset = MediaQuery.paddingOf(context).bottom + 16;
    await AppAdService.instance.maybeShowPageTransitionInterstitial();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MessagesPage(
          uid: widget.uid,
          bottomInset: bottomInset,
          showBackButton: true,
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _flashMessages = false);
  }

  Future<void> _onRewardTap() async {
    setState(() => _flashReward = true);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;

    try {
      final adResult = await AppAdService.instance.showRewarded(
        AppRewardedPlacement.coinsReward,
        userId: widget.uid,
      );
      if (!mounted) return;

      if (adResult.unavailable) {
        MysticToast.showInfo(
          context,
          AppTexts.t('ads.common.not_ready'),
          dedupeKey: 'coins-ad-not-ready',
        );
        return;
      }

      if (!adResult.earned) return;
      MysticToast.showInfo(
        context,
        AppTexts.t('ads.coins.pending_toast'),
        dedupeKey: 'coins-ad-pending',
      );
    } catch (error) {
      debugPrint('Coins rewarded flow failed: $error');
      if (!mounted) return;
      MysticToast.showInfo(
        context,
        AppTexts.t('ads.common.not_ready'),
        dedupeKey: 'coins-ad-failed',
      );
    } finally {
      if (mounted) {
        setState(() => _flashReward = false);
      }
    }
  }

  void _onNavTap(int i) {
    setState(() {
      if (i >= 0 && i <= 3) {
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
    final isCosmicPage = _navIndex == 1;
    final isCreditPage = _navIndex == 2;
    final isProfilePage = _navIndex == 3;
    final topBarHeight = _TopBar.estimatedHeight(context);
    final bottomBarHeight = _BottomNavBar.estimatedHeight(context);

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // ── Nebula background ──
          if (!isCosmicPage && !isCreditPage && !isProfilePage)
            const _NebulaBackground(),
          if (isCosmicPage)
            CosmicPage(
              bottomInset: bottomBarHeight,
              uid: widget.uid,
              onOpenCredits: () => _onNavTap(2),
            ),
          if (isCreditPage)
            CreditPage(bottomInset: bottomBarHeight, uid: widget.uid),
          if (isProfilePage)
            ProfilePage(
              bottomInset: bottomBarHeight,
              authService: widget.authService,
              uid: widget.uid,
            ),

          // ── Scrollable content ──
          if (!isCosmicPage && !isCreditPage && !isProfilePage)
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
                      const SizedBox(height: 18),
                      const InlineAdBanner(),
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
          if (!isCosmicPage && !isCreditPage && !isProfilePage)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopBar(
                authService: widget.authService,
                uid: widget.uid,
                flashNotification: _flashNotification,
                flashMessages: _flashMessages,
                flashReward: _flashReward,
                onMessagesTap: _onMessagesTap,
                onNotificationTap: _onNotificationTap,
                onRewardTap: _onRewardTap,
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
    required this.flashMessages,
    required this.flashReward,
    required this.onMessagesTap,
    required this.onNotificationTap,
    required this.onRewardTap,
  });
  final AuthService authService;
  final String uid;
  final bool flashNotification;
  final bool flashMessages;
  final bool flashReward;
  final VoidCallback onMessagesTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onRewardTap;

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
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(UserProfileContract.usersCollection)
                .doc(uid)
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              final wallet = Map<String, dynamic>.from(
                data?[UserProfileContract.wallet] as Map? ?? const {},
              );
              final adRewards = Map<String, dynamic>.from(
                data?['adRewards'] as Map? ?? const {},
              );
              final credits =
                  (wallet[UserProfileContract.walletCredits] as num?)?.toInt();
              final creditsText = credits?.toString() ?? '--';
              final coinsProgress =
                  (adRewards['coinsProgress'] as num?)?.toInt() ?? 0;

              Widget buildCircleButton({
                required VoidCallback onTap,
                required IconData icon,
                required bool flashing,
                String? badgeText,
                String? tooltip,
              }) {
                final button = GestureDetector(
                  onTap: onTap,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _kSurfaceContainerHigh.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(
                        color: (flashing ? _kTertiary : _kSecondary).withValues(
                          alpha: 0.25,
                        ),
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(
                          child: Icon(
                            icon,
                            color: flashing ? _kTertiary : _kPrimary,
                            size: 20,
                          ),
                        ),
                        if (badgeText != null && badgeText.isNotEmpty)
                          Positioned(
                            right: -2,
                            bottom: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: _kTertiary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badgeText,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: _kBg,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );

                if (tooltip == null || tooltip.isEmpty) return button;
                return Tooltip(message: tooltip, child: button);
              }

              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
                        Icon(
                          Icons.payments_rounded,
                          color: _kTertiary,
                          size: 14,
                        ),
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
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildCircleButton(
                        onTap: onRewardTap,
                        icon: Icons.smart_display_rounded,
                        flashing: flashReward,
                        badgeText: coinsProgress > 0
                            ? '$coinsProgress/3'
                            : null,
                        tooltip: AppTexts.t('ads.coins.watch_tooltip'),
                      ),
                      const SizedBox(width: 10),
                      buildCircleButton(
                        onTap: onMessagesTap,
                        icon: Icons.forum_outlined,
                        flashing: flashMessages,
                      ),
                      const SizedBox(width: 10),
                      buildCircleButton(
                        onTap: onNotificationTap,
                        icon: Icons.notifications_none_rounded,
                        flashing: flashNotification,
                      ),
                    ],
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

// ═════════════════════════════════════════════════════════════════
// HERO SECTION — TAROT REVEAL
// ═════════════════════════════════════════════════════════════════
class _HeroSection extends StatefulWidget {
  const _HeroSection({required this.uid, required this.authService});

  final String uid;
  final AuthService authService;

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection>
    with TickerProviderStateMixin {
  static const _loopItemCount = 100000;
  static const _initialLoopPage = _loopItemCount ~/ 2;
  static const _deckCardWidth = 224.0;
  static const _deckCardHeight = 348.0;
  static final List<String> _cardNames = TarotService.deck
      .map((card) => card.name)
      .toList(growable: false);

  late final AnimationController _flipController;
  late final PageController _pageController;
  final _random = math.Random();
  int _currentLoopPage = _initialLoopPage;
  int _deckOffset = 0;
  int? _selectedCardIndex;
  bool _isDrawing = false;
  bool _isDeckVisible = false;
  bool _selectionLocked = false;
  bool _isLoadingCard = false;
  bool _isDrawRequestInFlight = false;
  final _functionsClient = TarotFunctionsClient();
  final Map<int, String> _cardImageUrlByIndex = {};
  late final DocumentReference<Map<String, dynamic>> _userDoc =
      FirebaseFirestore.instance
          .collection(UserProfileContract.usersCollection)
          .doc(widget.uid);
  DrawnTarotCard? _drawnCard;
  DrawnTarotCard? _revealedPreviewCard;
  final List<DrawnTarotCard> _selectedCards = [];
  final Set<int> _pickedCardIndices = {};
  bool _isChoosingSpread = false;
  bool _isOpeningSpreadChat = false;
  _SpreadType? _selectedSpreadType;
  int _deckSpinGeneration = 0;
  static const int _deckSpinMsPerPageNormal = 380;
  static const int _deckSpinMsPerPageFast = 115;

  String _drawBadgeText({
    required bool isLoading,
    required int credits,
    required bool freeSingleAvailable,
  }) {
    if (isLoading) return AppTexts.t('common.loading');
    if (freeSingleAvailable) return AppTexts.t('tarot.spread.free');
    return AppTexts.t('tarot.spread.cost_note');
  }

  String _ctaText({
    required bool isLoading,
    required int credits,
    required bool freeSingleAvailable,
  }) {
    if (_isChoosingSpread) {
      return AppTexts.t('tarot.spread.cta_cancel');
    }
    if (_selectionLocked ||
        _isLoadingCard ||
        _isDrawRequestInFlight ||
        _isOpeningSpreadChat) {
      return AppTexts.t('tarot.spread.revealing');
    }
    if (isLoading) return AppTexts.t('common.loading');
    if (freeSingleAvailable) {
      return '${AppTexts.t('tarot.spread.free')} · ${AppTexts.t('tarot.spread.cta_draw')}';
    }
    return AppTexts.t('tarot.spread.cta_draw');
  }

  String _todayLocalDayKey() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  bool _freeSingleDrawAvailable(Map<String, dynamic>? data) {
    final lastFreeDay = data?['lastFreeCardDrawDay'];
    return lastFreeDay is! String || lastFreeDay != _todayLocalDayKey();
  }

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _pageController = PageController(
      viewportFraction: 0.68,
      initialPage: _initialLoopPage,
    );
    _warmCardImageCache();
  }

  void _warmCardImageCache() {
    TarotService.ensureLocalAssetsCached();
    _cardImageUrlByIndex
      ..clear()
      ..addAll(TarotService.imageUrlByIndex);
  }

  DrawnTarotCard _cardForIndex(int index) {
    final path =
        _cardImageUrlByIndex[index] ??
        TarotService.cachedUrlForIndex(index) ??
        TarotService.assetPathForIndex(index);
    _cardImageUrlByIndex[index] = path;
    return DrawnTarotCard(
      card: TarotService.cardForIndex(index),
      imageUrl: path,
    );
  }

  void _completeCardReveal({
    required int cardIndex,
    required DrawnTarotCard selectedCard,
  }) {
    setState(() {
      _drawnCard = null;
      _selectedCardIndex = null;
      _selectionLocked = false;
      _isLoadingCard = false;
      _revealedPreviewCard = selectedCard;
      _selectedCards.add(selectedCard);
      _pickedCardIndices.add(cardIndex);
      if (selectedCard.imageUrl.isNotEmpty) {
        _cardImageUrlByIndex[cardIndex] = selectedCard.imageUrl;
      }
    });
  }

  List<DrawnTarotCard> _enrichSelectedCardsForSpread() {
    final enriched = _selectedCards
        .map((card) => _cardForIndex(card.card.index))
        .toList();
    setState(() {
      _selectedCards
        ..clear()
        ..addAll(enriched);
    });
    return enriched;
  }

  Future<bool> _consumeDrawRight(int cost) async {
    try {
      await _functionsClient.consumeHomeCardDraw(cost: cost);
      return true;
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'failed-precondition') return false;
      return false;
    } catch (_) {
      return false;
    }
  }

  String _displayNameForIndex(int index) {
    final safeIndex = (index >= 0 && index < _cardNames.length)
        ? index
        : math.Random().nextInt(_cardNames.length);
    return TarotService.cardForIndex(safeIndex).displayName;
  }

  int _cardIndexForLoopPage(int loopPage) {
    final normalized = (loopPage + _deckOffset) % _cardNames.length;
    return normalized < 0 ? normalized + _cardNames.length : normalized;
  }

  String _spreadSessionId(List<String> cardNames) {
    final slug = cardNames
        .map(
          (name) => name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
        )
        .where((part) => part.isNotEmpty)
        .join('_');
    final compactSlug = slug.length > 12
        ? slug.substring(0, 12)
        : (slug.isEmpty ? 'spread' : slug);
    return newArisSessionId(prefix: 'spread_$compactSlug');
  }

  int _loopPageForCardIndex(int cardIndex) {
    final currentIndex = _cardIndexForLoopPage(_currentLoopPage);
    var delta = cardIndex - currentIndex;
    if (delta < 0) {
      delta += _cardNames.length;
    }
    return _currentLoopPage + delta;
  }

  List<int> _availableCardIndices() {
    return List<int>.generate(_cardNames.length, (index) => index)
        .where((index) => !_pickedCardIndices.contains(index))
        .toList(growable: false);
  }

  void _prepareDeckForRitual() {
    _deckOffset = _random.nextInt(_cardNames.length);
    _currentLoopPage = _initialLoopPage + _random.nextInt(6000) - 3000;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_currentLoopPage);
    }
  }

  Future<void> _resetSelection() async {
    _flipController.reset();
    if (!mounted) return;
    setState(() {
      _isDrawing = false;
      _isDeckVisible = false;
      _selectionLocked = false;
      _selectedCardIndex = null;
      _drawnCard = null;
      _revealedPreviewCard = null;
      _isLoadingCard = false;
      _selectedCards.clear();
      _pickedCardIndices.clear();
      _isChoosingSpread = false;
      _isOpeningSpreadChat = false;
      _selectedSpreadType = null;
    });
    _stopDeckSpin();
    if (_pageController.hasClients) {
      _currentLoopPage = _initialLoopPage;
      _pageController.jumpToPage(_initialLoopPage);
    }
  }

  bool get _shouldKeepDeckSpinning =>
      _isDrawing &&
      _isDeckVisible &&
      !_selectionLocked &&
      !_isOpeningSpreadChat;

  void _stopDeckSpin() {
    _deckSpinGeneration++;
  }

  Future<void> _startDeckSpin({required bool fast}) async {
    _stopDeckSpin();
    final generation = _deckSpinGeneration;
    final msPerPage = fast ? _deckSpinMsPerPageFast : _deckSpinMsPerPageNormal;

    while (mounted &&
        generation == _deckSpinGeneration &&
        _shouldKeepDeckSpinning) {
      if (!_pageController.hasClients) {
        await Future<void>.delayed(const Duration(milliseconds: 24));
        continue;
      }
      final targetPage = _currentLoopPage + 1;
      try {
        await _pageController.animateToPage(
          targetPage,
          duration: Duration(milliseconds: msPerPage),
          curve: Curves.linear,
        );
      } catch (_) {
        break;
      }
      if (!mounted || generation != _deckSpinGeneration) return;
      setState(() => _currentLoopPage = targetPage);
    }
  }

  Future<void> _landOnCardPage(int targetPage) async {
    _stopDeckSpin();
    if (!_pageController.hasClients) return;
    try {
      final pageDelta = (targetPage - _currentLoopPage).abs();
      if (pageDelta <= 4) {
        await _pageController
            .animateToPage(
              targetPage,
              duration: Duration(milliseconds: 140 * pageDelta.clamp(1, 4)),
              curve: Curves.easeOutCubic,
            )
            .timeout(const Duration(seconds: 2));
      } else {
        _pageController.jumpToPage(targetPage);
      }
    } catch (_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(targetPage);
      }
    }
  }

  void _toggleSpreadChooser() {
    if (_isDrawing ||
        _isDrawRequestInFlight ||
        _selectionLocked ||
        _isOpeningSpreadChat) {
      return;
    }
    setState(() => _isChoosingSpread = !_isChoosingSpread);
  }

  Future<void> _selectSpread(
    _SpreadType spread,
    int credits, {
    required bool freeSingleAvailable,
  }) async {
    if (_isDrawing || _isDrawRequestInFlight || _selectionLocked) return;
    _selectedSpreadType = spread;
    final effectiveCost = spread.effectiveCost(
      freeSingleAvailable: freeSingleAvailable,
    );
    // TODO(reklam): İleride jeton yerine reklam izle alternatifi burada eklenecek.
    if (effectiveCost > 0 && credits < effectiveCost) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      MysticToast.showWarning(
        context,
        AppTexts.t('tarot.gate.insufficient'),
        dedupeKey: 'tarot-insufficient-credits',
      );
      HomePage.openTab(2);
      if (!mounted) return;
      setState(() {
        _isChoosingSpread = true;
        _selectedSpreadType = spread;
      });
      return;
    }

    await _startRitual(spread);
  }

  Future<void> _startRitual(_SpreadType spread) async {
    if (_isDrawing ||
        _isDrawRequestInFlight ||
        _selectionLocked ||
        _isOpeningSpreadChat) {
      return;
    }

    setState(() {
      _isDrawRequestInFlight = true;
      _isDrawing = true;
      _isDeckVisible = false;
      _selectionLocked = false;
      _selectedCardIndex = null;
      _drawnCard = null;
      _selectedCards.clear();
      _pickedCardIndices.clear();
      _isChoosingSpread = false;
      _isOpeningSpreadChat = false;
      _selectedSpreadType = spread;
    });
    _prepareDeckForRitual();

    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (!mounted || !_isDrawing || _selectionLocked) return;
      setState(() => _isDeckVisible = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_startDeckSpin(fast: false));
      });
    });

    try {
      if (spread.baseCost > 0) {
        final consumed = await _consumeDrawRight(spread.baseCost);
        if (!consumed) {
          if (!mounted) return;
          await _resetSelection();
          if (!mounted) return;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          MysticToast.showWarning(
            context,
            AppTexts.t('tarot.gate.insufficient'),
            dedupeKey: 'tarot-insufficient-credits',
          );
          HomePage.openTab(2);
          return;
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isDrawRequestInFlight = false);
      }
    }
  }

  Future<void> _continueOrOpenSpread() async {
    final spread = _selectedSpreadType;
    if (spread == null || !mounted) return;
    if (_selectedCards.length >= spread.cardCount) {
      await _openSpreadReading();
      return;
    }

    _flipController.reset();
    setState(() {
      _selectionLocked = false;
      _selectedCardIndex = null;
      _drawnCard = null;
      _revealedPreviewCard = null;
      _isLoadingCard = false;
      _isDrawing = true;
      _isDeckVisible = true;
    });

    if (!_pageController.hasClients) return;
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted || _selectionLocked || _isOpeningSpreadChat) return;
    unawaited(_startDeckSpin(fast: true));
  }

  Future<void> _handleDeckRevealTap() async {
    if (_selectionLocked ||
        _isDrawRequestInFlight ||
        _isLoadingCard ||
        _isOpeningSpreadChat) {
      return;
    }
    if (!_isDeckVisible) return;

    final available = _availableCardIndices();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTexts.t('tarot.spread.max_cards'))),
      );
      return;
    }

    final cardIndex = available[_random.nextInt(available.length)];
    final targetPage = _loopPageForCardIndex(cardIndex);
    final languageCode = _resolveDeviceLanguageCode();

    try {
      setState(() {
        _selectionLocked = true;
        _selectedCardIndex = cardIndex;
        _isLoadingCard = true;
      });

      await _landOnCardPage(targetPage).timeout(const Duration(seconds: 3));
      if (!mounted) return;

      setState(() => _currentLoopPage = targetPage);
      final selectedCard = _cardForIndex(cardIndex);

      if (!mounted) return;
      setState(() {
        _drawnCard = selectedCard;
        _isLoadingCard = false;
      });

      await _flipController
          .forward(from: 0)
          .timeout(const Duration(seconds: 2));
      if (!mounted) return;

      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      _completeCardReveal(cardIndex: cardIndex, selectedCard: selectedCard);

      if (_selectedCards.length == 1) {
        unawaited(
          local_notifications.NotificationService.instance.onDailyCardDrawn(
            selectedCard.card.displayName,
            languageCode,
          ),
        );
      }
    } catch (error) {
      debugPrint('Tarot ritual draw failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTexts.t('tarot.spread.draw_failed'))),
      );
      await _resetSelection();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCard = false;
          if (_selectionLocked) {
            _selectionLocked = false;
            _selectedCardIndex = null;
            _drawnCard = null;
          }
        });
      }
    }

    if (mounted) {
      unawaited(_continueOrOpenSpread());
    }
  }

  Future<void> _openSpreadReading() async {
    final spread = _selectedSpreadType ?? _SpreadType.single;
    if (_selectedCards.isEmpty || _isOpeningSpreadChat) return;
    setState(() => _isOpeningSpreadChat = true);
    final spreadCards = _enrichSelectedCardsForSpread();
    if (!mounted) return;
    final cardNames = spreadCards
        .map((card) => card.card.displayName)
        .toList(growable: false);
    final positions = spread.positions;
    final sessionId = _spreadSessionId(cardNames);
    await AppAdService.instance.maybeShowPageTransitionInterstitial();
    if (!mounted) return;
    final chatResult = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => KozmikBilgePage(
          uid: widget.uid,
          spreadCards: List<DrawnTarotCard>.unmodifiable(spreadCards),
          spreadPositions: positions,
          spreadName: spread.name,
          spreadSessionId: sessionId,
        ),
      ),
    );
    if (!mounted) return;
    if (chatResult == 'credits') {
      context.findAncestorStateOfType<_HomePageState>()?._onNavTap(2);
    }
    await _resetSelection();
  }

  @override
  void dispose() {
    _stopDeckSpin();
    _pageController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  String _resolveDeviceLanguageCode() => AppLanguage.forAi();

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
        final freeSingleAvailable = _freeSingleDrawAvailable(data);
        final canDraw =
            !isLoading &&
            !_isLoadingCard &&
            !_isDrawRequestInFlight &&
            !_selectionLocked &&
            !_isOpeningSpreadChat;
        final drawBadgeText = _drawBadgeText(
          isLoading: isLoading,
          credits: credits,
          freeSingleAvailable: freeSingleAvailable,
        );
        final ctaText = _ctaText(
          isLoading: isLoading,
          credits: credits,
          freeSingleAvailable: freeSingleAvailable,
        );
        final selectedIndex =
            _selectedCardIndex ?? _cardIndexForLoopPage(_currentLoopPage);
        final spread = _selectedSpreadType;
        final headline = _selectionLocked
            ? _displayNameForIndex(selectedIndex)
            : (spread?.name ?? AppTexts.t('tarot.spread.name.single'));
        final subtitle = _isDrawing && _isDeckVisible
            ? (_selectedCards.isEmpty
                  ? AppTexts.t('tarot.spread.tap_to_draw')
                  : AppTexts.t('tarot.spread.selection_hint')
                        .replaceAll('{count}', '${_selectedCards.length}')
                        .replaceAll('{max}', '${spread?.cardCount ?? 1}'))
            : '';
        final canTapDeck =
            _isDrawing &&
            _isDeckVisible &&
            !_selectionLocked &&
            !_isLoadingCard &&
            !_isOpeningSpreadChat;
        final ritualStageHeight = _isDrawing ? 470.0 : 316.0;

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
                          if (_isDrawing)
                            const Positioned.fill(
                              child: IgnorePointer(child: _RitualAuraOverlay()),
                            ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 420),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(
                                    begin: 0.96,
                                    end: 1,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: _isDeckVisible
                                ? IgnorePointer(
                                    key: const ValueKey('drawing_deck'),
                                    ignoring: !canTapDeck,
                                    child: AnimatedOpacity(
                                      duration: const Duration(
                                        milliseconds: 280,
                                      ),
                                      opacity: _selectionLocked ? 0.16 : 1,
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final carouselWidth =
                                              constraints.maxWidth + 48;
                                          return OverflowBox(
                                            minWidth: carouselWidth,
                                            maxWidth: carouselWidth,
                                            child: SizedBox(
                                              width: carouselWidth,
                                              child: GestureDetector(
                                                onTap: canTapDeck
                                                    ? _handleDeckRevealTap
                                                    : null,
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                child: _FocusDeckCarousel(
                                                  controller: _pageController,
                                                  cardWidth: _deckCardWidth,
                                                  cardHeight: _deckCardHeight,
                                                  onPageChanged: (loopPage) {
                                                    _currentLoopPage = loopPage;
                                                  },
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  )
                                : Center(
                                    key: const ValueKey('hero_single_card'),
                                    child: _IdleGuideCard(
                                      compactGlow: !_isDrawing,
                                      expanded: _isDrawing,
                                    ),
                                  ),
                          ),
                          if (_selectionLocked && _selectedCardIndex != null)
                            _SelectedGuideCard(
                              title: _displayNameForIndex(_selectedCardIndex!),
                              imageUrl: _drawnCard?.imageUrl,
                              isLoading: _isLoadingCard,
                              flipAnimation: _flipController,
                            )
                          else if (_revealedPreviewCard != null)
                            _RevealedCardPreview(card: _revealedPreviewCard!),
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

                    if (_selectedCards.isNotEmpty) ...[
                      _SelectedSpreadStrip(cards: _selectedCards),
                      const SizedBox(height: 14),
                    ],

                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      child: _isChoosingSpread && !_isDrawing
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _SpreadChoicePanel(
                                selectedSpread: _selectedSpreadType,
                                freeSingleAvailable: freeSingleAvailable,
                                onSelected: (spread) => _selectSpread(
                                  spread,
                                  credits,
                                  freeSingleAvailable: freeSingleAvailable,
                                ),
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),

                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      opacity: _isDrawing ? 0 : 1,
                      child: IgnorePointer(
                        ignoring: _isDrawing,
                        child: _HeroCtaButton(
                          canDraw: canDraw,
                          ctaText: ctaText,
                          onPressed: _toggleSpreadChooser,
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

class _SpreadChoicePanel extends StatelessWidget {
  const _SpreadChoicePanel({
    required this.selectedSpread,
    required this.freeSingleAvailable,
    required this.onSelected,
  });

  final _SpreadType? selectedSpread;
  final bool freeSingleAvailable;
  final ValueChanged<_SpreadType> onSelected;

  @override
  Widget build(BuildContext context) {
    const spreads = _SpreadType.values;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kGlassBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.24)),
      ),
      child: Column(
        children: [
          Text(
            AppTexts.t('tarot.spread.cost_note'),
            style: GoogleFonts.spaceGrotesk(
              color: _kTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final spread in spreads) ...[
                Expanded(
                  child: _SpreadChoiceTile(
                    spread: spread,
                    selected: selectedSpread == spread,
                    freeSingleAvailable: freeSingleAvailable,
                    onTap: () => onSelected(spread),
                  ),
                ),
                if (spread != spreads.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SpreadChoiceTile extends StatelessWidget {
  const _SpreadChoiceTile({
    required this.spread,
    required this.selected,
    required this.freeSingleAvailable,
    required this.onTap,
  });

  final _SpreadType spread;
  final bool selected;
  final bool freeSingleAvailable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cost = spread.effectiveCost(freeSingleAvailable: freeSingleAvailable);
    final costText = cost == 0
        ? AppTexts.t('tarot.spread.free')
        : '$cost ${AppTexts.t('home.top.token_unit')}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 106),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? _kPrimary.withValues(alpha: 0.18)
                : _kSurfaceContainerHigh.withValues(alpha: 0.66),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? _kPrimary.withValues(alpha: 0.58)
                  : _kGlassBorder,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MiniSpreadFan(count: spread.cardCount),
              const SizedBox(height: 8),
              Text(
                spread.shortLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  color: _kOnSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                costText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: cost == 0 ? _kTertiary : _kSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniSpreadFan extends StatelessWidget {
  const _MiniSpreadFan({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final visibleCount = count.clamp(1, 5);
    return SizedBox(
      width: 48,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < visibleCount; i++)
            Transform.translate(
              offset: Offset((i - (visibleCount - 1) / 2) * 6, 0),
              child: Transform.rotate(
                angle: (i - (visibleCount - 1) / 2) * 0.10,
                child: Container(
                  width: 18,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_kSurfaceContainerHigh, _kBg],
                    ),
                    border: Border.all(
                      color: _kTertiary.withValues(alpha: 0.34),
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

class _SelectedSpreadStrip extends StatelessWidget {
  const _SelectedSpreadStrip({required this.cards});

  final List<DrawnTarotCard> cards;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final card = cards[index];
          final imageUrl = card.imageUrl.trim().isNotEmpty
              ? card.imageUrl
              : (TarotService.cachedUrlForIndex(card.card.index) ?? '');
          final hasImage = imageUrl.isNotEmpty;
          return Container(
            width: hasImage ? 64 : 92,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _kSurfaceContainerHigh,
              border: Border.all(color: _kPrimary.withValues(alpha: 0.35)),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasImage
                ? SizedBox(
                    width: 64,
                    height: 88,
                    child: TarotCardView(
                      imageUrl: imageUrl,
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    child: Center(
                      child: Text(
                        card.card.displayName,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.newsreader(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: _kOnSurface,
                        ),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _HeroCtaButton extends StatefulWidget {
  const _HeroCtaButton({
    required this.canDraw,
    required this.ctaText,
    required this.onPressed,
  });

  final bool canDraw;
  final String ctaText;
  final VoidCallback onPressed;

  @override
  State<_HeroCtaButton> createState() => _HeroCtaButtonState();
}

class _HeroCtaButtonState extends State<_HeroCtaButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1450),
  );

  late final Animation<double> _pulse = CurvedAnimation(
    parent: _pulseController,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    if (widget.canDraw) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _HeroCtaButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.canDraw && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.canDraw && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final glow = widget.canDraw ? 0.24 + (_pulse.value * 0.16) : 0.12;
        final scale = widget.canDraw ? 1.0 + (_pulse.value * 0.012) : 1.0;
        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kPrimary, _kPrimaryContainer],
                ),
                borderRadius: BorderRadius.circular(9999),
                boxShadow: [
                  BoxShadow(
                    color: _kPrimaryContainer.withValues(alpha: glow),
                    blurRadius: 20 + (_pulse.value * 10),
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: widget.canDraw ? widget.onPressed : null,
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
                  widget.ctaText,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: _kOnPrimary.withValues(
                      alpha: widget.canDraw ? 1 : 0.65,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FocusDeckCarousel extends StatelessWidget {
  const _FocusDeckCarousel({
    required this.controller,
    required this.cardWidth,
    required this.cardHeight,
    required this.onPageChanged,
  });

  final PageController controller;
  final double cardWidth;
  final double cardHeight;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardHeight + 24,
      child: PageView.builder(
        controller: controller,
        itemCount: _HeroSectionState._loopItemCount,
        clipBehavior: Clip.none,
        pageSnapping: false,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: onPageChanged,
        itemBuilder: (context, loopPage) {
          return Center(
            child: _GuideCardBack(
              cardName: '',
              width: cardWidth,
              height: cardHeight,
              margin: EdgeInsets.zero,
            ),
          );
        },
      ),
    );
  }
}

class _RitualAuraOverlay extends StatelessWidget {
  const _RitualAuraOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.05,
          colors: [_kPrimary.withValues(alpha: 0.14), Colors.transparent],
        ),
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
                border: Border.all(color: _kTertiary.withValues(alpha: 0.18)),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, color: _kTertiary, size: 38),
                const SizedBox(height: 12),
                Text(
                  'Tarot AI',
                  style: GoogleFonts.newsreader(
                    fontSize: 20,
                    fontStyle: FontStyle.italic,
                    color: _kOnSurface,
                  ),
                ),
                if (cardName.trim().isNotEmpty) ...[
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IdleGuideCard extends StatelessWidget {
  const _IdleGuideCard({this.compactGlow = true, this.expanded = false});

  final bool compactGlow;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final cardWidth = expanded ? 228.0 : 192.0;
    final cardHeight = expanded ? 342.0 : 288.0;
    final glowWidth = expanded ? 188.0 : (compactGlow ? 156.0 : 192.0);
    final glowHeight = expanded ? 282.0 : (compactGlow ? 236.0 : 288.0);

    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          width: glowWidth,
          height: glowHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withValues(
                  alpha: expanded ? 0.34 : (compactGlow ? 0.18 : 0.28),
                ),
                blurRadius: expanded ? 64 : (compactGlow ? 42 : 56),
                spreadRadius: expanded ? 10 : (compactGlow ? 4 : 8),
              ),
            ],
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          width: cardWidth,
          height: cardHeight,
          child: _GuideCardBack(
            cardName: AppTexts.t('tarot.spread.name.single'),
            width: cardWidth,
            height: cardHeight,
            margin: EdgeInsets.zero,
          ),
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
  const _SelectedGuideCardFace({required this.title, required this.imageUrl});

  final String title;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 320,
      child: Stack(
        children: [
          Positioned.fill(
            child: (imageUrl != null && imageUrl!.isNotEmpty)
                ? TarotCardView(
                    imageUrl: imageUrl!,
                    borderRadius: const BorderRadius.all(Radius.circular(18)),
                  )
                : _GuideCardBack(
                    cardName: title,
                    width: 210,
                    height: 320,
                    margin: EdgeInsets.zero,
                  ),
          ),
        ],
      ),
    );
  }
}

class _RevealedCardPreview extends StatelessWidget {
  const _RevealedCardPreview({required this.card});

  final DrawnTarotCard card;

  @override
  Widget build(BuildContext context) {
    final imageUrl = card.imageUrl.trim();
    return SizedBox(
      width: 210,
      height: 320,
      child: imageUrl.isNotEmpty
          ? TarotCardView(
              imageUrl: imageUrl,
              borderRadius: const BorderRadius.all(Radius.circular(18)),
            )
          : _GuideCardBack(
              cardName: card.card.displayName,
              width: 210,
              height: 320,
              margin: EdgeInsets.zero,
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

class _IdentityModuleState extends State<_IdentityModule>
    with WidgetsBindingObserver {
  String _commentKey = '';
  Future<String>? _commentFuture;
  Timer? _dailyCommentRefreshTimer;
  String _activeCommentDay = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleDailyCommentRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDailyCommentIfNeeded();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dailyCommentRefreshTimer?.cancel();
    super.dispose();
  }

  String _localDayKey([DateTime? value]) {
    final date = value ?? DateTime.now();
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  void _scheduleDailyCommentRefresh() {
    _dailyCommentRefreshTimer?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _dailyCommentRefreshTimer = Timer(
      nextDay.difference(now) + const Duration(seconds: 1),
      () {
        if (!mounted) return;
        _refreshDailyCommentIfNeeded();
      },
    );
  }

  void _refreshDailyCommentIfNeeded() {
    final today = _localDayKey();
    _scheduleDailyCommentRefresh();
    if (_activeCommentDay == today) return;
    setState(() {
      _commentFuture = null;
      _commentKey = '';
      _activeCommentDay = today;
    });
  }

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

  String _zodiacKey(DateTime date) {
    final m = date.month;
    final d = date.day;
    if ((m == 3 && d >= 21) || (m == 4 && d <= 19)) return 'aries';
    if ((m == 4 && d >= 20) || (m == 5 && d <= 20)) return 'taurus';
    if ((m == 5 && d >= 21) || (m == 6 && d <= 20)) return 'gemini';
    if ((m == 6 && d >= 21) || (m == 7 && d <= 22)) return 'cancer';
    if ((m == 7 && d >= 23) || (m == 8 && d <= 22)) return 'leo';
    if ((m == 8 && d >= 23) || (m == 9 && d <= 22)) return 'virgo';
    if ((m == 9 && d >= 23) || (m == 10 && d <= 22)) return 'libra';
    if ((m == 10 && d >= 23) || (m == 11 && d <= 21)) return 'scorpio';
    if ((m == 11 && d >= 22) || (m == 12 && d <= 21)) {
      return 'sagittarius';
    }
    if ((m == 12 && d >= 22) || (m == 1 && d <= 19)) return 'capricorn';
    if ((m == 1 && d >= 20) || (m == 2 && d <= 18)) return 'aquarius';
    return 'pisces';
  }

  Future<String> _dailyCommentFuture(String? storedBirthDate) {
    final key = (storedBirthDate ?? '').trim();
    final today = _localDayKey();
    final localeAwareKey = '$key|$today';
    if (_commentFuture == null || localeAwareKey != _commentKey) {
      _activeCommentDay = today;
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
        final birthDateText = birthDate != null
            ? _formatBirthDate(birthDate)
            : '—';
        final zodiacText = birthDate != null
            ? AppTexts.t('zodiac.${_zodiacKey(birthDate)}')
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
                      bodyText = AppTexts.t(
                        'home.birth_frequency.loading_comment',
                      );
                    } else {
                      final dynamicComment = (commentSnapshot.data ?? '')
                          .trim();
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
      (Icons.auto_awesome_rounded, AppTexts.t('home.tab.cosmic')),
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
              top: BorderSide(color: _kSecondary.withValues(alpha: 0.1)),
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
            left: 8,
            right: 8,
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
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        active
                            ? (i == 0 ? Icons.blur_circular_rounded : icon)
                            : icon,
                        size: 22,
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
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label.toUpperCase(),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 9,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                            color: iconColor,
                          ),
                        ),
                      ),
                    ],
                  ),
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
        actions: [
          ValueListenableBuilder<List<AppNotificationItem>>(
            valueListenable: NotificationService.instance.inbox,
            builder: (context, notifications, _) {
              if (notifications.isEmpty) return const SizedBox.shrink();
              final isTr = AppLocale.current == 'tr';
              return Tooltip(
                message: isTr ? 'Tum bildirimleri sil' : 'Clear notifications',
                child: IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) {
                        return AlertDialog(
                          backgroundColor: _kSurfaceContainerHigh,
                          title: Text(
                            isTr
                                ? 'Bildirimler silinsin mi?'
                                : 'Clear notifications?',
                            style: const TextStyle(color: _kOnSurface),
                          ),
                          content: Text(
                            isTr
                                ? 'Tum bildirim gecmisin bu ekrandan kaldirilacak.'
                                : 'All notification history will be removed from this screen.',
                            style: TextStyle(
                              color: _kSecondary.withValues(alpha: 0.9),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: Text(isTr ? 'Vazgec' : 'Cancel'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: Text(isTr ? 'Sil' : 'Delete'),
                            ),
                          ],
                        );
                      },
                    );
                    if (confirmed != true) return;
                    await NotificationService.instance.clearInbox();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            isTr
                                ? 'Bildirimler silindi'
                                : 'Notifications cleared',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ValueListenableBuilder<List<AppNotificationItem>>(
        valueListenable: NotificationService.instance.inbox,
        builder: (context, notifications, _) {
          final tarot = notifications
              .where((item) => item.category == 'tarot')
              .toList(growable: false);
          final coffee = notifications
              .where((item) => item.category == 'coffee')
              .toList(growable: false);
          final palm = notifications
              .where((item) => item.category == 'palm')
              .toList(growable: false);
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
              if (notifications.isNotEmpty) ...[
                _NotificationSection(
                  title: AppTexts.t('notificationsCategoryTarot'),
                  items: tarot,
                ),
                _NotificationSection(
                  title: AppTexts.t('notificationsCategoryCoffee'),
                  items: coffee,
                ),
                _NotificationSection(
                  title: AppTexts.t('notificationsCategoryPalm'),
                  items: palm,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _NotificationSection extends StatelessWidget {
  const _NotificationSection({required this.title, required this.items});

  final String title;
  final List<AppNotificationItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              letterSpacing: 1.2,
              color: _kTertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            _GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  AppTexts.t('notificationsEmpty'),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: _kSecondary.withValues(alpha: 0.76),
                  ),
                ),
              ),
            )
          else
            for (final item in items) ...[
              _NotificationListCard(item: item),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _NotificationListCard extends StatelessWidget {
  const _NotificationListCard({required this.item});

  final AppNotificationItem item;

  @override
  Widget build(BuildContext context) {
    final presentation = _NotificationPresentation.fromItem(item);
    final timestamp =
        '${item.receivedAt.day.toString().padLeft(2, '0')}.'
        '${item.receivedAt.month.toString().padLeft(2, '0')}.'
        '${item.receivedAt.year}  '
        '${item.receivedAt.hour.toString().padLeft(2, '0')}:'
        '${item.receivedAt.minute.toString().padLeft(2, '0')}';
    final deleteLabel = AppLocale.current == 'tr'
        ? 'Bildirimi sil'
        : 'Delete notification';

    Future<void> deleteItem() async {
      await NotificationService.instance.deleteNotification(item.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppLocale.current == 'tr'
                  ? 'Bildirim silindi'
                  : 'Notification deleted',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }

    return Dismissible(
      key: ValueKey(
        'notification_${item.id}_${item.receivedAt.microsecondsSinceEpoch}',
      ),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: _kPrimary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _kPrimary.withValues(alpha: 0.28)),
        ),
        child: Tooltip(
          message: deleteLabel,
          child: const Icon(Icons.delete_outline_rounded, color: _kPrimary),
        ),
      ),
      onDismissed: (_) => deleteItem(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => NotificationRouter.handleNotificationTap(item.toMap()),
        child: _GlassCard(
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
                        presentation.title,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          color: _kOnSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: deleteLabel,
                      child: IconButton(
                        onPressed: deleteItem,
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: _kSecondary.withValues(alpha: 0.85),
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  presentation.body,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    height: 1.45,
                    color: _kSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${presentation.sourceLabel}  •  $timestamp',
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
        ),
      ),
    );
  }
}

class _NotificationPresentation {
  const _NotificationPresentation({
    required this.title,
    required this.body,
    required this.sourceLabel,
  });

  final String title;
  final String body;
  final String sourceLabel;

  factory _NotificationPresentation.fromItem(AppNotificationItem item) {
    final lang = AppLocale.current;
    final type = _notificationType(item.type, item.source);
    final cleanTitle = _cleanNotificationText(item.title);
    final cleanBody = _cleanNotificationText(item.body);
    final extractedCard = _extractCardName(cleanBody);

    return _NotificationPresentation(
      title: _titleForType(type, lang, fallback: cleanTitle),
      body: _bodyForType(
        type,
        lang,
        fallback: cleanBody,
        cardName: extractedCard,
      ),
      sourceLabel: _sourceLabelForType(type, lang),
    );
  }

  static String _notificationType(String type, String source) {
    final normalizedType = type.toLowerCase();
    if (normalizedType != 'general' && normalizedType.isNotEmpty) {
      return normalizedType;
    }
    final normalized = source.toLowerCase();
    if (normalized.contains('arcana_chat')) return 'arcana_chat';
    if (normalized.contains('tarot_reminder')) return 'tarot_reminder';
    if (normalized.contains('daily_tarot') ||
        normalized.contains('daily_nudge')) {
      return 'daily_tarot';
    }
    return 'unknown';
  }

  static String _titleForType(
    String type,
    String lang, {
    required String fallback,
  }) {
    switch (type) {
      case 'daily_card':
      case 'daily_tarot':
        return lang == 'tr' ? 'Günün Kozmik Mesajı' : "Today's Cosmic Message";
      case 'tarot_reminder':
        return lang == 'tr' ? 'Kartın Seni Bekliyor' : 'Your Card Awaits';
      case 'arcana_chat':
        return lang == 'tr' ? 'Arcana Fısıldıyor...' : 'Arcana Whispers...';
      case 'coffee_followup':
        return fallback.isEmpty
            ? AppTexts.t('notificationsCategoryCoffee')
            : fallback;
      case 'palm_followup':
        return fallback.isEmpty
            ? AppTexts.t('notificationsCategoryPalm')
            : fallback;
      case 'wallet_low':
      case 'wallet_offer':
        return fallback.isEmpty ? AppTexts.t('shopTitle') : fallback;
      case 'reading_audio_ready':
        return fallback.isEmpty
            ? AppTexts.t('home.notifications.title')
            : fallback;
      case 'birth_chart_fallback':
        return fallback.isEmpty
            ? AppTexts.t('notificationsCategoryTarot')
            : fallback;
      default:
        return fallback.isEmpty
            ? (lang == 'tr' ? 'Bildirim' : 'Notification')
            : fallback;
    }
  }

  static String _bodyForType(
    String type,
    String lang, {
    required String fallback,
    String? cardName,
  }) {
    switch (type) {
      case 'daily_card':
      case 'daily_tarot':
        return lang == 'tr'
            ? 'Doğum haritandaki enerji bugün senin için şekillendi. Yorumun hazır!'
            : 'The energy in your birth chart has aligned for you today. Your reading is ready!';
      case 'tarot_reminder':
        return lang == 'tr'
            ? 'Günün potansiyelini henüz keşfetmedin, tarot kartını çekmeye ne dersin?'
            : "You haven't explored today's potential yet. Ready to draw your card?";
      case 'arcana_chat':
        final card = _localizedCardName(cardName ?? '', lang);
        if (card.isNotEmpty) {
          return lang == 'tr'
              ? 'Bugün çektiğin $card kartı hakkında derin bir sohbete hazır mısın?'
              : 'Are you ready for a deep conversation about the $card card you drew today?';
        }
        return fallback;
      default:
        return _localizedCardText(fallback, lang);
    }
  }

  static String _sourceLabelForType(String type, String lang) {
    switch (type) {
      case 'coffee_followup':
        return AppTexts.t('notificationsCategoryCoffee');
      case 'palm_followup':
        return AppTexts.t('notificationsCategoryPalm');
      case 'wallet_low':
      case 'wallet_offer':
        return AppTexts.t('shopTitle');
      case 'reading_audio_ready':
        return lang == 'tr' ? 'Sesli yorum' : 'Audio reading';
      case 'birth_chart_fallback':
        return lang == 'tr' ? 'Doğum frekansı' : 'Birth frequency';
      case 'daily_card':
      case 'daily_tarot':
        return lang == 'tr' ? 'Günlük mesaj' : 'Daily message';
      case 'tarot_reminder':
        return lang == 'tr' ? 'Kart hatırlatıcısı' : 'Card reminder';
      case 'arcana_chat':
        return lang == 'tr' ? 'Aris sohbeti' : 'Aris chat';
      default:
        return lang == 'tr' ? 'Bildirim' : 'Notification';
    }
  }

  static String _cleanNotificationText(String value) {
    return value
        .replaceAll('🌟', '')
        .replaceAll('🔮', '')
        .replaceAll('✨', '')
        .replaceAll('�', '')
        .trim();
  }

  static String? _extractCardName(String text) {
    for (final entry in _cardNames.entries) {
      if (text.contains(entry.key) || text.contains(entry.value)) {
        return entry.key;
      }
    }
    return null;
  }

  static String _localizedCardText(String text, String lang) {
    if (lang != 'tr') return text;
    var output = text;
    for (final entry in _cardNames.entries) {
      output = output.replaceAll(entry.key, entry.value);
    }
    return output;
  }

  static String _localizedCardName(String cardName, String lang) {
    if (cardName.isEmpty) return '';
    if (lang != 'tr') return cardName;
    return _cardNames[cardName] ?? cardName;
  }

  static const Map<String, String> _cardNames = <String, String>{
    'The Fool': 'Deli',
    'The Magician': 'Büyücü',
    'The High Priestess': 'Baş Rahibe',
    'The Empress': 'İmparatoriçe',
    'The Emperor': 'İmparator',
    'The Hierophant': 'Aziz',
    'The Lovers': 'Aşıklar',
    'The Chariot': 'Savaş Arabası',
    'Strength': 'Güç',
    'The Hermit': 'Ermiş',
    'The Wheel Of Fortune': 'Kader Çarkı',
    'Justice': 'Adalet',
    'The Hanged Man': 'Asılı Adam',
    'Death': 'Ölüm',
    'Temperance': 'Denge',
    'The Devil': 'Şeytan',
    'The Tower': 'Kule',
    'The Star': 'Yıldız',
    'The Moon': 'Ay',
    'The Sun': 'Güneş',
    'Judgement': 'Mahkeme',
    'The World': 'Dünya',
    'Ace Of Wands': 'Değnek Ası',
    'Two Of Wands': 'Değnek İkilisi',
    'Three Of Wands': 'Değnek Üçlüsü',
    'Four Of Wands': 'Değnek Dörtlüsü',
    'Five Of Wands': 'Değnek Beşlisi',
    'Six Of Wands': 'Değnek Altılısı',
    'Seven Of Wands': 'Değnek Yedilisi',
    'Eight Of Wands': 'Değnek Sekizlisi',
    'Nine Of Wands': 'Değnek Dokuzlusu',
    'Ten Of Wands': 'Değnek Onlusu',
    'Page Of Wands': 'Değnek Prensi',
    'Knight Of Wands': 'Değnek Şövalyesi',
    'Queen Of Wands': 'Değnek Kraliçesi',
    'King Of Wands': 'Değnek Kralı',
    'Ace Of Cups': 'Kupa Ası',
    'Two Of Cups': 'Kupa İkilisi',
    'Three Of Cups': 'Kupa Üçlüsü',
    'Four Of Cups': 'Kupa Dörtlüsü',
    'Five Of Cups': 'Kupa Beşlisi',
    'Six Of Cups': 'Kupa Altılısı',
    'Seven Of Cups': 'Kupa Yedilisi',
    'Eight Of Cups': 'Kupa Sekizlisi',
    'Nine Of Cups': 'Kupa Dokuzlusu',
    'Ten Of Cups': 'Kupa Onlusu',
    'Page Of Cups': 'Kupa Prensi',
    'Knight Of Cups': 'Kupa Şövalyesi',
    'Queen Of Cups': 'Kupa Kraliçesi',
    'King Of Cups': 'Kupa Kralı',
    'Ace Of Swords': 'Kılıç Ası',
    'Two Of Swords': 'Kılıç İkilisi',
    'Three Of Swords': 'Kılıç Üçlüsü',
    'Four Of Swords': 'Kılıç Dörtlüsü',
    'Five Of Swords': 'Kılıç Beşlisi',
    'Six Of Swords': 'Kılıç Altılısı',
    'Seven Of Swords': 'Kılıç Yedilisi',
    'Eight Of Swords': 'Kılıç Sekizlisi',
    'Nine Of Swords': 'Kılıç Dokuzlusu',
    'Ten Of Swords': 'Kılıç Onlusu',
    'Page Of Swords': 'Kılıç Prensi',
    'Knight Of Swords': 'Kılıç Şövalyesi',
    'Queen Of Swords': 'Kılıç Kraliçesi',
    'King Of Swords': 'Kılıç Kralı',
    'Ace Of Pentacles': 'Tılsım Ası',
    'Two Of Pentacles': 'Tılsım İkilisi',
    'Three Of Pentacles': 'Tılsım Üçlüsü',
    'Four Of Pentacles': 'Tılsım Dörtlüsü',
    'Five Of Pentacles': 'Tılsım Beşlisi',
    'Six Of Pentacles': 'Tılsım Altılısı',
    'Seven Of Pentacles': 'Tılsım Yedilisi',
    'Eight Of Pentacles': 'Tılsım Sekizlisi',
    'Nine Of Pentacles': 'Tılsım Dokuzlusu',
    'Ten Of Pentacles': 'Tılsım Onlusu',
    'Page Of Pentacles': 'Tılsım Prensi',
    'Knight Of Pentacles': 'Tılsım Şövalyesi',
    'Queen Of Pentacles': 'Tılsım Kraliçesi',
    'King Of Pentacles': 'Tılsım Kralı',
  };
}

// ═════════════════════════════════════════════════════════════════
// GLASS CARD (shared)
// ═════════════════════════════════════════════════════════════════
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.borderRadius = 24});

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
