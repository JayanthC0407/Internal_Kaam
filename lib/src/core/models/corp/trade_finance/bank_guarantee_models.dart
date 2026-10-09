import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/lc_common.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/lc_initiate_support.dart';

/// Bank Guarantee (Inward) models.
///
/// Field names are those the OBDX web components read from the responses
/// (`inward-guarantee-list`, `lodge-claims`, `claim-details`,
/// `inward-guarantee-amendment` in `inward_bank_guarantee_api.har` →
/// **BG #n**). The list call itself failed on pre-sales (400, host
/// unreachable), so a live `bankGuaranteeDTO` has not been seen; every
/// field is read through [TfJson] and tolerates being absent.

// ── Enumerations ────────────────────────────────────────────────────────

/// `categoryType` — every call carries one. Islamic guarantees are called
/// kafalah throughout the web client's labels.
enum BgCategory {
  conventional('CONVENTIONAL', 'Guarantee', 'guarantee'),
  islamic('ISLAMIC', 'Kafalah', 'kafalah');

  const BgCategory(this.apiValue, this.noun, this.lowerNoun);

  final String apiValue;

  /// "Guarantee" / "Kafalah" — for headings and labels.
  final String noun;

  /// "guarantee" / "kafalah" — for running text.
  final String lowerNoun;
}

/// `guaranteeStatus` / filter `bgStatus` (BG #45 filter options, plus
/// `LIQUIDATED`, which the Lodge Claim list styles but does not filter on).
enum BgStatus {
  active('ACTIVE', 'Active'),
  hold('HOLD', 'On hold'),
  reversed('REVERSED', 'Reversed'),
  closed('CLOSED', 'Closed'),
  cancelled('CANCELLED', 'Cancelled'),
  liquidated('LIQUIDATED', 'Liquidated');

  const BgStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// The statuses the web filter offers.
  static const filterable = [active, hold, reversed, closed, cancelled];

  static BgStatus? from(String? value) {
    final upper = value?.trim().toUpperCase();
    for (final s in values) {
      if (s.apiValue == upper) return s;
    }
    return null;
  }
}

/// `formofUndertaking` on a guarantee, `standByLC` on the search: `Y` is a
/// standby LC, `N` a guarantee (or kafalah).
enum BgUndertakingForm {
  standByLc('Y'),
  guarantee('N');

  const BgUndertakingForm(this.apiValue);

  final String apiValue;

  String label(BgCategory category) =>
      this == standByLc ? 'Stand By LC' : category.noun;

  static BgUndertakingForm? from(dynamic value) {
    final text = TfJson.str(value)?.toUpperCase();
    if (text == 'Y' || text == 'TRUE') return standByLc;
    if (text == 'N' || text == 'FALSE') return guarantee;
    return null;
  }
}

/// SWIFT MT765 field 22G — what the beneficiary asks the bank to do.
enum BgDemandType {
  pay('PAYM', 'Pay', 'Pay the claimed amount.'),
  extendOrPay(
    'EXOP',
    'Extend or pay',
    'Extend the expiry date, or else pay the claimed amount.',
  );

  const BgDemandType(this.apiValue, this.label, this.description);

  final String apiValue;
  final String label;
  final String description;
}

MoneyAmount? _money(dynamic json) {
  final map = TfJson.map(json);
  if (TfJson.dbl(map['amount']) == null) return null;
  return MoneyAmount.fromJson(map);
}

// ── Guarantee ───────────────────────────────────────────────────────────

/// One guarantee — a `bankGuaranteeDTO[]` row (list) or `bankGuarantee`
/// (detail). The web list reads the same fields from both.
class CorpBankGuarantee {
  const CorpBankGuarantee({
    required this.id,
    required this.category,
    required this.raw,
    this.customerReferenceNo,
    this.beneficiaryName,
    this.applicantName,
    this.issuingBank,
    this.issuingBankRefNo,
    this.statusCode,
    this.issueDate,
    this.expiryDate,
    this.undertakingAmount,
    this.equivalentUndertakingAmount,
    this.outstandingAmount,
    this.equivalentOutstandingAmount,
    this.totalClaims,
    this.form,
    this.validityType,
    this.demandIndicator,
    this.versionNo,
  });

  /// `bgId`.
  final String id;
  final BgCategory category;
  final Map<String, dynamic> raw;

