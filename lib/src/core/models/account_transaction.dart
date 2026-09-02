import 'package:ubci_bank/src/core/models/casa_account.dart';

/// Debit / credit direction of a transaction line.
enum TransactionDirection { debit, credit, unknown }

/// A single posted transaction line from
/// `GET /digx-common/dda/v1/demandDeposit/{accountId}/transactions`.
///
/// Shape confirmed against the OBDX Mobile Banking Postman collection —
/// one `items[]` entry looks like:
/// ```json
/// {
///   "postingDate": "2022-12-22T00:00:00",
///   "transactionDate": "2022-12-22T00:00:00",
///   "accountId": { "displayValue": "xxxxxxxxxxxx0139", "value": "CAA567...2909" },
///   "amountInAccountCurrency": { "currency": "GBP", "amount": 5000 },
///   "description": "PRINCIPAL Liquidation",
///   "userReferenceNumber": "000ZTRF2235606CY",
///   "key": { "transactionReferenceNumber": "000ZTRF2235606CY", "subSequenceNumber": "74129" },
///   "transactionType": "D",
///   "runningBalance": { "currency": "GBP", "amount": 140000 }
/// }
/// ```
/// `transactionType`: `"D"` → debit, `"C"` → credit. OBDX doesn't return
/// any spend-category classification on this endpoint — [description] is
/// a free-text host narrative (e.g. "PRINCIPAL Liquidation").
class AccountTransaction {
  const AccountTransaction({
    required this.reference,
    required this.description,
    required this.direction,
    required this.amount,
    this.date,
    this.runningBalance,
  });

  /// `userReferenceNumber` (falls back to `key.transactionReferenceNumber`).
  final String reference;

  /// Host narrative (`description`), e.g. "PRINCIPAL Liquidation".
  final String description;

  final TransactionDirection direction;

  /// Always a positive magnitude — sign is conveyed via [direction].
  final MoneyAmount amount;

  /// `transactionDate`, falling back to `postingDate`.
  final DateTime? date;

  final MoneyAmount? runningBalance;

  bool get isCredit => direction == TransactionDirection.credit;
  bool get isDebit => direction == TransactionDirection.debit;

  /// True when parsing found essentially none of the fields this model
  /// expects. This parser is built and confirmed for the CASA
  /// (`dda/v1/.../transactions`) payload shape — if another module's
  /// endpoint (e.g. loans) uses different field names, every transaction
  /// silently comes back as a fabricated "0.00, direction unknown" row
  /// instead of a visible error. Callers should treat an all-unparsed
  /// batch as a failure, not an empty/zero result.
  bool get looksUnparsed =>
      amount.amount == 0 &&
      direction == TransactionDirection.unknown &&
      reference.isEmpty &&
      date == null;

  /// Signed amount for callers that want a single number (credit positive).
  double get signedAmount =>
      isDebit ? -amount.amount.abs() : amount.amount.abs();

  factory AccountTransaction.fromJson(Map<String, dynamic> json) {
    final amountDTO = json['amountInAccountCurrency'];
    final runningBalanceDTO = json['runningBalance'];
    final keyDTO = json['key'] is Map
        ? Map<String, dynamic>.from(json['key'] as Map)
        : null;

    final rawDirection =
    (json['transactionType'] ?? '').toString().trim().toUpperCase();
    final direction = rawDirection == 'C'
        ? TransactionDirection.credit
        : rawDirection == 'D'
        ? TransactionDirection.debit
        : TransactionDirection.unknown;

    final amount = MoneyAmount.fromJson(amountDTO);

    final reference = (json['userReferenceNumber'] ??
        keyDTO?['transactionReferenceNumber'] ??
        '')
        .toString()
        .trim();

    final description = (json['description'] ?? '').toString().trim();

    final rawDate = json['transactionDate'] ?? json['postingDate'];

    return AccountTransaction(
      reference: reference,
      description: description.isEmpty ? '—' : description,
      direction: direction,
      amount: MoneyAmount(amount: amount.amount.abs(), currency: amount.currency),
      date: _parseDate(rawDate),
      runningBalance: runningBalanceDTO == null
          ? null
          : MoneyAmount.fromJson(runningBalanceDTO),
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim());
    }
    return null;
  }

  /// Parses the `{ "items": [ ... ], "summary": { ... } }` response body
  /// (or a wrapped HTTP-response map with `body`/`rawBody`).
  static List<AccountTransaction> listFromPayload(dynamic data) {
    final root = _unwrap(data);
    if (root == null) return const [];

    final rawList = root['items'];
    if (rawList is! List) return const [];

    final transactions = <AccountTransaction>[];
    for (final item in rawList) {
      if (item is! Map) continue;
      transactions
          .add(AccountTransaction.fromJson(Map<String, dynamic>.from(item)));
    }
    // Most-recent-first — the host doesn't consistently guarantee ordering.
    transactions.sort((a, b) {
      final da = a.date;
      final db = b.date;
      if (da == null || db == null) return 0;
      return db.compareTo(da);
    });
    return transactions;
  }

  static Map<String, dynamic>? _unwrap(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map.containsKey('items')) return map;
    final body = map['body'];
    if (body is Map) return _unwrap(body);
    return map;
  }
}

/// Opening/closing balance + debit/credit totals from the same response's
/// `summary` block — for a future statement screen; not currently wired up.
class TransactionStatementSummary {
  const TransactionStatementSummary({
    required this.openingBalance,
    required this.closingBalance,
    required this.debitCount,
    required this.creditCount,
    required this.debitAmount,
    required this.creditAmount,
  });

  final double openingBalance;
  final double closingBalance;
  final int debitCount;
  final int creditCount;
  final double debitAmount;
  final double creditAmount;

  factory TransactionStatementSummary.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) =>
        v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;
    int toInt(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;

    return TransactionStatementSummary(
      openingBalance: toDouble((json['openingBalance'] as Map?)?['amount']),
      closingBalance: toDouble((json['closingBalance'] as Map?)?['amount']),
      debitCount: toInt(json['debitCount']),
      creditCount: toInt(json['creditCount']),
      debitAmount: toDouble((json['debitAmount'] as Map?)?['amount']),
      creditAmount: toDouble((json['creditAmount'] as Map?)?['amount']),
    );
  }
}