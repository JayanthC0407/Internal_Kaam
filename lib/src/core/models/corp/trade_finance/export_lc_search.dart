import 'package:ubci_bank/src/core/models/corp/trade_finance/corp_letter_of_credit.dart';

/// LC status filter — `lcStatus` on `GET /letterofcredits`. The options are
/// the manual's (View Export LC, ch. 11); `ACTIVE` is the one seen in the
/// View Export LC capture.
enum ExportLcStatus {
  active('ACTIVE', 'Active'),
  hold('HOLD', 'Hold'),
  cancelled('CANCELLED', 'Cancelled'),
  closed('CLOSED', 'Closed'),
  reversed('REVERSED', 'Reversed');

  const ExportLcStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// LC drawing status filter — sent as `status` (the capture sends
/// `status=PARTIAL` beside `lcStatus`). Options from the manual.
enum ExportLcDrawingStatus {
  partial('PARTIAL', 'Partial'),
  full('FULL', 'Full'),
  undrawn('UNDRAWN', 'Undrawn'),
  expired('EXPIRED', 'Expired');

  const ExportLcDrawingStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// Expired / not expired — matched against each LC's `expiryStatus`.
enum ExportLcExpiry {
  expired('Expired'),
  notExpired('Non expired');

  const ExportLcExpiry(this.label);

  final String label;
}

/// A list download format — `media` / `mediaFormat` on the list call, as
/// the capture sends them.
enum TfListFormat {
  pdf('application/pdf', 'pdf', 'PDF'),
  csv('text/csv', 'csv', 'CSV');

  const TfListFormat(this.media, this.mediaFormat, this.label);

  final String media;
  final String mediaFormat;
  final String label;
}

/// One removable filter of an [ExportLcSearch] — a chip on the results.
/// Ranges come off as a whole.
enum ExportLcFilter {
  lcNumber,
  applicant,
  status,
  drawingStatus,
  amount,
  issueDate,
  expiryDate,
  expiry,
}

/// The View Export LC search (manual ch. 11).
///
/// Split by what the host is known to accept:
///  - **sent to the host** ([toQuery]) — the parameters the View Export LC
///    and Initiate Transfer captures send: `lcStatus`, `status` (drawing
///    status), `fromAmount` / `toAmount`, `expiryDatefrom` / `expiryDateto`;
///  - **applied to the results** ([matches]) — LC number, applicant, issue
///    dates and expired / not: their parameter names were never captured,
///    so rather than guess, the app filters what the host returns.
class ExportLcSearch {
  const ExportLcSearch({
    this.lcNumber,
    this.applicantName,
    this.status,
    this.drawingStatus,
    this.fromAmount,
    this.toAmount,
    this.issueFrom,
    this.issueTo,
    this.expiryFrom,
    this.expiryTo,
    this.expiry,
  });

  static const none = ExportLcSearch();

  final String? lcNumber;
  final String? applicantName;
  final ExportLcStatus? status;
  final ExportLcDrawingStatus? drawingStatus;
  final double? fromAmount;
  final double? toAmount;
  final DateTime? issueFrom;
  final DateTime? issueTo;
  final DateTime? expiryFrom;
  final DateTime? expiryTo;
  final ExportLcExpiry? expiry;

  /// How many filters are set — the badge on the Filter button.
  int get activeCount => [
        _text(lcNumber),
        _text(applicantName),
        status,
        drawingStatus,
        fromAmount,
        toAmount,
        issueFrom,
        issueTo,
        expiryFrom,
        expiryTo,
        expiry,
      ].where((v) => v != null).length;

  bool get isEmpty => activeCount == 0;

  /// The filters that are set, in the form's order.
  List<ExportLcFilter> get activeFilters => [
        if (_text(lcNumber) != null) ExportLcFilter.lcNumber,
        if (_text(applicantName) != null) ExportLcFilter.applicant,
        if (status != null) ExportLcFilter.status,
        if (drawingStatus != null) ExportLcFilter.drawingStatus,
        if (fromAmount != null || toAmount != null) ExportLcFilter.amount,
        if (issueFrom != null || issueTo != null) ExportLcFilter.issueDate,
        if (expiryFrom != null || expiryTo != null) ExportLcFilter.expiryDate,
        if (expiry != null) ExportLcFilter.expiry,
      ];

  /// This search with [filter] taken off.
  ExportLcSearch without(ExportLcFilter filter) => ExportLcSearch(
        lcNumber: filter == ExportLcFilter.lcNumber ? null : lcNumber,
        applicantName:
            filter == ExportLcFilter.applicant ? null : applicantName,
        status: filter == ExportLcFilter.status ? null : status,
        drawingStatus:
            filter == ExportLcFilter.drawingStatus ? null : drawingStatus,
        fromAmount: filter == ExportLcFilter.amount ? null : fromAmount,
        toAmount: filter == ExportLcFilter.amount ? null : toAmount,
        issueFrom: filter == ExportLcFilter.issueDate ? null : issueFrom,
        issueTo: filter == ExportLcFilter.issueDate ? null : issueTo,
        expiryFrom: filter == ExportLcFilter.expiryDate ? null : expiryFrom,
        expiryTo: filter == ExportLcFilter.expiryDate ? null : expiryTo,
        expiry: filter == ExportLcFilter.expiry ? null : expiry,
      );

  /// The list call's query, `lcType=Export` and the party included.
  Map<String, dynamic> toQuery({String? partyId}) {
    return {
      'lcType': LcType.exportLc.apiValue,
      if (partyId != null && partyId.isNotEmpty) 'partyIds': partyId,
      if (status != null) 'lcStatus': status!.apiValue,
      if (drawingStatus != null) 'status': drawingStatus!.apiValue,
      if (fromAmount != null) 'fromAmount': _amount(fromAmount!),
      if (toAmount != null) 'toAmount': _amount(toAmount!),
      if (expiryFrom != null) 'expiryDatefrom': _day(expiryFrom!),
      if (expiryTo != null) 'expiryDateto': _day(expiryTo!),
    };
  }

  /// The filters the host is not asked to apply.
  bool matches(CorpLetterOfCredit lc) {
    final number = _text(lcNumber)?.toLowerCase();
    if (number != null && !lc.id.toLowerCase().contains(number)) return false;

    // On an export LC the applicant is the counterparty — the buyer.
    final applicant = _text(applicantName)?.toLowerCase();
    if (applicant != null &&
        !(lc.counterPartyName?.toLowerCase().contains(applicant) ?? false)) {
      return false;
    }

    final issued = lc.applicationDate;
    if (issueFrom != null &&
        (issued == null || _dayOf(issued).isBefore(_dayOf(issueFrom!)))) {
      return false;
    }
    if (issueTo != null &&
        (issued == null || _dayOf(issued).isAfter(_dayOf(issueTo!)))) {
      return false;
    }

    if (expiry == ExportLcExpiry.expired && !lc.isExpired) return false;
    if (expiry == ExportLcExpiry.notExpired && lc.isExpired) return false;
    return true;
  }

  static String? _text(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// `yyyy-MM-dd`, the format the transfer capture sends.
  static String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Whole amounts as integers (`1000`, as captured), not `1000.0`.
  static num _amount(double v) => v == v.truncateToDouble() ? v.toInt() : v;
}
