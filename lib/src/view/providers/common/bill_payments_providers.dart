import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/bill_payment_models.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/biller_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';

/// Bill Payments — Billers (docs/obdx/features/bill-payments.md §3).
///
/// autoDispose, like OBDX: the list is fetched each time Billers opens and
/// is dropped when the screen (or the user's session) goes away.

/// `GET registeredBillers`. A failed call surfaces as an error whose message
/// is the OBDX text when there is one.
final registeredBillersProvider =
    FutureProvider.autoDispose<List<RegisteredBiller>>((ref) async {
  final result = await ref.read(billPaymentsRepositoryProvider).fetchRegisteredBillers();
  if (result is Success<List<RegisteredBiller>> && result.data != null) {
    return result.data!;
  }
  throw BillPaymentsLoadError(result is Error<List<RegisteredBiller>> ? result.error : null);
});

/// Biller Details: the registration, then its biller master (category,
/// location and the labels for the relationship fields) — the same two
/// calls OBDX's `biller-details` makes. The master is optional: when it
/// fails the details still show what the registration has.
final billerDetailsProvider = FutureProvider.autoDispose
    .family<BillerDetailsData, String>((ref, registrationId) async {
  final repository = ref.read(billPaymentsRepositoryProvider);
  final result = await repository.fetchRegisteredBiller(registrationId);
  if (result is! Success<RegisteredBiller> || result.data == null) {
    throw BillPaymentsLoadError(result is Error<RegisteredBiller> ? result.error : null);
  }
  final registration = result.data!;
  BillerInfo? biller = registration.biller;
  if (biller == null && registration.billerId.isNotEmpty) {
    final master = await repository.fetchBiller(registration.billerId);
    if (master is Success<BillerInfo>) biller = master.data;
  }
  return BillerDetailsData(registration: registration, biller: biller);
});

/// Add Billers: every biller the bank offers (`GET billers`), sorted by name.
final availableBillersProvider =
    FutureProvider.autoDispose<List<BillerInfo>>((ref) async {
  final result = await ref.read(billPaymentsRepositoryProvider).fetchBillers();
  if (result is Success<List<BillerInfo>> && result.data != null) return result.data!;
  throw BillPaymentsLoadError(result is Error<List<BillerInfo>> ? result.error : null);
});

/// Bill Payment History for one search (Select Period / dates).
final billPaymentHistoryProvider = FutureProvider.autoDispose
    .family<List<BillPayment>, BillHistoryQuery>((ref, query) async {
  final result = await ref.read(billPaymentsRepositoryProvider).fetchBillPayments(query);
  if (result is Success<List<BillPayment>> && result.data != null) return result.data!;
  throw BillPaymentsLoadError(result is Error<List<BillPayment>> ? result.error : null);
});

class BillerDetailsData {
  const BillerDetailsData({required this.registration, this.biller});

  final RegisteredBiller registration;
  final BillerInfo? biller;
}

/// Load failure; [message] is OBDX's text when the server sent one.
class BillPaymentsLoadError implements Exception {
  const BillPaymentsLoadError(this.message);

  final String? message;

  @override
  String toString() => message ?? 'BillPaymentsLoadError';
}
