import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:ubci_bank/src/infra/pref/pref_const.dart';
import 'package:ubci_bank/src/infra/pref/secure_storage_service.dart';

/// Generates and persists a stable per-install device identifier for OBDX.
class SecureDeviceIdService {
  SecureDeviceIdService._();

  static final SecureDeviceIdService instance = SecureDeviceIdService._();

  final SecureStorageService _secure = SecureStorageService.instance;

  /// Returns existing id or creates a new 16-char hex string (8 random bytes).
  Future<String> getOrCreate() async {
    final existing = await _secure.read(PrefConst.obdxSecureDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;

    final id = _generateHexId();
    await _secure.write(PrefConst.obdxSecureDeviceId, id);
    return id;
  }

  Future<void> clear() async {
    await _secure.delete(PrefConst.obdxSecureDeviceId);
  }

  @visibleForTesting
  String generateForTest() => _generateHexId();

  String _generateHexId() {
    final random = Random.secure();
    return List<int>.generate(8, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