  final String? customerReferenceNo;

  /// `beneName` — on an inward guarantee, the user's own party.
  final String? beneficiaryName;

  /// `partyName` — the web list's "Applicant Name" column.
  final String? applicantName;

  /// `advisingBankDetails.name` — "Issuing Bank" on an inward guarantee.
  final String? issuingBank;

  /// `beneContractReferenceNo` — "Issuing Bank Reference No.".
  final String? issuingBankRefNo;

  /// `guaranteeStatus`, as sent.
  final String? statusCode;
  final DateTime? issueDate;
  final DateTime? expiryDate;

  /// `contractAmount` — "Undertaking Amount".
  final MoneyAmount? undertakingAmount;

  /// `localCurrency` — "Equivalent Undertaking Amount" (indicative).
  final MoneyAmount? equivalentUndertakingAmount;

  /// `guaranteeAmount` — "Outstanding Amount".
  final MoneyAmount? outstandingAmount;

  /// `equivalentOutstandingAmount` (indicative).
  final MoneyAmount? equivalentOutstandingAmount;

  /// `totalClaims` — total already claimed, in the guarantee currency.
  final double? totalClaims;

  /// `formofUndertaking`.
  final BgUndertakingForm? form;

  /// `validityType` — `FIXD`/`LIMT` fixed, `UNLM`/`OPEN` open, `COND`
  /// conditional, `CONU` conditional without expiry (`claim-details`).
  final String? validityType;

  /// `demandIndicator` — a `demandIndicatorTypes` code (SWIFT 48D, e.g.
  /// `NMPT` no multiple and no partial demands).
  final String? demandIndicator;

  /// Passed back as `versionNo` on the detail call.
  final String? versionNo;

  BgStatus? get status => BgStatus.from(statusCode);

  String get statusLabel => status?.label ?? (statusCode ?? '—');

  bool get isActive => status == BgStatus.active;

  bool get isExpired {
    final expiry = expiryDate;
    if (expiry == null) return false;
    final now = DateTime.now();
    return expiry.isBefore(DateTime(now.year, now.month, now.day));
  }

  String get formLabel => form?.label(category) ?? '—';

  /// "Expiry Type" as `claim-details` words it.
  String? get expiryTypeLabel => switch (validityType?.toUpperCase()) {
        'CONU' => 'Conditional - Without Expiry',
        'COND' => 'Conditional',
        'FIXD' || 'LIMT' => 'Fixed',
        'UNLM' || 'OPEN' => 'Open',
        _ => validityType,
      };

  /// Claims lodged so far, in the guarantee's currency.
  MoneyAmount? get claimedAmount {
    final total = totalClaims;
    if (total == null) return null;
    return MoneyAmount(
      amount: total,
      currency: TfJson.str(TfJson.map(raw['amount'])['currency']) ??
          outstandingAmount?.currency ??
          undertakingAmount?.currency,
    );
  }

  /// Fields shown elsewhere on the detail screen, so the "everything else"
  /// section does not repeat them.
  static const knownKeys = {
    'bgId',
    'id',
    'customerReferenceNo',
    'beneName',
    'partyName',
    'advisingBankDetails',
    'beneContractReferenceNo',
    'guaranteeStatus',
    'issueDate',
    'expiryDate',
    'contractAmount',
    'localCurrency',
    'guaranteeAmount',
    'equivalentOutstandingAmount',
    'totalClaims',
    'amount',
    'formofUndertaking',
    'validityType',
    'demandIndicator',
    'versionNo',
  };

