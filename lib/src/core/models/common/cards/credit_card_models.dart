import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// OBDX Credit Cards — list and transactions.
/// Evidence for every field and rule: docs/obdx/features/credit-cards.md.

/// `cardStatus` (nls credit-card-listing.js:28-32).
enum CreditCardStatus {
  active('ACT'),
  inactive('IAT'),
  hotlisted('HTL'),
  cancelled('CLD'),
  blocked('BLK'),
  unknown('');

  const CreditCardStatus(this.code);

  final String code;

  static CreditCardStatus fromCode(dynamic raw) {
    final code = (raw ?? '').toString().trim().toUpperCase();
    for (final s in values) {
      if (s != unknown && s.code == code) return s;
    }
    return unknown;
  }
}

/// One `creditcards[]` item, read the way OBDX's credit-card-listing does
/// (hooks.js:129-145; credit-card-listing.html:36-54).
class CreditCard {
  const CreditCard({
    required this.id,
    required this.displayNumber,
    this.ownerName,
    this.expiry,
    this.status = CreditCardStatus.unknown,
    this.rawStatus,
    this.isPrimary = true,
    this.availableCredit,
    this.creditLimit,
    this.currentOutstanding,
    this.totalDue,
    this.minimumDue,
    this.dueDate,
  });

  /// `creditCard.value` — used in `cards/credit/{id}/…`.
  final String id;

  /// `creditCard.displayValue` (masked).
  final String displayNumber;
  final String? ownerName;

  /// `validity.end`; shown as MM/YY.
  final DateTime? expiry;
  final CreditCardStatus status;
  final String? rawStatus;

  /// `cardOwnershipType` PRIMARY (else an Add-On card).
  final bool isPrimary;

  /// `limits[type == CR].available` — "Available Credit Limit".
  final MoneyAmount? availableCredit;

  /// `limits[type == CR].total` — the card's whole limit (UAT shows it next
  /// to `available`); summed for the design's "Total Credit Limit" tile.
  final MoneyAmount? creditLimit;

  /// `due.unbilledAmount` — "Current Outstanding".
  final MoneyAmount? currentOutstanding;

  /// `due.billedAmount` — "Total Due".
  final MoneyAmount? totalDue;

  /// `due.minimumAmount` — "Minimum Due".
  final MoneyAmount? minimumDue;

  /// `due.expectedPaymentDate` — "Due On".
  final DateTime? dueDate;

  /// OBDX shows Total Due / Minimum Due / Due On and "Pay" only when the
  /// billed amount is not 0; otherwise "No Dues" (html:42-54).
  bool get hasDues => totalDue != null && totalDue!.amount != 0;

  /// OBDX offers Transactions for a PRIMARY card that is not INACTIVE
  /// (hooks.js:147-154).
  bool get canViewTransactions => isPrimary && status != CreditCardStatus.inactive;

  /// "MM/YY", as OBDX formats `validity.end` (hooks.js:131-133).
  String? get expiryLabel {
    final e = expiry;
    if (e == null) return null;
    return '${e.month.toString().padLeft(2, '0')}/${(e.year % 100).toString().padLeft(2, '0')}';
  }

  /// Last four digits of the masked number, for compact labels.
  String get lastDigits {
    final digits = displayNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length <= 4 ? digits : digits.substring(digits.length - 4);
  }

  static CreditCard? fromJson(dynamic json) {
    if (json is! Map) return null;
    final map = ObdxApiUtils.asMap(json);
    final number = ObdxApiUtils.asMap(map['creditCard']);
    final id = _str(number['value']);
    if (id == null) return null;
    final limits = map['limits'];
    Map<String, dynamic>? creditLimit;
    if (limits is List) {
      for (final l in limits.map(ObdxApiUtils.asMap)) {
        if (_str(l['type'])?.toUpperCase() == 'CR') creditLimit = l;
      }
    }
    final due = ObdxApiUtils.asMap(map['due']);
    MoneyAmount? money(dynamic v) => v == null ? null : MoneyAmount.fromJson(v);
    return CreditCard(
      id: id,
      displayNumber: _str(number['displayValue']) ?? id,
      ownerName: _str(map['ownerName']),
      expiry: parseObdxDate(ObdxApiUtils.asMap(map['validity'])['end']),
      status: CreditCardStatus.fromCode(map['cardStatus']),
      rawStatus: _str(map['cardStatus']),
      isPrimary: (_str(map['cardOwnershipType']) ?? 'PRIMARY').toUpperCase() == 'PRIMARY',
      availableCredit: money(creditLimit?['available']),
      creditLimit: money(creditLimit?['total']),
      currentOutstanding: money(due['unbilledAmount']),
      totalDue: money(due['billedAmount']),
      minimumDue: money(due['minimumAmount']),
      dueDate: parseObdxDate(due['expectedPaymentDate']),
    );
  }

