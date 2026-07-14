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
      // Ekranın yaklaşık %60'ı; 0.55-0.65 arasında ayarlanabilir.
      final height = MediaQuery.of(sheetContext).size.height * 0.6;
      return Container(
        height: height,
        decoration: BoxDecoration(
          // Sayfa arka planından (0xFF17081C) belirgin şekilde daha açık,
          // böylece sheet sayfadan görsel olarak ayrışır.
          color: const Color(0xFF1E0E2C),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: const Color(0x66D4AF37), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 24,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Gold sürükleme tutamacı
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                // CosmicWalletScreen kendi üst barını status-bar padding'ine
                // göre konumlandırıyor; sheet içinde fazladan boşluk olmasın
                // diye kaldır.
                child: MediaQuery.removePadding(
                  context: sheetContext,
                  removeTop: true,
                  child: CosmicWalletScreen(bottomInset: 0, uid: resolvedUid),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
