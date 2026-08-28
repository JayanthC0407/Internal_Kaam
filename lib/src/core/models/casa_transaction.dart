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
            ObdxApiUtils.asMap(json['amount'])['currency'] ??
            ObdxApiUtils.asMap(json['transactionAmount'])['currency'] ??
            '')
        .toString()
        .trim();

    final amount = CasaAccount.readBalance(
          json,
          const [
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

/// OBDX `searchBy` period codes. Default [currentMonth] keeps the live
/// Postman value `CPR` so unfiltered loads stay unchanged.
enum CasaTransactionPeriod {
  currentMonth('CPR'),
  currentDay('C'),
  previousDay('P'),
  previousMonth('PM'),
  currentAndPreviousMonth('CP');

  const CasaTransactionPeriod(this.searchBy);

  final String searchBy;

  static CasaTransactionPeriod fromSearchBy(String? raw) {
    final code = (raw ?? '').trim().toUpperCase();
    for (final value in CasaTransactionPeriod.values) {
      if (value.searchBy == code) return value;
    }
    return CasaTransactionPeriod.currentMonth;
  }
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
class CasaTransactionQuery {
  const CasaTransactionQuery({
    this.period = CasaTransactionPeriod.currentMonth,
    this.creditDebit = CasaCreditDebitFilter.all,
    this.amount,
    this.referenceNumber,
  });

  final CasaTransactionPeriod period;
  final CasaCreditDebitFilter creditDebit;
  final String? amount;
  final String? referenceNumber;

  String get searchBy => period.searchBy;
  String get transactionType => creditDebit.code;

  bool get isDefault =>
      period == CasaTransactionPeriod.currentMonth &&
      creditDebit == CasaCreditDebitFilter.all &&
      !_hasText(amount) &&
      !_hasText(referenceNumber);

  CasaTransactionQuery copyWith({
    CasaTransactionPeriod? period,
    CasaCreditDebitFilter? creditDebit,
    String? amount,
    String? referenceNumber,
    bool clearAmount = false,
    bool clearReference = false,
  }) {
    return CasaTransactionQuery(
      period: period ?? this.period,
      creditDebit: creditDebit ?? this.creditDebit,
      amount: clearAmount ? null : (amount ?? this.amount),
      referenceNumber:
          clearReference ? null : (referenceNumber ?? this.referenceNumber),
    );
  }

  /// Query params for list and PDF download. Empty amount/ref are omitted.
  Map<String, dynamic> toQueryParameters() {
    return {
      'searchBy': searchBy,
      'transactionType': transactionType,
      if (_hasText(amount)) 'amount': amount!.trim(),
      if (_hasText(referenceNumber)) 'referenceNumber': referenceNumber!.trim(),
    };
  }

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CasaTransactionQuery &&
          period == other.period &&
          creditDebit == other.creditDebit &&
          amount == other.amount &&
          referenceNumber == other.referenceNumber;

  @override
  int get hashCode =>
      Object.hash(period, creditDebit, amount, referenceNumber);
}
