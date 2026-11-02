import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Corporate Loans & Finances (OBDX corporate menu `OBCL_LOAN`):
/// Transactions (`loans/obcl-loan-transactions`), Messages and Advices
/// (`obcl-loan-messages`, `obcl-loan-advices`), Multiple Loan Repayment
/// (flow `obcl-multi-loan-repayment`) and Application Tracker
/// (`process-management/loan-application-listing`). Payload shapes follow
/// those components' model.js.

/// A corporate loan: `GET corporateloan` → `accounts[]`.
class CorpLoan {
  const CorpLoan({
    required this.id,
    required this.displayNumber,
    required this.currency,
    this.productName,
    this.nickname,
    this.approved,
    this.outstanding,
    this.valueDate,
    this.maturityDate,
  });

  /// `id.value`, sent back in every per-loan call.
  final String id;
  final String displayNumber;
  final String currency;
  final String? productName;
  final String? nickname;

  /// Amount Financed (`approvedAmount`).
  final MoneyAmount? approved;

  /// Total Outstanding (`outstandingAmount`).
  final MoneyAmount? outstanding;
  final DateTime? valueDate;
  final DateTime? maturityDate;

  /// `{value, displayValue}` as OBDX sends account ids back.
  Map<String, dynamic> get idJson => {'value': id, 'displayValue': displayNumber};

  String get title => [productName, displayNumber].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

  static List<CorpLoan> listFromPayload(Map<String, dynamic> body) => [
        for (final a in _maps(body['accounts']))
          () {
            final id = ObdxApiUtils.asMap(a['id']);
            final approved = _money(a['approvedAmount']);
            final outstanding = _money(a['outstandingAmount']);
            return CorpLoan(
              id: _str(id['value']),
              displayNumber: _str(id['displayValue'] ?? id['value']),
              currency: _str(a['currencyCode'] ?? approved?.currency ?? outstanding?.currency),
              productName: _nullable(ObdxApiUtils.asMap(a['productDTO'])['name'] ?? a['productName']),
              nickname: _nullable(a['accountNickname']),
              approved: approved,
              outstanding: outstanding,
              valueDate: DateTime.tryParse(_str(a['valueDate'] ?? a['openingDate'])),
              maturityDate: DateTime.tryParse(_str(a['maturityDate'])),
            );
          }(),
      ].where((l) => l.id.isNotEmpty).toList();
}

// ── Transactions ─────────────────────────────────────────────────────────

/// OBDX's View Options for the transactions search.
enum CorpLoanPeriod {
  currentMonth('CPR'),
  currentDay('CDT'),
  previousDay('PDT'),
  previousMonth('PMT'),
  currentAndPreviousMonth('CPMT'),
  previousQuarter('PQT'),
  dateRange('SPD'),
  lastTen('LNT');

  const CorpLoanPeriod(this.code);

  final String code;
}

/// All / Credits Only / Debits Only.
enum CorpLoanTxnType {
  all('A'),
  credits('C'),
  debits('D');

  const CorpLoanTxnType(this.code);

  final String code;
}

/// The transactions search, turned into OBDX's query.
class CorpLoanTxnQuery {
  const CorpLoanTxnQuery({
    this.period = CorpLoanPeriod.currentMonth,
    this.type = CorpLoanTxnType.all,
    this.from,
    this.to,
    this.amount,
    this.reference,
  });

  final CorpLoanPeriod period;
  final CorpLoanTxnType type;

  /// Date Range only.
  final DateTime? from;
  final DateTime? to;

  /// When given, both `fromAmount` and `toAmount`.
  final double? amount;

  /// Party Reference Number (`referenceNo`).
  final String? reference;

  @override
  bool operator ==(Object other) =>
      other is CorpLoanTxnQuery &&
      other.period == period &&
      other.type == type &&
      other.from == from &&
      other.to == to &&
      other.amount == amount &&
      other.reference == reference;

