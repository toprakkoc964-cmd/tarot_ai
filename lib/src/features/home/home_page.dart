import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_page.dart';
import 'cosmic_page.dart';
import 'credit_page.dart';
import 'messages_page.dart';
import 'home_palette.dart';
import 'profile_page.dart';
import '../auth/auth_service.dart';
import '../auth/user_profile_contract.dart';
import '../../core/app_locale.dart';
import '../../core/notification_service.dart';
import '../../core/app_texts.dart';
import '../../core/frequency_service.dart';
import '../../core/tarot_functions_client.dart';
import '../../core/widgets/cosmic_permission_dialog.dart';
import '../readings/tarot_service.dart';
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
    try {
      await local_notifications.NotificationService.instance
          .scheduleMorningNotifications();
      await local_notifications.NotificationService.instance
          .scheduleMiddayReminders();
    } catch (e, st) {
      debugPrint('Notification queue scheduling skipped: $e');
      debugPrintStack(stackTrace: st);
    }
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
    await local_notifications.NotificationService.instance
        .syncDeliveredScheduledNotificationsToInbox();
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
      if (i >= 0 && i <= 4) {
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
    final isMessagesPage = _navIndex == 1;
    final isCosmicPage = _navIndex == 2;
    final isCreditPage = _navIndex == 3;
    final isProfilePage = _navIndex == 4;
    final topBarHeight = _TopBar.estimatedHeight(context);
    final bottomBarHeight = _BottomNavBar.estimatedHeight(context);

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // ── Nebula background ──
          if (!isMessagesPage && !isCosmicPage && !isCreditPage && !isProfilePage)
            const _NebulaBackground(),
          if (isMessagesPage)
            MessagesPage(
              uid: widget.uid,
              bottomInset: bottomBarHeight,
            ),
          if (isCosmicPage)
            CosmicPage(
              bottomInset: bottomBarHeight,
              uid: widget.uid,
            ),
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
          if (!isMessagesPage &&
              !isCosmicPage &&
              !isCreditPage &&
              !isProfilePage)
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
          if (!isMessagesPage &&
              !isCosmicPage &&
              !isCreditPage &&
              !isProfilePage)
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
  static const _deckCardWidth = 224.0;
  static const _deckCardHeight = 348.0;
  static const _maxSpreadCards = 7;
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
    viewportFraction: 0.68,
    initialPage: _initialLoopPage,
  );
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
  late final DocumentReference<Map<String, dynamic>> _userDoc =
      FirebaseFirestore.instance
          .collection(UserProfileContract.usersCollection)
          .doc(widget.uid);
  DrawnTarotCard? _drawnCard;
  final List<DrawnTarotCard> _selectedCards = [];
  final Set<int> _pickedCardIndices = {};
  bool _awaitingSpreadAction = false;
  int _deckSpinGeneration = 0;
  static const int _deckSpinMsPerPageNormal = 380;
  static const int _deckSpinMsPerPageFast = 115;

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
    if (_awaitingSpreadAction) {
      return AppTexts.t('tarot.spread.continue_cta');
    }
    if (_selectionLocked || _isLoadingCard || _isDrawRequestInFlight) {
      return AppTexts.t('tarot.spread.revealing');
    }
    if (isLoading) return AppTexts.t('common.loading');
    if (credits >= _kPaidDrawCost) {
      return '5 JETONLA CEK';
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

  String _displayNameForIndex(int index) {
    final safeIndex = (index >= 0 && index < _cardNames.length)
        ? index
        : math.Random().nextInt(_cardNames.length);
    return TarotService.majorArcana[safeIndex].displayName;
  }

  int _cardIndexForLoopPage(int loopPage) {
    final normalized = (loopPage + _deckOffset) % _cardNames.length;
    return normalized < 0 ? normalized + _cardNames.length : normalized;
  }

  DrawnTarotCard _localCardForIndex(int index) {
    return DrawnTarotCard(
      card: TarotService.majorArcana[index],
      imageUrl: '',
    );
  }

  String _spreadSessionId(List<String> cardNames) {
    final slug = cardNames
        .map((name) => name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'))
        .join('_');
    final day = DateTime.now().toIso8601String().split('T').first;
    final raw = '${day}_$slug';
    return raw.length <= 48 ? raw : raw.substring(0, 48);
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
      _isLoadingCard = false;
      _selectedCards.clear();
      _pickedCardIndices.clear();
      _awaitingSpreadAction = false;
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
      !_awaitingSpreadAction;

  void _stopDeckSpin() {
    _deckSpinGeneration++;
  }

  Future<void> _startDeckSpin({required bool fast}) async {
    _stopDeckSpin();
    final generation = _deckSpinGeneration;
    final msPerPage =
        fast ? _deckSpinMsPerPageFast : _deckSpinMsPerPageNormal;

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
    final pageDelta = (targetPage - _currentLoopPage).abs();
    final pages = pageDelta < 1 ? 1 : pageDelta;
    await _pageController.animateToPage(
      targetPage,
      duration: Duration(
        milliseconds: pages * _deckSpinMsPerPageNormal,
      ),
      curve: Curves.linear,
    );
  }

  Future<void> _startRitual({required bool canDraw}) async {
    if (_isDrawing ||
        _isDrawRequestInFlight ||
        _selectionLocked ||
        _awaitingSpreadAction) {
      return;
    }
    if (!canDraw) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppTexts.t('home.cta.insufficient_credits_message')),
        ),
      );
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
      _awaitingSpreadAction = false;
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
      final consumed = await _consumeDrawRight();
      if (!consumed) {
        if (!mounted) return;
        await _resetSelection();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppTexts.t('home.cta.insufficient_credits_message')),
          ),
        );
        return;
      }
    } finally {
      if (mounted) {
        setState(() => _isDrawRequestInFlight = false);
      }
    }
  }

  Future<void> _handleDeckRevealTap() async {
    if (_awaitingSpreadAction ||
        _selectionLocked ||
        _isDrawRequestInFlight ||
        _isLoadingCard) {
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

    try {
      setState(() {
        _selectionLocked = true;
        _selectedCardIndex = cardIndex;
        _isLoadingCard = true;
      });

      await _landOnCardPage(targetPage);
      if (!mounted) return;

      setState(() => _currentLoopPage = targetPage);
      final selectedCard = _localCardForIndex(cardIndex);
      setState(() {
        _drawnCard = selectedCard;
        _isLoadingCard = false;
      });
      await _flipController.forward(from: 0);
      if (!mounted) return;

      setState(() {
        _selectedCards.add(selectedCard);
        _pickedCardIndices.add(cardIndex);
        _awaitingSpreadAction = true;
      });

      if (_selectedCards.length == 1) {
        final homePageState = context.findAncestorStateOfType<_HomePageState>();
        final languageCode = _resolveDeviceLanguageCode();
        await local_notifications.NotificationService.instance.onDailyCardDrawn(
          selectedCard.card.displayName,
          languageCode,
        );
        await homePageState?._maybePromptNotificationPermission();
      }
    } catch (error) {
      debugPrint('Tarot ritual draw failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTexts.t('tarot.spread.load_failed'))),
      );
      await _resetSelection();
    } finally {
      if (mounted) {
        setState(() => _isLoadingCard = false);
      }
    }
  }

  Future<void> _pickAnotherCard() async {
    if (!_awaitingSpreadAction || _selectedCards.length >= _maxSpreadCards) {
      return;
    }
    _flipController.reset();
    setState(() {
      _awaitingSpreadAction = false;
      _selectionLocked = false;
      _selectedCardIndex = null;
      _drawnCard = null;
      _isLoadingCard = false;
      _isDrawing = true;
      _isDeckVisible = true;
    });

    if (!_pageController.hasClients) return;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted || _awaitingSpreadAction || _selectionLocked) return;
    unawaited(_startDeckSpin(fast: true));
  }

  Future<void> _openSpreadReading() async {
    if (_selectedCards.isEmpty) return;
    final cardNames =
        _selectedCards.map((card) => card.card.displayName).toList(growable: false);
    final sessionId = _spreadSessionId(cardNames);
    final chatResult = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => KozmikBilgePage(
          uid: widget.uid,
          spreadCards: List<DrawnTarotCard>.unmodifiable(_selectedCards),
          spreadSessionId: sessionId,
        ),
      ),
    );
    if (!mounted) return;
    if (chatResult == 'credits') {
      context.findAncestorStateOfType<_HomePageState>()?._onNavTap(3);
    }
    await _resetSelection();
  }

  @override
  void dispose() {
    _stopDeckSpin();
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
        final selectedIndex =
            _selectedCardIndex ?? _cardIndexForLoopPage(_currentLoopPage);
        final headline = _awaitingSpreadAction
            ? AppTexts.t('tarot.spread.headline')
            : (_selectionLocked
                ? _displayNameForIndex(selectedIndex)
                : 'Gunun Rehberi');
        final subtitle = _awaitingSpreadAction
            ? AppTexts.t('tarot.spread.selection_hint')
                .replaceAll('{count}', '${_selectedCards.length}')
                .replaceAll('{max}', '$_maxSpreadCards')
            : (_isDrawing && _isDeckVisible
                ? AppTexts.t('tarot.spread.tap_to_draw')
                : '');
        final canTapDeck = _isDrawing &&
            _isDeckVisible &&
            !_selectionLocked &&
            !_isLoadingCard &&
            !_awaitingSpreadAction;
        final ritualStageHeight = _isDrawing
            ? (_awaitingSpreadAction ? 430.0 : 470.0)
            : 316.0;
        final canPickAnother =
            _awaitingSpreadAction && _selectedCards.length < _maxSpreadCards;

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
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 360),
                                curve: Curves.easeOutCubic,
                                opacity: _isDrawing ? 1 : 0,
                                child: _RitualStarBands(
                                  animation: _ritualAuraController,
                                ),
                              ),
                            ),
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
                                      duration:
                                          const Duration(milliseconds: 280),
                                      opacity: (_selectionLocked ||
                                              _awaitingSpreadAction)
                                          ? 0.16
                                          : 1,
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
                                                  cardCount: _cardNames.length,
                                                  cardWidth: _deckCardWidth,
                                                  cardHeight: _deckCardHeight,
                                                  displayNameForIndex:
                                                      _displayNameForIndex,
                                                  cardIndexForLoopPage:
                                                      _cardIndexForLoopPage,
                                                  onPageChanged: (loopPage) {
                                                    _currentLoopPage =
                                                        loopPage;
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

                    if (_selectedCards.isNotEmpty) ...[
                      _SelectedSpreadStrip(cards: _selectedCards),
                      const SizedBox(height: 14),
                    ],

                    if (_awaitingSpreadAction) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  canPickAnother ? _pickAnotherCard : null,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _kSecondary,
                                side: BorderSide(
                                  color: _kPrimary.withValues(alpha: 0.35),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 14,
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  AppTexts.t('tarot.spread.pick_another_short'),
                                  maxLines: 1,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: _HeroCtaButton(
                              canDraw: true,
                              ctaText: AppTexts.t('tarot.spread.continue_cta'),
                              onPressed: _openSpreadReading,
                            ),
                          ),
                        ],
                      ),
                    ] else
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        opacity: _isDrawing ? 0 : 1,
                        child: IgnorePointer(
                          ignoring: _isDrawing,
                          child: _HeroCtaButton(
                            canDraw: canDraw,
                            ctaText: ctaText,
                            onPressed: () => _startRitual(canDraw: canDraw),
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
          return Container(
            width: 92,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _kSurfaceContainerHigh,
              border: Border.all(color: _kPrimary.withValues(alpha: 0.35)),
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
          );
        },
      ),
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

