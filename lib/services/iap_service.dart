/// Tip-jar IAP for Chess: "buy me a coffee" / "buy me a chocolate".
///
/// The products must be created by Wajiha in Play Console; until then (or on
/// any store error) the service degrades gracefully — the UI shows the
/// products as unavailable instead of crashing or hanging.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class TipJar {
  static const coffeeId = 'buy_me_a_coffee';
  static const chocolateId = 'buy_me_a_chocolate';
  static const productIds = {coffeeId, chocolateId};

  final InAppPurchase _iap = InAppPurchase.instance;

  bool available = false;
  List<ProductDetails> products = [];
  String? error;
  bool _initialized = false;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Last completed tip, for a thank-you toast. Reset by the UI after showing.
  final ValueNotifier<String?> lastThanks = ValueNotifier(null);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      available = await _iap.isAvailable();
      if (!available) {
        error = 'Store unavailable';
        return;
      }
      _sub = _iap.purchaseStream.listen(
        _onPurchases,
        onError: (_) {},
        cancelOnError: false,
      );
      final resp = await _iap.queryProductDetails(productIds);
      if (resp.error != null) {
        error = 'Could not load products';
        return;
      }
      products = resp.productDetails;
      if (resp.notFoundIDs.isNotEmpty) {
        // Products not created in Play Console yet — normal during dev.
        error = 'Products not configured yet';
      }
    } catch (_) {
      available = false;
      error = 'Store error';
    }
  }

  void _onPurchases(List<PurchaseDetails> list) {
    for (final p in list) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        lastThanks.value = p.productID == chocolateId
            ? 'Thank you for the chocolate!'
            : 'Thank you for the coffee!';
      }
      if (p.pendingCompletePurchase) {
        _iap.completePurchase(p).catchError((_) {});
      }
    }
  }

  Future<bool> buy(ProductDetails product) async {
    try {
      return await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    lastThanks.dispose();
  }
}