  @override
  int get hashCode => Object.hash(period, type, from, to, amount, reference);

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// As OBDX sends it: Current Day, Previous Day and Current & Previous
  /// Month are worked out here and sent as a date range (`SPD`); Last 10
  /// sends `noOfTransactions=10`.
  Map<String, dynamic> toQuery(DateTime today) {
    final t = DateTime(today.year, today.month, today.day);
    final q = <String, dynamic>{'transactionType': type.code};
    void range(DateTime a, DateTime b) {
      q['searchBy'] = 'SPD';
      q['fromDate'] = _day(a);
      q['toDate'] = _day(b);
    }

    switch (period) {
      case CorpLoanPeriod.currentDay:
        range(t, t);
      case CorpLoanPeriod.previousDay:
        final y = t.subtract(const Duration(days: 1));
        range(y, y);
      case CorpLoanPeriod.currentAndPreviousMonth:
        range(DateTime(t.year, t.month - 1, 1), t);
      case CorpLoanPeriod.dateRange:
        range(from ?? t, to ?? t);
      case CorpLoanPeriod.lastTen:
        q['searchBy'] = 'LNT';
        q['noOfTransactions'] = 10;
      default:
        q['searchBy'] = period.code;
    }
    if (amount != null) {
      q['fromAmount'] = amount;
      q['toAmount'] = amount;
    }
    if ((reference ?? '').trim().isNotEmpty) q['referenceNo'] = reference!.trim();
    return q;
  }
}

/// One row: `corporateloan/{id}/transactions` → `items[]`.
class CorpLoanTxn {
  const CorpLoanTxn({
    required this.description,
    required this.reference,
    required this.isCredit,
    this.date,
    this.valueDate,
    this.amount,
  });

  final DateTime? date;
  final DateTime? valueDate;
  final String description;
  final String reference;
  final bool isCredit;
  final MoneyAmount? amount;

  static ({List<CorpLoanTxn> items, bool showValueDate}) fromPayload(Map<String, dynamic> body) {
    // `accountingEntryBasisType` V dates rows by value date, T by posting.
    final byValue = _str(body['accountingEntryBasisType']).toUpperCase() == 'V';
    final items = [
      for (final i in _maps(body['items']))
        CorpLoanTxn(
          date: DateTime.tryParse(_str(byValue ? (i['valueDate'] ?? i['postingDate']) : (i['postingDate'] ?? i['date']))),
          valueDate: DateTime.tryParse(_str(i['valueDate'])),
          description: _str(i['description']),
          reference: _str(ObdxApiUtils.asMap(i['key'])['transactionReferenceNumber']),
          isCredit: _str(i['transactionType']).toUpperCase() == 'C',
          amount: _money(i['amountInAccountCurrency'] ?? i['amount']),
        ),
    ];
    return (items: items, showValueDate: body['showValueDate'] == true);
  }
}

// ── Messages and Advices ─────────────────────────────────────────────────

/// `MESSAGE` (SWIFT messages) or `ADVICE`.
enum CorpLoanNoticeKind {
  message('MESSAGE'),
  advice('ADVICE');

  const CorpLoanNoticeKind(this.code);

  final String code;
}

/// `corporateloan/{id}/swiftMessageOrAdviceDetails` → `swiftMessages[]`.
class CorpLoanNotice {
  const CorpLoanNotice({
    required this.messageId,
    required this.description,
    required this.text,
    this.date,
    this.messageType,
    this.eventDescription,
  });

  final String messageId;
  final DateTime? date;
  final String description;

  /// Messages: `messageType`.
  final String? messageType;

  /// Advices: `eventDescription`.
  final String? eventDescription;

  /// The full message / advice.
  final String text;

  static List<CorpLoanNotice> listFromPayload(Map<String, dynamic> body) => [
        for (final m in _maps(body['swiftMessages']))
          CorpLoanNotice(
            messageId: _str(m['messageId']),
            date: DateTime.tryParse(_str(m['date'])),
            description: _str(m['description']),
            messageType: _nullable(m['messageType']),
            eventDescription: _nullable(m['eventDescription']),
            text: _str(m['message']),
          ),
      ];
}

// ── Multiple Loan Repayment ──────────────────────────────────────────────

