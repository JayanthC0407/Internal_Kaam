import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Encrypts the OBDX JWT setup token with a key derived from PIN or pattern.
///
/// Payload format (Base64): `salt(16) || iv(16) || ciphertext`.
class AlternateLoginCrypto {
  AlternateLoginCrypto._();

  static const int _iterations = 100000;
  static const int _keyLength = 32;
  static const int _saltLength = 16;
  static const int _ivLength = 16;

  /// Encodes a pattern as a stable secret string (e.g. `0-1-4-7`).
  static String patternSecret(List<int> dots) => dots.join('-');

  static String encrypt({
    required String plaintext,
    required String secret,
  }) {
    final salt = _randomBytes(_saltLength);
    final iv = _randomBytes(_ivLength);
    final key = _deriveKey(secret, salt);
    final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
      ..init(
        true,
        PaddedBlockCipherParameters(
          ParametersWithIV(KeyParameter(key), iv),
          null,
        ),
      );
    final encrypted =
        cipher.process(Uint8List.fromList(utf8.encode(plaintext)));
    final out = BytesBuilder(copy: false)
      ..add(salt)
      ..add(iv)
      ..add(encrypted);
    return base64Encode(out.toBytes());
  }

  /// Returns plaintext on success, or `null` if the secret is wrong / payload corrupt.
  static String? decrypt({
    required String payload,
    required String secret,
  }) {
    try {
      final raw = base64Decode(payload);
      if (raw.length < _saltLength + _ivLength + 16) return null;
      final salt = Uint8List.fromList(raw.sublist(0, _saltLength));
      final iv = Uint8List.fromList(
        raw.sublist(_saltLength, _saltLength + _ivLength),
      );
      final cipherText = Uint8List.fromList(
        raw.sublist(_saltLength + _ivLength),
      );
      final key = _deriveKey(secret, salt);
      final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
        ..init(
          false,
          PaddedBlockCipherParameters(
            ParametersWithIV(KeyParameter(key), iv),
            null,
          ),
        );
      final decrypted = cipher.process(cipherText);
      return utf8.decode(decrypted);
    } catch (_) {
      return null;
    }
  }

  static Uint8List _deriveKey(String secret, Uint8List salt) {
    final derivator = KeyDerivator('SHA-256/HMAC/PBKDF2')
      ..init(Pbkdf2Parameters(salt, _iterations, _keyLength));
    return derivator.process(Uint8List.fromList(utf8.encode(secret)));
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
