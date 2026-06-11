import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_locale.dart';
import '../../../core/app_texts.dart';
import '../../../core/theme/app_colors.dart';
import '../models/shop_item_view_model.dart';
import '../models/shop_product_catalog.dart';
import '../models/shop_product_config.dart';
import '../services/entitlement_service.dart';
import '../services/purchase_service.dart';
import '../services/shop_config_service.dart';
import '../widgets/cosmic_benefits_row.dart';
import '../widgets/credit_pack_card.dart';
import '../widgets/premium_card.dart';
import '../widgets/restore_purchases_button.dart';
import '../widgets/shop_footer_links.dart';

class CosmicWalletScreen extends StatefulWidget {
  const CosmicWalletScreen({
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
  State<CosmicWalletScreen> createState() => _CosmicWalletScreenState();
}

class _CosmicWalletScreenState extends State<CosmicWalletScreen> {
  final ScrollController _scrollController = ScrollController();
  static const Set<String> _localeReloadSuppressedMessages = <String>{
    'shopPurchaseUnavailable',
    'shopProductsNotFoundHint',
    'shopPriceUnavailable',
  };
  late Future<ShopConfig> _configFuture;
  late final PurchaseService _purchaseService;
  late final ShopConfigService _shopConfigService;
  late final EntitlementService _entitlementService;
  PurchaseServicePhase? _lastNotifiedPhase;
  String? _expandedCreditProductId;
  bool _hasTouchedCreditExpansion = false;
  bool _premiumExpanded = false;
  bool _suppressLocaleReloadMessage = false;

  @override
  void initState() {
    super.initState();
    _purchaseService = GetIt.instance<PurchaseService>();
    _shopConfigService = GetIt.instance<ShopConfigService>();
    _entitlementService = GetIt.instance<EntitlementService>();
    _configFuture = _loadShopConfig();
    _purchaseService.addListener(_handlePurchaseStateChanged);
    AppLocale.notifier.addListener(_reloadForLocale);
  }

  Future<ShopConfig> _loadShopConfig() async {
    final cachedConfig = _shopConfigService.cachedConfig;
    if (cachedConfig != null) {
      unawaited(_loadProductsForConfig(cachedConfig));
      return cachedConfig;
    }

    final config = await _shopConfigService.fetchConfig();
    if (!mounted) return config;
    await _loadProductsForConfig(config);
    return config;
  }

  Future<void> _loadProductsForConfig(ShopConfig config) {
    return _purchaseService.loadProducts(
      productIds: ShopProductCatalog.productIdsFromConfig(config),
    );
  }

  @override
  void dispose() {
    _purchaseService.removeListener(_handlePurchaseStateChanged);
    AppLocale.notifier.removeListener(_reloadForLocale);
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleCreditCard(
    String productId,
    bool wasExpanded,
    BuildContext cardContext,
  ) {
    setState(() {
      _hasTouchedCreditExpansion = true;
      _expandedCreditProductId = wasExpanded ? null : productId;
      if (!wasExpanded) {
        _premiumExpanded = false;
      }
    });

    if (!wasExpanded) {
      _scrollExpandedCardIntoView(cardContext);
    }
  }

  void _togglePremiumCard(BuildContext cardContext) {
    final shouldOpen = !_premiumExpanded;
    setState(() {
      _premiumExpanded = shouldOpen;
      if (shouldOpen) {
        _hasTouchedCreditExpansion = true;
        _expandedCreditProductId = null;
      }
    });

    if (shouldOpen) {
      _scrollExpandedCardIntoView(cardContext);
    }
  }

  void _scrollExpandedCardIntoView(BuildContext cardContext) {
    Future<void> scroll() async {
      if (!mounted || !cardContext.mounted) return;
      if (_isCardMostlyVisible(cardContext)) return;

      final renderObject = cardContext.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;

      final media = MediaQuery.of(context);
      final topSafe = media.padding.top + 96;
      final bottomSafe = media.size.height - widget.bottomInset - 118;
      final safeHeight = bottomSafe - topSafe;
      if (safeHeight <= 0) return;

      final cardTop = renderObject.localToGlobal(Offset.zero).dy;
      final cardHeight = renderObject.size.height;
      final desiredTop = cardHeight <= safeHeight
          ? topSafe + (safeHeight - cardHeight) / 2
          : topSafe + 8;
      final targetOffset = (_scrollController.offset + cardTop - desiredTop)
          .clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          );

      if ((targetOffset - _scrollController.offset).abs() < 8) return;
      await _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 140), scroll);
      Future<void>.delayed(const Duration(milliseconds: 340), scroll);
    });
  }

  bool _isCardMostlyVisible(BuildContext cardContext) {
    final renderObject = cardContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final media = MediaQuery.of(context);
    final topSafe = media.padding.top + 86;
    final bottomSafe = media.size.height - widget.bottomInset - 132;
    final cardTop = topLeft.dy;
    final cardBottom = cardTop + size.height;

    return cardTop >= topSafe && cardBottom <= bottomSafe;
  }

  void _reloadForLocale() {
    if (!mounted) return;
    _suppressLocaleReloadMessage = true;
    _lastNotifiedPhase = null;
    setState(() {
      _shopConfigService.invalidate();
      _configFuture = _loadShopConfig();
    });
  }

  void _handlePurchaseStateChanged() {
    final current = _purchaseService.state.value;
    if (!mounted || current.phase == _lastNotifiedPhase) return;
    _lastNotifiedPhase = current.phase;

    final messageKey = current.messageKey;
    if (_suppressLocaleReloadMessage &&
        current.phase != PurchaseServicePhase.loadingProducts) {
      if (messageKey == null ||
          messageKey.isEmpty ||
          _localeReloadSuppressedMessages.contains(messageKey)) {
        _suppressLocaleReloadMessage = false;
        if (messageKey != null &&
            messageKey.isNotEmpty &&
            _localeReloadSuppressedMessages.contains(messageKey)) {
          return;
        }
      }
    }
    if (messageKey == null || messageKey.isEmpty) return;
    if (current.phase == PurchaseServicePhase.loadingProducts ||
        current.phase == PurchaseServicePhase.purchasing) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppTexts.t(messageKey)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _WalletBackground(),
        FutureBuilder<ShopConfig>(
          future: _configFuture,
          builder: (context, snapshot) {
            final config = snapshot.data ?? _shopConfigService.cachedConfig;
            return ListView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                20,
                CosmicWalletScreen.topBarHeight(context) + 8,
                20,
                widget.bottomInset + 28,
              ),
              children: [
                if (snapshot.connectionState != ConnectionState.done &&
                    config == null)
                  const _WalletSkeleton()
                else if (config == null)
                  _ErrorPanel(message: AppTexts.t('error.default'))
                else
                  ValueListenableBuilder<PurchaseServiceState>(
                    valueListenable: _purchaseService.state,
                    builder: (context, purchaseState, _) {
                      return _WalletContent(
                        config: config,
                        purchaseService: _purchaseService,
                        shopConfigService: _shopConfigService,
                        purchaseState: purchaseState,
                        expandedCreditProductId: _expandedCreditProductId,
                        hasTouchedCreditExpansion: _hasTouchedCreditExpansion,
                        onCreditExpandedChanged: _toggleCreditCard,
                        premiumExpanded: _premiumExpanded,
                        onPremiumToggle: _togglePremiumCard,
                      );
                    },
                  ),
              ],
            );
          },
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _WalletTopBar(
            uid: widget.uid,
            entitlementService: _entitlementService,
          ),
        ),
      ],
    );
  }
}