/// The Get Contracts filter (the flow's filter panel).
class CorpLoanContractFilter {
  const CorpLoanContractFilter({
    this.product,
    this.currency,
    this.amountFrom,
    this.amountTo,
    this.disbursedFrom,
    this.disbursedTo,
    this.maturityFrom,
    this.maturityTo,
  });

  final String? product;
  final String? currency;
  final double? amountFrom;
  final double? amountTo;
  final DateTime? disbursedFrom;
  final DateTime? disbursedTo;
  final DateTime? maturityFrom;
  final DateTime? maturityTo;

  bool get isEmpty =>
      product == null &&
      currency == null &&
      amountFrom == null &&
      amountTo == null &&
      disbursedFrom == null &&
      disbursedTo == null &&
      maturityFrom == null &&
      maturityTo == null;

  Map<String, dynamic> toQuery(DateTime today) {
    String day(DateTime d) => CorpLoanTxnQuery._day(d);
    return {
      'applicationDate': day(today),
      if (product != null) 'product': product,
      if (currency != null) 'currencyCode': currency,
      if (amountFrom != null) 'loanAmountFrom': amountFrom,
      if (amountTo != null) 'loanAmountTo': amountTo,
      if (disbursedFrom != null) 'dsbrFromDate': day(disbursedFrom!),
      if (disbursedTo != null) 'dsbrToDate': day(disbursedTo!),
      if (maturityFrom != null) 'maturityFromDate': day(maturityFrom!),
      if (maturityTo != null) 'maturityToDate': day(maturityTo!),
    };
  }
}

/// One line of `bulkCorporateLoan/{id}/fetchRepaymentAllocation` →
/// `components[]`: how a repayment is split.
class CorpRepaymentComponent {
  const CorpRepaymentComponent({
    required this.component,
    required this.description,
    this.due,
    this.overdueDays,
    this.paid,
    this.taxPaid,
    required this.raw,
  });

  final String component;
  final String description;
  final MoneyAmount? due;
  final int? overdueDays;
  final MoneyAmount? paid;
  final MoneyAmount? taxPaid;

  /// Sent back as one `repaymentSimulations[]` entry.
  final Map<String, dynamic> raw;

  Map<String, dynamic> toSimulation() => {
        'amountDue': raw['amountDue'],
        'amountPaid': raw['amountPaid'],
        'component': component,
        'componentDescription': description,
        'totalTaxPaid': raw['totalTaxPaid'],
      };

  static List<CorpRepaymentComponent> listFromPayload(Map<String, dynamic> body) => [
        for (final c in _maps(body['components'] ?? ObdxApiUtils.asMap(body['repaymentDetailDTO'])['components']))
          CorpRepaymentComponent(
            component: _str(c['component']),
            description: _str(c['componentDescription']),
            due: _money(c['amountDue']),
            overdueDays: c['overdueDays'] is num ? (c['overdueDays'] as num).toInt() : int.tryParse(_str(c['overdueDays'])),
            paid: _money(c['amountPaid']),
            taxPaid: _money(c['totalTaxPaid']),
            raw: c,
          ),
      ];
}

/// One contract to repay, as filled in on the first step.
class CorpRepaymentLine {
  const CorpRepaymentLine({
    required this.loan,
    required this.amount,
    required this.principalAccount,
    this.interestAccount,
    this.chargesAccount,
    this.dealReference,
    this.components = const [],
  });

  final CorpLoan loan;
  final double amount;

  /// Source Account (Principal / Interest / Charges): `{value, displayValue}`.
  final Map<String, dynamic> principalAccount;
  final Map<String, dynamic>? interestAccount;
  final Map<String, dynamic>? chargesAccount;
  final String? dealReference;

  /// This contract's own allocation (OBDX accumulated every earlier
  /// contract's too; here each sends only its own).
  final List<CorpRepaymentComponent> components;

