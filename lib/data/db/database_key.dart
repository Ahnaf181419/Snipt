import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Generates and persists the SQLCipher encryption key in the Android Keystore.
///
/// The key is a 256-bit (32-byte) random value hex-encoded as a 64-char string.
/// It is created once on first launch and reused for every subsequent open.
/// If the key is lost (e.g. user clears app data), the database is unrecoverable.
class DatabaseKeyManager {
  const DatabaseKeyManager._();

  static const _storage = FlutterSecureStorage();
  static const _keyField = 'snipt_db_key';

  /// Returns the existing key, or generates and persists a new one on first call.
  static Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _keyField);
    if (existing != null) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final key =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _keyField, value: key);
    return key;
  }
}