  static CorpBankGuarantee? fromJson(dynamic json, BgCategory category) {
    final map = TfJson.map(json);
    final id = TfJson.str(map['bgId']) ?? TfJson.str(map['id']);
    if (id == null) return null;
    final resolved = switch (TfJson.str(map['categoryType'])?.toUpperCase()) {
      'ISLAMIC' => BgCategory.islamic,
      'CONVENTIONAL' => BgCategory.conventional,
      _ => category,
    };
    return CorpBankGuarantee(
      id: id,
      category: resolved,
      raw: map,
      customerReferenceNo: TfJson.str(map['customerReferenceNo']),
      beneficiaryName: TfJson.str(map['beneName']),
      applicantName: TfJson.str(map['partyName']),
      issuingBank: TfJson.str(TfJson.map(map['advisingBankDetails'])['name']),
      issuingBankRefNo: TfJson.str(map['beneContractReferenceNo']),
      statusCode: TfJson.str(map['guaranteeStatus']),
      issueDate: TfJson.date(map['issueDate']),
      expiryDate: TfJson.date(map['expiryDate']),
      undertakingAmount: _money(map['contractAmount']),
      equivalentUndertakingAmount: _money(map['localCurrency']),
      outstandingAmount: _money(map['guaranteeAmount']),
      equivalentOutstandingAmount: _money(map['equivalentOutstandingAmount']),
      totalClaims: TfJson.dbl(map['totalClaims']),
      form: BgUndertakingForm.from(map['formofUndertaking']),
      validityType: TfJson.str(map['validityType']),
      demandIndicator: TfJson.str(map['demandIndicator']),
      versionNo: TfJson.str(map['versionNo']),
    );
  }

  /// `bankGuaranteeDTO[]` — note the singular key (BG #37 list mapping).
  static List<CorpBankGuarantee> listFromPayload(
    dynamic data,
    BgCategory category,
  ) {
    final root = TfJson.root(data);
    final rows = root['bankGuaranteeDTO'] ?? root['bankGuaranteeDTOs'];
    return [
      for (final item in TfJson.maps(rows))
        if (CorpBankGuarantee.fromJson(item, category) case final bg?) bg,
    ];
  }

  /// `bankGuarantee` (detail).
  static CorpBankGuarantee? fromDetailPayload(
    dynamic data,
    BgCategory category,
  ) {
    final root = TfJson.root(data);
    return CorpBankGuarantee.fromJson(root['bankGuarantee'], category);
  }
}

// ── Search ──────────────────────────────────────────────────────────────

/// One removable filter of a [BgSearch] — a chip above the results.
enum BgFilter {
  guaranteeNumber,
  applicant,
  issuingBank,
  issuingBankRefNo,
  status,
  amount,
  issueDate,
  expiryDate,
  form,
  parties,
}

/// The guarantee search — the View filter panel (BG #45) and the Lodge
/// Claim form (BG #68) send the same `bankguarantees` parameters.
class BgSearch {
  const BgSearch({
    this.guaranteeNumber,
    this.applicantName,
    this.issuingBank,
    this.issuingBankRefNo,
    this.status,
    this.currency,
    this.fromAmount,
    this.toAmount,
    this.issueFrom,
    this.issueTo,
    this.expiryFrom,
    this.expiryTo,
    this.form,
    this.partyIds = const [],
  });

  static const none = BgSearch();

  final String? guaranteeNumber;
  final String? applicantName;
  final String? issuingBank;
  final String? issuingBankRefNo;
  final BgStatus? status;

  /// Currency of the amount range (`currency`).
  final String? currency;
  final double? fromAmount;
  final double? toAmount;
  final DateTime? issueFrom;
  final DateTime? issueTo;
  final DateTime? expiryFrom;
  final DateTime? expiryTo;
  final BgUndertakingForm? form;

  /// Parties to search for (`partyId`); empty means the user's own party,
  /// as the web list sends no `partyId` until one is picked (BG #44).
  final List<String> partyIds;

  List<BgFilter> get activeFilters => [
        if (_text(guaranteeNumber) != null) BgFilter.guaranteeNumber,
        if (_text(applicantName) != null) BgFilter.applicant,
        if (_text(issuingBank) != null) BgFilter.issuingBank,
        if (_text(issuingBankRefNo) != null) BgFilter.issuingBankRefNo,
        if (status != null) BgFilter.status,
        if (fromAmount != null || toAmount != null || _text(currency) != null)
          BgFilter.amount,
        if (issueFrom != null || issueTo != null) BgFilter.issueDate,
        if (expiryFrom != null || expiryTo != null) BgFilter.expiryDate,
        if (form != null) BgFilter.form,
        if (partyIds.isNotEmpty) BgFilter.parties,
      ];

  /// Filters other than the party choice — the badge on the Filter button
  /// (the party has its own selector).
  int get filterCount =>
      activeFilters.where((f) => f != BgFilter.parties).length;