  /// Body of `GET cards/credit?expand=ALL`: `{ creditcards: [...] }`.
  static List<CreditCard> listFromPayload(Map<String, dynamic> body) {
    final items = body['creditcards'];
    if (items is! List) return const [];
    return items.map(fromJson).whereType<CreditCard>().toList();
  }
}

/// "Unbilled Transactions" (`UBT`) / "Billed Transactions" (`BT`).
enum CardStatementType {
  unbilled('UNBILLED'),
  billed('BILLED');

  const CardStatementType(this.code);

  final String code;
}

/// A statement month for Billed Transactions. [month] is 1-12 (Dart).
class CardStatementMonth {
  const CardStatementMonth(this.year, this.month);

  final int year;
  final int month;

  /// The `statementMonth` OBDX sends: the **0-based** JavaScript month
  /// (account-transactions/hooks.js:737-738, 1676-1682). [UNKNOWN] on the
  /// wire until a UAT capture confirms it — change only here.
  int get obdxMonth => month - 1;

  @override
  bool operator ==(Object other) => other is CardStatementMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

/// OBDX's month list: the 12 months back from the last statement date
/// (hooks.js:725-748), newest first.
List<CardStatementMonth> billedMonths(DateTime statementDate) => [
      for (var i = 0; i < 12; i++)
        () {
          final d = DateTime(statementDate.year, statementDate.month - i, 1);
          return CardStatementMonth(d.year, d.month);
        }(),
    ];

/// `GET cards/credit/{cardId}/statements/transactions` search.
class CardTransactionsQuery {
  const CardTransactionsQuery({required this.cardId, this.type = CardStatementType.unbilled, this.month});

  final String cardId;
  final CardStatementType type;

  /// Billed only; null asks OBDX for the latest statement (used to learn
  /// the statement date before the month list is shown).
  final CardStatementMonth? month;

  Map<String, dynamic> toQueryParameters() => {
        'type': type.code,
        if (type == CardStatementType.billed && month != null) ...{
          'statementMonth': month!.obdxMonth,
          'statementYear': month!.year,
        },
      };

  @override
  bool operator ==(Object other) =>
      other is CardTransactionsQuery && other.cardId == cardId && other.type == type && other.month == month;

  @override
  int get hashCode => Object.hash(cardId, type, month);
}

/// One `statmentItems[]` row (OBDX's spelling), shaped like OBDX's table
/// (hooks.js:1245-1262).
class CardTransaction {
  const CardTransaction({
    required this.description,
    this.date,
    this.isCredit = false,
    this.amount,
  });

  /// `product-cardOwnershipType-number-transactionDescription`, as OBDX
  /// builds it.
  final String description;
  final DateTime? date;

  /// `crdrFlag` C (else debit).
  final bool isCredit;
  final MoneyAmount? amount;
}

/// Body of the card transactions call.
class CardStatementResult {
  const CardStatementResult({required this.transactions, this.statementDate});

  /// Newest first, like OBDX.
  final List<CardTransaction> transactions;

  /// The last `statement[].statementDate` — the anchor of the Billed
  /// month list.
  final DateTime? statementDate;

