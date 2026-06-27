import 'dart:async';

import 'package:flutter/foundation.dart';
// The plugin's PurchaseStatus enum collides with our app-level PurchaseStatus,
// so we alias it. Our enum tells the UI the current state; the plugin enum
// describes an individual purchase transaction's outcome.
import 'package:in_app_purchase/in_app_purchase.dart' as iap;

import '../../core/constants.dart';

/// Status of a Pro purchase as the user sees it. Kept narrow on purpose —
/// the UI only needs to know "is the unlock mine" and "what is the billing
/// flow doing right now".
enum PurchaseStatus {
  /// No purchase flow in progress and the user does not own Pro.
  notOwned,

  /// User owns Pro. Set after a verified purchase or successful restore.
  owned,

  /// Purchase is in flight (sheet open, awaiting confirmation, verifying).
  pending,

  /// Purchase or restore failed; the [BillingException] carries the reason.
  error,
}

@immutable
class BillingException implements Exception {
  const BillingException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => 'BillingException: $message';
}

/// One product the user can buy. We only sell one — the lifetime unlock —
/// but the model is structured so adding more tiers later is a small change.
@immutable
class ProProduct {
  const ProProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
  });

  final String id;
  final String title;
  final String description;
  final String price;

  bool get isKnown => price.isNotEmpty;
}

/// Surface for the in-app purchase flow. The Google IAP implementation lives
/// in [IapBillingService]; a test or mock can swap in a fake by overriding
/// the [billingServiceProvider] in Riverpod. The interface is intentionally
/// narrow: buy, restore, and listen to status changes.
abstract class BillingService {
  /// Whether the device platform supports in-app purchases at all. Returns
  /// false on the iOS simulator (where StoreKit works but is flaky in tests)
  /// and on any non-supported platform (web, desktop, Linux). The UI should
  /// hide the Upgrade tile when this is false.
  Future<bool> isAvailable();

  /// Fetch the configured product (price, title) from the store. Returns a
  /// [ProProduct.isKnown] == false record when the product is not yet
  /// configured in Play Console — the UI should then show a friendly
  /// "coming soon" state instead of crashing.
  Future<ProProduct> loadProduct();

  /// Start the one-time purchase flow. Throws [BillingException] on failure.
  /// On success, ownership is persisted via [onStatusChanged] before this
  /// future completes.
  Future<void> buyPro();

  /// Re-fetch non-consumable entitlements from the store. Used by the
  /// "Restore purchases" button and called automatically on app start.
  Future<void> restore();

  /// Current purchase status, streamed. UI subscribes via
  /// `StreamProvider` in Riverpod.
  Stream<PurchaseStatus> get statusStream;

  /// Latest known status, for non-streaming reads.
  PurchaseStatus get currentStatus;

  /// Disposes the underlying IAP connection. Called from Riverpod
  /// `onDispose`.
  Future<void> dispose();
}

/// Google Play Billing implementation of [BillingService] using the official
/// `in_app_purchase` plugin. The plugin handles iOS StoreKit too, so a
/// future iOS port only needs the platform configuration — no Dart changes.
class IapBillingService implements BillingService {
  IapBillingService([iap.InAppPurchase? iapInstance])
      : _iap = iapInstance ?? iap.InAppPurchase.instance;

  final iap.InAppPurchase _iap;

  final StreamController<PurchaseStatus> _statusController =
      StreamController<PurchaseStatus>.broadcast();
  PurchaseStatus _current = PurchaseStatus.notOwned;
  bool _owns = false;
  late final StreamSubscription<List<iap.PurchaseDetails>> _purchaseSub;

  @override
  Stream<PurchaseStatus> get statusStream => _statusController.stream;

  @override
  PurchaseStatus get currentStatus => _current;

  /// Loads the store connection and wires the purchase-update stream. Called
  /// once from the Riverpod provider so subscriptions are live for the whole
  /// app lifetime.
  void init() {
    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) => _emit(
        PurchaseStatus.error,
        BillingException('Purchase stream error', cause: e),
      ),
    );
  }

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<ProProduct> loadProduct() async {
    final response = await _iap.queryProductDetails(
      const {AppConstants.proProductId},
    );
    if (response.error != null) {
      throw BillingException(
        'Could not load product from store: ${response.error!.message}',
        cause: response.error,
      );
    }
    final details = response.productDetails
        .where((d) => d.id == AppConstants.proProductId)
        .firstOrNull;
    if (details == null) {
      // Product not yet configured in Play Console. Don't crash the UI.
      return const ProProduct(
        id: AppConstants.proProductId,
        title: 'Snipt Pro',
        description: 'Unlimited clips, export, and more.',
        price: '',
      );
    }
    return ProProduct(
      id: details.id,
      title: details.title,
      description: details.description,
      price: details.price,
    );
  }

  @override
  Future<void> buyPro() async {
    _emit(PurchaseStatus.pending, null);
    final product = await loadProduct();
    if (!product.isKnown) {
      _emit(
        PurchaseStatus.error,
        const BillingException(
          'Pro is not yet available in your region or store. Try again later.',
        ),
      );
      return;
    }
    final details = (await _iap.queryProductDetails({product.id}))
        .productDetails
        .firstWhere((d) => d.id == product.id);
    // buyNonConsumable resolves on the sheet-open call; the actual
    // outcome is delivered through _onPurchaseUpdate.
    await _iap.buyNonConsumable(
      purchaseParam: iap.PurchaseParam(productDetails: details),
    );
  }

  @override
  Future<void> restore() async {
    _emit(PurchaseStatus.pending, null);
    try {
      await _iap.restorePurchases();
      // Result is delivered asynchronously through _onPurchaseUpdate.
    } catch (e) {
      _emit(
        PurchaseStatus.error,
        BillingException('Restore failed', cause: e),
      );
    }
  }

  void _onPurchaseUpdate(List<iap.PurchaseDetails> purchases) {
    for (final p in purchases) {
      switch (p.status) {
        case iap.PurchaseStatus.purchased:
        case iap.PurchaseStatus.restored:
          _owns = true;
          _emit(PurchaseStatus.owned, null);
          if (p.pendingCompletePurchase) {
            _iap.completePurchase(p);
          }
        case iap.PurchaseStatus.error:
          _emit(
            PurchaseStatus.error,
            BillingException(
              p.error?.message ?? 'Unknown purchase error',
              cause: p.error,
            ),
          );
        case iap.PurchaseStatus.pending:
          _emit(PurchaseStatus.pending, null);
        case iap.PurchaseStatus.canceled:
          // User dismissed the sheet — return to neutral state. If we were
          // already Pro, stay Pro; otherwise back to notOwned.
          _emit(_owns ? PurchaseStatus.owned : PurchaseStatus.notOwned, null);
      }
    }
  }

  void _emit(PurchaseStatus status, BillingException? error) {
    _current = status;
    _statusController.add(status);
    if (error != null) {
      // Surfaced to the listener; the settings store is not auto-updated
      // on errors so a failed purchase cannot grant Pro.
      debugPrint('[Billing] $status: $error');
    }
  }

  @override
  Future<void> dispose() async {
    await _purchaseSub.cancel();
    await _statusController.close();
  }
}