class _FocusDeckCarousel extends StatelessWidget {
  const _FocusDeckCarousel({
    required this.controller,
    required this.cardCount,
    required this.cardWidth,
    required this.cardHeight,
    required this.displayNameForIndex,
    required this.cardIndexForLoopPage,
    required this.onPageChanged,
  });

  final PageController controller;
  final int cardCount;
  final double cardWidth;
  final double cardHeight;
  final String Function(int index) displayNameForIndex;
  final int Function(int loopPage) cardIndexForLoopPage;
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
          final cardIndex = cardIndexForLoopPage(loopPage);
          return Center(
            child: _GuideCardBack(
              cardName: displayNameForIndex(cardIndex),
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

class _RitualStarBands extends StatelessWidget {
  const _RitualStarBands({
    required this.animation,
  });

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RitualStarBandPainter(animation: animation),
    );
  }
}

class _RitualStarBandPainter extends CustomPainter {
  _RitualStarBandPainter({required this.animation}) : super(repaint: animation);

  final Animation<double> animation;

  static const _seeds = <_StarSeed>[
    _StarSeed(0.06, 0.02, 0.72, 0.76, 0.92),
    _StarSeed(0.19, 0.24, 0.88, 0.62, 0.74),
    _StarSeed(0.33, 0.49, 1.02, 0.82, 1.08),
    _StarSeed(0.47, 0.15, 0.78, 0.68, 0.84),
    _StarSeed(0.61, 0.67, 0.94, 0.76, 1.0),
    _StarSeed(0.74, 0.36, 0.86, 0.58, 0.72),
    _StarSeed(0.88, 0.81, 1.08, 0.78, 1.06),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final seed in _seeds) {
      _paintStar(canvas, size, seed, topBand: true);
      _paintStar(canvas, size, seed.shifted(), topBand: false);
    }
  }

