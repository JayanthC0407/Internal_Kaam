import 'package:ubci_bank/src/core/models/corp/trade_finance/corp_letter_of_credit.dart';

/// Search criteria for `GET /letterofcredits` (OBDX spec
/// `LetterOfCredit.list`), used by the Initiate LC tabs:
///
///  - **Copy & Initiate** — [LcSearchCriteria.copy]: Import LCs by reference.
///  - **Back to Back LC** — [LcSearchCriteria.backToBack]: active Export LCs
///    (we are the beneficiary) that can back a new Import LC. The fixed
///    parameters are the ones digx-ui sends (H1 #93).
///
/// Only non-empty criteria go on the wire.
class LcSearchCriteria {
  const LcSearchCriteria({
    required this.lcType,
    this.lcNumber,
    this.beneficiaryName,
    this.applicantName,
    this.currency,
    this.fromAmount,
    this.toAmount,
    this.issueFrom,
    this.issueTo,
    this.expiryFrom,
    this.expiryTo,
    this.fixed = const {},
  });

  factory LcSearchCriteria.copy({String? lcNumber}) => LcSearchCriteria(
        lcType: LcType.importLc,
        lcNumber: lcNumber,
      );

  factory LcSearchCriteria.backToBack() => const LcSearchCriteria(
        lcType: LcType.exportLc,
        fixed: {
          'lcStatus': 'ACTIVE',
          'back2backAvailable': 'false',
          'transferrable': 'false',
        },
      );

  final LcType lcType;
  final String? lcNumber;
  final String? beneficiaryName;
  final String? applicantName;
  final String? currency;
  final double? fromAmount;
  final double? toAmount;
  final DateTime? issueFrom;
  final DateTime? issueTo;
  final DateTime? expiryFrom;
  final DateTime? expiryTo;

  /// Mode-specific parameters that always go with the request.
  final Map<String, String> fixed;

  LcSearchCriteria copyWith({
    String? lcNumber,
    String? beneficiaryName,
    String? applicantName,
    String? currency,
    double? fromAmount,
    double? toAmount,
    DateTime? issueFrom,
    DateTime? issueTo,
    DateTime? expiryFrom,
    DateTime? expiryTo,
  }) {
    return LcSearchCriteria(
      lcType: lcType,
      lcNumber: lcNumber ?? this.lcNumber,
      beneficiaryName: beneficiaryName ?? this.beneficiaryName,
      applicantName: applicantName ?? this.applicantName,
      currency: currency ?? this.currency,
      fromAmount: fromAmount ?? this.fromAmount,
      toAmount: toAmount ?? this.toAmount,
      issueFrom: issueFrom ?? this.issueFrom,
      issueTo: issueTo ?? this.issueTo,
      expiryFrom: expiryFrom ?? this.expiryFrom,
      expiryTo: expiryTo ?? this.expiryTo,
      fixed: fixed,
    );
  }

  /// Same mode, every user-entered criterion cleared.
  LcSearchCriteria cleared() =>
      LcSearchCriteria(lcType: lcType, fixed: fixed);

  /// Date query parameters as `yyyy-MM-dd`.
  ///
  /// ASSUMPTION: the spec types them as `Date` but no captured request
  /// carries one; adjust if the host expects `…T00:00:00`.
  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String? _text(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Map<String, dynamic> toQuery({String? partyId}) {
    final q = <String, dynamic>{
      ...fixed,
      'lcType': lcType.apiValue,
      if (partyId != null && partyId.isNotEmpty) 'partyIds': partyId,
    };
    void put(String key, Object? value) {
      if (value != null) q[key] = value;
    }

    put('lcNumber', _text(lcNumber)?.toUpperCase());
    put('beneName', _text(beneficiaryName));
    put('applicantName', _text(applicantName));
    put('currency', _text(currency));
    put('fromAmount', fromAmount);
    put('toAmount', toAmount);
    put('issueDatefrom', issueFrom == null ? null : _day(issueFrom!));
    put('issueDateto', issueTo == null ? null : _day(issueTo!));
    put('expiryDatefrom', expiryFrom == null ? null : _day(expiryFrom!));
    put('expiryDateto', expiryTo == null ? null : _day(expiryTo!));
    return q;
  }
}
