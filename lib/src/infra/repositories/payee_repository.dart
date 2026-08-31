import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/models/payee/payee_models.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_payee_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_error_mapper.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

class PayeeRepository {
  PayeeRepository({required ObdxPayeeApi payeeApi}) : _payeeApi = payeeApi;

  final ObdxPayeeApi _payeeApi;

  Future<ResponseHandler<Map<String, dynamic>>> fetchMaintenance() =>
      _payeeApi.fetchMaintenance();

  Future<ResponseHandler<Map<String, dynamic>>> fetchCustomLimits() =>
      _payeeApi.fetchCustomLimits();

  Future<ResponseHandler<Map<String, dynamic>>> fetchBankConfiguration() =>
      _payeeApi.fetchBankConfiguration();

  Future<ResponseHandler<Map<String, dynamic>>> fetchCountries() =>
      _payeeApi.fetchCountries();

  /// Typed country list for the International Payee / Demand Draft "Country"
  /// and "Draft Payable At" pickers. Uses the same confirmed
  /// `/enumerations/country` endpoint as [fetchCountries], parsed the same
  /// way [fetchAccountTypes] parses its `enumRepresentations`.
  Future<ResponseHandler<List<CountryOption>>> fetchCountryOptions() async {
    final result = await _payeeApi.fetchCountries();
    final bodyResult = _body(result);
    if (bodyResult == null) return _mapFailure(result);
    final body = bodyResult.body;
    if (!_isSuccess(body, bodyResult.statusCode)) {
      return _businessFailure(bodyResult.statusCode, body);
    }

    final enumRepresentations = body['enumRepresentations'];
    final first = enumRepresentations is List && enumRepresentations.isNotEmpty
        ? enumRepresentations.first
        : null;
    final data = first is Map ? first['data'] : null;
    final list = data is List
        ? data
            .whereType<Map>()
            .map((item) => CountryOption.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .toList()
        : <CountryOption>[];
    return ResponseHandler.success(list, code: bodyResult.statusCode);
  }

  Future<ResponseHandler<Map<String, dynamic>>> fetchAssignedLimits() =>
      _payeeApi.fetchAssignedLimits();

  Future<ResponseHandler<Map<String, dynamic>>> fetchPayeeContent() =>
      _payeeApi.fetchPayeeContent();

  Future<ResponseHandler<List<PayeeSummary>>> fetchPayees() async {
    final result = await _payeeApi.fetchPayees();
    final bodyResult = _body(result);
    if (bodyResult == null) return _mapFailure(result);
    final body = bodyResult.body;
    if (!_isSuccess(body, bodyResult.statusCode)) {
      return _businessFailure(bodyResult.statusCode, body);
    }

    final raw = body['listPayees'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((item) => PayeeSummary.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .toList()
        : <PayeeSummary>[];
    return ResponseHandler.success(list, code: bodyResult.statusCode);
  }

  Future<ResponseHandler<List<PayeeAccountTypeOption>>> fetchAccountTypes() async {
    final result = await _payeeApi.fetchAccountTypes();
    final bodyResult = _body(result);
    if (bodyResult == null) return _mapFailure(result);
    final body = bodyResult.body;
    if (!_isSuccess(body, bodyResult.statusCode)) {
      return _businessFailure(bodyResult.statusCode, body);
    }

    final enumRepresentations = body['enumRepresentations'];
    final first = enumRepresentations is List && enumRepresentations.isNotEmpty
        ? enumRepresentations.first
        : null;
    final data = first is Map ? first['data'] : null;
    final list = data is List
        ? data
            .whereType<Map>()
            .map((item) => PayeeAccountTypeOption.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .toList()
        : <PayeeAccountTypeOption>[];
    return ResponseHandler.success(list, code: bodyResult.statusCode);
  }

  Future<ResponseHandler<List<DomesticNetworkOption>>>
      fetchDomesticNetworks() async {
    final result = await _payeeApi.fetchDomesticNetworks();
    final bodyResult = _body(result);
    if (bodyResult == null) return _mapFailure(result);
    final body = bodyResult.body;
    if (!_isSuccess(body, bodyResult.statusCode)) {
      return _businessFailure(bodyResult.statusCode, body);
    }

    final raw = body['network'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((item) => DomesticNetworkOption.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .where((item) => item.enabled)
            .toList()
        : <DomesticNetworkOption>[];
    return ResponseHandler.success(list, code: bodyResult.statusCode);
  }

  Future<ResponseHandler<void>> createInternalPayee({
    required String nickname,
    required String accountNumber,
    required String accountName,
    required String payeeEmail,
  }) async {
    final result = await _payeeApi.createInternalPayee(
      nickname: nickname,
      accountNumber: accountNumber,
      accountName: accountName,
      payeeEmail: payeeEmail,
      validateOnly: true,
    );
    final bodyResult = _body(result);
    if (bodyResult == null) return _mapFailure(result);
    final body = bodyResult.body;

    // Captured API returns HTTP 200 + result SUCCESSFUL even for a business
    // validation failure, with message.type = ERROR.
    if (ObdxApiUtils.hasErrorMessage(body)) {
      return _businessFailure(bodyResult.statusCode, body);
    }
    if (!_isSuccess(body, bodyResult.statusCode)) {
      return _businessFailure(bodyResult.statusCode, body);
    }
    return ResponseHandler.success(null, code: bodyResult.statusCode);
  }

  _BodyResult? _body(ResponseHandler<Map<String, dynamic>> result) {
    if (result is! Success<Map<String, dynamic>> || result.data == null) {
      return null;
    }
    final wrapped = result.data!;
    final statusCode = wrapped['statusCode'] as int? ?? 0;
    final body = ObdxApiUtils.asMap(wrapped['body'] ?? wrapped['rawBody']);
    return _BodyResult(statusCode, body);
  }

  bool _isSuccess(Map<String, dynamic> body, int statusCode) {
    if (statusCode != StatusCode.OK) return false;
    return ObdxApiUtils.isSuccessfulPayload(body) ||
        (!body.containsKey('status') && !body.containsKey('result'));
  }

  ResponseHandler<T> _businessFailure<T>(
    int statusCode,
    Map<String, dynamic> body,
  ) {
    final obdxError = ObdxErrorMapper.fromHttpResponse(statusCode, body);
    return ResponseHandler.error(
      obdxError.httpStatusCode ?? statusCode,
      obdxError.userMessage,
      obdxError: obdxError,
    );
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

class _BodyResult {
  const _BodyResult(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;
}
