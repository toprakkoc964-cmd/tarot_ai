enum ShopProductType {
  consumableCredit,
  monthlyPremium,
}

extension ShopProductTypeX on ShopProductType {
  bool get isConsumable => this == ShopProductType.consumableCredit;
  bool get isPremium => this == ShopProductType.monthlyPremium;
}
