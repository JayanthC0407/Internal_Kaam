import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/bill_pay_models.dart';
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

/// Pay Bill's data, as OBDX's `showPayBill` and stage 1 load it
/// (bill-payments.md §7.2): the registration and the biller master are
/// needed; Recharge plans and the location are best effort (no plans → no
/// plan picker; no location → the registration's own).
///
/// Plans are fetched for RECHARGE billers only: OBDX fires the call for
/// every type but uses it only there.
final payBillContextProvider = FutureProvider.autoDispose
    .family<PayBillContext, String>((ref, registrationId) async {
  final repository = ref.read(billPaymentsRepositoryProvider);
  final result = await repository.fetchRegisteredBiller(registrationId);
  if (result is! Success<RegisteredBiller> || result.data == null) {
    throw BillPaymentsLoadError(result is Error<RegisteredBiller> ? result.error : null);
  }
  final registration = result.data!;
  final master = await repository.fetchBiller(registration.billerId);
  if (master is! Success<BillerInfo> || master.data == null) {
    throw BillPaymentsLoadError(master is Error<BillerInfo> ? master.error : null);
  }
  final areaId = registration.location?.id;
  final (plans, area) = await (
    registration.type == BillerType.recharge
        ? repository.fetchPlans(registration.billerId)
        : Future.value(ResponseHandler<List<BillPlan>>.success(const [])),
    areaId == null
        ? Future.value(ResponseHandler<Map<String, dynamic>>.success(null))
        : repository.fetchOperationalArea(areaId),
  ).wait;
  return PayBillContext(
    registration: registration,
    biller: master.data!,
    plans: plans is Success<List<BillPlan>> ? plans.data ?? const [] : const [],
    location: billLocationLabel(area is Success<Map<String, dynamic>> ? area.data : null, registration),
  );
});

/// Which Pay From list: the Payment Type, the CASA task code (null: none)
/// and whether it is the several-bills flow (its debit card filter).
typedef BillPayAccountsQuery = ({BillPayType type, String? taskCode, bool multiple});

/// Pay From for one [BillPayAccountsQuery].
final billPayAccountsProvider = FutureProvider.autoDispose
    .family<List<BillPayAccount>, BillPayAccountsQuery>((ref, q) async {
  final result = await ref
      .read(billPaymentsRepositoryProvider)
      .fetchPayAccounts(q.type, taskCode: q.taskCode, multiple: q.multiple);
  if (result is Success<List<BillPayAccount>> && result.data != null) return result.data!;
  throw BillPaymentsLoadError(result is Error<List<BillPayAccount>> ? result.error : null);
});

/// One bill of the several-bills flow: OBDX loads `billers/{billerId}` and
/// `operationalareas/{id}` for each list row it was given
/// (initiate-multiple-bill-payments-stage1/hooks.js:411, 648) — no
/// `registeredBillers/{id}`. Plans are not loaded: the flow only takes
/// presented bills and its plan field never shows (bill-payments.md §8.2).
final billPayMasterProvider = FutureProvider.autoDispose
    .family<PayBillContext, RegisteredBiller>((ref, registration) async {
  final repository = ref.read(billPaymentsRepositoryProvider);
  final areaId = registration.location?.id;
  final (master, area) = await (
    repository.fetchBiller(registration.billerId),
    areaId == null
        ? Future.value(ResponseHandler<Map<String, dynamic>>.success(null))
        : repository.fetchOperationalArea(areaId),
  ).wait;
  if (master is! Success<BillerInfo> || master.data == null) {
    throw BillPaymentsLoadError(master is Error<BillerInfo> ? master.error : null);
  }
  return PayBillContext(
    registration: registration,
    biller: master.data!,
    location: billLocationLabel(area is Success<Map<String, dynamic>> ? area.data : null, registration),
  );
});

class PayBillContext {
  const PayBillContext({
    required this.registration,
    required this.biller,
    this.plans = const [],
    this.location,
  });

  /// `GET registeredBillers/{id}` — has no embedded biller.
  final RegisteredBiller registration;
  final BillerInfo biller;
  final List<BillPlan> plans;

  /// Display string, also sent as `location`.
  final String? location;
}

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
