import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

class RsaCryptoUtils {
  static String encryptPassword(RSAPublicKey rsaKey, String password) {
    final plainBytes = Uint8List.fromList(utf8.encode(password));
    final cipher = PKCS1Encoding(RSAEngine());
    cipher.init(true, PublicKeyParameter<RSAPublicKey>(rsaKey));
    final encrypted = _processInBlocks(cipher, plainBytes);
    return Uri.encodeComponent(base64.encode(encrypted));
  }

  static RSAPublicKey buildPublicKeyFromHex(
    String modulusHex,
    String exponentHex,
  ) {
    final modulus = BigInt.parse(modulusHex, radix: 16);
    final exponent = BigInt.parse(exponentHex, radix: 16);
    return RSAPublicKey(modulus, exponent);
  }

  static RSAPublicKey parsePublicKeyPem(String keyStr) {
    final cleaned = keyStr
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll('-----BEGIN RSA PUBLIC KEY-----', '')
        .replaceAll('-----END RSA PUBLIC KEY-----', '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .trim();

    final keyBytes = base64.decode(cleaned);
    final asn1Parser = ASN1Parser(Uint8List.fromList(keyBytes));
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;

    BigInt modulus;
    BigInt exponent;

    if (topLevelSeq.elements != null &&
        topLevelSeq.elements!.isNotEmpty &&
        topLevelSeq.elements![0] is ASN1Sequence) {
      final bitString = topLevelSeq.elements![1] as ASN1BitString;
      final pubKeyBytes = bitString.stringValues as Uint8List;
      final innerParser = ASN1Parser(pubKeyBytes.sublist(1));
      final innerSeq = innerParser.nextObject() as ASN1Sequence;
      modulus = (innerSeq.elements![0] as ASN1Integer).integer!;
      exponent = (innerSeq.elements![1] as ASN1Integer).integer!;
    } else {
      modulus = (topLevelSeq.elements![0] as ASN1Integer).integer!;
      exponent = (topLevelSeq.elements![1] as ASN1Integer).integer!;
    }

    return RSAPublicKey(modulus, exponent);
  }

  static Uint8List _processInBlocks(
    AsymmetricBlockCipher engine,
    Uint8List input,
  ) {
    final blockSize = engine.inputBlockSize;
    final numBlocks = (input.length / blockSize).ceil();
    final output = BytesBuilder();
    for (var i = 0; i < numBlocks; i++) {
      final start = i * blockSize;
      final end =
          start + blockSize < input.length ? start + blockSize : input.length;
      output.add(engine.process(input.sublist(start, end)));
    }
    return output.toBytes();
  }
}
