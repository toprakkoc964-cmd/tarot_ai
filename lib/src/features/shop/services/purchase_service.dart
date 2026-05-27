import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/purchase_verification_request.dart';
import '../models/shop_product_catalog.dart';
import '../models/shop_product_type.dart';
import 'backend_purchase_verification_service.dart';

enum PurchaseServicePhase {
  idle,
  loadingProducts,
  purchasing,
  pending,
  verifying,
  restoring,
  restored,
  success,
  error,
}

class PurchaseServiceState {
  const PurchaseServiceState({
    this.phase = PurchaseServicePhase.idle,
    this.storeAvailable = false,
    this.products = const <String, ProductDetails>{},
    this.notFoundIds = const <String>{},
    this.activeProductId,
    this.messageKey,
  });

  final PurchaseServicePhase phase;
  final bool storeAvailable;
  final Map<String, ProductDetails> products;
  final Set<String> notFoundIds;
  final String? activeProductId;
  final String? messageKey;

  bool get isBusy {
    return phase == PurchaseServicePhase.loadingProducts ||
        phase == PurchaseServicePhase.purchasing ||
        phase == PurchaseServicePhase.pending ||
        phase == PurchaseServicePhase.verifying ||
        phase == PurchaseServicePhase.restoring;
  }

  PurchaseServiceState copyWith({
    PurchaseServicePhase? phase,
    bool? storeAvailable,
    Map<String, ProductDetails>? products,
    Set<String>? notFoundIds,
    String? activeProductId,
    String? messageKey,
    bool clearActiveProductId = false,
    bool clearMessageKey = false,
  }) {
    return PurchaseServiceState(
      phase: phase ?? this.phase,
      storeAvailable: storeAvailable ?? this.storeAvailable,
      products: products ?? this.products,
      notFoundIds: notFoundIds ?? this.notFoundIds,
      activeProductId:
          clearActiveProductId ? null : activeProductId ?? this.activeProductId,
      messageKey: clearMessageKey ? null : messageKey ?? this.messageKey,
    );
  }
}

class PurchaseService {
  PurchaseService({
    InAppPurchase? inAppPurchase,
    BackendPurchaseVerificationService? verificationService,
  })  : _iap = inAppPurchase ?? InAppPurchase.instance,
        _verificationService =
            verificationService ?? BackendPurchaseVerificationService();

  final InAppPurchase _iap;
  final BackendPurchaseVerificationService _verificationService;
  final ValueNotifier<PurchaseServiceState> state =
      ValueNotifier<PurchaseServiceState>(const PurchaseServiceState());

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _initialized = false;

  void addListener(VoidCallback listener) => state.addListener(listener);

  void removeListener(VoidCallback listener) => state.removeListener(listener);

  Future<void> initialize() async {
    if (_initialized) return;
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error, StackTrace stackTrace) {
        if (kDebugMode) {
          debugPrint('Purchase stream error: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
        state.value = state.value.copyWith(
          phase: PurchaseServicePhase.error,
          messageKey: 'error.default',
          clearActiveProductId: true,
        );
      },
    );
    _initialized = true;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
    state.dispose();
  }

  Future<void> loadProducts({Set<String>? productIds}) async {
    final ids = productIds ?? ShopProductCatalog.productIds;
    state.value = state.value.copyWith(
      phase: PurchaseServicePhase.loadingProducts,
      clearMessageKey: true,
    );

    final available = await _iap.isAvailable();
    if (!available) {
      state.value = state.value.copyWith(
        phase: PurchaseServicePhase.idle,
        storeAvailable: false,
        products: const <String, ProductDetails>{},
        notFoundIds: ids,
        messageKey: 'shopPurchaseUnavailable',
      );
      return;
    }

    final response = await _iap.queryProductDetails(ids);
    final products = <String, ProductDetails>{
      for (final product in response.productDetails) product.id: product,
    };

    if (kDebugMode && response.notFoundIDs.isNotEmpty) {
      debugPrint('StoreKit not found IDs: ${response.notFoundIDs.join(', ')}');
    }

    state.value = state.value.copyWith(
      phase: PurchaseServicePhase.idle,
      storeAvailable: true,
      products: products,
      notFoundIds: response.notFoundIDs.toSet(),
      clearMessageKey: true,
    );
  }

