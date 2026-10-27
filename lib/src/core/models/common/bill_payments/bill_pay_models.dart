import 'package:ubci_bank/src/core/models/common/bill_payments/biller_models.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/obdx_otp_outcome.dart';
import 'package:ubci_bank/src/core/models/common/payment/network_transfer.dart' show obdxPaymentDate;
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// OBDX Bill Payments — Pay Bill (`flows/pay-bill`), one bill.
///
/// Rules and shapes from the OBDX source; evidence in
/// docs/obdx/features/bill-payments.md §7 (`S1/` = pay-bill-stage1,
/// `RV/` = pay-bill-review). Where OBDX has a bug the app follows what the
/// code is plainly trying to do; each such place says so (§7.6).

/// OBDX's task code for bill payment (S1/hooks.js:212): sent with the CASA
/// account list and used for limits.
const billPayTaskCode = 'EB_F_BP';

/// `paymentMethodsList[].paymentType`: what the bill is paid from.
enum BillPayType {
  casa('CASA'),
  creditCard('CREDITCARD'),
  debitCard('DEBITCARD');

  const BillPayType(this.code);

  final String code;

  static BillPayType? fromCode(String? raw) {
    final code = (raw ?? '').trim().toUpperCase();
    for (final t in values) {
      if (t.code == code) return t;
    }
    return null;
  }

  /// The biller's methods in its order, known ones only, no repeats.
  static List<BillPayType> supportedBy(BillerInfo biller) =>
      biller.paymentTypes.map(fromCode).whereType<BillPayType>().toSet().toList();

  /// The Payment Type to start with: the registration's, else Account when
  /// the biller takes it, else the first. OBDX means CASA first but its
  /// check compares an object with "CASA" and never matches
  /// (S1/hooks.js:430-442) — the app follows the intent.
  static BillPayType? initial(List<BillPayType> supported, String? registrationType) {
    if (supported.isEmpty) return null;
    final fromRegistration = fromCode(registrationType);
    if (fromRegistration != null && supported.contains(fromRegistration)) return fromRegistration;
    return supported.contains(casa) ? casa : supported.first;
  }
}

/// A recharge plan (`GET plans?billerID=`, S1/hooks.js:376-388). Picking
/// one sets the amount and locks it.
class BillPlan {
  const BillPlan({required this.id, this.description, this.amount, this.currency});

  final String id;
  final String? description;
  final double? amount;
  final String? currency;

  static List<BillPlan> listFromPayload(Map<String, dynamic> body) {
    final items = body['planDTOs'];
    if (items is! List) return const [];
    return [
      for (final item in items.map(ObdxApiUtils.asMap))
        if (_str(item['id']) != null)
          BillPlan(
            id: _str(item['id'])!,
            description: _str(item['description']),
            amount: item['amount'] == null ? null : MoneyAmount.fromJson(item['amount']).amount,
            currency: _str(ObdxApiUtils.asMap(item['amount'])['currency']),
          ),
    ];
  }
}

/// One entry of Pay From — an account, a credit card or a debit card, read
/// the way OBDX's parsers do (S1/hooks.js:732-794).
class BillPayAccount {
  const BillPayAccount({
    required this.value,
    required this.displayNumber,
    this.nickname,
    this.currency,
    this.isDefault = false,
    this.balance,
  });

  /// `id.value` (account), `creditCard.value` or `cardNo.value`.
  final String value;

  /// The masked number (`displayValue`).
  final String displayNumber;
  final String? nickname;
  final String? currency;

  /// `defaultAccount`: OBDX's account-input starts on it, else the first
  /// (account-input.js:175-195).
  final bool isDefault;
  final MoneyAmount? balance;

  /// account-input's label, sent as `debitAccount.displayValue`:
  /// "{displayValue} - {nickname}" (nls/account-input.js:8).
  String get label => nickname == null ? displayNumber : '$displayNumber - $nickname';

