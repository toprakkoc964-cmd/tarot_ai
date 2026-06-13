import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/app_texts.dart';
import '../../core/di/service_locator.dart';
import '../shop/models/shop_product_catalog.dart';
import '../shop/models/shop_product_config.dart';
import '../shop/services/purchase_service.dart';
import '../shop/services/shop_config_service.dart';
import '../shop/widgets/shop_footer_links.dart';
import 'widgets/mystic_toast.dart';

class OnboardingPaywallPage extends StatefulWidget {
  const OnboardingPaywallPage({
    super.key,
    required this.uid,
    required this.onContinue,
    required this.onClose,
    PurchaseService? purchaseService,
    ShopConfigService? shopConfigService,
  }) : _purchaseService = purchaseService,
       _shopConfigService = shopConfigService;

  final String uid;
  final VoidCallback onContinue;
  final VoidCallback onClose;
  final PurchaseService? _purchaseService;
  final ShopConfigService? _shopConfigService;

  @override
  State<OnboardingPaywallPage> createState() => _OnboardingPaywallPageState();
}

class _OnboardingPaywallPageState extends State<OnboardingPaywallPage>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFF17081C);
  static const _surface = Color(0xFF1E0C25);
  static const _surfaceHigh = Color(0xFF361A41);
  static const _primary = Color(0xFFFF5ED6);
  static const _primaryDeep = Color(0xFFFF00D4);
  static const _secondary = Color(0xFFCDBDFF);
  static const _onSurface = Color(0xFFFADCFF);
  static const _gold = Color(0xFFFFE792);
  static const _outlineVariant = Color(0xFF5B3C66);
  static const _ctaText = Color(0xFF430036);

  late final PurchaseService _purchaseService;
  late final ShopConfigService _shopConfigService;
  late final AnimationController _glowController;

  ShopConfig? _shopConfig;
  String _selectedProductId = ShopProductCatalog.credits250;
  bool _loadingConfig = true;
  bool _purchaseStarted = false;
  bool _continued = false;

  static const _creditProductIds = <String>{
    ShopProductCatalog.credits50,
    ShopProductCatalog.credits250,
    ShopProductCatalog.credits1000,
  };

  @override
  void initState() {
    super.initState();
    _purchaseService = widget._purchaseService ?? getIt<PurchaseService>();
    _shopConfigService =
        widget._shopConfigService ?? getIt<ShopConfigService>();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _purchaseService.addListener(_handlePurchaseState);
    _load();
  }

  @override
  void dispose() {
    _purchaseService.removeListener(_handlePurchaseState);
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadingConfig = true);
    try {
      final config = await _shopConfigService.fetchConfig();
      if (!mounted) return;
      setState(() => _shopConfig = config);
      await _purchaseService.loadProducts(productIds: _creditProductIds);
    } catch (_) {
      if (!mounted) return;
      MysticToast.showError(
        context,
        AppTexts.t('onboarding.paywall.load_error'),
      );
    } finally {
      if (mounted) setState(() => _loadingConfig = false);
    }
  }

  void _handlePurchaseState() {
    final state = _purchaseService.state.value;
    if (!_purchaseStarted || _continued) return;

    if (state.phase == PurchaseServicePhase.success &&
        state.activeProductId == _selectedProductId) {
      _continued = true;
      widget.onContinue();
      return;
    }

    if (state.phase == PurchaseServicePhase.error) {
      final messageKey = state.messageKey ?? 'error.default';
      MysticToast.showError(context, AppTexts.t(messageKey));
    }
  }

  Future<void> _buySelected() async {
    _purchaseStarted = true;
    await _purchaseService.buyProduct(_selectedProductId);
  }

  Future<void> _restore() async {
    await _purchaseService.restorePurchases();
  }

  List<_CreditPack> _packs(Map<String, ProductDetails> products) {
    return const [
      _CreditPack(
        productId: ShopProductCatalog.credits50,
        credits: 50,
        badgeKey: null,
      ),
      _CreditPack(
        productId: ShopProductCatalog.credits250,
        credits: 250,
        badgeKey: 'onboarding.paywall.badge_popular',
      ),
      _CreditPack(
        productId: ShopProductCatalog.credits1000,
        credits: 1000,
        badgeKey: 'onboarding.paywall.badge_best',
      ),
    ].where((pack) => ShopProductCatalog.find(pack.productId) != null).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PurchaseServiceState>(
      valueListenable: _purchaseService.state,
      builder: (context, purchaseState, _) {
        final products = purchaseState.products;
        final packs = _packs(products);
        final selectedPack = packs.firstWhere(
          (pack) => pack.productId == _selectedProductId,
          orElse: () => packs[math.min(1, packs.length - 1)],
        );
        final selectedProduct = products[selectedPack.productId];
        final busy = purchaseState.isBusy;
        final loadingProducts =
            _loadingConfig ||
            purchaseState.phase == PurchaseServicePhase.loadingProducts;
        return Scaffold(
          backgroundColor: _bg,
          body: Stack(
            children: [
              const Positioned.fill(child: _PaywallBackground()),
              SafeArea(
                child: Column(
                  children: [
                    _topBar(busy),
                    Expanded(
                      child: loadingProducts && products.isEmpty
                          ? _loadingBody()
                          : _content(packs, products, purchaseState),
                    ),
                    _bottomCta(
                      pack: selectedPack,
                      product: selectedProduct,
                      busy: busy,
                      enabled:
                          selectedProduct != null &&
                          purchaseState.storeAvailable &&
                          !busy,
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

  Widget _topBar(bool busy) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: busy ? null : widget.onClose,
            icon: const Icon(Icons.close_rounded, color: _secondary, size: 28),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: busy ? null : _restore,
            icon: const Icon(Icons.restore_rounded, size: 18),
            label: Text(AppTexts.t('shopRestorePurchases')),
            style: TextButton.styleFrom(
              foregroundColor: _secondary.withValues(alpha: 0.88),
              textStyle: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      children: [
        _titleBlock(),
        const SizedBox(height: 26),
        for (var i = 0; i < 3; i++) ...[
          _SkeletonCard(delay: i * 0.16),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _content(
    List<_CreditPack> packs,
    Map<String, ProductDetails> products,
    PurchaseServiceState purchaseState,
  ) {
    final config = _shopConfig;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
      children: [
        _titleBlock(),
        const SizedBox(height: 22),
        if (purchaseState.messageKey != null &&
            !purchaseState.storeAvailable) ...[
          _InfoPanel(
            text: AppTexts.t(purchaseState.messageKey!),
            onRetry: _load,
          ),
          const SizedBox(height: 18),
        ],
        for (final pack in packs) ...[
          _packCard(
            pack: pack,
            product: products[pack.productId],
            selected: pack.productId == _selectedProductId,
            busy: purchaseState.isBusy,
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 8),
        _legalNote(),
        const SizedBox(height: 18),
        ShopFooterLinks(
          termsUrl: config == null
              ? ''
              : _shopConfigService.legalTermsUrl(config),
          privacyUrl: config == null
              ? ''
              : _shopConfigService.legalPrivacyUrl(config),
          onError: () => MysticToast.showError(
            context,
            AppTexts.t('onboarding.paywall.link_error'),
          ),
        ),
      ],
    );
  }

  Widget _titleBlock() {
    return Column(
      children: [
        Text(
          AppTexts.t('onboarding.paywall.title'),
          textAlign: TextAlign.center,
          style: GoogleFonts.newsreader(
            color: _onSurface,
            fontSize: 42,
            height: 1.04,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(color: _primary.withValues(alpha: 0.28), blurRadius: 18),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppTexts.t('onboarding.paywall.subtitle'),
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: _secondary.withValues(alpha: 0.84),
            fontSize: 15,
            height: 1.42,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _packCard({
    required _CreditPack pack,
    required ProductDetails? product,
    required bool selected,
    required bool busy,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy
          ? null
          : () => setState(() => _selectedProductId = pack.productId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [
                    _primary.withValues(alpha: 0.28),
                    _surfaceHigh.withValues(alpha: 0.66),
                    _primaryDeep.withValues(alpha: 0.12),
                  ]
                : [
                    _surface.withValues(alpha: 0.58),
                    _bg.withValues(alpha: 0.54),
                  ],
          ),
          border: Border.all(
            color: selected
                ? _primary.withValues(alpha: 0.72)
                : _outlineVariant.withValues(alpha: 0.46),
            width: selected ? 1.35 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.28),
                    blurRadius: 28,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                final glow = selected
                    ? 0.22 + _glowController.value * 0.16
                    : 0.10;
                return Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _surfaceHigh.withValues(alpha: 0.54),
                    border: Border.all(
                      color: selected
                          ? _gold.withValues(alpha: 0.58)
                          : _outlineVariant.withValues(alpha: 0.42),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withValues(alpha: glow),
                        blurRadius: 22,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: Icon(
                pack.credits == 1000
                    ? Icons.wb_sunny_rounded
                    : pack.credits == 250
                    ? Icons.nightlight_round
                    : Icons.token_rounded,
                color: _gold,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pack.badgeKey != null) ...[
                    _badge(AppTexts.t(pack.badgeKey!)),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    _template('onboarding.paywall.pack_title', {
                      'amount': pack.credits.toString(),
                    }),
                    style: GoogleFonts.newsreader(
                      color: _onSurface,
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      height: 1.04,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    AppTexts.t('onboarding.paywall.pack_subtitle'),
                    style: GoogleFonts.manrope(
                      color: _secondary.withValues(alpha: 0.78),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected
                      ? _primary
                      : _secondary.withValues(alpha: 0.62),
                ),
                const SizedBox(height: 12),
                Text(
                  product?.price ?? AppTexts.t('shopLoadingPrice'),
                  style: GoogleFonts.spaceGrotesk(
                    color: _gold,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _primary.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          color: _gold,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _legalNote() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surface.withValues(alpha: 0.44),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _outlineVariant.withValues(alpha: 0.42)),
          ),
          child: Text(
            AppTexts.t('onboarding.paywall.apple_notice'),
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: _secondary.withValues(alpha: 0.74),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomCta({
    required _CreditPack pack,
    required ProductDetails? product,
    required bool busy,
    required bool enabled,
  }) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final label = product == null
        ? AppTexts.t('shopLoadingPrice')
        : _template('onboarding.paywall.cta', {
            'amount': pack.credits.toString(),
            'price': product.price,
          });
    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(20, 8, 20, math.max(16, bottom + 8)),
      child: GestureDetector(
        onTap: enabled ? _buySelected : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: enabled ? 1 : 0.64,
          child: Container(
            height: 62,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_primary, _primaryDeep]),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: _primaryDeep.withValues(alpha: 0.34),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _ctaText,
                    ),
                  )
                : Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                      color: _ctaText,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  String _template(String key, Map<String, String> values) {
    var text = AppTexts.t(key);
    for (final entry in values.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value);
    }
    return text;
  }
}

class _CreditPack {
  const _CreditPack({
    required this.productId,
    required this.credits,
    required this.badgeKey,
  });

  final String productId;
  final int credits;
  final String? badgeKey;
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E0C25).withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF5B3C66).withValues(alpha: 0.48),
        ),
      ),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: const Color(0xFFCDBDFF),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onRetry,
            child: Text(AppTexts.t('onboarding.paywall.retry')),
          ),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard({required this.delay});

  final double delay;

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

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
        final value = (_controller.value + widget.delay) % 1;
        return Container(
          height: 124,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment(-1 + value * 2, -1),
              end: Alignment(value * 2, 1),
              colors: [
                const Color(0xFF26112E).withValues(alpha: 0.40),
                const Color(0xFF5B3C66).withValues(alpha: 0.36),
                const Color(0xFF26112E).withValues(alpha: 0.40),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF5B3C66).withValues(alpha: 0.32),
            ),
          ),
        );
      },
    );
  }
}

class _PaywallBackground extends StatelessWidget {
  const _PaywallBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.2,
          colors: [Color(0xFF32133B), Color(0xFF17081C), Color(0xFF120516)],
          stops: [0, 0.62, 1],
        ),
      ),
      child: CustomPaint(painter: _PaywallStarsPainter()),
    );
  }
}

class _PaywallStarsPainter extends CustomPainter {
  const _PaywallStarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 34; i++) {
      final x = (i * 83.0) % size.width;
      final y = (i * 137.0) % size.height;
      paint.color =
          (i.isEven
                  ? _OnboardingPaywallPalette.gold
                  : _OnboardingPaywallPalette.secondary)
              .withValues(alpha: i % 5 == 0 ? 0.42 : 0.20);
      canvas.drawCircle(Offset(x, y), i % 6 == 0 ? 1.7 : 1.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OnboardingPaywallPalette {
  const _OnboardingPaywallPalette._();

  static const gold = Color(0xFFFFE792);
  static const secondary = Color(0xFFCDBDFF);
}
