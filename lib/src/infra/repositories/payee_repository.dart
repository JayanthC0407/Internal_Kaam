import 'dart:convert';

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

  Future<ResponseHandler<Map<String, dynamic>>> fetchEffectiveToday() =>
      _payeeApi.fetchEffectiveToday();

  /// International Payee "Pay Via" network types (NAC / SPE / SWI).
  Future<ResponseHandler<List<PayeeEnumOption>>>
      fetchInternationalNetworkTypes() async {
    final result = await _payeeApi.fetchInternationalNetworkTypes();
    return _parseEnumOptionList(result);
  }

  /// National clearing code "type" (SC = BANK_IDENTIFIER_CODE_FROM_SWIFT),
  /// used as the second path segment for [verifyNationalClearingCode].
  Future<ResponseHandler<List<PayeeEnumOption>>>
      fetchNationalClearingCodeTypes() async {
    final result = await _payeeApi.fetchNationalClearingCodeTypes();
    return _parseEnumOptionList(result);
  }

  /// Demand Draft Payee address type (WRK/RES/PST = Work/Residence/Postal).
  Future<ResponseHandler<List<PayeeEnumOption>>> fetchAddressTypes() async {
    final result = await _payeeApi.fetchAddressTypes();
    return _parseEnumOptionList(result);
  }

  Future<ResponseHandler<List<PayeeEnumOption>>> _parseEnumOptionList(
    ResponseHandler<Map<String, dynamic>> result,
  ) async {
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
            .map((item) => PayeeEnumOption.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .toList()
        : <PayeeEnumOption>[];
    return ResponseHandler.success(list, code: bodyResult.statusCode);
  }

  /// Domestic Payee "Verify" (IFSC/BIC code). Confirmed endpoint; only the
  /// failure case (DIGX_NC_003) was captured, so success is reported when
  /// the response has no error message rather than by matching a specific
  /// field.
  Future<ResponseHandler<Map<String, dynamic>>> verifyNetworkCode({
    required String code,
    required String network,
  }) async {
    final result = await _payeeApi.fetchNetworkCodeDetails(
      code: code,
      network: network,
    );
    final bodyResult = _body(result);
    if (bodyResult == null) return _mapFailure(result);
    final body = bodyResult.body;
    if (ObdxApiUtils.hasErrorMessage(body) ||
        !_isSuccess(body, bodyResult.statusCode)) {
      return _businessFailure(bodyResult.statusCode, body);
    }
    return ResponseHandler.success(body, code: bodyResult.statusCode);
  }

  /// International Payee "Verify" (National Clearing Code). Confirmed
  /// endpoint; only the failure case (DIGX_PY_0273 — no record found) was
  /// captured.
  Future<ResponseHandler<Map<String, dynamic>>> verifyNationalClearingCode({
    required String country,
    required String codeType,
  }) async {
    final result = await _payeeApi.fetchNationalClearingDetails(
      country: country,
      codeType: codeType,
    );
    final bodyResult = _body(result);
    if (bodyResult == null) return _mapFailure(result);
    final body = bodyResult.body;
    if (ObdxApiUtils.hasErrorMessage(body) ||
        !_isSuccess(body, bodyResult.statusCode)) {
      return _businessFailure(bodyResult.statusCode, body);
    }
    return ResponseHandler.success(body, code: bodyResult.statusCode);
  }

  /// City/location list for the Demand Draft Payee "Draft Payable At" /
  /// "City" pickers. See [CityOption] for why parsing is lenient.
  Future<ResponseHandler<List<CityOption>>> fetchCities() async {
    final result = await _payeeApi.fetchAllCities();
    final raw = _rawResult(result);
    if (raw == null) return _mapFailure(result);
    if (!_isSuccess(raw.body, raw.statusCode)) {
      return _businessFailure(raw.statusCode, raw.body);
    }
    final items = _extractList(
      raw.body,
      raw.rawBody,
      const ['data', 'list', 'cities', 'city'],
    );
    return ResponseHandler.success(
      items.map(CityOption.fromValue).toList(),
      code: raw.statusCode,
    );
  }

  /// Branch options for a selected city
  /// (`.../country/all/city/{city}/branchCode`). Returns the first match —
  /// the captured trace showed a single NMB / NMB BANK PLC result for TZ.
  Future<ResponseHandler<BranchOption?>> fetchBranchForCity(
    String city,
  ) async {
    final result = await _payeeApi.fetchBranchCodeForCity(city);
    final raw = _rawResult(result);
    if (raw == null) return _mapFailure(result);
    if (!_isSuccess(raw.body, raw.statusCode)) {
      return _businessFailure(raw.statusCode, raw.body);
    }
    final items = _extractList(
      raw.body,
      raw.rawBody,
      // Confirmed key from the real response: {"branchAddressDTO": [...]}.
      const ['branchAddressDTO', 'data', 'list', 'branches', 'branchCode'],
    );
    final branch = items.isNotEmpty
        ? BranchOption.fromValue(items.first)
        : (raw.body.containsKey('id') ||
                raw.body.containsKey('branchCode') ||
                raw.body.containsKey('code')
            ? BranchOption.fromValue(raw.body)
            : null);
    return ResponseHandler.success(branch, code: raw.statusCode);
  }

  /// Resolved branch/address details for the "Branch Near Me" preview.
  ///
  /// Unlike `.../city/{city}/branchCode` (which lists every branch for a
  /// city and returns `branchAddressDTO` as a JSON array),
  /// `.../locations/branches?branchCode=...` resolves a *single* branch and
  /// OBDX returns `branchAddressDTO` as a bare JSON object in that case.
  /// `_extractList` only ever matches array values, so the object form was
  /// silently falling through to the outer envelope and producing an empty
  /// [BranchAddress] — this is why the dropdown resolved but the address
  /// preview never rendered. Handle both shapes here.
  Future<ResponseHandler<BranchAddress?>> fetchBranchAddress(
    String branchCode,
  ) async {
    final result = await _payeeApi.fetchBranches(branchCode);
    final raw = _rawResult(result);
    if (raw == null) return _mapFailure(result);
    if (!_isSuccess(raw.body, raw.statusCode)) {
      return _businessFailure(raw.statusCode, raw.body);
    }
    // Confirmed real key from a captured trace: {"addressDTO": [{...}]}.
    // Older guesses (branchAddressDTO/data/list/branches) kept as fallbacks
    // in case a different OBDX environment/version shapes this differently.
    const candidateKeys = [
      'addressDTO',
      'branchAddressDTO',
      'data',
      'list',
      'branches',
    ];
    final items = _extractList(raw.body, raw.rawBody, candidateKeys);

    Map<String, dynamic>? map;
    if (items.isNotEmpty && items.first is Map) {
      // List form (defensive — matches fetchBranchForCity's shape).
      map = Map<String, dynamic>.from(items.first as Map);
    } else {
      // Single-object form: the actual response shape for a branchCode
      // lookup. Check the same candidate keys for a nested Map before
      // falling back to the raw envelope.
      for (final key in candidateKeys) {
        final value = raw.body[key];
        if (value is Map) {
          map = Map<String, dynamic>.from(value);
          break;
        }
      }
      final rawDecoded = raw.rawBody.isNotEmpty ? _tryDecode(raw.rawBody) : null;
      if (map == null && rawDecoded is Map) {
        for (final key in candidateKeys) {
          final value = rawDecoded[key];
          if (value is Map) {
            map = Map<String, dynamic>.from(value);
            break;
          }
        }
      }
      map ??= raw.body;
    }

    final address = BranchAddress.fromMap(map);
    return ResponseHandler.success(
      address.isEmpty ? null : address,
      code: raw.statusCode,
    );
  }

  dynamic _tryDecode(String rawBody) {
    try {
      return jsonDecode(rawBody);
    } catch (_) {
      return null;
    }
  }

  /// Logged-in user's saved addresses (Postal/Residence/Work), used for the
  /// Demand Draft Payee "My Address" preview.
  Future<ResponseHandler<List<PartyAddress>>> fetchPartyAddresses() async {
    final result = await _payeeApi.fetchPartyDetails();
    final bodyResult = _body(result);
    if (bodyResult == null) return _mapFailure(result);
    final body = bodyResult.body;
    if (!_isSuccess(body, bodyResult.statusCode)) {
      return _businessFailure(bodyResult.statusCode, body);
    }
    return ResponseHandler.success(
      PartyAddress.listFromPartyResponse(body),
      code: bodyResult.statusCode,
    );
  }

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

  /// International Payee final submit. Confirmed endpoint + payload shape;
  /// the captured attempt itself failed validation (DIGX_PY_0012 — Bank
  /// code is a mandatory field) because bankDetails was left empty, so a
  /// real submission still depends on the caller populating bankDetails
  /// correctly for the chosen Pay Via option.
  Future<ResponseHandler<void>> createInternationalPayee({
    required String nickname,
    required String accountNumber,
    required String accountName,
    required String payeeEmail,
    required String network,
    required Map<String, dynamic> bankDetails,
    required Map<String, dynamic> address,
  }) async {
    final result = await _payeeApi.createInternationalPayee(
      nickname: nickname,
      accountNumber: accountNumber,
      accountName: accountName,
      payeeEmail: payeeEmail,
      network: network,
      bankDetails: bankDetails,
      address: address,
    );
    final bodyResult = _body(result);
    if (bodyResult == null) return _mapFailure(result);
    final body = bodyResult.body;
    if (ObdxApiUtils.hasErrorMessage(body) ||
        !_isSuccess(body, bodyResult.statusCode)) {
      return _businessFailure(bodyResult.statusCode, body);
    }
    return ResponseHandler.success(null, code: bodyResult.statusCode);
  }

  /// Shared final-submit for Demand Draft Payee (Domestic/International)
  /// and Peer-To-Peer Payee. See [ObdxPayeeApi.submitPayeeGroup] — only
  /// `name` is a confirmed field; the captured attempts both returned HTTP
  /// 403 (DIGX_PROD_ACCESS_DENIED_0000 / FC_SM_025) because the test user
  /// lacked permission, not because of a validation error.
  Future<ResponseHandler<void>> submitPayeeGroup({required String name}) async {
    final result = await _payeeApi.submitPayeeGroup(name: name);
    final bodyResult = _body(result);
    if (bodyResult == null) return _mapFailure(result);
    final body = bodyResult.body;
    if (ObdxApiUtils.hasErrorMessage(body) ||
        !_isSuccess(body, bodyResult.statusCode)) {
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

  /// Like [_body], but also keeps the raw response string so [_extractList]
  /// can recover data from endpoints that return a bare JSON array (which
  /// [ObdxApiUtils.asMap] otherwise collapses to `{}`).
  _RawResult? _rawResult(ResponseHandler<Map<String, dynamic>> result) {
    if (result is! Success<Map<String, dynamic>> || result.data == null) {
      return null;
    }
    final wrapped = result.data!;
    final statusCode = wrapped['statusCode'] as int? ?? 0;
    final body = ObdxApiUtils.asMap(wrapped['body']);
    final rawBody = wrapped['rawBody']?.toString() ?? '';
    return _RawResult(statusCode, body, rawBody);
  }

  /// Best-effort list extraction for endpoints whose exact JSON envelope
  /// wasn't in the captured document (city/branch lookups). Tries the
  /// common wrapper keys first, then falls back to parsing the raw response
  /// body directly as a JSON list.
  List<dynamic> _extractList(
    Map<String, dynamic> body,
    String rawBody,
    List<String> candidateKeys,
  ) {
    for (final key in candidateKeys) {
      final value = body[key];
      if (value is List) return value;
    }
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is List) return decoded;
      if (decoded is Map) {
        for (final key in candidateKeys) {
          final value = decoded[key];
          if (value is List) return value;
        }
      }
    } catch (_) {
      // rawBody wasn't valid standalone JSON — nothing more to try.
    }
    return const [];
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

class _RawResult {
  const _RawResult(this.statusCode, this.body, this.rawBody);

  final int statusCode;
  final Map<String, dynamic> body;
  final String rawBody;
}