import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../data/settings.dart';

/// Shown when app lock is enabled and the session is not yet unlocked.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _authenticating = false;
  String? _error;
  // Set when biometrics are unavailable/unenrolled so the user isn't stuck.
  bool _showDisableLock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _error = null;
      _showDisableLock = false;
    });
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: 'Unlock snipt',
        persistAcrossBackgrounding: true,
      );
      if (ok && mounted) {
        ref.read(sessionUnlockedProvider.notifier).state = true;
      } else if (mounted) {
        setState(() => _error = 'Authentication failed. Try again.');
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      // These codes mean no biometrics are set up on the device. Show an
      // escape hatch so the user is never permanently locked out of their data.
      const unrecoverable = {'NotEnrolled', 'notEnrolled', 'NotAvailable'};
      if (unrecoverable.contains(e.code)) {
        setState(() {
          _error = 'No biometrics available on this device.';
          _showDisableLock = true;
        });
      } else {
        setState(() => _error = 'Authentication error: ${e.message}');
      }
    } on Exception catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  Future<void> _disableLock() async {
    await ref
        .read(settingsControllerProvider.notifier)
        .setLockEnabled(false);
    if (mounted) {
      ref.read(sessionUnlockedProvider.notifier).state = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 64, color: scheme.primary),
            const SizedBox(height: 16),
            Text('snipt is locked',
                style: Theme.of(context).textTheme.titleLarge),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _authenticating ? null : _authenticate,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Unlock'),
            ),
            if (_showDisableLock) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _disableLock,
                child: const Text('Disable app lock'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