  /// `POST corporateloan/{id}/repayments`, in the loan's own currency (OBDX
  /// sent USD whatever the loan).
  Map<String, dynamic> toBody(String bulkReference) {
    String? day(DateTime? d) => d == null ? null : CorpLoanTxnQuery._day(d);
    return {
      'amount': {'amount': amount, 'currency': loan.currency},
      'date': day(loan.maturityDate),
      'chargesAccount': chargesAccount ?? principalAccount,
      'settlementAccountId': principalAccount,
      'interestSettlementAccountId': interestAccount ?? principalAccount,
      'dealReferenceNumber': dealReference ?? '',
      'typeOfSettlement': 'P',
      'branchId': '',
      'maturityDate': day(loan.maturityDate),
      'valueDate': day(loan.valueDate),
      'bulkReferenceNumber': bulkReference,
      'repaymentSimulations': [for (final c in components) c.toSimulation()],
    };
  }
}

/// How one contract's repayment went.
class CorpRepaymentResult {
  const CorpRepaymentResult({required this.loan, required this.status, this.reference, this.message});

  final CorpLoan loan;

  /// `success`, `pending` (approval) or `failure`.
  final String status;
  final String? reference;
  final String? message;
}

// ── Application Tracker ──────────────────────────────────────────────────

/// The tracker's tabs (`processManagement?status=`).
enum CorpAppStatus {
  draft('DRAFT', 'Draft'),
  submitted('SUBMITTED', 'Submitted'),
  inProgress('IN_PROGRESS', 'In Progress'),
  completed('COMPLETED', 'Completed');

  const CorpAppStatus(this.code, this.label);

  final String code;
  final String label;
}

/// `processManagement` → `processManagementDTOs[]`.
class CorpLoanApplicationItem {
  const CorpLoanApplicationItem({
    required this.refId,
    required this.type,
    required this.status,
    this.draftName,
    this.midOfficeRefNo,
    this.amount,
    this.date,
  });

  final String refId;

  /// `Loan Drawdown`, `Trade Loan Drawdown`, …
  final String type;
  final String status;
  final String? draftName;

  /// The bank's reference once submitted.
  final String? midOfficeRefNo;
  final MoneyAmount? amount;
  final DateTime? date;

  /// What the card leads with: the draft's name, else the bank's
  /// reference, else ours.
  String get title => (draftName ?? midOfficeRefNo ?? refId);

  static List<CorpLoanApplicationItem> listFromPayload(Map<String, dynamic> body) => [
        for (final p in _maps(body['processManagementDTOs']))
          CorpLoanApplicationItem(
            refId: _str(p['refId']),
            type: _str(p['type']),
            status: _str(p['status']),
            draftName: _nullable(p['draftName']),
            midOfficeRefNo: _nullable(p['midOfficeRefNo']),
            amount: _money(p['amount']),
            date: DateTime.tryParse(_str(p['creationDate'] ?? p['appDate'])),
          ),
      ]..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
}

/// An application's document: `processManagement/{id}/documents` →
/// `contentDTOList[]`.
class CorpAppDocument {
  const CorpAppDocument({required this.contentId, required this.title});

  final String contentId;
  final String title;

  static List<CorpAppDocument> listFromPayload(Map<String, dynamic> body) => [
        for (final c in _maps(body['contentDTOList']))
          CorpAppDocument(
            contentId: _str(ObdxApiUtils.asMap(c['contentId'])['value'] ?? c['contentId']),
            title: _str(c['title'] ?? c['fileName']),
          ),
      ].where((d) => d.contentId.isNotEmpty).toList();
}

// ── Helpers ──────────────────────────────────────────────────────────────

String _str(dynamic v) => v == null || v is Map || v is List ? '' : v.toString().trim();

String? _nullable(dynamic v) {
  final s = _str(v);
  return s.isEmpty ? null : s;
}

MoneyAmount? _money(dynamic raw) {
  if (raw is num) return MoneyAmount(amount: raw.toDouble());
  final m = ObdxApiUtils.asMap(raw);
  final amount = m['amount'];
  if (amount == null) return null;
  final value = amount is num ? amount.toDouble() : double.tryParse(amount.toString());
  if (value == null) return null;
  return MoneyAmount(amount: value, currency: _nullable(m['currency']));
}

List<Map<String, dynamic>> _maps(dynamic raw) => [
      if (raw is List)
        for (final item in raw)
          if (item is Map) Map<String, dynamic>.from(item),
    ];