  Future<void> buyProduct(String productId) async {
    final product = state.value.products[productId];
    final catalogItem = ShopProductCatalog.find(productId);

    if (product == null || catalogItem == null || !state.value.storeAvailable) {
      state.value = state.value.copyWith(
        phase: PurchaseServicePhase.error,
        activeProductId: productId,
        messageKey: 'shopPriceUnavailable',
      );
      return;
    }

    final purchaseParam = PurchaseParam(productDetails: product);
    state.value = state.value.copyWith(
      phase: PurchaseServicePhase.purchasing,
      activeProductId: productId,
      messageKey: 'shopPurchasePending',
    );

    try {
      if (catalogItem.type == ShopProductType.consumableCredit) {
        await _iap.buyConsumable(
          purchaseParam: purchaseParam,
          autoConsume: true,
        );
      } else {
        await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Purchase start failed product=$productId error=$e');
        debugPrintStack(stackTrace: st);
      }
      state.value = state.value.copyWith(
        phase: PurchaseServicePhase.error,
        activeProductId: productId,
        messageKey: 'error.default',
      );
    }
  }

  Future<void> restorePurchases() async {
    state.value = state.value.copyWith(
      phase: PurchaseServicePhase.restoring,
      messageKey: 'shopRestoreInProgress',
      clearActiveProductId: true,
    );
    try {
      await _iap.restorePurchases();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Restore purchases failed: $e');
        debugPrintStack(stackTrace: st);
      }
      state.value = state.value.copyWith(
        phase: PurchaseServicePhase.error,
        messageKey: 'error.default',
      );
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      await _handleSinglePurchase(purchase);
    }
  }

  Future<void> _handleSinglePurchase(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        state.value = state.value.copyWith(
          phase: PurchaseServicePhase.pending,
          activeProductId: purchase.productID,
          messageKey: 'shopPurchasePending',
        );
        return;
      case PurchaseStatus.error:
        if (kDebugMode) {
          debugPrint(
            'Purchase error product=${purchase.productID}: ${purchase.error}',
          );
        }
        state.value = state.value.copyWith(
          phase: PurchaseServicePhase.error,
          activeProductId: purchase.productID,
          messageKey: 'error.default',
        );
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        return;
      case PurchaseStatus.canceled:
        state.value = state.value.copyWith(
          phase: PurchaseServicePhase.idle,
          activeProductId: purchase.productID,
          clearMessageKey: true,
        );
        return;
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        await _verifyAndComplete(purchase);
        return;
    }
  }

  Future<void> _verifyAndComplete(PurchaseDetails purchase) async {
    final userId = _verificationService.currentUserId;
    if (userId == null || userId.isEmpty) {
      state.value = state.value.copyWith(
        phase: PurchaseServicePhase.error,
        activeProductId: purchase.productID,
        messageKey: 'error.default',
      );
      return;
    }

    state.value = state.value.copyWith(
      phase: PurchaseServicePhase.verifying,
      activeProductId: purchase.productID,
      messageKey: 'shopPurchaseVerifying',
    );

    try {
      final request = PurchaseVerificationRequest.fromPurchaseDetails(
        userId: userId,
        purchase: purchase,
      );
      final response = await _verificationService.verifyPurchase(request);

      if (!response.success) {
        throw StateError(response.message ?? 'PURCHASE_VERIFICATION_FAILED');
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }

      state.value = state.value.copyWith(
        phase: purchase.status == PurchaseStatus.restored
            ? PurchaseServicePhase.restored
            : PurchaseServicePhase.success,
        activeProductId: purchase.productID,
        messageKey: purchase.status == PurchaseStatus.restored
            ? 'shopRestoreSuccess'
            : 'shopPurchaseVerified',
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          'Purchase verification failed product=${purchase.productID}: $e',
        );
        debugPrintStack(stackTrace: st);
      }
      state.value = state.value.copyWith(
        phase: PurchaseServicePhase.error,
        activeProductId: purchase.productID,
        messageKey: 'error.default',
      );
    }
  }
}