  void _paintStar(
    Canvas canvas,
    Size size,
    _StarSeed seed, {
    required bool topBand,
  }) {
    final progress = (animation.value * seed.speed + seed.phase) % 1;
    final x = topBand
        ? -24 + ((size.width + 48) * progress)
        : size.width + 24 - ((size.width + 48) * progress);
    final y = topBand
        ? 26 + (math.sin((progress + seed.x) * math.pi * 2) * 8)
        : size.height - 26 + (math.sin((progress + seed.x) * math.pi * 2) * 8);
    final pulse = 0.62 + (math.sin((progress + seed.phase) * math.pi) * 0.22);
    final radius = 4 + (seed.scale * 5);

    final paint = Paint()
      ..color = _kPrimaryContainer.withValues(alpha: seed.opacity * pulse)
      ..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..color = _kPrimary.withValues(alpha: seed.opacity * pulse * 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(Offset(x, y), radius * 1.8, glowPaint);

    final path = Path()
      ..moveTo(x, y - radius)
      ..lineTo(x + radius * 0.34, y - radius * 0.34)
      ..lineTo(x + radius, y)
      ..lineTo(x + radius * 0.34, y + radius * 0.34)
      ..lineTo(x, y + radius)
      ..lineTo(x - radius * 0.34, y + radius * 0.34)
      ..lineTo(x - radius, y)
      ..lineTo(x - radius * 0.34, y - radius * 0.34)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RitualStarBandPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}

class _StarSeed {
  const _StarSeed(this.x, this.phase, this.speed, this.opacity,
      [this.scale = 1]);

  final double x;
  final double phase;
  final double speed;
  final double opacity;
  final double scale;

  _StarSeed shifted() {
    return _StarSeed(
      (x + 0.06) % 1,
      (phase + 0.36) % 1,
      speed * 0.88,
      opacity * 0.92,
      scale * 0.9,
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
    this.expanded = false,
  });

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
            cardName: 'Gunun Rehberi',
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
            child: isLoading
                ? Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: _kSurfaceContainerHigh,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: _kTertiary),
                    ),
                  )
                : _GuideCardBack(
                    cardName: title,
                    width: 210,
                    height: 320,
                    margin: EdgeInsets.zero,
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
    final today = _localDayKey();
    final localeAwareKey = '$key|${AppLocale.current}|$today';
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
      (Icons.forum_outlined, AppTexts.t('home.tab.messages')),
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
    final presentation = _NotificationPresentation.fromItem(item);
    final timestamp = '${item.receivedAt.day.toString().padLeft(2, '0')}.'
        '${item.receivedAt.month.toString().padLeft(2, '0')}.'
        '${item.receivedAt.year}  '
        '${item.receivedAt.hour.toString().padLeft(2, '0')}:'
        '${item.receivedAt.minute.toString().padLeft(2, '0')}';
    final deleteLabel =
        AppLocale.current == 'tr' ? 'Bildirimi sil' : 'Delete notification';

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
          'notification_${item.id}_${item.receivedAt.microsecondsSinceEpoch}'),
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
          child: const Icon(
            Icons.delete_outline_rounded,
            color: _kPrimary,
          ),
        ),
      ),
      onDismissed: (_) => deleteItem(),
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
    final type = _notificationType(item.source);
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

  static String _notificationType(String source) {
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
      case 'daily_tarot':
        return lang == 'tr' ? 'Günün Kozmik Mesajı' : "Today's Cosmic Message";
      case 'tarot_reminder':
        return lang == 'tr' ? 'Kartın Seni Bekliyor' : 'Your Card Awaits';
      case 'arcana_chat':
        return lang == 'tr' ? 'Arcana Fısıldıyor...' : 'Arcana Whispers...';
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
  };
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