class _WalletContent extends StatelessWidget {
  const _WalletContent({
    required this.config,
    required this.purchaseService,
    required this.shopConfigService,
    required this.purchaseState,
    required this.expandedCreditProductId,
    required this.hasTouchedCreditExpansion,
    required this.onCreditExpandedChanged,
    required this.premiumExpanded,
    required this.onPremiumToggle,
  });

  final ShopConfig config;
  final PurchaseService purchaseService;
  final ShopConfigService shopConfigService;
  final PurchaseServiceState purchaseState;
  final String? expandedCreditProductId;
  final bool hasTouchedCreditExpansion;
  final void Function(
    String productId,
    bool wasExpanded,
    BuildContext cardContext,
  )
  onCreditExpandedChanged;
  final bool premiumExpanded;
  final void Function(BuildContext cardContext) onPremiumToggle;

  @override
  Widget build(BuildContext context) {
    final creditItems = config.creditProducts
        .where((item) => item.isActive)
        .map(
          (config) => ShopItemViewModel.fromConfig(
            config: config,
            productDetails: purchaseState.products[config.productId],
            storeAvailable: purchaseState.storeAvailable,
            isBusy: purchaseState.isBusy,
            isNotFound: purchaseState.notFoundIds.contains(config.productId),
            allProductsMissing: purchaseState.allQueriedProductsMissing,
          ),
        )
        .toList();
    String? defaultExpandedId;
    for (final item in creditItems) {
      if (item.isHighlighted) {
        defaultExpandedId = item.productId;
        break;
      }
    }
    final activeExpandedId = !hasTouchedCreditExpansion
        ? defaultExpandedId ??
              (creditItems.isEmpty ? null : creditItems.first.productId)
        : expandedCreditProductId;
    final configs = config.premiumProducts.where((item) => item.isActive);
    final premiumItem = configs.isEmpty
        ? null
        : ShopItemViewModel.fromConfig(
            config: configs.first,
            productDetails: purchaseState.products[configs.first.productId],
            storeAvailable: purchaseState.storeAvailable,
            isBusy: purchaseState.isBusy,
            isNotFound: purchaseState.notFoundIds.contains(
              configs.first.productId,
            ),
            allProductsMissing: purchaseState.allQueriedProductsMissing,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WalletHeroTitle(),
        const SizedBox(height: 26),
        CosmicBenefitsRow(),
        const SizedBox(height: 18),
        for (final item in creditItems) ...[
          Builder(
            builder: (cardContext) {
              final isExpanded = activeExpandedId == item.productId;
              return CreditPackCard(
                item: item,
                isBusy:
                    purchaseState.activeProductId == item.productId &&
                    purchaseState.isBusy,
                isExpanded: isExpanded,
                onToggle: () => onCreditExpandedChanged(
                  item.productId,
                  isExpanded,
                  cardContext,
                ),
                onBuy: () => purchaseService.buyProduct(item.productId),
              );
            },
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 2),
        _InfoStrip(text: AppTexts.t('creditsConsumableInfo')),
        const SizedBox(height: 20),
        if (premiumItem == null)
          _ErrorPanel(message: AppTexts.t('shopPriceUnavailable'))
        else
          Builder(
            builder: (premiumContext) {
              return PremiumCard(
                item: premiumItem,
                isBusy:
                    purchaseState.activeProductId == premiumItem.productId &&
                    purchaseState.isBusy,
                isExpanded: premiumExpanded,
                onToggle: () => onPremiumToggle(premiumContext),
                onBuy: () => purchaseService.buyProduct(premiumItem.productId),
              );
            },
          ),
        const SizedBox(height: 14),
        RestorePurchasesButton(
          isRestoring: purchaseState.phase == PurchaseServicePhase.restoring,
          onPressed: purchaseService.restorePurchases,
        ),
        const SizedBox(height: 12),
        _InfoStrip(text: AppTexts.t('home.credit.legal_disclaimer')),
        const SizedBox(height: 12),
        ShopFooterLinks(
          termsUrl: shopConfigService.legalTermsUrl(config),
          privacyUrl: shopConfigService.legalPrivacyUrl(config),
          onError: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppTexts.t('shopLinkOpenFailed')),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _WalletHeroTitle extends StatelessWidget {
  const _WalletHeroTitle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          AppTexts.t('shopTitle'),
          textAlign: TextAlign.center,
          maxLines: 1,
          style: GoogleFonts.newsreader(
            color: AppColors.primaryPink,
            fontSize: 56,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            shadows: [
              Shadow(
                color: AppColors.primaryPink.withValues(alpha: 0.45),
                blurRadius: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletTopBar extends StatelessWidget {
  const _WalletTopBar({required this.uid, required this.entitlementService});

  final String uid;
  final EntitlementService entitlementService;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: top + 84,
          padding: EdgeInsets.fromLTRB(20, top + 14, 20, 12),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.82),
            border: Border(
              bottom: BorderSide(
                color: AppColors.glassBorder.withValues(alpha: 0.68),
              ),
            ),
          ),
          child: StreamBuilder(
            stream: entitlementService.watchUserEntitlements(uid),
            initialData: entitlementService.cachedUserEntitlements(uid),
            builder: (context, snapshot) {
              final balance = snapshot.data?.creditBalance;
              final premiumActive = snapshot.data?.premium.active == true;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _TokenPill(balance: balance),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: premiumActive
                        ? _PremiumPill(text: AppTexts.t('premiumMonthlyTitle'))
                        : const SizedBox(width: 86),
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

class _TokenPill extends StatelessWidget {
  const _TokenPill({required this.balance});

  final int? balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primaryPink.withValues(alpha: 0.24),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPink.withValues(alpha: 0.18),
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
            color: AppColors.tertiaryGold,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            '${balance?.toString() ?? '...'} ${AppTexts.t('home.top.token_unit')}',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.tertiaryGold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumPill extends StatelessWidget {
  const _PremiumPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryPink.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primaryPink.withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: AppColors.primaryPink,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.primaryPink,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          color: AppColors.secondaryLavender.withValues(alpha: 0.78),
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _InfoStrip(text: message);
  }
}

class _WalletSkeleton extends StatefulWidget {
  const _WalletSkeleton();

  @override
  State<_WalletSkeleton> createState() => _WalletSkeletonState();
}

class _WalletSkeletonState extends State<_WalletSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1350),
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
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: _SkeletonBlock(
                width: 260,
                height: 52,
                radius: 18,
                progress: _controller.value,
              ),
            ),
            const SizedBox(height: 28),
            _SkeletonBlock(
              width: 184,
              height: 24,
              radius: 8,
              progress: _controller.value,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 192,
              child: Row(
                children: [
                  _SkeletonBlock(
                    width: 180,
                    height: 180,
                    radius: 24,
                    progress: _controller.value,
                  ),
                  const SizedBox(width: 14),
                  _SkeletonBlock(
                    width: 180,
                    height: 180,
                    radius: 24,
                    progress: _controller.value,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SkeletonBlock(
              width: double.infinity,
              height: 136,
              radius: 24,
              progress: _controller.value,
            ),
            const SizedBox(height: 14),
            _SkeletonBlock(
              width: double.infinity,
              height: 230,
              radius: 28,
              progress: _controller.value,
            ),
            const SizedBox(height: 14),
            _SkeletonBlock(
              width: double.infinity,
              height: 136,
              radius: 24,
              progress: _controller.value,
            ),
          ],
        );
      },
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    required this.radius,
    required this.progress,
  });

  final double width;
  final double height;
  final double radius;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.glassBg,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shimmerWidth = constraints.maxWidth * 0.72;
            final travel = constraints.maxWidth + shimmerWidth;
            final left = travel * progress - shimmerWidth;
            return Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.surfaceHigh.withValues(alpha: 0.24),
                          AppColors.primaryPink.withValues(alpha: 0.08),
                          AppColors.surfaceHigh.withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: left,
                  top: 0,
                  bottom: 0,
                  width: shimmerWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppColors.primaryPink.withValues(alpha: 0.16),
                          AppColors.tertiaryGold.withValues(alpha: 0.10),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WalletBackground extends StatelessWidget {
  const _WalletBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background,
            AppColors.cosmicGradientTop,
            AppColors.background,
          ],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}
