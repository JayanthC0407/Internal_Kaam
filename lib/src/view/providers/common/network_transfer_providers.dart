import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations_helper.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/own_account_transfer.dart';
import 'package:ubci_bank/src/core/models/common/payment/network_transfer.dart';
import 'package:ubci_bank/src/core/models/retail/casa_account.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/infra/repositories/common/network_transfer_repository.dart';
import 'package:ubci_bank/src/view/providers/common/network_providers.dart';

final networkTransferRepositoryProvider = Provider(
  (ref) => NetworkTransferRepository(
    paymentsApi: ref.watch(obdxPaymentsApiProvider),
    payeeApi: ref.watch(obdxPayeeApiProvider),
    accountsApi: ref.watch(obdxAccountsApiProvider),
  ),
);

/// Turns a failed result into the message to throw from a provider.
Future<String> _message(ResponseHandler<dynamic> result, String fallback) async {
  final l10n = await AppLocalizationsHelper.current();
  return result.resolveUserMessage(l10n: l10n, fallback: fallback);
}

final transferNetworksProvider =
    FutureProvider.autoDispose<List<TransferNetwork>>((ref) async {
  final result =
      await ref.read(networkTransferRepositoryProvider).fetchNetworks();
  if (result is Success<List<TransferNetwork>>) return result.data ?? const [];
  throw await _message(result, "We couldn't load the payment networks.");
});

final transferPayeesProvider =
    FutureProvider.autoDispose<List<TransferPayee>>((ref) async {
  final result = await ref.read(networkTransferRepositoryProvider).fetchPayees();
  if (result is Success<List<TransferPayee>>) return result.data ?? const [];
  throw await _message(result, "We couldn't load your payees.");
});

/// Accounts that may pay, by the network's task code (null: the default).
final transferDebitAccountsProvider = FutureProvider.autoDispose
    .family<List<CasaAccount>, String?>((ref, taskCode) async {
  final result = await ref
      .read(networkTransferRepositoryProvider)
      .fetchDebitAccounts(taskCode);
  if (result is Success<List<CasaAccount>>) return result.data ?? const [];
  throw await _message(result, "We couldn't load your accounts.");
});

/// Purposes on a network — empty when the bank has none or the call fails
/// (purpose is then simply not asked).
final transferPurposesProvider = FutureProvider.autoDispose
    .family<List<TransferPurpose>, String>((ref, network) async {
  final result =
      await ref.read(networkTransferRepositoryProvider).fetchPurposes(network);
  return result is Success<List<TransferPurpose>> ? result.data ?? const [] : [];
});

final gpiCurrenciesProvider =
    FutureProvider.autoDispose<List<GpiCurrency>>((ref) async {
  final result =
      await ref.read(networkTransferRepositoryProvider).fetchGpiCurrencies();
  if (result is Success<List<GpiCurrency>>) return result.data ?? const [];
  throw await _message(result, "We couldn't load the currencies.");
});

/// Repeat frequencies — the app's full list if the enumeration fails.
final transferFrequenciesProvider =
    FutureProvider.autoDispose<List<TransferFrequency>>((ref) async {
  final result =
      await ref.read(networkTransferRepositoryProvider).fetchFrequencies();
  if (result is Success<List<TransferFrequency>> &&
      (result.data?.isNotEmpty ?? false)) {
    return result.data!;
  }
  return TransferFrequency.all;
});

// ── Confirming ───────────────────────────────────────────────────────────

/// One submit attempt; [otp]/[challenge] are set on the OTP retry.
typedef TransferSubmitAttempt = Future<ResponseHandler<TransferSubmitOutcome>>
    Function(String? otp, ObdxChallenge? challenge);

class TransferSubmissionState {
  const TransferSubmissionState({
    this.isSubmitting = false,
    this.result,
    this.errorMessage,
    this.challenge,
    this.otpError,
  });

  final bool isSubmitting;
  final TransferSubmitResult? result;
  final String? errorMessage;

  /// Set while the bank waits for an OTP.
  final ObdxChallenge? challenge;
  final String? otpError;
}

/// Confirms a transfer through OBDX's OTP step: a first 417 opens the OTP
/// sheet, a further one means the code was wrong, and a failure while
/// verifying keeps the sheet open with the message.
class TransferSubmissionNotifier
    extends StateNotifier<TransferSubmissionState> {
  TransferSubmissionNotifier() : super(const TransferSubmissionState());

  TransferSubmitAttempt? _attempt;

  Future<void> submit(TransferSubmitAttempt attempt) async {
    _attempt = attempt;
    state = const TransferSubmissionState(isSubmitting: true);
    await _run();
  }

  Future<void> verifyOtp(String otp) async {
    final challenge = state.challenge;
    if (challenge == null) return;
    state = TransferSubmissionState(isSubmitting: true, challenge: challenge);
    await _run(otp: otp, challenge: challenge);
  }

  Future<void> _run({String? otp, ObdxChallenge? challenge}) async {
    final attempt = _attempt;
    if (attempt == null) return;
    final result = await attempt(otp, challenge);
    if (!mounted) return;

    if (result is Success<TransferSubmitOutcome> && result.data != null) {
      final outcome = result.data!;
      if (outcome.result != null) {
        state = TransferSubmissionState(result: outcome.result);
        return;
      }
      if (outcome.challenge != null) {
        state = TransferSubmissionState(
          challenge: outcome.challenge,
          otpError: otp != null || outcome.invalidOtp
              ? 'That code is not right. Please try again.'
              : null,
        );
        return;
      }
    }
    final message =
        await _message(result, "We couldn't complete the transfer.");
    if (!mounted) return;
    state = otp != null && challenge != null
        ? TransferSubmissionState(challenge: challenge, otpError: message)
        : TransferSubmissionState(errorMessage: message);
  }

  void reset() {
    _attempt = null;
    state = const TransferSubmissionState();
  }
}

final transferSubmissionProvider = StateNotifierProvider.autoDispose<
    TransferSubmissionNotifier, TransferSubmissionState>(
  (ref) => TransferSubmissionNotifier(),
);
