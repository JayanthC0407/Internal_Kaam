import 'package:dio/dio.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_api_base.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/obdx_dio_client.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';

/// OBDX Credit Cards (`apiType: card` → `/digx-common/card/v1`).
/// docs/obdx/features/credit-cards.md. Common: the corporate menu has
/// credit cards too.
class ObdxCardsApi extends ObdxApiBase {
  ObdxCardsApi([ObdxDioClient? client]) : super(client ?? ObdxDioClient.instance);

  static const _creditCards = '/digx-common/card/v1/cards/credit';

  /// `GET …/cards/credit?expand=ALL` — `creditcards[]`
  /// (credit-card-listing/model.js:11-24, hooks.js:129).
  Future<ResponseHandler<Map<String, dynamic>>> fetchCreditCards() =>
      _get(_creditCards, const {'expand': 'ALL'});

  /// `GET …/cards/credit/{cardId}/statements/transactions` with `type`
  /// UNBILLED / BILLED (+ `statementMonth`/`statementYear` for billed).
  Future<ResponseHandler<Map<String, dynamic>>> fetchStatementTransactions(
    String cardId,
    Map<String, dynamic> queryParameters,
  ) =>
      _get('$_creditCards/${Uri.encodeComponent(cardId)}/statements/transactions', queryParameters);

  /// `GET /digx-common/dda/v1/demandDeposit/debitCards` — every debit card
  /// of the user, `debitCardDetails[]` (debit-card-list/model.js:15-23).
  /// apiType `dda`, so not under the card base.
  Future<ResponseHandler<Map<String, dynamic>>> fetchDebitCards() =>
      _get('/digx-common/dda/v1/demandDeposit/debitCards', const {});

  Future<ResponseHandler<Map<String, dynamic>>> _get(String path, Map<String, dynamic> query) async {
    try {
      final response = await dio.get(
        ObdxApiUtils.appendLocaleQuery(path),
        queryParameters: query,
        options: Options(headers: {ApiConst.contentTypeKey: ApiConst.contentTypeValue}),
      );
      return ResponseHandler.success(ObdxApiUtils.wrapHttpResponse(response));
    } on DioException catch (error) {
      return getErrorResponse(error);
    } catch (exc, stack) {
      return getExceptionErrorResponse(exc, stack);
    }
  }
}
