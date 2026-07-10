import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'cosmic_wallet_screen.dart';

/// Tüm "jeton gerekli / jeton al" akışlarında açılan ortak satın alma sheet'i.
Future<void> showCreditPurchaseSheet(BuildContext context, {String? uid}) {
  final resolvedUid = uid ?? FirebaseAuth.instance.currentUser?.uid ?? '';
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final height = MediaQuery.of(sheetContext).size.height * 0.9;
      return SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          // CosmicWalletScreen kendi üst barını status-bar padding'ine göre
          // konumlandırıyor; sheet içinde fazladan boşluk olmasın diye kaldır.
          child: MediaQuery.removePadding(
            context: sheetContext,
            removeTop: true,
            child: CosmicWalletScreen(bottomInset: 0, uid: resolvedUid),
          ),
        ),
      );
    },
  );
}