  BgSearch copyWith({List<String>? partyIds}) => BgSearch(
        guaranteeNumber: guaranteeNumber,
        applicantName: applicantName,
        issuingBank: issuingBank,
        issuingBankRefNo: issuingBankRefNo,
        status: status,
        currency: currency,
        fromAmount: fromAmount,
        toAmount: toAmount,
        issueFrom: issueFrom,
        issueTo: issueTo,
        expiryFrom: expiryFrom,
        expiryTo: expiryTo,
        form: form,
        partyIds: partyIds ?? this.partyIds,
      );

  /// This search with [filter] taken off.
  BgSearch without(BgFilter filter) {
    final amount = filter == BgFilter.amount;
    final issue = filter == BgFilter.issueDate;
    final expiry = filter == BgFilter.expiryDate;
    return BgSearch(
      guaranteeNumber:
          filter == BgFilter.guaranteeNumber ? null : guaranteeNumber,
      applicantName: filter == BgFilter.applicant ? null : applicantName,
      issuingBank: filter == BgFilter.issuingBank ? null : issuingBank,
      issuingBankRefNo:
          filter == BgFilter.issuingBankRefNo ? null : issuingBankRefNo,
      status: filter == BgFilter.status ? null : status,
      currency: amount ? null : currency,
      fromAmount: amount ? null : fromAmount,
      toAmount: amount ? null : toAmount,
      issueFrom: issue ? null : issueFrom,
      issueTo: issue ? null : issueTo,
      expiryFrom: expiry ? null : expiryFrom,
      expiryTo: expiry ? null : expiryTo,
      form: filter == BgFilter.form ? null : form,
      partyIds: filter == BgFilter.parties ? const [] : partyIds,
    );
  }

  /// The `bankguarantees` query. [claimableOnly] adds `isClaimable=true`,
  /// as the Lodge Claim search does (BG #76).
  ///
  /// Date parameters are sent as `yyyy-MM-dd`, the shape the other trade
  /// finance searches use; no guarantee search with dates was captured.
  Map<String, dynamic> toQuery({
    required BgCategory category,
    String transactionType = 'INWARD',
    bool claimableOnly = false,
  }) {
    return {
      'categoryType': category.apiValue,
      'transactionType': transactionType,
      if (claimableOnly) 'isClaimable': 'true',
      if (_text(guaranteeNumber) case final v?) 'bgNumber': v,
      if (_text(applicantName) case final v?) 'applicantName': v,
      if (_text(issuingBank) case final v?) 'issuingBank': v,
      if (_text(issuingBankRefNo) case final v?) 'issuingBankRefNo': v,
      if (status != null) 'bgStatus': status!.apiValue,
      if (_text(currency) case final v?) 'currency': v.toUpperCase(),
      if (fromAmount != null) 'fromAmount': _amount(fromAmount!),
      if (toAmount != null) 'toAmount': _amount(toAmount!),
      if (issueFrom != null) 'issueDatefrom': _day(issueFrom!),
      if (issueTo != null) 'issueDateto': _day(issueTo!),
      if (expiryFrom != null) 'expiryDatefrom': _day(expiryFrom!),
      if (expiryTo != null) 'expiryDateto': _day(expiryTo!),
      if (form != null) 'standByLC': form!.apiValue,
      if (partyIds.isNotEmpty) 'partyId': partyIds.join(','),
    };
  }

  static String? _text(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Whole amounts as integers (`1000`), not `1000.0`.
  static num _amount(double v) => v == v.truncateToDouble() ? v.toInt() : v;
}

// ── Amendments ──────────────────────────────────────────────────────────

/// An amendment (or cancellation) of an inward guarantee awaiting the
/// beneficiary's acceptance — `bankGuaranteeAmendmentDTOs[]` (BG #62:
/// `id`, `bgId`, `newAmount`, `applicantName`, `productType`, …) or
/// `bankGuaranteeAmendment` (detail, FROM COMPONENT).
class CorpBgAmendment {
  const CorpBgAmendment({
    required this.id,
    required this.bgId,
    required this.category,
    required this.raw,
    this.newAmount,
    this.equivalentAmount,
    this.applicantName,
    this.productType,
    this.isCancellation = false,
    this.standByLc,
    this.newExpiryDate,
    this.amendmentDate,
    this.versionNo,
    this.narrative,
  });

  /// Amendment number within the guarantee (`"1"` in BG #62).
  final String id;
  final String bgId;
  final BgCategory category;
  final Map<String, dynamic> raw;
  final MoneyAmount? newAmount;

