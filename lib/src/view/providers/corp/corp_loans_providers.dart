import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/service_requests/service_request_models.dart';
import 'package:ubci_bank/src/core/models/corp/corp_loans_models.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_loans_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_loans_repository.dart';
import 'package:ubci_bank/src/view/providers/common/network_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_profile_providers.dart';

/// Corporate Loans & Finances. autoDispose: loaded while a screen is open.

final obdxCorpLoansApiProvider = Provider((ref) => ObdxCorpLoansApi(ref.watch(obdxDioClientProvider)));

final corpLoansRepositoryProvider = Provider((ref) => CorpLoansRepository(api: ref.watch(obdxCorpLoansApiProvider)));

T _unwrap<T>(ResponseHandler<T> result) {
  if (result is Success<T> && result.data != null) return result.data as T;
  throw CorpLoansLoadError(result is Error<T> ? result.error : null);
}

/// The Loan Account list.
final corpLoansProvider = FutureProvider.autoDispose<List<CorpLoan>>(
  (ref) async => _unwrap(await ref.read(corpLoansRepositoryProvider).fetchLoans()),
);

/// A loan's transactions for a search.
final corpLoanTransactionsProvider =
    FutureProvider.autoDispose.family<({List<CorpLoanTxn> items, bool showValueDate}), (String, CorpLoanTxnQuery)>(
  (ref, args) async => _unwrap(await ref.read(corpLoansRepositoryProvider).fetchTransactions(args.$1, args.$2)),
);

/// A loan's messages or advices.
final corpLoanNoticesProvider = FutureProvider.autoDispose.family<List<CorpLoanNotice>, (String, CorpLoanNoticeKind)>(
  (ref, args) async => _unwrap(await ref.read(corpLoansRepositoryProvider).fetchNotices(args.$1, args.$2)),
);

/// CASA accounts for the repayment's source accounts.
final corpRepaymentSourceAccountsProvider = FutureProvider.autoDispose<List<SrAccount>>(
  (ref) async => _unwrap(await ref.read(corpLoansRepositoryProvider).fetchSourceAccounts()),
);

/// The signed-in company's party id; waits while the profile loads.
final corpLoansPartyIdProvider = FutureProvider.autoDispose<String>((ref) async {
  final (partyId, loading) = ref.watch(corpProfileProvider.select((s) => (s.party?.id, s.isLoading)));
  if (partyId == null || partyId.isEmpty) {
    if (loading) return Completer<String>().future;
    throw const CorpLoansLoadError('Your company details could not be loaded.');
  }
  return partyId;
});

/// Application Tracker: one tab's applications.
final corpLoanApplicationsByStatusProvider = FutureProvider.autoDispose.family<List<CorpLoanApplicationItem>, CorpAppStatus>(
  (ref, status) async {
    final partyId = await ref.watch(corpLoansPartyIdProvider.future);
    return _unwrap(await ref.read(corpLoansRepositoryProvider).fetchApplications(status, partyId: partyId));
  },
);

/// An application's documents.
final corpLoanApplicationDocumentsProvider = FutureProvider.autoDispose.family<List<CorpAppDocument>, String>((ref, refId) async {
  final partyId = await ref.watch(corpLoansPartyIdProvider.future);
  return _unwrap(await ref.read(corpLoansRepositoryProvider).fetchDocuments(refId, partyId));
});

/// Load failure; [message] is OBDX's text when the server sent one.
class CorpLoansLoadError implements Exception {
  const CorpLoansLoadError(this.message);

  final String? message;

  @override
  String toString() => message ?? 'CorpLoansLoadError';
}
