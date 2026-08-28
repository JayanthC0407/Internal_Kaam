import 'package:pointycastle/export.dart';
import 'package:ubci_bank/src/core/utils/rsa_crypto_utils.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_auth_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Encrypts a plain password for OBDX using a fresh public key + salt round-trip.
class ObdxPasswordCryptoService {
  const ObdxPasswordCryptoService(this._authApi);

  final ObdxAuthApi _authApi;

  Future<ResponseHandler<String>> encryptForUser({
    required String userName,
    required String plainPassword,
  }) async {
    final publicKeyResult = await _authApi.getPublicKey();
    if (publicKeyResult is! Success<Map<String, dynamic>> ||
        publicKeyResult.data == null) {
      return _mapFailure(publicKeyResult);
    }

    final saltResult = await _authApi.getSalt(userName);
    if (saltResult is! Success<Map<String, dynamic>> ||
        saltResult.data == null) {
      return _mapFailure(saltResult);
    }

    try {
      final publicKeyDTO =
          publicKeyResult.data!['publicKeyDTO'] as Map<String, dynamic>?;
      final RSAPublicKey rsaKey;
      final modulusHex = publicKeyDTO?['modulus'] as String?;
      final exponentHex = publicKeyDTO?['publicExponent'] as String?;
      if (modulusHex != null && exponentHex != null) {
        rsaKey =
            RsaCryptoUtils.buildPublicKeyFromHex(modulusHex, exponentHex);
      } else {
        final publicKeyStr = (publicKeyDTO?['publicKey'] as String?) ??
            _authApi.extractPublicKey(publicKeyResult.data!);
        rsaKey = RsaCryptoUtils.parsePublicKeyPem(publicKeyStr);
      }

      return ResponseHandler.success(
        RsaCryptoUtils.encryptPassword(rsaKey, plainPassword),
      );
    } catch (e) {
      return ResponseHandler.error(0, 'Password encryption failed: $e');
    }
  }

  ResponseHandler<T> _mapFailure<T>(ResponseHandler<dynamic> result) {
    if (result is Error) {
      return ResponseHandler.error(
        result.code,
        result.error,
        requestId: result.requestId,
        obdxError: result.obdxError,
      );
    }
    if (result is NetworkError) {
      return ResponseHandler.networkError(obdxError: result.obdxError);
    }
    return ResponseHandler.exceptionError();
  }
}
