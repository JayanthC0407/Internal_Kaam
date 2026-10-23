import 'package:ubci_bank/src/core/models/common/cards/credit_card_models.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_cards_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/obdx_repository_base.dart';

/// Credit Cards — parses [ObdxCardsApi] responses into
/// `credit_card_models.dart` (docs/obdx/features/credit-cards.md).
class CardsRepository extends ObdxRepositoryBase {
  CardsRepository({required ObdxCardsApi api}) : _api = api;

  final ObdxCardsApi _api;

  Future<ResponseHandler<List<CreditCard>>> fetchCreditCards() async =>
      parseBody(await _api.fetchCreditCards(), CreditCard.listFromPayload);

  Future<ResponseHandler<CardStatementResult>> fetchTransactions(CardTransactionsQuery query) async =>
      parseBody(
        await _api.fetchStatementTransactions(query.cardId, query.toQueryParameters()),
        CardStatementResult.fromPayload,
      );
}
