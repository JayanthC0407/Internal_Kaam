import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/bank_guarantee_models.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_bank_guarantee_api.dart';
import 'package:ubci_bank/src/infra/network/corp/corp_bank_guarantee_api_constants.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_repository_base.dart';

/// Bank Guarantee repository — turns [ObdxCorpBankGuaranteeApi] envelopes
/// into models, with OBDX's failure shapes mapped by
/// [CorpRepositoryBase.parseBody].
class CorpBankGuaranteeRepository extends CorpRepositoryBase {
  CorpBankGuaranteeRepository({required ObdxCorpBankGuaranteeApi api})
      : _api = api;

  final ObdxCorpBankGuaranteeApi _api;

  static const _created = {StatusCode.OK, 201, 202};

  // ── Guarantees ───────────────────────────────────────────────────────

  Future<ResponseHandler<List<CorpBankGuarantee>>> searchGuarantees(
    BgSearch search, {
    required BgCategory category,
    bool claimableOnly = false,
  }) async {
    final result = await _api.fetchBankGuarantees(
      search.toQuery(category: category, claimableOnly: claimableOnly),
    );
    return parseBody(
      result,
      (body) => CorpBankGuarantee.listFromPayload(body, category),
    );
  }

  Future<ResponseHandler<List<int>>> downloadGuarantees(
    BgSearch search, {
    required BgCategory category,
    required String media,
    required String mediaFormat,
    bool claimableOnly = false,
  }) {
    return _api.downloadBankGuarantees(
      search.toQuery(category: category, claimableOnly: claimableOnly),
      media: media,
      mediaFormat: mediaFormat,
    );
  }

  Future<ResponseHandler<CorpBankGuarantee>> fetchGuarantee(
    String id, {
    required BgCategory category,
    String? versionNo,
  }) async {
    final result = await _api.fetchBankGuarantee(
      id,
      categoryType: category.apiValue,
      versionNo: versionNo,
    );
    return parseBody(result, (body) {
      final bg = CorpBankGuarantee.fromDetailPayload(body, category);
      if (bg == null) throw const FormatException('bankGuarantee missing');
      return bg;
    });
  }

  // ── Amendments ───────────────────────────────────────────────────────

  Future<ResponseHandler<List<CorpBgAmendment>>> fetchAmendments({
    required BgCategory category,
    String? partyId,
  }) async {
    final result = await _api.fetchAmendments(
      categoryType: category.apiValue,
      partyId: partyId,
    );
    return parseBody(
      result,
      (body) => CorpBgAmendment.listFromPayload(body, category),
    );
  }

  Future<ResponseHandler<CorpBgAmendment>> fetchAmendment(
    CorpBgAmendment amendment,
  ) async {
    final result = await _api.fetchAmendment(
      amendment.bgId,
      amendment.id,
      categoryType: amendment.category.apiValue,
    );
    return parseBody(result, (body) {
      final a = CorpBgAmendment.fromDetailPayload(body, amendment.category);
      if (a == null) throw const FormatException('bankGuaranteeAmendment missing');
      return a;
    });
  }

