import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// OBDX Debit Cards — `components/demand-deposits/debit-card-list`.
/// Evidence for every field and rule: docs/obdx/features/debit-cards.md.

/// The status OBDX shows: ACTIVATED reads "ACTIVE", HOTLISTED "BLOCKED"
/// (debit-card-list/hooks.js:50-79).
enum DebitCardStatus { active, blocked, cancelled }

/// One `debitCardDetails[]` item of `GET demandDeposit/debitCards`.
class DebitCard {
  const DebitCard({
    required this.cardNo,
    required this.displayNumber,
    required this.status,
    this.cardType,
    this.holderName,
    this.expiry,
    this.accountId,
    this.accountDisplay,
  });

  /// `cardNo.value` — used by the card's own calls.
  final String cardNo;

  /// `cardNo.displayValue`, masked by the server.
  final String displayNumber;
  final DebitCardStatus status;
  final String? cardType;
  final String? holderName;
  final DateTime? expiry;

  /// The linked account: `accountId.value` / `.displayValue` ("Account
  /// Number" on the tile).
  final String? accountId;
  final String? accountDisplay;

  /// "MM/YY". OBDX shows `M/YY` unpadded (debit-card/hooks.js:38-44).
  String? get expiryLabel {
    final e = expiry;
    if (e == null) return null;
    return '${e.month.toString().padLeft(2, '0')}/${(e.year % 100).toString().padLeft(2, '0')}';
  }

  /// Last four digits of the masked number.
  String get lastDigits {
    final digits = displayNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length <= 4 ? digits : digits.substring(digits.length - 4);
  }

  static DebitCard? fromJson(Map<String, dynamic> map, DebitCardStatus status) {
    final number = ObdxApiUtils.asMap(map['cardNo']);
    final value = _str(number['value']);
    if (value == null) return null;
    final account = ObdxApiUtils.asMap(map['accountId']);
    return DebitCard(
      cardNo: value,
      displayNumber: _str(number['displayValue']) ?? value,
      status: status,
      cardType: _str(map['cardType']),
      holderName: _str(map['cardHolderName']),
      expiry: DateTime.tryParse(_str(map['expiryDate']) ?? ''),
      accountId: _str(account['value']),
      accountDisplay: _str(account['displayValue']),
    );
  }

  /// OBDX's list (debit-card-list/hooks.js:50-79): ACTIVE cards, then
  /// ACTIVATED (as ACTIVE), then HOTLISTED (as BLOCKED), then CANCELLED,
  /// each in the server's order; any other status is not shown.
  static List<DebitCard> listFromPayload(Map<String, dynamic> body) {
    final raw = body['debitCardDetails'];
    if (raw is! List) return const [];
    final items = [for (final r in raw) if (r is Map) ObdxApiUtils.asMap(r)];
    String status(Map<String, dynamic> m) => (_str(m['cardStatus']) ?? '').toUpperCase();
    const passes = [
      ('ACTIVE', DebitCardStatus.active),
      ('ACTIVATED', DebitCardStatus.active),
      ('HOTLISTED', DebitCardStatus.blocked),
      ('CANCELLED', DebitCardStatus.cancelled),
    ];
    return [
      for (final (code, shown) in passes)
        for (final m in items)
          if (status(m) == code)
            if (fromJson(m, shown) case final card?) card,
    ];
  }
}

/// A debit card's menu, in OBDX's order (debit-card/hooks.js:81-121):
/// Debit Card Limits always; an ACTIVE card adds Block/Unblock Card,
/// Request PIN, Upgrade Card, Reset PIN and Reissue Card; a BLOCKED one
/// Block/Unblock Card. All are write flows, not built yet.
enum DebitCardAction { limits, blockUnblock, requestPin, upgradeCard, resetPin, reissueCard }

List<DebitCardAction> debitCardMenu(DebitCard card) => [
      DebitCardAction.limits,
      if (card.status == DebitCardStatus.active) ...[
        DebitCardAction.blockUnblock,
        DebitCardAction.requestPin,
        DebitCardAction.upgradeCard,
        DebitCardAction.resetPin,
        DebitCardAction.reissueCard,
      ],
      if (card.status == DebitCardStatus.blocked) DebitCardAction.blockUnblock,
    ];

/// The design's search ("Card Number or Holder Name") and Filter (Status,
/// Account Number) — on the device; OBDX's list has neither.
class DebitCardFilter {
  const DebitCardFilter({this.query = '', this.status, this.accountId});

  final String query;
  final DebitCardStatus? status;
  final String? accountId;

  bool get isActive => status != null || accountId != null;

  DebitCardFilter copyWith({String? query, DebitCardStatus? Function()? status, String? Function()? accountId}) =>
      DebitCardFilter(
        query: query ?? this.query,
        status: status == null ? this.status : status(),
        accountId: accountId == null ? this.accountId : accountId(),
      );

  bool matches(DebitCard c) {
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      final digits = q.replaceAll(RegExp(r'\s+'), '');
      final number = c.displayNumber.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      if (!number.contains(digits) && !(c.holderName ?? '').toLowerCase().contains(q)) return false;
    }
    if (status != null && c.status != status) return false;
    if (accountId != null && c.accountId != accountId) return false;
    return true;
  }
}

String? _str(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
