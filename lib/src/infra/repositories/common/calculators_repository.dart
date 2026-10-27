import 'package:ubci_bank/src/core/models/common/calculators/calculator_models.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_calculators_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/obdx_repository_base.dart';

/// Calculators — parses [ObdxCalculatorsApi] responses into
/// `calculator_models.dart` (docs/obdx/features/calculators.md).
class CalculatorsRepository extends ObdxRepositoryBase {
  CalculatorsRepository({required ObdxCalculatorsApi api}) : _api = api;

  final ObdxCalculatorsApi _api;

  /// The bank's local currency; an empty answer is a failure.
  Future<ResponseHandler<String>> fetchLocalCurrency() async {
    final r = await parseBody(await _api.fetchBankConfiguration(), localCurrencyFromPayload);
    if (r is Success<String?> && r.data != null) return ResponseHandler.success(r.data!, code: r.code);
    return mapFailure(r);
  }

  /// Every range [kind] needs, by `var` name (OBDX asks for them together).
  Future<ResponseHandler<Map<String, CalcRange>>> fetchRanges(CalcKind kind) async {
    final results = await Future.wait([
      for (final v in kind.variables) _api.fetchDefaultRange(kind.code, v).then((r) => parseBody(r, CalcRange.fromPayload)),
    ]);
    final out = <String, CalcRange>{};
    for (final (i, r) in results.indexed) {
      if (r is! Success<CalcRange> || r.data == null) return mapFailure(r);
      out[kind.variables[i]] = r.data!;
    }
    return ResponseHandler.success(out, code: 200);
  }

  Future<ResponseHandler<ForexPairs>> fetchForexPairs() async =>
      parseBody(await _api.fetchCurrencyPairs(), ForexPairs.fromPayload);

  // ── Calculations: POSTs, so 417 OTP and approval apply (decision 3a). ──

  Future<ResponseHandler<CalcOutcome<TdMaturity>>> tdMaturity(Map<String, dynamic> body, {ObdxChallenge? challenge, String? otp}) =>
      _calc((h) => _api.tdMaturity(body, challengeResponseHeader: h), TdMaturity.fromPayload, challenge, otp);

  Future<ResponseHandler<CalcOutcome<LoanInstallment>>> loanInstallment(Map<String, dynamic> body,
          {ObdxChallenge? challenge, String? otp}) =>
      _calc((h) => _api.loanSchedule(body, challengeResponseHeader: h), LoanInstallment.fromPayload, challenge, otp);

  Future<ResponseHandler<CalcOutcome<LoanEligibility>>> loanEligibility(Map<String, dynamic> body,
          {ObdxChallenge? challenge, String? otp}) =>
      _calc((h) => _api.loanEligibility(body, challengeResponseHeader: h), LoanEligibility.fromPayload, challenge, otp);

  Future<ResponseHandler<CalcOutcome<ForexQuote>>> forex(Map<String, dynamic> body, {ObdxChallenge? challenge, String? otp}) =>
      _calc((h) => _api.foreignExchange(body, challengeResponseHeader: h), ForexQuote.fromPayload, challenge, otp);

  Future<ResponseHandler<CalcOutcome<T>>> _calc<T>(
    Future<ResponseHandler<Map<String, dynamic>>> Function(String? challengeResponseHeader) call,
    T Function(Map<String, dynamic> body) parse,
    ObdxChallenge? challenge,
    String? otp,
  ) async {
    final otpValue = otp?.trim() ?? '';
    final otpSubmitted = challenge != null && otpValue.isNotEmpty;
    final result = await call(otpSubmitted ? challenge.toChallengeResponseHeader(otpValue) : null);
    try {
      return writeOutcome(
        result,
        otpSubmitted: otpSubmitted,
        onOtp: (next, invalid) => CalcOutcome<T>.otpRequired(next, invalidOtp: invalid),
        onDone: (body, _, pending) => CalcOutcome<T>.done(parse(body), pendingApproval: pending),
      );
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }
}