  static List<BillPayAccount> listFromPayload(BillPayType type, Map<String, dynamic> body) {
    switch (type) {
      case BillPayType.casa:
        return [
          for (final a in _list(body['accounts']))
            if (_id(a['id']) case final id?)
              BillPayAccount(
                value: id.$1,
                displayNumber: id.$2,
                nickname: _str(a['accountNickname']),
                currency: _str(a['currencyCode']),
                isDefault: _str(a['defaultAccount'])?.toLowerCase() == 'true',
                balance: a['availableBalance'] == null ? null : MoneyAmount.fromJson(a['availableBalance']),
              ),
        ];
      case BillPayType.creditCard:
        // PRIMARY cards with status ACT only.
        return [
          for (final c in _list(body['creditcards']))
            if (_str(c['cardOwnershipType']) == 'PRIMARY' && _str(c['cardStatus']) == 'ACT')
              if (_id(c['creditCard']) case final id?)
                BillPayAccount(
                  value: id.$1,
                  displayNumber: id.$2,
                  nickname: _str(c['cardNickname']),
                  currency: _str(c['cardCurrency']),
                ),
        ];
      case BillPayType.debitCard:
        // The accounts' debit cards that are ACTIVATED or ACTIVE.
        return [
          for (final a in _list(body['accounts']))
            for (final d in _list(a['debitCards']))
              if (_str(d['cardStatus']) == 'ACTIVATED' || _str(d['cardStatus']) == 'ACTIVE')
                if (_id(d['cardNo']) case final id?)
                  BillPayAccount(
                    value: id.$1,
                    displayNumber: id.$2,
                    nickname: _str(d['cardNickname']),
                  ),
        ];
    }
  }

  /// The account Pay From starts on: the registration's, else the
  /// default, else the first.
  static BillPayAccount? initial(List<BillPayAccount> list, String? registrationValue) {
    if (list.isEmpty) return null;
    for (final a in list) {
      if (a.value == registrationValue) return a;
    }
    for (final a in list) {
      if (a.isDefault) return a;
    }
    return list.first;
  }
}

/// Location as Pay Bill shows and sends it: `areaName`, else
/// "city,state,country" (S1/hooks.js:668-708). [registration] picks the
/// area out of a list answer; the registration's own location is the
/// fallback when the call gave nothing.
String? billLocationLabel(Map<String, dynamic>? body, RegisteredBiller registration) {
  Map<String, dynamic>? area;
  if (body != null) {
    if (body['operationalArea'] is Map) {
      area = ObdxApiUtils.asMap(body['operationalArea']);
    } else {
      final list = _list(body['operationalAreaDTOs']);
      // OBDX compares the location object with each areaName, which never
      // matches; the app matches the registration's area name.
      area = list.where((a) => _str(a['areaName']) == registration.location?.areaName).firstOrNull ??
          list.firstOrNull;
    }
  }
  final loc = registration.location;
  final areaName = area == null ? loc?.areaName : _str(area['areaName']);
  if (areaName != null) return areaName;
  final parts = area == null
      ? [loc?.city, loc?.state, loc?.country]
      : [_str(area['city']), _str(area['state']), _str(area['country'])];
  final text = parts.whereType<String>().join(',');
  return text.isEmpty ? null : text;
}

/// What happens before the form opens (`showPayBill`,
/// manage-bill-payments/hooks.js:613-661).
enum PayBillGate {
  open,

  /// "Last Date of Bill Payment has Passed. Late Payment not allowed by
  /// Biller!" — Ok only.
  latePaymentBlocked,

  /// Auto Pay is on — duplicate-payment warning, Continue / Cancel.
  autopayWarning,

  /// A scheduled payment exists — same warning, Continue / Cancel.
  scheduledWarning,
}

/// [single]: a row's Pay (OBDX `isSinglePay`); false for Select all to Pay
/// with one bill ticked, which OBDX opens without these checks for a
/// presentment biller. The checks use the biller master's type, as OBDX.
///
/// OBDX bug: a single Pay on a presentment biller with none of the
/// conditions opens nothing (hooks.js:625-644); the app opens the form.
PayBillGate payBillGate(
  RegisteredBiller registration,
  BillerInfo biller, {
  required bool single,
  required DateTime today,
}) {
  if (biller.type == BillerType.presentment) {
    if (!single) return PayBillGate.open;
    final due = registration.ebill?.dueDate;
    if (!biller.latePaymentAllowed && due != null && _day(today).isAfter(_day(due))) {
      return PayBillGate.latePaymentBlocked;
    }
  }
  if (registration.autopay) return PayBillGate.autopayWarning;
  if (registration.schedulePayment) return PayBillGate.scheduledWarning;
  return PayBillGate.open;
}

