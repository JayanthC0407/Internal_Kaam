import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/retail/sweep_in_models.dart';
import 'package:ubci_bank/src/infra/network/apis/retail/obdx_sweep_in_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/obdx_repository_base.dart';

/// Sweep-In: parses [ObdxSweepInApi] answers. docs/obdx/features/sweep-in.md.
class SweepInRepository extends ObdxRepositoryBase {
  SweepInRepository({required ObdxSweepInApi api}) : _api = api;

  final ObdxSweepInApi _api;

  Future<ResponseHandler<List<SweepAccount>>> fetchPickerAccounts() async =>
      parseBody(await _api.fetchPickerAccounts(), SweepAccount.listFromPayload);

  /// Linked and provider lists for [accountId] and [type]: the account's
  /// instructions, then the CASA or TD list (stage1/hooks.js:359-531).
  Future<ResponseHandler<SweepLists>> fetchLists(String accountId, SweepType type) async {
    final instructions = await parseBody(await _api.fetchInstructions(accountId), SweepInstruction.listFromPayload);
    if (instructions is! Success<List<SweepInstruction>>) return mapFailure(instructions);
    final accounts = await parseBody(
      await (type == SweepType.casa ? _api.fetchCasaAccounts() : _api.fetchDeposits()),
      SweepAccount.listFromPayload,
    );
    if (accounts is! Success<List<SweepAccount>>) return mapFailure(accounts);
    return ResponseHandler.success(
      SweepLists.build(
        type: type,
        selectedId: accountId,
        instructions: instructions.data ?? const [],
        accounts: accounts.data ?? const [],
      ),
      code: 200,
    );
  }

  /// Confirm: one batch for the ticked [providers], with the OTP loop's
  /// challenge and OTP once asked.
  Future<ResponseHandler<SweepLinkOutcome>> link(
    String accountId,
    List<SweepAccount> providers, {
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    final otpValue = otp?.trim() ?? '';
    final otpSubmitted = challenge != null && otpValue.isNotEmpty;
    final result = await _api.linkProviders(
      sweepLinkItems(accountId, providers),
      challengeResponseHeader: otpSubmitted ? challenge.toChallengeResponseHeader(otpValue) : null,
    );
    return writeOutcome(
      result,
      otpSubmitted: otpSubmitted,
      onOtp: (next, invalid) => SweepLinkOutcome.otpRequired(next, invalidOtp: invalid),
      onDone: (body, _, pending) =>
          SweepLinkOutcome.done(rows: SweepResultRow.listFrom(body, providers), pendingApproval: pending),
    );
  }

  /// Delete one linked provider's instruction.
  Future<ResponseHandler<SweepDelinkOutcome>> delink(
    String accountId,
    String instructionNumber, {
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    final otpValue = otp?.trim() ?? '';
    final otpSubmitted = challenge != null && otpValue.isNotEmpty;
    final result = await _api.deleteInstruction(
      accountId,
      instructionNumber,
      challengeResponseHeader: otpSubmitted ? challenge.toChallengeResponseHeader(otpValue) : null,
    );
    return writeOutcome(
      result,
      otpSubmitted: otpSubmitted,
      onOtp: (next, invalid) => SweepDelinkOutcome.otpRequired(next, invalidOtp: invalid),
      onDone: (body, reference, pending) => SweepDelinkOutcome.done(
        reference: ObdxApiUtils.asMap(body)['externalReferenceId']?.toString() ?? reference,
        pendingApproval: pending,
      ),
    );
  }
}
