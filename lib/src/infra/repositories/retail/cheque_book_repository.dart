import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/payee/payee_models.dart';
import 'package:ubci_bank/src/core/models/retail/cheque_book_models.dart';
import 'package:ubci_bank/src/infra/network/apis/retail/obdx_cheque_book_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/obdx_repository_base.dart';

/// Cheque Book Request: parses [ObdxChequeBookApi] answers.
/// docs/obdx/features/cheque-book-request.md.
class ChequeBookRepository extends ObdxRepositoryBase {
  ChequeBookRepository({required ObdxChequeBookApi api}) : _api = api;

  final ObdxChequeBookApi _api;

  /// The form's data. Accounts and types are needed to show it; the two
  /// settings fall back to off when their call fails.
  Future<ResponseHandler<ChequeBookSetup>> fetchSetup() async {
    final (corp, books, types, accounts) = await (
      _api.fetchCorpDdaConfig(),
      _api.fetchBooksConfig(),
      _api.fetchBookTypes(),
      _api.fetchAccounts(),
    ).wait;
    final accountList = await parseBody(accounts, ChequeAccount.listFromPayload);
    if (accountList is! Success<List<ChequeAccount>>) return mapFailure(accountList);
    final typeList = await parseBody(types, ChequeBookType.listFromPayload);
    if (typeList is! Success<List<ChequeBookType>>) return mapFailure(typeList);
    final corpDda = await parseBody(corp, ChequeBookConfig.corpDdaFrom);
    final booksEnabled = await parseBody(books, ChequeBookConfig.booksEnabledFrom);
    return ResponseHandler.success(
      ChequeBookSetup(
        config: ChequeBookConfig(
          corpDda: corpDda is Success<bool> && corpDda.data == true,
          booksEnabled: booksEnabled is Success<bool> && booksEnabled.data == true,
        ),
        types: typeList.data ?? const [],
        accounts: accountList.data ?? const [],
      ),
      code: 200,
    );
  }

  /// My Address, `corpDDAEnabled` off: the party's addresses with their
  /// type descriptions (OBDX loads both together, address.js:100-104).
  Future<ResponseHandler<List<ChequePartyAddress>>> fetchPartyAddresses() async {
    final (party, types) = await (_api.fetchParty(), _api.fetchAddressTypes()).wait;
    final typeBody = await parseBody(types, (b) => b);
    if (typeBody is! Success<Map<String, dynamic>>) return mapFailure(typeBody);
    return parseBody(party, (b) => ChequePartyAddress.listFrom(b, typeBody.data ?? const {}));
  }

  /// My Address, `corpDDAEnabled` on: the account's address.
  Future<ResponseHandler<ChequeAddress>> fetchAccountAddress(String accountId) async =>
      parseBody(await _api.fetchAccountAddress(accountId), ChequeAddress.fromAccountAddress);

  /// `cities[]`.
  Future<ResponseHandler<List<String>>> fetchCities() async => parseBody(await _api.fetchCities(), (b) {
        final raw = b['cities'];
        return raw is List ? [for (final c in raw) CityOption.fromValue(c).code].where((c) => c.isNotEmpty).toList() : <String>[];
      });

  /// `branchAddressDTO[]{id, branchName}`.
  Future<ResponseHandler<List<BranchOption>>> fetchBranches(String city) async =>
      parseBody(await _api.fetchBranches(city), (b) {
        final raw = b['branchAddressDTO'];
        return raw is List ? [for (final r in raw) BranchOption.fromValue(r)].where((o) => o.code.isNotEmpty).toList() : <BranchOption>[];
      });

  Future<ResponseHandler<ChequeAddress>> fetchBranchAddress(String branchCode) async =>
      parseBody(await _api.fetchBranchAddress(branchCode), ChequeAddress.fromBranchPayload);

  /// Confirm, with the OTP loop's challenge and OTP once asked.
  Future<ResponseHandler<ChequeBookOutcome>> requestChequeBook(
    ChequeBookRequest request, {
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    final otpValue = otp?.trim() ?? '';
    final otpSubmitted = challenge != null && otpValue.isNotEmpty;
    final result = await _api.requestChequeBook(
      request.account.id,
      request.toJson(),
      challengeResponseHeader: otpSubmitted ? challenge.toChallengeResponseHeader(otpValue) : null,
    );
    return writeOutcome(
      result,
      otpSubmitted: otpSubmitted,
      onOtp: (next, invalid) => ChequeBookOutcome.otpRequired(next, invalidOtp: invalid),
      onDone: (body, reference, pending) => ChequeBookOutcome.done(
        reference: ObdxApiUtils.asMap(body['chequeBookDTO'])['chequeBookRequestRefNo']?.toString() ?? reference,
        pendingApproval: pending,
      ),
    );
  }
}
