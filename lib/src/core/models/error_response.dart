import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';

/// Legacy model — prefer [ObdxError] via [ObdxErrorMapper].
class ErrorResponse {
  ErrorResponse({this.errorMessage});

  factory ErrorResponse.fromJson(dynamic json) {
    final obdxError = ObdxErrorMapper.fromPayload(json);
    if (obdxError != null) {
      return ErrorResponse(errorMessage: obdxError.userMessage);
    }
    return ErrorResponse(errorMessage: json?.toString());
  }

  final String? errorMessage;
}