  static CardStatementResult fromPayload(Map<String, dynamic> body) {
    final statements = body['statement'];
    final rows = <CardTransaction>[];
    DateTime? statementDate;
    if (statements is List) {
      for (final st in statements.map(ObdxApiUtils.asMap)) {
        statementDate = parseObdxDate(st['statementDate']) ?? statementDate;
        final prefix = [
          _str(st['product']),
          _str(st['cardOwnershipType']),
          _str(ObdxApiUtils.asMap(st['number'])['displayValue']),
        ].whereType<String>().join('-');
        final items = st['statmentItems'];
        if (items is! List) continue;
        for (final it in items.map(ObdxApiUtils.asMap)) {
          final text = _str(it['transactionDescription']) ?? '';
          rows.add(CardTransaction(
            description: [prefix, text].where((v) => v.isNotEmpty).join('-'),
            date: parseObdxDate(it['transactionDate']),
            isCredit: _str(it['crdrFlag'])?.toUpperCase() == 'C',
            amount: it['amount'] == null ? null : MoneyAmount.fromJson(it['amount']),
          ));
        }
      }
    }
    rows.sort((a, b) {
      final da = a.date, db = b.date;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return CardStatementResult(transactions: rows, statementDate: statementDate);
  }
}

/// OBDX dates: ISO (`2026-10-22T00:00:00`) or `DD-MM-YYYY` (the pattern
/// OBDX's month list parses, hooks.js:727-729).
DateTime? parseObdxDate(dynamic value) {
  final text = _str(value);
  if (text == null) return null;
  final dmy = RegExp(r'^(\d{2})-(\d{2})-(\d{4})').firstMatch(text);
  if (dmy != null) {
    return DateTime(int.parse(dmy.group(3)!), int.parse(dmy.group(2)!), int.parse(dmy.group(1)!));
  }
  return DateTime.tryParse(text);
}

String? _str(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

/// A credit card's row menu, in OBDX's order (credit-card-listing/
/// hooks.js:147-227): Credit Card Details always, then by ownership and
/// status. Only Transactions is built; the others are Access Denied in UAT.
enum CreditCardAction {
  details,
  transactions,
  cardPayment,
  requestPin,
  resetPin,
  blockCard,
  unblockCard,
  cancelCard,
  autoPay,
  addOnCard,
}

List<CreditCardAction> creditCardMenu(CreditCard card) {
  final s = card.status;
  final primary = card.isPrimary;
  return [
    CreditCardAction.details,
    if (primary && s != CreditCardStatus.inactive) CreditCardAction.transactions,
    if (primary &&
        (s == CreditCardStatus.active || s == CreditCardStatus.hotlisted || s == CreditCardStatus.blocked))
      CreditCardAction.cardPayment,
    if (s == CreditCardStatus.active) ...[
      CreditCardAction.requestPin,
      CreditCardAction.resetPin,
      CreditCardAction.blockCard,
    ],
    if (s == CreditCardStatus.blocked) CreditCardAction.unblockCard,
    if (s != CreditCardStatus.cancelled) CreditCardAction.cancelCard,
    if (primary && s == CreditCardStatus.active) ...[
      CreditCardAction.autoPay,
      CreditCardAction.addOnCard,
    ],
  ];
}

/// The design's summary tiles (UI designs 2026-10-27; not in OBDX), added
/// up from the card list per currency: Total Credit Limit, Current
/// Outstanding, Total Due, the active cards and the next due date.
class CreditCardTotals {
  const CreditCardTotals({
    required this.currency,
    required this.creditLimit,
    required this.outstanding,
    required this.totalDue,
    required this.activeCards,
    this.nextDue,
  });

  final String currency;
  final double creditLimit;
  final double outstanding;
  final double totalDue;

  /// Cards with status ACT.
  final int activeCards;

  /// The earliest Due On of a card with dues.
  final DateTime? nextDue;

  /// Current Outstanding as a share of the limit, in percent (null without
  /// a limit).
  double? get outstandingShare => creditLimit > 0 ? outstanding / creditLimit * 100 : null;

  /// One entry per currency, in the order the cards first use it. A card's
  /// currency is its limit's, else its dues'.
  static List<CreditCardTotals> fromCards(List<CreditCard> cards) {
    final order = <String>[];
    final byCurrency = <String, List<CreditCard>>{};
    for (final c in cards) {
      final cur = c.creditLimit?.currency ??
          c.availableCredit?.currency ??
          c.currentOutstanding?.currency ??
          c.totalDue?.currency ??
          '';
      if (!byCurrency.containsKey(cur)) order.add(cur);
      byCurrency.putIfAbsent(cur, () => []).add(c);
    }
    return [
      for (final cur in order)
        () {
          final list = byCurrency[cur]!;
          DateTime? next;
          for (final c in list) {
            final d = c.dueDate;
            if (c.hasDues && d != null && (next == null || d.isBefore(next))) next = d;
          }
          double sum(MoneyAmount? Function(CreditCard) f) => list.fold(0, (t, c) => t + (f(c)?.amount ?? 0));
          return CreditCardTotals(
            currency: cur,
            creditLimit: sum((c) => c.creditLimit),
            outstanding: sum((c) => c.currentOutstanding),
            totalDue: sum((c) => c.hasDues ? c.totalDue : null),
            activeCards: list.where((c) => c.status == CreditCardStatus.active).length,
            nextDue: next,
          );
        }(),
    ];
  }
}

/// The design's search ("Card Number or Holder Name") and Filter
/// (ownership, card number) — applied on the device; OBDX's list has
/// neither.
class CreditCardFilter {
  const CreditCardFilter({this.query = '', this.primary, this.cardId});

  final String query;

  /// true Primary, false Add-On, null both.
  final bool? primary;
  final String? cardId;

  bool get isActive => primary != null || cardId != null;

  bool matches(CreditCard c) {
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      final digits = q.replaceAll(RegExp(r'\s+'), '');
      final number = c.displayNumber.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      if (!number.contains(digits) && !(c.ownerName ?? '').toLowerCase().contains(q)) return false;
    }
    if (primary != null && c.isPrimary != primary) return false;
    if (cardId != null && c.id != cardId) return false;
    return true;
  }
}
