import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Manage Payee / Add Bank Account Payee / Demand Draft Payee / Peer-To-Peer
/// Payee APIs captured from the OBDX UI (see
/// Manage_Payee_API_Call_Sequence_Final_Flow_Updated_With_Peer_to_Peer_Payee).
///
/// International Payee, Demand Draft Payee and Peer-To-Peer Payee now have
/// confirmed submit endpoints and are wired up. The supplied API document
/// still does not contain a final Domestic Payee (Add Account Payee) submit
/// endpoint/payload — its IFSC verification failed before a submit call was
/// captured — so no unverified Domestic submit endpoint is invented.
class ObdxPayeeApi extends ObdxApiBase {
  ObdxPayeeApi([ObdxDioClient? client])
      : super(client ?? ObdxDioClient.instance);

  static const _maintenance =
      '/digx-payments/payment/v1/payments/maintenance';
  static const _customLimits = '/digx-admin/finlimit/v1/myCustomLimits';
  static const _assignedLimits = '/digx-admin/finlimit/v1/myAssignedLimits';
  static const _bankConfiguration =
      '/digx-common/common/v1/bankConfiguration';
  static const _payees = '/digx-payments/payment/v1/payments/payeesv3';
  static const _accountTypes =
      '/digx-payments/payment/v1/enumerations/payeeAccountType';
  static const _country = '/digx-payments/payment/v1/enumerations/country';
  static const _payeeContent =
      '/digx-payments/payment/v1/payments/maintenance/payeecontent';
  static const _fetchNetwork =
      '/digx-payments/payment/v1/payments/fetchNetwork';
  static const _fetchNetworkCodeDetails =
      '/digx-payments/payment/v1/payments/fetchNetworkCodeDetails';
  static const _internalPayee =
      '/digx-payments/payment/v1/payments/payeesv3/internal';
  static const _internationalPayee =
      '/digx-payments/payment/v1/payments/payeesv3/international';
  static const _internationalNetworkType =
      '/digx-payments/payment/v1/enumerations/networkType';
  static const _nationalClearingCodeType =
      '/digx-payments/payment/v1/enumerations/nationalClearingCodeType';
  static const _nationalClearingDetails =
      '/digx-payments/payment/v1/payments/financialInstitution/nationalClearingDetails';
  static const _payeeGroup = '/digx-payments/payment/v1/payments/payeeGroup';
  static const _effectiveToday =
      '/digx-admin/finlimit/v1/limitPackages/config/effectiveToday';
  static const _allCities =
      '/digx-common/location/v1/locations/country/all/city';
  static const _party = '/digx-common/user/v1/me/party';
  static const _addressType =
      '/digx-payments/payment/v1/enumerations/addressType';
  static const _branches = '/digx-common/location/v1/locations/branches';

  Future<ResponseHandler<Map<String, dynamic>>> fetchMaintenance() =>
      _get(_maintenance);

  Future<ResponseHandler<Map<String, dynamic>>> fetchCustomLimits() =>
      _get(_customLimits);

  Future<ResponseHandler<Map<String, dynamic>>> fetchAssignedLimits() =>
      _get(_assignedLimits);

  Future<ResponseHandler<Map<String, dynamic>>> fetchBankConfiguration() =>
      _get(_bankConfiguration);

  Future<ResponseHandler<Map<String, dynamic>>> fetchCountries() =>
      _get(_country);

  Future<ResponseHandler<Map<String, dynamic>>> fetchPayeeContent() =>
      _get(_payeeContent);

  Future<ResponseHandler<Map<String, dynamic>>> fetchAccountTypes({
    String region = 'INDIA',
  }) =>
      _get(_accountTypes, queryParameters: {'REGION': region});

  Future<ResponseHandler<Map<String, dynamic>>> fetchDomesticNetworks() =>
      _get(_fetchNetwork, queryParameters: {'paymentType': 'DOMESTIC'});

  /// Domestic Payee IFSC/BIC "Verify" — confirmed endpoint; the captured
  /// trace only shows the failure case (DIGX_NC_003, invalid code).
  Future<ResponseHandler<Map<String, dynamic>>> fetchNetworkCodeDetails({
    required String code,
    required String network,
  }) =>
      _get(
        '$_fetchNetworkCodeDetails/$code',
        queryParameters: {'network': network},
      );

