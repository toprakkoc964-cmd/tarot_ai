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

class _CosmicWalletScreenState extends State<CosmicWalletScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<ShopConfig> _configFuture;
  late final PurchaseService _purchaseService;
  late final ShopConfigService _shopConfigService;
  late final EntitlementService _entitlementService;
  PurchaseServicePhase? _lastNotifiedPhase;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _purchaseService = GetIt.instance<PurchaseService>();
    _shopConfigService = GetIt.instance<ShopConfigService>();
    _entitlementService = GetIt.instance<EntitlementService>();
    _configFuture = _loadShopConfig();
    _purchaseService.addListener(_handlePurchaseStateChanged);
    AppLocale.notifier.addListener(_reloadForLocale);
  }

  Future<ShopConfig> _loadShopConfig() async {
    final config = await _shopConfigService.fetchConfig();
    if (!mounted) return config;
    await _purchaseService.loadProducts(
      productIds: ShopProductCatalog.productIdsFromConfig(config),
    );
    return config;
  }

  @override
  void dispose() {
    _purchaseService.removeListener(_handlePurchaseStateChanged);
    AppLocale.notifier.removeListener(_reloadForLocale);
    _tabController.dispose();
    super.dispose();
  }

  void _reloadForLocale() {
    if (!mounted) return;
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
            final config = snapshot.data;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                CosmicWalletScreen.topBarHeight(context) + 8,
                20,
                widget.bottomInset + 28,
              ),
              children: [
                _HeaderTabs(controller: _tabController),
                const SizedBox(height: 20),
                if (snapshot.connectionState != ConnectionState.done &&
                    config == null)
                  const _WalletSkeleton()
                else if (config == null)
                  _ErrorPanel(message: AppTexts.t('error.default'))
                else
                  ValueListenableBuilder<PurchaseServiceState>(
                    valueListenable: _purchaseService.state,
                    builder: (context, purchaseState, _) {
                      return SizedBox(
                        height: _tabController.index == 0 ? null : null,
                        child: AnimatedBuilder(
                          animation: _tabController,
                          builder: (context, _) {
                            return _tabController.index == 0
                                ? _CreditsTab(
                                    config: config,
                                    purchaseService: _purchaseService,
                                    purchaseState: purchaseState,
                                  )
                                : _PremiumTab(
                                    config: config,
                                    purchaseService: _purchaseService,
                                    shopConfigService: _shopConfigService,
                                    purchaseState: purchaseState,
                                  );
                          },
                        ),
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

class _HeaderTabs extends StatelessWidget {
  const _HeaderTabs({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppTexts.t('shopTitle'),
          style: GoogleFonts.newsreader(
            color: AppColors.onSurface,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 46,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: TabBar(
            controller: controller,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: AppColors.primaryPink.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.primaryPink.withValues(alpha: 0.30),
              ),
            ),
            labelColor: AppColors.onSurface,
            unselectedLabelColor:
                AppColors.secondaryLavender.withValues(alpha: 0.68),
            labelStyle: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
            tabs: [
              Tab(text: AppTexts.t('shopCreditsTab')),
              Tab(text: AppTexts.t('shopPremiumTab')),
            ],
          ),
        ),
      ],
    );
  }
}

class _CreditsTab extends StatelessWidget {
  const _CreditsTab({
    required this.config,
    required this.purchaseService,
    required this.purchaseState,
  });

  final ShopConfig config;
  final PurchaseService purchaseService;
  final PurchaseServiceState purchaseState;

  @override
  Widget build(BuildContext context) {
    final items = config.creditProducts
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

    return Column(
      children: [
        for (final item in items) ...[
          CreditPackCard(
            item: item,
            isBusy: purchaseState.activeProductId == item.productId &&
                purchaseState.isBusy,
            onBuy: () => purchaseService.buyProduct(item.productId),
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 6),
        _InfoStrip(text: AppTexts.t('creditsConsumableInfo')),
      ],
    );
  }
}

class _PremiumTab extends StatelessWidget {
  const _PremiumTab({
    required this.config,
    required this.purchaseService,
    required this.shopConfigService,
    required this.purchaseState,
  });

  final ShopConfig config;
  final PurchaseService purchaseService;
  final ShopConfigService shopConfigService;
  final PurchaseServiceState purchaseState;

  @override
  Widget build(BuildContext context) {
    final configs = config.premiumProducts.where((item) => item.isActive);
    final item = configs.isEmpty
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
      children: [
        if (item == null)
          _ErrorPanel(message: AppTexts.t('shopPriceUnavailable'))
        else
          PremiumCard(
            item: item,
            isBusy: purchaseState.activeProductId == item.productId &&
                purchaseState.isBusy,
            onBuy: () => purchaseService.buyProduct(item.productId),
          ),
        const SizedBox(height: 12),
        RestorePurchasesButton(
          isRestoring: purchaseState.phase == PurchaseServicePhase.restoring,
          onPressed: purchaseService.restorePurchases,
        ),
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

class _WalletTopBar extends StatelessWidget {
  const _WalletTopBar({
    required this.uid,
    required this.entitlementService,
  });

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
            builder: (context, snapshot) {
              final balance = snapshot.data?.creditBalance ?? 0;
              return Row(
                children: [
                  _TokenPill(balance: balance),
                  const Spacer(),
                  if (snapshot.data?.premium.active == true)
                    _PremiumPill(text: AppTexts.t('premiumMonthlyTitle')),
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

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primaryPink.withValues(alpha: 0.34),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.generating_tokens_rounded,
            color: AppColors.tertiaryGold,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            '$balance ${AppTexts.t('home.top.token_unit')}',
            style: GoogleFonts.spaceGrotesk(
              color: AppColors.tertiaryGold,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
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

class _WalletSkeleton extends StatelessWidget {
  const _WalletSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          height: index == 0 ? 178 : 154,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.glassBorder),
          ),
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
