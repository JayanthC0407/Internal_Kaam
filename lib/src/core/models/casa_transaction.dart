import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Single CASA transaction from
/// `GET /digx-common/dda/v1/demandDeposit/{accountId}/transactions`.
class CasaTransaction {
  const CasaTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.isCredit,
    this.subtitle,
    this.reference,
    this.dateTime,
    this.transactionDate,
    this.valueDate,
    this.runningBalance,
    this.status,
  });

  final String id;
  final String title;
  final MoneyAmount amount;
  final bool isCredit;
  final String? subtitle;
  final String? reference;
  final DateTime? dateTime;
  final DateTime? transactionDate;
  final DateTime? valueDate;
  final MoneyAmount? runningBalance;
  final String? status;

  bool get isSuccess {
    final s = status?.toUpperCase() ?? '';
    if (s.isEmpty) return true;
    return s.contains('SUCCESS') ||
        s == 'COMPLETED' ||
        s == 'POSTED' ||
        s == 'PROCESSED';
  }

  factory CasaTransaction.fromJson(Map<String, dynamic> json) {
    final currency = (json['currencyCode'] ??
            json['currency'] ??
            ObdxApiUtils.asMap(json['amountInAccountCurrency'])['currency'] ??
            ObdxApiUtils.asMap(json['amount'])['currency'] ??
            ObdxApiUtils.asMap(json['transactionAmount'])['currency'] ??
            '')
        .toString()
        .trim();

    final amount = CasaAccount.readBalance(
          json,
          const [
            // Confirmed field name (HAR capture of
            // dda/v1/demandDeposit/.../transactions) — kept first.
            'amountInAccountCurrency',
            'transactionAmount',
            'amount',
            'txnAmount',
            'value',
          ],
          currency,
        ) ??
        MoneyAmount(amount: 0, currency: currency);

    final indicator = (json['creditDebitIndicator'] ??
            json['drCrIndicator'] ??
            json['transactionType'] ??
            json['type'] ??
            '')
        .toString()
        .trim()
        .toUpperCase();

    final isCredit = indicator.startsWith('C') ||
        indicator == 'CREDIT' ||
        indicator == 'CR' ||
        (json['isCredit'] == true);

    final title = _toDisplayCase(
      _firstNonEmpty([
            json['narrative'],
            json['description'],
            json['txnDescription'],
            json['transactionDescription'],
            json['remarks'],
            json['counterPartyName'],
            json['payeeName'],
            json['merchantName'],
          ]) ??
          'Transaction',
    );

    final rawSubtitle = _firstNonEmpty([
      json['location'],
      json['counterPartyLocation'],
      json['branchName'],
      json['additionalInfo'],
    ]);
    final subtitle =
        rawSubtitle == null ? null : _toDisplayCase(rawSubtitle);
    final reference = _firstNonEmpty([
      // Confirmed field names (HAR capture): top-level userReferenceNumber,
      // falling back to the nested key.transactionReferenceNumber.
      json['userReferenceNumber'],
      ObdxApiUtils.asMap(json['key'])['transactionReferenceNumber'],
      json['referenceNumber'],
      json['txnReference'],
      json['transactionReference'],
      json['refNo'],
      json['retrievalReferenceNumber'],
      json['id'],
    ]);

    final valueDate = _parseDate(
      json['valueDate'] ?? json['postedDate'],
    );
    final transactionDate = _parseDate(
      json['transactionDate'] ??
          json['bookingDate'] ??
          json['date'] ??
          json['txnDate'],
    );
    final dateTime = valueDate ?? transactionDate;

    final runningBalance = CasaAccount.readBalance(
      json,
      const [
        'runningBalance',
        'balance',
        'accountBalance',
        'currentBalance',
      ],
      currency,
    );

    final id = (json['transactionId'] ??
            json['id'] ??
            reference ??
            '${title}_${dateTime?.millisecondsSinceEpoch ?? 0}')
        .toString();

    return CasaTransaction(
      id: id,
      title: title,
      amount: amount,
      isCredit: isCredit,
      subtitle: subtitle,
      reference: reference,
      dateTime: dateTime,
      transactionDate: transactionDate,
      valueDate: valueDate,
      runningBalance: runningBalance,
      status: _firstNonEmpty([
        json['status'],
        json['transactionStatus'],
        ObdxApiUtils.asMap(json['statusDTO'])['description'],
      ]),
    );
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  /// Normalizes mixed bank narratives (e.g. `PRINCIPAL Liquidation`) to
  /// consistent Title Case while keeping short acronyms (ATM, NEFT, UPI).
  static String _toDisplayCase(String input) {
    final trimmed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return trimmed;
    return trimmed.split(' ').map(_toDisplayWord).join(' ');
  }

  static String _toDisplayWord(String word) {
    if (word.isEmpty) return word;
    return word.replaceAllMapped(RegExp(r'[A-Za-z0-9]+'), (match) {
      final token = match[0]!;
      if (_isShortAcronym(token)) return token;
      final lower = token.toLowerCase();
      return '${lower[0].toUpperCase()}${lower.substring(1)}';
    });
  }

  static bool _isShortAcronym(String token) {
    return token.length >= 2 &&
        token.length <= 4 &&
        token == token.toUpperCase() &&
        RegExp(r'^[A-Z0-9]+$').hasMatch(token);
  }
  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is int) {
      // Epoch ms or seconds.
      if (raw > 9999999999) {
        return DateTime.fromMillisecondsSinceEpoch(raw);
      }
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
    }
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}