  Future<ResponseHandler<Map<String, dynamic>>>
      fetchInternationalNetworkTypes() => _get(
            _internationalNetworkType,
            queryParameters: {'REGION': 'INTERNATIONAL'},
          );

  Future<ResponseHandler<Map<String, dynamic>>>
      fetchNationalClearingCodeTypes() => _get(_nationalClearingCodeType);

  /// International Payee "Verify" (National Clearing Code) — confirmed
  /// endpoint; the captured trace only shows the failure case (DIGX_PY_0273,
  /// no record found).
  Future<ResponseHandler<Map<String, dynamic>>> fetchNationalClearingDetails({
    required String country,
    required String codeType,
  }) =>
      _get('$_nationalClearingDetails/$country/$codeType');

  Future<ResponseHandler<Map<String, dynamic>>> fetchEffectiveToday() =>
      _get(_effectiveToday);

  Future<ResponseHandler<Map<String, dynamic>>> fetchAllCities() =>
      _get(_allCities);

  Future<ResponseHandler<Map<String, dynamic>>> fetchPartyDetails() =>
      _get(_party);

  Future<ResponseHandler<Map<String, dynamic>>> fetchAddressTypes() =>
      _get(_addressType);

  Future<ResponseHandler<Map<String, dynamic>>> fetchBranchCodeForCity(
    String city,
  ) =>
      _get('$_allCities/$city/branchCode');

  Future<ResponseHandler<Map<String, dynamic>>> fetchBranches(
    String branchCode,
  ) =>
      _get(_branches, queryParameters: {'branchCode': branchCode});

  Future<ResponseHandler<Map<String, dynamic>>> fetchPayees() => _get(
        _payees,
        queryParameters: {
          'types': 'INTERNAL,INTERNATIONAL,GENERICDOMESTIC',
        },
      );

  Future<ResponseHandler<Map<String, dynamic>>> createInternalPayee({
    required String nickname,
    required String accountNumber,
    required String accountName,
    required String payeeEmail,
    bool shared = false,
    String status = 'ACT',
    bool validateOnly = true,
  }) async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(_internalPayee),
        data: {
          'nickName': nickname,
          'status': status,
          'accountNumber': accountNumber,
          'accountName': accountName,
          'payeeEmail': payeeEmail,
          'shared': shared,
        },
        options: Options(
          headers: {
            ApiConst.contentTypeKey: ApiConst.contentTypeValue,
            'X-Validate-Only': validateOnly ? 'Y' : 'N',
          },
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// International Payee final submit — confirmed endpoint + payload shape.
  /// The captured trace's own attempt failed with DIGX_PY_0012 ("Bank code
  /// is a mandatory field") because `bankDetails` was left entirely null, so
  /// this fills `bankDetails` from whichever Pay Via variant the user chose.
  Future<ResponseHandler<Map<String, dynamic>>> createInternationalPayee({
    required String nickname,
    required String accountNumber,
    required String accountName,
    required String payeeEmail,
    required String network, // NAC | SPE | SWI
    required Map<String, dynamic> bankDetails,
    required Map<String, dynamic> address,
    bool shared = false,
    String status = 'ACT',
    String transferMode = 'ACC',
  }) async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(_internationalPayee),
        data: {
          'status': status,
          'nickName': nickname,
          'shared': shared,
          'accountNumber': accountNumber,
          'accountName': accountName,
          'transferMode': transferMode,
          'payeeEmail': payeeEmail,
          'network': network,
          'bankDetails': bankDetails,
          'address': address,
        },
        options: Options(
          headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue},
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// Shared final-submit endpoint for Demand Draft Payee (Domestic and
  /// International) and Peer-To-Peer Payee. The only field confirmed in the
  /// captured trace for either flow is `name`; the captured attempts both
  /// returned HTTP 403 / DIGX_PROD_ACCESS_DENIED_0000 rather than a
  /// validation error, so no further fields are confirmed and none are
  /// invented here.
  Future<ResponseHandler<Map<String, dynamic>>> submitPayeeGroup({
    required String name,
  }) async {
    try {
      final response = await dio.post(
        ObdxApiUtils.appendLocaleQuery(_payeeGroup),
        data: {'name': name},
        options: Options(
          headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue},
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  Future<ResponseHandler<Map<String, dynamic>>> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(path),
        queryParameters: queryParameters,
        options: Options(
          headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue},
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }
}