  /// `localCurrency` — indicative local-currency equivalent.
  final MoneyAmount? equivalentAmount;
  final String? applicantName;

  /// `INWARD` / `OUTWARD`.
  final String? productType;

  /// `cancellationAllowed` — the web client tags these rows
  /// "Cancellation" instead of "Amendment".
  final bool isCancellation;

  /// `standByLC` — shown as sent in the "Type" column.
  final String? standByLc;
  final DateTime? newExpiryDate;
  final DateTime? amendmentDate;
  final String? versionNo;
  final String? narrative;

  /// Stable key: the amendment id alone repeats across guarantees.
  String get key => '$bgId#$id';

  String get kindLabel => isCancellation ? 'Cancellation' : 'Amendment';

  /// "Inward Bank Guarantee" — the web table's Product Name.
  String get productLabel => switch (productType?.toUpperCase()) {
        'OUTWARD' => 'Outward Bank ${category.noun}',
        _ => 'Inward Bank ${category.noun}',
      };

  /// The "Type" column: `Y`/`N` read as the undertaking form, anything
  /// else shown as sent.
  String? get typeLabel {
    final form = BgUndertakingForm.from(standByLc);
    return form?.label(category) ?? standByLc;
  }

  static CorpBgAmendment? fromJson(dynamic json, BgCategory category) {
    final map = TfJson.map(json);
    final id = TfJson.str(map['id']);
    final bgId = TfJson.str(map['bgId']);
    if (id == null || bgId == null) return null;
    return CorpBgAmendment(
      id: id,
      bgId: bgId,
      category: category,
      raw: map,
      newAmount: _money(map['newAmount']),
      equivalentAmount: _money(map['localCurrency']),
      applicantName:
          TfJson.str(map['applicantName']) ?? TfJson.str(map['partyName']),
      productType: TfJson.str(map['productType']) ?? TfJson.str(map['type']),
      isCancellation: TfJson.boolean(map['cancellationAllowed']),
      standByLc: TfJson.str(map['standByLC']),
      newExpiryDate: TfJson.date(map['newExpiryDate']),
      amendmentDate: TfJson.date(map['amendmentDate']),
      versionNo: TfJson.str(map['versionNo']),
      narrative: TfJson.str(map['narrative']) ?? TfJson.str(map['remarks']),
    );
  }

  static List<CorpBgAmendment> listFromPayload(
    dynamic data,
    BgCategory category,
  ) {
    final root = TfJson.root(data);
    return [
      for (final item in TfJson.maps(root['bankGuaranteeAmendmentDTOs']))
        if (CorpBgAmendment.fromJson(item, category) case final a?) a,
    ];
  }

  static CorpBgAmendment? fromDetailPayload(
    dynamic data,
    BgCategory category,
  ) {
    final root = TfJson.root(data);
    return CorpBgAmendment.fromJson(root['bankGuaranteeAmendment'], category);
  }

  /// Accept / reject body.
  ///
  /// NOT CAPTURED: the web client sends it from
  /// `review-guarantee-acceptance`, which the capture does not open. This
  /// sends the amendment back with `customerAcceptanceStatus` set — the
  /// field the LC amendment acceptance uses (`CorpLcAmendment
  /// .toResponseJson`) — plus the special instructions as `remarks`, which
  /// is where the web screen reads them back from (`remark`). Confirm
  /// against a capture of Approve / Reject.
  Map<String, dynamic> toResponseJson({
    required bool accept,
    required String instructions,
  }) {
    return {
      ...raw,
      'customerAcceptanceStatus': accept ? 'ACCEPTED' : 'REJECTED',
      'remarks': instructions.trim(),
      'categoryType': category.apiValue,
    };
  }
}

// ── Claim ───────────────────────────────────────────────────────────────

/// The claim the beneficiary lodges under an inward guarantee.
class BgClaimDraft {
  const BgClaimDraft({
    required this.guarantee,
    this.amount,
    this.demandType = BgDemandType.pay,
    this.extendTo,
    this.description,
  });

  final CorpBankGuarantee guarantee;

  /// Claimed amount, in the guarantee's currency.
  final double? amount;
  final BgDemandType demandType;

  /// Requested new expiry date, for [BgDemandType.extendOrPay].
  final DateTime? extendTo;