/// Transactions list plus optional opening/closing balances from the payload.
class CasaTransactionsResult {
  const CasaTransactionsResult({
    required this.transactions,
    this.openingBalance,
    this.closingBalance,
    this.currencyCode,
  });

  final List<CasaTransaction> transactions;
  final MoneyAmount? openingBalance;
  final MoneyAmount? closingBalance;
  final String? currencyCode;

  factory CasaTransactionsResult.fromPayload(dynamic data) {
    final root = _unwrap(data) ?? {};
    final currency = (root['currencyCode'] ?? root['currency'] ?? '')
        .toString()
        .trim();

    final rawList = root['transactions'] ??
        root['transactionDTOs'] ??
        root['items'] ??
        root['accountTransactions'];

    final transactions = <CasaTransaction>[];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is! Map) continue;
        transactions.add(
          CasaTransaction.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }

    return CasaTransactionsResult(
      transactions: transactions,
      openingBalance: CasaAccount.readBalance(
        root,
        const ['openingBalance', 'openingBal', 'todaysOpeningBalance'],
        currency,
      ),
      closingBalance: CasaAccount.readBalance(
        root,
        const [
          'closingBalance',
          'closingBal',
          'currentBalance',
          'availableBalance',
        ],
        currency,
      ),
      currencyCode: currency.isEmpty ? null : currency,
    );
  }

  static Map<String, dynamic>? _unwrap(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map.containsKey('transactions') ||
        map.containsKey('transactionDTOs') ||
        map.containsKey('openingBalance') ||
        map.containsKey('items')) {
      return map;
    }
    final body = map['body'];
    if (body is Map) return _unwrap(body);
    return map;
  }
}

/// OBDX `searchBy` period codes, per the API doc's confirmed enum:
/// `CPR` (current period), `SPD` (specific period — a single day, the
/// previous day, or a date range, all expressed via `fromDate`/`toDate`),
/// `PMT` (previous month), `PQT` (previous quarter), and `LNT` (last N
/// transactions). [specificDay], [previousDay], and [dateRange] are
/// distinct UI options that all resolve to `SPD` on the wire — they only
/// differ in how [CasaTransactionQuery] computes `fromDate`/`toDate` for
/// each. Default [currentMonth] keeps the live Postman value `CPR` so
/// unfiltered loads stay unchanged.
enum CasaTransactionPeriod {
  currentMonth('CPR'),
  specificDay('SPD'),
  previousDay('SPD'),
  dateRange('SPD'),
  previousMonth('PMT'),
  previousQuarter('PQT'),
  last10('LNT');

  const CasaTransactionPeriod(this.searchBy);

  final String searchBy;
}

/// OBDX `transactionType`: A = all, C = credits, D = debits.
enum CasaCreditDebitFilter {
  all('A'),
  credits('C'),
  debits('D');

  const CasaCreditDebitFilter(this.code);

  final String code;

  static CasaCreditDebitFilter fromCode(String? raw) {
    final code = (raw ?? '').trim().toUpperCase();
    for (final value in CasaCreditDebitFilter.values) {
      if (value.code == code) return value;
    }
    return CasaCreditDebitFilter.all;
  }
}