  Future<ResponseHandler<LcSubmitOutcome>> respondToAmendment(
    CorpBgAmendment amendment, {
    required bool accept,
    required String instructions,
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    final result = await _api.respondToAmendment(
      amendment.bgId,
      amendment.id,
      amendment.toResponseJson(accept: accept, instructions: instructions),
      challengeResponseHeader: (challenge != null && otp != null)
          ? challenge.toChallengeResponseHeader(otp)
          : null,
    );
    return _parseSubmit(result);
  }

  // ── Claims ───────────────────────────────────────────────────────────

  Future<ResponseHandler<LcSubmitOutcome>> lodgeClaim(
    BgClaimDraft draft, {
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    final result = await _api.lodgeClaim(
      draft.guarantee.id,
      draft.toJson(),
      challengeResponseHeader: (challenge != null && otp != null)
          ? challenge.toChallengeResponseHeader(otp)
          : null,
    );
    return _parseSubmit(result);
  }

  // ── Lookups ──────────────────────────────────────────────────────────

  /// Parties, currencies, demand indicators and the business date, in one
  /// round. Each part is optional: a lookup that fails leaves its part
  /// empty instead of failing the screen (the branch date fails on
  /// pre-sales, BG #75).
  Future<BgLookups> fetchLookups({bool withBranchDate = false}) async {
    final results = await Future.wait([
      _api.fetchMeParty(),
      _api.fetchPartyRelations(),
      _api.fetchEnumeration(CorpBankGuaranteeApiConst.enumCurrencies),
      _api.fetchEnumeration(CorpBankGuaranteeApiConst.enumDemandIndicatorTypes),
    ]);
    final own = await _soft<BgParty?>(results[0], BgParty.fromMeParty, null);
    final related = await _soft(
      results[1],
      LcRelatedParty.listFromPayload,
      const <LcRelatedParty>[],
    );

    DateTime? branchDate;
    if (withBranchDate) {
      final config = await _soft(
        await _api.fetchConfigurations(),
        TradeFinanceConfiguration.fromPayload,
        TradeFinanceConfiguration.empty,
      );
      final branch = config.branchCode;
      if (branch != null) {
        branchDate = await _soft<DateTime?>(
          await _api.fetchBranchDate(branch),
          BgLookups.branchDateFrom,
          null,
        );
      }
    }

    return BgLookups(
      parties: [
        if (own != null) own,
        for (final p in related)
          if (p.id.value != own?.id.value) BgParty(id: p.id, name: p.name),
      ],
      currencies: await _soft(
        results[2],
        TradeCode.fromEnumeration,
        const <TradeCode>[],
      ),
      demandIndicators: await _soft(
        results[3],
        TradeCode.fromEnumeration,
        const <TradeCode>[],
      ),
      branchDate: branchDate,
    );
  }

  Future<T> _soft<T>(
    ResponseHandler<Map<String, dynamic>> result,
    T Function(Map<String, dynamic>) parse,
    T fallback,
  ) async {
    final parsed = await parseBody(result, parse);
    if (parsed is Success<T>) return parsed.data ?? fallback;
    return fallback;
  }

  // ── Submit ───────────────────────────────────────────────────────────

  /// 2xx → [LcSubmitted]; 417 with a challenge → [LcAwaitingOtp]; anything
  /// else an error. Same handling as the LC submits.
  ///
  /// SUCCESS RESPONSE NOT CAPTURED for either guarantee submit: this reads
  /// `status.referenceNumber` and the host message, as every digx
  /// transaction response carries them.
  Future<ResponseHandler<LcSubmitOutcome>> _parseSubmit(
    ResponseHandler<Map<String, dynamic>> result,
  ) async {
    if (result is Success<Map<String, dynamic>> && result.data != null) {
      final wrapped = result.data!;
      final statusCode = wrapped['statusCode'] as int? ?? 0;
      final body = ObdxApiUtils.asMap(wrapped['body'] ?? wrapped['rawBody']);
      if (statusCode == ApiConst.expectationFailed) {
        final challenge = ObdxChallenge.fromResponse(
          headers: wrapped['headers'],
          body: body,
        );
        if (challenge != null && challenge.referenceNo.isNotEmpty) {
          return ResponseHandler.success(
            LcAwaitingOtp(challenge),
            code: statusCode,
          );
        }
      }
    }
    return parseBody<LcSubmitOutcome>(
      result,
      _submitted,
      successCodes: _created,
    );
  }

  static LcSubmitted _submitted(Map<String, dynamic> body) {
    final status = TfJson.map(body['status']);
    final message = TfJson.map(status['message']);
    final text = [
      TfJson.str(message['detail']),
      TfJson.str(message['title']),
      TfJson.str(message['code']),
    ].whereType<String>().join(' ').toUpperCase();
    final bg = TfJson.map(body['bankGuarantee']);
    final claim = TfJson.map(body['bankGuaranteeClaim'] ?? body['claim']);
    return LcSubmitted(
      referenceNo: TfJson.str(status['referenceNumber']) ??
          TfJson.str(status['referenceNo']),
      lcId: TfJson.str(claim['id']) ?? TfJson.str(bg['bgId']),
      hostMessage:
          TfJson.str(message['detail']) ?? TfJson.str(message['title']),
      pendingApproval: text.contains('APPROV'),
    );
  }
}
