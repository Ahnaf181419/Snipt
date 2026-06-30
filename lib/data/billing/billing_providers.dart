import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings.dart';
import 'billing_service.dart';

/// Singleton billing service for the app lifetime. The interface lives in
/// [BillingService] so tests and a future RevenueCat port can supply a
/// different implementation by overriding this provider.
final billingServiceProvider = Provider<BillingService>((ref) {
  final service = IapBillingService();
  service.init();
  ref.onDispose(service.dispose);
  return service;
});

/// Bootstrap side-effects: runs a purchase restore on first read and pipes
/// the live billing status into the settings store so `isProProvider` stays
/// in sync with the store. This provider is intentionally
/// `keepAlive`-style: it should be touched once at app start (from
/// `main.dart` or `RootGate`) and the subscription lives for the app's
/// lifetime.
///
/// We use a [Provider] (not a Notifier) because the only side effect is
/// plumbing; the canonical state stays in the settings store.
final billingBootstrapProvider = Provider<void>((ref) {
  final service = ref.watch(billingServiceProvider);
  final controller = ref.read(settingsControllerProvider.notifier);

  // 1. Restore on startup so a fresh install on a device that already owns
  //    Pro gets the entitlement without a tap. Failure here is non-fatal —
  //    the user can always tap "Restore purchases" in Settings.
  //
  //    The restore is observation-only: we do NOT let it write the local
  //    isPro flag down to false. The flag can only be cleared by an explicit
  //    user action (manual restore button in settings, or uninstall). This
  //    protects users who flipped on a dev/QA flag, or who are testing Pro
  //    locally without a Play Store connection, from having their flag
  //    silently clobbered.
  unawaited(service.restore().catchError((Object e) {
    debugPrint('[Billing] startup restore failed: $e');
  }));

  // 2. Listen to status changes and ONLY mirror "owned" into the settings
  //    store. We do NOT mirror "notOwned" or "error" — those would silently
  //    revoke Pro. The user has to tap "Restore purchases" or uninstall to
  //    lose the flag.
  final sub = service.statusStream.listen((status) {
    if (status == PurchaseStatus.owned) {
      unawaited(controller.setPro(true));
    }
    // intentionally no `else if (notOwned) setPro(false)` — see comment above.
  });

  ref.onDispose(sub.cancel);
});

/// True when the user has a verified Pro entitlement. Reads from the
/// settings store so it is correct on the first frame, before the billing
/// restore completes.
final isProProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsControllerProvider).value;
  return settings?.isPro ?? false;
});

/// Live purchase status from the billing service. UI uses this to show
/// "Opening Google Play…" / "Last attempt failed" in the upgrade tile.
final purchaseStatusProvider = StreamProvider<PurchaseStatus>((ref) {
  final service = ref.watch(billingServiceProvider);
  // Yield the current value first so listeners don't sit on a spinner
  // while waiting for the next event.
  final controller = StreamController<PurchaseStatus>();
  controller.add(service.currentStatus);
  final sub = service.statusStream.listen(controller.add);
  ref.onDispose(() async {
    await sub.cancel();
    await controller.close();
  });
  return controller.stream;
});
