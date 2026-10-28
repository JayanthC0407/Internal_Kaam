import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/cards/credit_card_models.dart';
import 'package:ubci_bank/src/core/models/common/cards/debit_card_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';

/// Credit Cards (docs/obdx/features/credit-cards.md). autoDispose: loaded
/// when a screen (or the Home card tab) shows cards, dropped afterwards and
/// on logout.

/// `GET cards/credit?expand=ALL`.
final creditCardsProvider = FutureProvider.autoDispose<List<CreditCard>>((ref) async {
  final result = await ref.read(cardsRepositoryProvider).fetchCreditCards();
  if (result is Success<List<CreditCard>> && result.data != null) return result.data!;
  throw CardsLoadError(result is Error<List<CreditCard>> ? result.error : null);
});

/// Card transactions for one search (card, Unbilled/Billed, month).
final cardTransactionsProvider = FutureProvider.autoDispose
    .family<CardStatementResult, CardTransactionsQuery>((ref, query) async {
  final result = await ref.read(cardsRepositoryProvider).fetchTransactions(query);
  if (result is Success<CardStatementResult> && result.data != null) return result.data!;
  throw CardsLoadError(result is Error<CardStatementResult> ? result.error : null);
});

/// Debit Cards: `GET dda demandDeposit/debitCards` (debit-cards.md).
final debitCardsProvider = FutureProvider.autoDispose<List<DebitCard>>((ref) async {
  final result = await ref.read(cardsRepositoryProvider).fetchDebitCards();
  if (result is Success<List<DebitCard>> && result.data != null) return result.data!;
  throw CardsLoadError(result is Error<List<DebitCard>> ? result.error : null);
});

/// Load failure; [message] is OBDX's text when the server sent one.
class CardsLoadError implements Exception {
  const CardsLoadError(this.message);

  final String? message;

  @override
  String toString() => message ?? 'CardsLoadError';
}