/// Why an amount was refused; the screen maps each to OBDX's message.
enum BillAmountError {
  required,

  /// "Amount should be greater than 0".
  notPositive,

  /// "Amount should be lesser than 1 trillion" — also OBDX's message for
  /// anything not a number or with more than 2 decimals.
  invalid,
}

abstract final class BillPayRules {
  /// OBDX `validateAmount` (S1/hooks.js:915-935): > 0, at most 13 integer
  /// digits and 2 decimals.
  static BillAmountError? amount(String text) {
    final v = text.trim().replaceAll(',', '');
    if (v.isEmpty) return BillAmountError.required;
    final n = double.tryParse(v);
    if (n != null && n <= 0) return BillAmountError.notPositive;
    final parts = v.split('.');
    final digits = RegExp(r'^[0-9]+$');
    if (n == null || parts.length > 2) return BillAmountError.invalid;
    if (parts[0].isNotEmpty && (parts[0].length > 13 || !digits.hasMatch(parts[0]))) {
      return BillAmountError.invalid;
    }
    if (parts.length == 2 && parts[1].isNotEmpty && (parts[1].length > 2 || !digits.hasMatch(parts[1]))) {
      return BillAmountError.invalid;
    }
    return null;
  }

  /// The amount a presented bill starts with: what is left of a
  /// `PARTIALPAID` bill, else the total (S1/hooks.js:657-666).
  static double? prefill(EBill? ebill) {
    final total = ebill?.totalAmount?.amount;
    if (total == null) return null;
    final paid = ebill!.isPartPaid ? ebill.amountPaid?.amount : null;
    return paid == null ? total : total - paid;
  }

  /// Text for the amount box: no trailing ".0".
  static String amountText(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  /// The last day of the card's expiry month, sent as `cardExpiryDate`
  /// (S1/pay-bill-stage1.js:720-740).
  static DateTime cardExpiryLastDay(int month, int year) => DateTime(year, month + 1, 0);

  /// A card is accepted through the last day of its month. OBDX compares
  /// that midnight with the current time, refusing a card on its last
  /// valid day; the app compares days.
  static bool cardExpiryValid(int month, int year, DateTime today) =>
      !_day(cardExpiryLastDay(month, year)).isBefore(_day(today));

  /// Expiry Year choices: this year and the next nine (S1/hooks.js:600-655).
  static List<int> expiryYears(DateTime today) => [for (var i = 0; i < 10; i++) today.year + i];

  /// Earliest Scheduled Date: tomorrow (S1/hooks.js:836-846). No latest.
  static DateTime earliestScheduled(DateTime today) => _day(today).add(const Duration(days: 1));
}

/// Attachment rules (S1/hooks.js:937-1000): 15 MB, OBDX's types. OBDX lets
/// several files be picked but uploads only the first; the app takes one.
abstract final class BillAttachmentRules {
  static const maxBytes = 15728640;
  static const extensions = ['pdf', 'jpg', 'jpeg', 'png', 'zip', 'txt', 'doc', 'docx'];

  /// The extension in lower or upper case (".Pdf" is refused, as OBDX).
  static bool allowedName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return false;
    final ext = name.substring(dot + 1);
    return extensions.contains(ext) || extensions.map((e) => e.toUpperCase()).contains(ext);
  }
}

