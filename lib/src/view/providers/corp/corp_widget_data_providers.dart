import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations_helper.dart';
import 'package:ubci_bank/src/core/models/corp/corp_account.dart';
import 'package:ubci_bank/src/core/models/corp/corp_cash_collection.dart';
import 'package:ubci_bank/src/core/models/corp/corp_loan_application.dart';
import 'package:ubci_bank/src/core/models/corp/corp_loan_record.dart';
import 'package:ubci_bank/src/core/models/retail/loan_account.dart';
import 'package:ubci_bank/src/core/models/retail/loan_account_details.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_process_management_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_lending_repository.dart';
import 'package:ubci_bank/src/infra/repositories/retail/accounts_repository.dart';
import 'package:ubci_bank/src/view/providers/common/network_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_cash_management_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_profile_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_repository_providers.dart';
import 'package:ubci_bank/src/view/providers/retail/accounts_providers.dart';
import 'package:ubci_bank/src/view/providers/retail/loan_providers.dart';

/// Data for the Corporate dashboard's Loans, Term Deposit and Cash
/// Withdrawal widgets, from the calls the widgets capture shows the web
/// client making.
///
/// Each is a `FutureProvider.autoDispose`: it loads when the first widget
/// that needs it is on screen, is shared by every widget that needs it (the
/// four Loans widgets make one set of calls between them), and is dropped
/// when none is — a widget the user has not chosen costs no request, and
/// signing out leaves nothing behind for the next user.
///
/// They return the host's records; the widgets work out their figures
/// from them (see the `*_live_data.dart` files beside each widget).

/// A load that failed, with the message to show on the widget.
class CorpWidgetLoadError implements Exception {
  const CorpWidgetLoadError(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<Never> _fail(ResponseHandler<dynamic> result) async {
  final l10n = await AppLocalizationsHelper.current();
  throw CorpWidgetLoadError(result.resolveUserMessage(l10n: l10n));
}

/// The bank's business date — "today" for due dates and date ranges.
///
/// The host judges dates by it, not by the device's clock: the web client's
/// cash-withdrawal requests, sent with the device's date, were refused with
/// `DATE006` "The date is not valid". Falls back to the device's date when
/// the host does not answer, so the widgets still load.
final corpBusinessDateProvider =
    FutureProvider.autoDispose<DateTime>((ref) async {
  final result =
      await ref.read(accountsRepositoryProvider).fetchCurrentBankingDate();
  final date = result is Success<BankingDate> ? result.data?.currentDate : null;
  final now = date ?? DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// At most this many loans get the detail call behind their rate, EMI and
/// maturity; the rest still count towards the balances.
const int corpLoanDetailLimit = 20;

/// `loan/v1/loan`, then `loan/v1/loan/{id}` for each loan.
///
/// A detail call that fails leaves that loan with its list figures only —
/// the balances are still right, the rate and dates show as not available
/// — rather than failing all four widgets over one loan.
final corpLoanRecordsProvider = FutureProvider.autoDispose<
    ({List<CorpLoanRecord> records, DateTime today})>((ref) async {
  final today = await ref.watch(corpBusinessDateProvider.future);
  final repository = ref.read(loanRepositoryProvider);

  final list = await repository.fetchLoans();
  if (list is! Success<LoanAccountsSummary>) return _fail(list);
  final loans = list.data?.loans ?? const <LoanAccount>[];

  final details = await Future.wait([
    for (final loan in loans.take(corpLoanDetailLimit))
      repository.fetchLoanDetails(loan.id, module: loan.module),
  ]);
  return (
    today: today,
    records: [
      for (var i = 0; i < loans.length; i++)
        CorpLoanRecord(
          account: loans[i],
          details:
              i < details.length && details[i] is Success<LoanAccountDetails>
                  ? (details[i] as Success<LoanAccountDetails>).data
                  : null,
        ),
    ],
  );
});

/// `td/v1/deposit`.
final corpDepositsProvider =
    FutureProvider.autoDispose<List<CorpAccount>>((ref) async {
  final result = await ref.read(corpAccountsRepositoryProvider).fetchDeposits();
  if (result is! Success<List<CorpAccount>>) return _fail(result);
  return result.data ?? const [];
});

final obdxCorpProcessManagementApiProvider = Provider(
  (ref) => ObdxCorpProcessManagementApi(ref.watch(obdxDioClientProvider)),
);

final corpLendingRepositoryProvider = Provider(
  (ref) => CorpLendingRepository(
    processManagementApi: ref.watch(obdxCorpProcessManagementApiProvider),
  ),
);

/// `processManagement?moduleId=OBCLPM&partyId=…` — needs the party, from
/// the Corporate profile, which the dashboard loads as it opens.
final corpLoanApplicationsProvider =
    FutureProvider.autoDispose<List<CorpLoanApplication>>((ref) async {
  final profile = ref.watch(
    corpProfileProvider.select((s) => (s.party?.id, s.isLoading)),
  );
  final (partyId, profileLoading) = profile;
  if (partyId == null || partyId.isEmpty) {
    if (profileLoading) {
      // Still loading; this provider runs again when the party arrives.
      return Completer<List<CorpLoanApplication>>().future;
    }
    throw const CorpWidgetLoadError(
      'Your company details could not be loaded.',
    );
  }
  final result =
      await ref.read(corpLendingRepositoryProvider).fetchLoanApplications(
            partyId,
          );
  if (result is! Success<List<CorpLoanApplication>>) return _fail(result);
  return result.data ?? const [];
});

/// `cashmanagement/collections/CW`, by month, for the current month to
/// the business date.
final corpWithdrawalsProvider = FutureProvider.autoDispose<
    ({List<CorpCashCollectionEntry> entries, DateTime month})>((ref) async {
  final today = await ref.watch(corpBusinessDateProvider.future);
  final from = DateTime(today.year, today.month);
  final result = await ref
      .read(corpCashManagementRepositoryProvider)
      .fetchCashWithdrawals(from: from, to: today);
  if (result is! Success<List<CorpCashCollectionEntry>>) return _fail(result);
  return (
    entries: result.data ?? const <CorpCashCollectionEntry>[],
    month: from
  );
});