/// Query sent to `GET …/demandDeposit/{accountId}/transactions`.
///
/// [specificDate] is only meaningful when [period] is
/// [CasaTransactionPeriod.specificDay]; [rangeStart]/[rangeEnd] only when
/// [period] is [CasaTransactionPeriod.dateRange]. [CasaTransactionPeriod.previousDay]
/// needs no stored date — it's computed as "yesterday" at query time.
class CasaTransactionQuery {
  const CasaTransactionQuery({
    this.period = CasaTransactionPeriod.currentMonth,
    this.creditDebit = CasaCreditDebitFilter.all,
    this.specificDate,
    this.rangeStart,
    this.rangeEnd,
    this.fromAmount,
    this.toAmount,
    this.referenceNumber,
  });

  final CasaTransactionPeriod period;
  final CasaCreditDebitFilter creditDebit;
  final DateTime? specificDate;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final String? fromAmount;
  final String? toAmount;
  final String? referenceNumber;

  String get searchBy => period.searchBy;
  String get transactionType => creditDebit.code;

  bool get isDefault =>
      period == CasaTransactionPeriod.currentMonth &&
      creditDebit == CasaCreditDebitFilter.all &&
      !_hasText(fromAmount) &&
      !_hasText(toAmount) &&
      !_hasText(referenceNumber);

  CasaTransactionQuery copyWith({
    CasaTransactionPeriod? period,
    CasaCreditDebitFilter? creditDebit,
    DateTime? specificDate,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    String? fromAmount,
    String? toAmount,
    String? referenceNumber,
    bool clearSpecificDate = false,
    bool clearRangeStart = false,
    bool clearRangeEnd = false,
    bool clearFromAmount = false,
    bool clearToAmount = false,
    bool clearReference = false,
  }) {
    return CasaTransactionQuery(
      period: period ?? this.period,
      creditDebit: creditDebit ?? this.creditDebit,
      specificDate: clearSpecificDate
          ? null
          : (specificDate ?? this.specificDate),
      rangeStart: clearRangeStart ? null : (rangeStart ?? this.rangeStart),
      rangeEnd: clearRangeEnd ? null : (rangeEnd ?? this.rangeEnd),
      fromAmount: clearFromAmount ? null : (fromAmount ?? this.fromAmount),
      toAmount: clearToAmount ? null : (toAmount ?? this.toAmount),
      referenceNumber:
          clearReference ? null : (referenceNumber ?? this.referenceNumber),
    );
  }

  /// Resolves the `fromDate`/`toDate` pair to send for `SPD`-family
  /// periods. Returns null for periods that don't send dates at all.
  (DateTime, DateTime)? _resolveDateRange() {
    switch (period) {
      case CasaTransactionPeriod.specificDay:
        final day = specificDate ?? DateTime.now();
        return (day, day);
      case CasaTransactionPeriod.previousDay:
        final yesterday =
            DateTime.now().subtract(const Duration(days: 1));
        return (yesterday, yesterday);
      case CasaTransactionPeriod.dateRange:
        if (rangeStart == null || rangeEnd == null) return null;
        return (rangeStart!, rangeEnd!);
      case CasaTransactionPeriod.currentMonth:
      case CasaTransactionPeriod.previousMonth:
      case CasaTransactionPeriod.previousQuarter:
      case CasaTransactionPeriod.last10:
        return null;
    }
  }

  /// Query params for list and PDF download. Empty/absent fields are
  /// omitted rather than sent blank.
  Map<String, dynamic> toQueryParameters() {
    final params = <String, dynamic>{
      'searchBy': searchBy,
      'transactionType': transactionType,
    };

    final dateRange = _resolveDateRange();
    if (dateRange != null) {
      params['fromDate'] = _formatDate(dateRange.$1);
      params['toDate'] = _formatDate(dateRange.$2);
    }

    if (period == CasaTransactionPeriod.last10) {
      params['noOfTransactions'] = 10;
    }

    if (_hasText(fromAmount)) params['fromAmount'] = fromAmount!.trim();
    if (_hasText(toAmount)) params['toAmount'] = toAmount!.trim();
    if (_hasText(referenceNumber)) {
      params['referenceNo'] = referenceNumber!.trim();
    }

    return params;
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CasaTransactionQuery &&
          period == other.period &&
          creditDebit == other.creditDebit &&
          specificDate == other.specificDate &&
          rangeStart == other.rangeStart &&
          rangeEnd == other.rangeEnd &&
          fromAmount == other.fromAmount &&
          toAmount == other.toAmount &&
          referenceNumber == other.referenceNumber;

  @override
  int get hashCode => Object.hash(
        period,
        creditDebit,
        specificDate,
        rangeStart,
        rangeEnd,
        fromAmount,
        toAmount,
        referenceNumber,
      );
}
