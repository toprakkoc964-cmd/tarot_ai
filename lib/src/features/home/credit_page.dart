import 'package:flutter/material.dart';

import '../shop/screens/cosmic_wallet_screen.dart';

class CreditPage extends StatelessWidget {
  const CreditPage({
    super.key,
    required this.bottomInset,
    required this.uid,
  });

  final double bottomInset;
  final String uid;

  static double topBarHeight(BuildContext context) {
    return CosmicWalletScreen.topBarHeight(context);
  }

  @override
  Widget build(BuildContext context) {
    return CosmicWalletScreen(
      bottomInset: bottomInset,
      uid: uid,
    );
  }
}
