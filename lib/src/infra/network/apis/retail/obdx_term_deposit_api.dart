import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// Retail term deposit APIs (`/digx-common/td/v1`), as captured from the
/// OBDX retail TD screens (`TD.har`).
class ObdxTermDepositApi extends ObdxApiBase {
  ObdxTermDepositApi([ObdxDioClient? client])
      : super(client ?? ObdxDioClient.instance);

  static final _json = Options(
    headers: {ApiConst.contentTypeKey: 'application/json'},
  );

  /// `GET .../deposit?module=CON&module=ISL&status=ACTIVE[&status=CLOSED]`,
  /// optionally narrowed by an OBDX [taskCode] (`TD_F_TTD` top-up,
  /// `TD_F_RTD` redeem, `TD_N_ATD` maturity edit).
  Future<ResponseHandler<Map<String, dynamic>>> fetchDeposits({
    bool includeClosed = false,
    String? taskCode,
  }) =>
      _get(ApiConst.termDepositsApi, {
        'module': const ['CON', 'ISL'],
        'status': ['ACTIVE', if (includeClosed) 'CLOSED'],
        if (taskCode != null) 'taskCode': taskCode,
      });

  /// `GET .../deposit/{id};module=` → `termDepositDetails`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchDeposit(String id) =>
      _get(ApiConst.termDepositApi(id));

  /// `GET .../deposit/{id}/payOutInstructions;module=`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchPayoutInstructions(
    String id,
  ) =>
      _get(ApiConst.termDepositPayoutApi(id));

  /// `GET .../deposit/{id}/transactions` — [searchBy] is OBDX's period
  /// code (`CPR` current month, `PMT` previous month, `PQT` previous
  /// quarter, `LNT` last [noOfTransactions], `SPD` [fromDate]–[toDate] as
  /// `yyyy-MM-dd`); [transactionType] `A` all, `C` credits, `D` debits.
  Future<ResponseHandler<Map<String, dynamic>>> fetchTransactions(
    String id, {
    String searchBy = 'CPR',
    String transactionType = 'A',
    String? fromDate,
    String? toDate,
    int? noOfTransactions,
  }) =>
      _get(ApiConst.termDepositTransactionsApi(id), {
        'searchBy': searchBy,
        'transactionType': transactionType,
        if (fromDate != null) 'fromDate': fromDate,
        if (toDate != null) 'toDate': toDate,
        if (noOfTransactions != null) 'noOfTransactions': '$noOfTransactions',
      });

  /// `GET .../termDepositProducts?depositProductType=CON&productModule=TD`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchProducts() =>
      _get(ApiConst.termDepositProductsApi, {
        'depositProductType': 'CON',
        'productModule': 'TD',
      });

  /// `GET .../td/v1/enumerations/{name}`.
  Future<ResponseHandler<Map<String, dynamic>>> fetchEnumeration(
    String name,
  ) =>
      _get(ApiConst.termDepositEnumerationApi(name));

  /// `POST .../deposit/{id}/topUps` (`?simulation=true` to validate only).
  Future<ResponseHandler<Map<String, dynamic>>> topUp(
    String id,
    Map<String, dynamic> body, {
    bool simulation = false,
    String? challengeResponse,
  }) =>
      _send(
        'POST',
        ApiConst.termDepositTopUpsApi(id),
        body,
        query: {if (simulation) 'simulation': 'true'},
        challengeResponse: challengeResponse,
      );

  /// `POST .../deposit/{id}/penalities` — the redemption quote.
  Future<ResponseHandler<Map<String, dynamic>>> redemptionQuote(
    String id,
    Map<String, dynamic> body,
  ) =>
      _send('POST', ApiConst.termDepositPenaltiesApi(id), body);

  /// `POST .../deposit/{id}/redemptions`.
  Future<ResponseHandler<Map<String, dynamic>>> redeem(
    String id,
    Map<String, dynamic> body, {
    String? challengeResponse,
  }) =>
      _send(
        'POST',
        ApiConst.termDepositRedemptionsApi(id),
        body,
        challengeResponse: challengeResponse,
      );

  /// `PUT .../deposit/{id}` — new maturity instructions.
  Future<ResponseHandler<Map<String, dynamic>>> updateMaturity(
    String id,
    Map<String, dynamic> body, {
    String? challengeResponse,
  }) =>
      _send(
        'PUT',
        ApiConst.termDepositUpdateApi(id),
        body,
        challengeResponse: challengeResponse,
      );

  /// `POST .../deposit` — open a new deposit. [validateOnly] sends OBDX's
  /// `X-Validate-Only: Y`, which checks the request and answers the rate,
  /// maturity date and amount without opening anything (the review step).
  Future<ResponseHandler<Map<String, dynamic>>> openDeposit(
    Map<String, dynamic> body, {
    bool validateOnly = false,
    String? challengeResponse,
  }) =>
      _send(
        'POST',
        ApiConst.termDepositsApi,
        body,
        validateOnly: validateOnly,
        challengeResponse: challengeResponse,
      );

  /// CASA accounts a TD task may use — `GET .../dda/v1/demandDeposit
  /// ?taskCode=` (`TD_F_OTD` open, `TD_F_TTD` top-up, `TD_F_RTD` redeem,
  /// `TD_N_ATD` maturity edit).
  Future<ResponseHandler<Map<String, dynamic>>> fetchPayAccounts(
    String taskCode,
  ) =>
      _get(ApiConst.accountsApiDemandDeposit, {'taskCode': taskCode});

  /// `GET .../location/v1/locations/branches?branchCode=` — the branch's
  /// name and address, which an own-account payout carries.
  Future<ResponseHandler<Map<String, dynamic>>> fetchBranch(
    String branchCode,
  ) =>
      _get(ApiConst.branchLocationsApi, {'branchCode': branchCode});

  Future<ResponseHandler<Map<String, dynamic>>> _get(
    String path, [
    Map<String, dynamic> query = const {},
  ]) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(path),
        queryParameters: query,
        options: _json.copyWith(listFormat: ListFormat.multi),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }

  /// POST / PUT a JSON [body]. [challengeResponse] is the OTP retry's
  /// `X-CHALLENGE_RESPONSE` header. A `417` — OBDX asking for an OTP, with
  /// an `X-CHALLENGE` header — comes back as a success envelope so the
  /// repository can read the challenge, as for loan repayments.
  Future<ResponseHandler<Map<String, dynamic>>> _send(
    String method,
    String path,
    Map<String, dynamic> body, {
    Map<String, dynamic> query = const {},
    bool validateOnly = false,
    String? challengeResponse,
  }) async {
    try {
      final response = await dio.request(
        ObdxApiUtils.appendLocaleQuery(path),
        data: jsonEncode(body),
        queryParameters: query,
        options: Options(
          method: method,
          headers: {
            ApiConst.contentTypeKey: 'application/json',
            if (validateOnly) 'X-Validate-Only': 'Y',
            if (challengeResponse != null)
              'X-CHALLENGE_RESPONSE': challengeResponse,
          },
        ),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      final response = error.response;
      if (response != null && response.statusCode == 417) {
        return ResponseHandler.success(
          ObdxApiUtils.wrapHttpResponse(response),
        );
      }
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }
}