/// A picked attachment, uploaded on Submit.
class BillAttachment {
  const BillAttachment({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

/// Confirm's `POST ebillPayments` body, built like OBDX's model
/// (S1/hooks.js:330-372) and filled on Submit (S1/pay-bill-stage1.js:712-848):
/// the 25 keys of the UAT capture, `payLater` / `recurring` as strings.
class PayBillRequest {
  const PayBillRequest({
    required this.registration,
    required this.biller,
    required this.type,
    required this.account,
    required this.amount,
    required this.today,
    this.payLater = false,
    this.scheduledDate,
    this.plan,
    this.location,
    this.cardExpiry,
    this.attachmentId,
  });

  final RegisteredBiller registration;
  final BillerInfo biller;
  final BillPayType type;
  final BillPayAccount account;
  final double amount;
  final DateTime today;
  final bool payLater;
  final DateTime? scheduledDate;
  final BillPlan? plan;
  final String? location;

  /// The last day of the card's expiry month (credit cards).
  final DateTime? cardExpiry;

  /// `{value, displayValue}` from the upload.
  final Map<String, dynamic>? attachmentId;

  /// `biller.currency`, as OBDX; the bill's when the biller has none.
  String? get currency => biller.currency ?? registration.ebill?.totalAmount?.currency ?? plan?.currency;

  DateTime get paymentDate => payLater && scheduledDate != null ? scheduledDate! : today;

  Map<String, dynamic> toJson() => {
        'id': null,
        'debitAccount': {'value': account.value, 'displayValue': account.label},
        'customerName': registration.customerName,
        'billerRegistrationId': registration.id,
        'billAmount': {'currency': currency, 'amount': amount},
        'paymentDate': obdxPaymentDate(paymentDate),
        'planId': plan?.id,
        'billerId': biller.id.isEmpty ? registration.billerId : biller.id,
        'location': location,
        'billerName': biller.name ?? registration.displayBillerName,
        'billId': registration.ebill?.id,
        'partyId': null,
        'cardExpiryDate': type == BillPayType.creditCard && cardExpiry != null ? obdxPaymentDate(cardExpiry!) : null,
        'paymentStatus': 'COM',
        'billPaymentRelDetails': [
          for (final r in registration.relationships) {'labelId': r.labelId, 'value': r.value},
        ],
        'paymentType': type.code,
        'payLater': payLater ? 'true' : 'false',
        'recurring': 'false',
        'billerType': registration.type.code,
        'locationId': null,
        'categoryId': null,
        'category': biller.categoryName,
        'paymentHostStatus': null,
        'billerRegistration': {
          'billerNickName': registration.nickname,
          'autopayInstructions': {'frequency': null, 'endDate': null},
          'subcategory': registration.subcategory ?? '',
        },
        'attachmentId': attachmentId,
      };
}

/// Result of Confirm. Like every OBDX write it may first ask for an OTP
/// (417) or go for approval (202 / `APPROVAL_STATUS: INITIATED`).
class BillPayOutcome implements ObdxOtpOutcome {
  const BillPayOutcome.done({this.reference, this.pendingApproval = false})
      : challenge = null,
        invalidOtp = false;

  const BillPayOutcome.otpRequired(ObdxChallenge this.challenge, {this.invalidOtp = false})
      : reference = null,
        pendingApproval = false;

  /// `status.referenceNumber`, else `billPayment.id` (RV/pay-bill-review.js:92-94).
  final String? reference;
  final bool pendingApproval;
  @override
  final ObdxChallenge? challenge;
  @override
  final bool invalidOtp;
}

/// Result of the attachment upload (`POST content contents`).
class BillAttachmentOutcome implements ObdxOtpOutcome {
  const BillAttachmentOutcome.uploaded(this.contentId)
      : challenge = null,
        invalidOtp = false;

  const BillAttachmentOutcome.otpRequired(ObdxChallenge this.challenge, {this.invalidOtp = false})
      : contentId = null;

  /// `contentDTOList[0].contentId` — `{value, displayValue}`, sent as
  /// `attachmentId`.
  final Map<String, dynamic>? contentId;
  @override
  final ObdxChallenge? challenge;
  @override
  final bool invalidOtp;
}

String? _str(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

List<Map<String, dynamic>> _list(dynamic value) =>
    value is List ? [for (final v in value) if (v is Map) ObdxApiUtils.asMap(v)] : const [];

/// `{value, displayValue}` → (value, displayValue or value).
(String, String)? _id(dynamic json) {
  final map = ObdxApiUtils.asMap(json);
  final value = _str(map['value']);
  if (value == null) return null;
  return (value, _str(map['displayValue']) ?? value);
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
