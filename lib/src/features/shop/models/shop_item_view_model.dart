import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/app_texts.dart';
import 'shop_product_catalog.dart';
import 'shop_product_config.dart';
import 'shop_product_type.dart';

class ShopItemViewModel {
  const ShopItemViewModel({
    required this.productId,
    required this.title,
    required this.subtitle,
    required this.features,
    required this.priceText,
    required this.isHighlighted,
    required this.isStoreProductLoaded,
    required this.isPurchasable,
    required this.type,
    this.badge,
    this.iconKey,
    this.productDetails,
    this.creditAmount = 0,
    this.bonusCredits = 0,
  });

  final String productId;
  final String title;
  final String subtitle;
  final List<String> features;
  final String? badge;
  final String? iconKey;
  final String priceText;
  final bool isHighlighted;
  final bool isStoreProductLoaded;
  final bool isPurchasable;
  final ProductDetails? productDetails;
  final ShopProductType type;
  final int creditAmount;
  final int bonusCredits;

  factory ShopItemViewModel.fromConfig({
    required ShopProductConfig config,
    required ProductDetails? productDetails,
    required bool storeAvailable,
    required bool isBusy,
    bool isNotFound = false,
  }) {
    final catalog = ShopProductCatalog.find(config.productId);
    final loaded = productDetails != null;
    final purchasable = config.isActive && storeAvailable && loaded && !isBusy;

    return ShopItemViewModel(
      productId: config.productId,
      title: AppTexts.t(config.titleKey),
      subtitle: AppTexts.t(config.subtitleKey),
      features: config.featureKeys.map(AppTexts.t).toList(),
      badge: config.badgeKey == null ? null : AppTexts.t(config.badgeKey!),
      iconKey: config.iconKey,
      priceText: loaded
          ? productDetails.price
          : isNotFound
              ? AppTexts.t('shopPriceUnavailable')
              : (isBusy || storeAvailable)
                  ? AppTexts.t('shopLoadingPrice')
                  : AppTexts.t('shopPurchaseUnavailable'),
      isHighlighted: config.isHighlighted,
      isStoreProductLoaded: loaded,
      isPurchasable: purchasable,
      productDetails: productDetails,
      type: catalog?.type ?? ShopProductType.consumableCredit,
      creditAmount: catalog?.creditAmount ?? 0,
      bonusCredits: catalog?.bonusCredits ?? 0,
    );
  }
}
