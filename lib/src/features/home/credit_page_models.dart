class CreditPageData {
  const CreditPageData({
    required this.localeCode,
    required this.title,
    required this.advantagesTitle,
    required this.rechargeCta,
    required this.restoreLabel,
    required this.termsLabel,
    required this.privacyLabel,
    required this.legalDisclaimer,
    required this.advantagesCards,
    required this.packages,
  });

  final String localeCode;
  final String title;
  final String advantagesTitle;
  final String rechargeCta;
  final String restoreLabel;
  final String termsLabel;
  final String privacyLabel;
  final String legalDisclaimer;
  final List<AdvantageCard> advantagesCards;
  final List<CreditPackage> packages;

  factory CreditPageData.fromMap(Map<String, dynamic> map, String localeCode) {
    final advantagesRaw = map['advantages_cards'];
    final packagesRaw = map['packages'];

    return CreditPageData(
      localeCode: localeCode,
      title: (map['title'] as String?)?.trim() ?? '',
      advantagesTitle: (map['advantages_title'] as String?)?.trim() ?? '',
      rechargeCta: (map['recharge_cta'] as String?)?.trim() ?? '',
      restoreLabel: (map['restore_label'] as String?)?.trim() ?? '',
      termsLabel: (map['terms_label'] as String?)?.trim() ?? '',
      privacyLabel: (map['privacy_label'] as String?)?.trim() ?? '',
      legalDisclaimer: (map['legal_disclaimer'] as String?)?.trim() ?? '',
      advantagesCards: advantagesRaw is List
          ? advantagesRaw
              .whereType<Map>()
              .map(
                (item) => AdvantageCard.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
      packages: packagesRaw is List
          ? packagesRaw
              .whereType<Map>()
              .map(
                (item) => CreditPackage.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const [],
    );
  }
}

class AdvantageCard {
  const AdvantageCard({
    required this.iconKey,
    required this.title,
    required this.description,
    required this.accentKey,
  });

  final String iconKey;
  final String title;
  final String description;
  final String accentKey;

  factory AdvantageCard.fromMap(Map<String, dynamic> map) {
    return AdvantageCard(
      iconKey: (map['icon_key'] as String?)?.trim() ?? 'stars',
      title: (map['title'] as String?)?.trim() ?? '',
      description: (map['description'] as String?)?.trim() ?? '',
      accentKey: (map['accent'] as String?)?.trim() ?? 'primary',
    );
  }
}

class CreditPackage {
  const CreditPackage({
    required this.coins,
    required this.title,
    required this.price,
    required this.iconKey,
    required this.features,
    required this.accentKey,
    required this.badge,
    required this.isPopular,
  });

  final String coins;
  final String title;
  final String price;
  final String iconKey;
  final List<String> features;
  final String accentKey;
  final String? badge;
  final bool isPopular;

  factory CreditPackage.fromMap(Map<String, dynamic> map) {
    final featuresRaw = map['features'];
    return CreditPackage(
      coins: (map['coins'] as String?)?.trim() ?? '',
      title: (map['title'] as String?)?.trim() ?? '',
      price: (map['price'] as String?)?.trim() ?? '',
      iconKey: (map['icon_key'] as String?)?.trim() ?? 'star',
      accentKey: (map['accent'] as String?)?.trim() ?? 'primary',
      badge: (map['badge'] as String?)?.trim(),
      isPopular: map['is_popular'] == true,
      features: featuresRaw is List
          ? featuresRaw
              .whereType<String>()
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList()
          : const [],
    );
  }
}