  /// The beneficiary's statement of the claim.
  final String? description;

  String? get currency =>
      guarantee.outstandingAmount?.currency ??
      guarantee.undertakingAmount?.currency;

  BgClaimDraft copyWith({
    double? amount,
    bool clearAmount = false,
    BgDemandType? demandType,
    DateTime? extendTo,
    bool clearExtendTo = false,
    String? description,
  }) {
    return BgClaimDraft(
      guarantee: guarantee,
      amount: clearAmount ? null : (amount ?? this.amount),
      demandType: demandType ?? this.demandType,
      extendTo: clearExtendTo ? null : (extendTo ?? this.extendTo),
      description: description ?? this.description,
    );
  }

  /// Lodge-claim body.
  ///
  /// NOT CAPTURED: the web client sends it from `view-lodge-claim`, which
  /// the capture does not open. Field names follow the guarantee DTO
  /// (`bgId`, `categoryType`, `{ amount, currency }` money) and SWIFT
  /// MT765 (demand type `PAYM` / `EXOP`, requested expiry). Confirm
  /// against a capture of Lodge Claim → Submit.
  Map<String, dynamic> toJson() {
    final value = amount ?? 0;
    return {
      'bgId': guarantee.id,
      'categoryType': guarantee.category.apiValue,
      'transactionType': 'INWARD',
      'claimAmount': {
        'currency': currency,
        'amount': value == value.truncateToDouble() ? value.toInt() : value,
      },
      'demandType': demandType.apiValue,
      if (demandType == BgDemandType.extendOrPay && extendTo != null)
        'requestedExpiryDate': TfDate.toApi(extendTo),
      'claimDescription': description?.trim(),
    };
  }
}

// ── Lookups ─────────────────────────────────────────────────────────────

/// A party the user may search for: their own (`me/party`, BG #41) or a
/// related one (`me/party/relations`, BG #42).
class BgParty {
  const BgParty({required this.id, required this.name, this.isOwn = false});

  final TfId id;
  final String name;
  final bool isOwn;

  /// `party.id` + `party.personalDetails.fullName` (BG #41).
  static BgParty? fromMeParty(dynamic data) {
    final party = TfJson.map(TfJson.root(data)['party']);
    final id = TfId.fromJson(party['id']);
    if (id.isEmpty) return null;
    final name = TfJson.str(TfJson.map(party['personalDetails'])['fullName']);
    return BgParty(
      id: id,
      name: name ?? id.displayValue ?? id.value!,
      isOwn: true,
    );
  }

  @override
  bool operator ==(Object other) => other is BgParty && other.id.value == id.value;

  @override
  int get hashCode => id.value.hashCode;
}

/// Everything the guarantee screens look up once per visit.
class BgLookups {
  const BgLookups({
    this.parties = const [],
    this.currencies = const [],
    this.demandIndicators = const [],
    this.branchDate,
  });

  static const empty = BgLookups();

  /// The user's own party first, then related parties.
  final List<BgParty> parties;

  /// `tradeEnumerations/currencies` (BG #39 — empty on pre-sales, so the
  /// screens fall back to a free-text currency).
  final List<TradeCode> currencies;

  /// `tradeEnumerations/demandIndicatorTypes` (`claim-details`).
  final List<TradeCode> demandIndicators;

  /// The bank's business date for `TRADE_BRANCH_CODE` (BG #75 — 400 on
  /// pre-sales; screens fall back to today).
  final DateTime? branchDate;

  /// Related parties exist, so a party choice means something.
  bool get hasRelatedParties => parties.length > 1;

  BgParty? get ownParty =>
      parties.where((p) => p.isOwn).firstOrNull ?? parties.firstOrNull;

  String? demandIndicatorLabel(String? code) {
    if (code == null) return null;
    for (final c in demandIndicators) {
      if (c.code == code) return c.label;
    }
    return code;
  }

  /// `businessDate` reading for `branchdate/{branch}`: the lodge-claim
  /// component reads a top-level `branchDate` string; the shared LC reader
  /// covers the other shapes.
  static DateTime? branchDateFrom(dynamic data) {
    final root = TfJson.root(data);
    final direct = TfJson.date(root['branchDate']);
    if (direct != null) return DateTime(direct.year, direct.month, direct.day);
    return LcBranchDate.fromPayload(data);
  }
}
