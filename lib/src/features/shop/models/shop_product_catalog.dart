import 'shop_product_type.dart';

class ShopProductCatalogItem {
  const ShopProductCatalogItem({
    required this.productId,
    required this.type,
    this.creditAmount = 0,
    this.bonusCredits = 0,
  });

  final String productId;
  final ShopProductType type;
  final int creditAmount;
  final int bonusCredits;

  bool get isPremium => type == ShopProductType.monthlyPremium;
}

class ShopProductCatalog {
  const ShopProductCatalog._();

  static const String credits50 = 'tarotai.credits.50';
  static const String credits250 = 'tarotai.credits.250';
  static const String credits1000 = 'tarotai.credits.1000';
  static const String premiumMonthly = 'tarotai.premium.monthly';

  static const List<ShopProductCatalogItem> items = [
    ShopProductCatalogItem(
      productId: credits50,
      type: ShopProductType.consumableCredit,
      creditAmount: 50,
    ),
    ShopProductCatalogItem(
      productId: credits250,
      type: ShopProductType.consumableCredit,
      creditAmount: 250,
    ),
    ShopProductCatalogItem(
      productId: credits1000,
      type: ShopProductType.consumableCredit,
      creditAmount: 1000,
    ),
    ShopProductCatalogItem(
      productId: premiumMonthly,
      type: ShopProductType.monthlyPremium,
      bonusCredits: 200,
    ),
  ];

  static Set<String> get productIds =>
      items.map((item) => item.productId).toSet();

  static ShopProductCatalogItem? find(String productId) {
    for (final item in items) {
      if (item.productId == productId) return item;
    }
    return null;
  }
}
