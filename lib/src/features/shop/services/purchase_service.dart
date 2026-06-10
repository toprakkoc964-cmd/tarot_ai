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
    this.queriedProductIds = const <String>{},
    this.activeProductId,
    this.messageKey,
    this.queryErrorCode,
  });

  final PurchaseServicePhase phase;
  final bool storeAvailable;
  final Map<String, ProductDetails> products;
  final Set<String> notFoundIds;
  final Set<String> queriedProductIds;
  final String? activeProductId;
  final String? messageKey;
  final String? queryErrorCode;

  bool get isBusy {
    return phase == PurchaseServicePhase.loadingProducts ||
        phase == PurchaseServicePhase.purchasing ||
        phase == PurchaseServicePhase.pending ||
        phase == PurchaseServicePhase.verifying ||
        phase == PurchaseServicePhase.restoring;
  }

  bool get allQueriedProductsMissing {
    return storeAvailable &&
        queriedProductIds.isNotEmpty &&
        products.isEmpty &&
        notFoundIds.length >= queriedProductIds.length;
  }

  PurchaseServiceState copyWith({
    PurchaseServicePhase? phase,
    bool? storeAvailable,
    Map<String, ProductDetails>? products,
    Set<String>? notFoundIds,
    Set<String>? queriedProductIds,
    String? activeProductId,
    String? messageKey,
    String? queryErrorCode,
    bool clearActiveProductId = false,
    bool clearMessageKey = false,
    bool clearQueryErrorCode = false,
  }) {
    return PurchaseServiceState(
      phase: phase ?? this.phase,
      storeAvailable: storeAvailable ?? this.storeAvailable,
      products: products ?? this.products,
      notFoundIds: notFoundIds ?? this.notFoundIds,
      queriedProductIds: queriedProductIds ?? this.queriedProductIds,
      activeProductId: clearActiveProductId
          ? null
          : activeProductId ?? this.activeProductId,
      messageKey: clearMessageKey ? null : messageKey ?? this.messageKey,
      queryErrorCode: clearQueryErrorCode
          ? null
          : queryErrorCode ?? this.queryErrorCode,
    );
  }
}

class PurchaseService {
  PurchaseService({
    InAppPurchase? inAppPurchase,
    BackendPurchaseVerificationService? verificationService,
  }) : _iap = inAppPurchase ?? InAppPurchase.instance,
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
    final ids = (productIds ?? ShopProductCatalog.productIds)
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return;

    final hasCachedProducts =
        state.value.storeAvailable &&
        ids.every((id) => state.value.products.containsKey(id));

    state.value = state.value.copyWith(
      phase: hasCachedProducts
          ? state.value.phase
          : PurchaseServicePhase.loadingProducts,
      queriedProductIds: ids,
      clearMessageKey: true,
      clearQueryErrorCode: true,
    );

    final available = await _iap.isAvailable();
    if (!available) {
      if (kDebugMode) {
        debugPrint('IAP store is not available on this device/build.');
      }
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

    if (kDebugMode) {
      if (response.error != null) {
        debugPrint(
          'IAP query error: code=${response.error!.code} '
          'message=${response.error!.message} '
          'details=${response.error!.details}',
        );
      }
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('IAP not found IDs: ${response.notFoundIDs.join(', ')}');
      }
      if (products.isNotEmpty) {
        debugPrint('IAP loaded products: ${products.keys.join(', ')}');
      }
    }

    final queryFailed = response.error != null;
    state.value = state.value.copyWith(
      phase: PurchaseServicePhase.idle,
      storeAvailable: !queryFailed,
      products: products,
      notFoundIds: response.notFoundIDs.toSet(),
      queryErrorCode: response.error?.code,
      messageKey: queryFailed
          ? 'shopPurchaseUnavailable'
          : (products.isEmpty && response.notFoundIDs.isNotEmpty)
          ? 'shopProductsNotFoundHint'
          : null,
      clearMessageKey:
          !queryFailed &&
          !(products.isEmpty && response.notFoundIDs.isNotEmpty),
    );
  }

  Future<void> buyProduct(String productId) async {
    final product = state.value.products[productId];
    final catalogItem = ShopProductCatalog.find(productId);

    if (product == null || catalogItem == null || !state.value.storeAvailable) {
      state.value = state.value.copyWith(
        phase: PurchaseServicePhase.error,
        activeProductId: productId,
        messageKey: state.value.allQueriedProductsMissing
            ? 'shopProductsNotFoundHint'
            : 'shopPriceUnavailable',
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

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
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
