import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// OBDX Bill Payments (EBPP) — Billers.
///
/// Shapes come from the UAT capture and the rules from the original OBDX
/// `manage-bill-payments` component; see docs/obdx/features/bill-payments.md
/// §3 for the evidence (hooks.js line numbers are quoted below).

/// `billerType`. [presentmentPayment] billers are shown under
/// [presentment] when they have an e-bill, otherwise under [payment].
enum BillerType {
  presentment('PRESENTMENT'),
  presentmentPayment('PRESENTMENT_PAYMENT'),
  payment('PAYMENT'),
  recharge('RECHARGE'),
  unknown('');

  const BillerType(this.code);

  final String code;

  static BillerType fromCode(dynamic raw) {
    final code = (raw ?? '').toString().trim().toUpperCase();
    for (final type in values) {
      if (type != unknown && type.code == code) return type;
    }
    return unknown;
  }

  /// The list groups, in OBDX's order (hooks.js:150-157).
  static const groups = [presentment, recharge, payment];
}

/// Badge OBDX shows on an APPROVED biller (hooks.js:223-266).
enum BillerPaymentStatus { overdue, autopay, scheduledPay }

class BillerCategory {
  const BillerCategory({this.id, this.name, this.logoId});

  final String? id;
  final String? name;

  /// `category.logo.value` — content id for the logo (fetched via batch).
  final String? logoId;

  static BillerCategory? fromJson(dynamic json) {
    if (json is! Map) return null;
    final map = ObdxApiUtils.asMap(json);
    return BillerCategory(
      id: _str(map['id']),
      name: _str(map['name']),
      logoId: _str(ObdxApiUtils.asMap(map['logo'])['value']),
    );
  }
}

class BillerLocation {
  const BillerLocation({this.id, this.areaName, this.city, this.state, this.country});

  final String? id;
  final String? areaName;
  final String? city;
  final String? state;
  final String? country;

  static BillerLocation? fromJson(dynamic json) {
    if (json is! Map) return null;
    final map = ObdxApiUtils.asMap(json);
    return BillerLocation(
      id: _str(map['id']),
      areaName: _str(map['areaName']),
      city: _str(map['city']),
      state: _str(map['state']),
      country: _str(map['country']),
    );
  }
}

/// One `relationshipDetails` entry — the customer's reference with the
/// biller (e.g. consumer number). [labelId] names the biller field.
class BillerRelationship {
  const BillerRelationship({this.labelId, this.value});

  final String? labelId;
  final String? value;

  static BillerRelationship fromJson(dynamic json) {
    final map = ObdxApiUtils.asMap(json);
    return BillerRelationship(
      labelId: _str(map['labelId']),
      value: _str(map['value']),
    );
  }
}

/// A presented bill (`ebill`). OBDX spells the registration id
/// `billerRegistartionId`.
class EBill {
  const EBill({this.id, this.dueDate, this.status, this.totalAmount});

  final String? id;
  final DateTime? dueDate;
  final String? status;
  final MoneyAmount? totalAmount;

  static EBill? fromJson(dynamic json) {
    if (json is! Map) return null;
    final map = ObdxApiUtils.asMap(json);
    return EBill(
      id: _str(map['id']),
      dueDate: _date(map['dueDate']),
      status: _str(map['status']),
      totalAmount: map['totalAmount'] == null
          ? null
          : MoneyAmount.fromJson(map['totalAmount']),
    );
  }
}

class AutopayInstructions {
  const AutopayInstructions({
    this.startDate,
    this.endDate,
    this.frequency,
    this.paymentType,
    this.debitAccountDisplay,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final String? frequency;
  final String? paymentType;

  /// `debitAccount.displayValue` (masked) — OBDX "Pay From".
  final String? debitAccountDisplay;

  static AutopayInstructions? fromJson(dynamic json) {
    if (json is! Map) return null;
    final map = ObdxApiUtils.asMap(json);
    return AutopayInstructions(
      startDate: _date(map['startDate']),
      endDate: _date(map['endDate']),
      frequency: _str(map['frequency']),
      paymentType: _str(map['paymentType']),
      debitAccountDisplay: _str(ObdxApiUtils.asMap(map['debitAccount'])['displayValue']),
    );
  }
}

/// One `biller.specifications[]` entry — a reference field the customer
/// fills when adding the biller (Add Billers stage 1, hooks.js:557-583).
class BillerSpec {
  const BillerSpec({
    required this.id,
    required this.label,
    this.required = false,
    this.datatype,
    this.maxLength,
    this.allowedValues = const [],
  });

  final String id;
  final String label;
  final bool required;

  /// ALPHANUMERIC / NUMERIC / TEXT; anything else allows all specials.
  final String? datatype;

  /// Sent as a string by OBDX (UAT capture); null when absent or unparsable.
  final int? maxLength;

  /// `allowedChars` split on commas — when present the field is a list.
  final List<String> allowedValues;

  static BillerSpec? fromJson(dynamic json) {
    final map = ObdxApiUtils.asMap(json);
    final id = _str(map['id']);
    final label = _str(map['label']);
    // OBDX only builds a field when the spec has a label (hooks.js:559).
    if (id == null || label == null) return null;
    final allowed = _str(map['allowedChars']);
    return BillerSpec(
      id: id,
      label: label,
      required: map['required'] == true,
      datatype: _str(map['datatype'])?.toUpperCase(),
      maxLength: int.tryParse(_str(map['maxLength']) ?? ''),
      allowedValues: allowed == null
          ? const []
          : allowed.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList(),
    );
  }
}

/// Biller master data — `GET billers` items, the `biller` embedded in a
/// list item, or the body of `GET billers/{id}`.
class BillerInfo {
  const BillerInfo({
    required this.id,
    this.name,
    this.currency,
    this.type = BillerType.unknown,
    this.categoryId,
    this.categoryName,
    this.subcategory,
    this.operationalAreaId,
    this.operationalAreaName,
    this.specifications = const [],
    this.paymentTypes = const [],
  });

  final String id;
  final String? name;
  final String? currency;
  final BillerType type;

  /// From `areaCategoryDetails[0]` (OBDX always reads the first one).
  final String? categoryId;
  final String? categoryName;
  final String? subcategory;
  final String? operationalAreaId;
  final String? operationalAreaName;

  final List<BillerSpec> specifications;

  /// `paymentMethodsList[].paymentType` — CASA / CREDITCARD / DEBITCARD.
  final List<String> paymentTypes;

  /// `specifications[].id` → `label`: names the customer's
  /// `relationshipDetails` (OBDX biller-details/hooks.js:198-206).
  Map<String, String> get specLabels => {for (final s in specifications) s.id: s.label};

  /// Add Billers list label: `{category} | {subCat} | {loc}`, or
  /// `{category} | {loc}` without a sub-category (nls add-biller-stage1:51-52).
  String get pickerLabel => [categoryName, subcategory, operationalAreaName]
      .whereType<String>()
      .where((v) => v.isNotEmpty)
      .join(' | ');

  static BillerInfo? fromJson(dynamic json) {
    if (json is! Map) return null;
    final map = ObdxApiUtils.asMap(json);
    final areas = map['areaCategoryDetails'];
    final firstArea = areas is List && areas.isNotEmpty
        ? ObdxApiUtils.asMap(areas.first)
        : const <String, dynamic>{};
    final specs = map['specifications'];
    final methods = map['paymentMethodsList'];
    return BillerInfo(
      id: _str(map['id']) ?? '',
      name: _str(map['name']),
      currency: _str(map['currency']),
      type: BillerType.fromCode(map['type']),
      categoryId: _str(firstArea['categoryId']),
      categoryName: _str(firstArea['categoryName']),
      subcategory: _str(firstArea['subcategory']),
      operationalAreaId: _str(firstArea['operationalAreaId']),
      operationalAreaName: _str(firstArea['operationalAreaName']),
      specifications: specs is List
          ? specs.map(BillerSpec.fromJson).whereType<BillerSpec>().toList()
          : const [],
      paymentTypes: methods is List
          ? methods
              .map((m) => _str(ObdxApiUtils.asMap(m)['paymentType']))
              .whereType<String>()
              .toList()
          : const [],
    );
  }

  /// Body of `GET billers/{id}`: `{ biller: {...} }`.
  static BillerInfo? fromPayload(Map<String, dynamic> body) =>
      fromJson(body['biller']);

  /// Body of `GET billers`: `{ billerDTOs: [...] }`, sorted by name as OBDX
  /// shows them (add-biller-stage1/hooks.js:536-546).
  static List<BillerInfo> listFromPayload(Map<String, dynamic> body) {
    final items = body['billerDTOs'];
    if (items is! List) return const [];
    final list = items.map(fromJson).whereType<BillerInfo>().where((b) => b.id.isNotEmpty).toList()
      ..sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
    return list;
  }
}

/// A biller the user registered (`billerRegistrationDTOs[]` item or
/// `billerRegistration`).
class RegisteredBiller {
  const RegisteredBiller({
    required this.id,
    required this.billerId,
    required this.nickname,
    required this.type,
    this.billerName,
    this.customerName,
    this.registrationStatus,
    this.autopay = false,
    this.schedulePayment = false,
    this.autopayInstructions,
    this.category,
    this.location,
    this.relationships = const [],
    this.ebill,
    this.biller,
    this.raw,
  });

  /// `id` — the registration id used in `registeredBillers/{id}`.
  final String id;
  final String billerId;

  /// `billerNickName`.
  final String nickname;
  final BillerType type;

  /// `billerName` — sent on list items only; fall back to [biller].
  final String? billerName;
  final String? customerName;

  /// APPROVED / PENDING / REJECTED (only APPROVED seen in UAT so far).
  final String? registrationStatus;
  final bool autopay;

  /// Missing on some UAT items — treated as false.
  final bool schedulePayment;
  final AutopayInstructions? autopayInstructions;
  final BillerCategory? category;
  final BillerLocation? location;
  final List<BillerRelationship> relationships;
  final EBill? ebill;

  /// Embedded on list items, absent on `registeredBillers/{id}`.
  final BillerInfo? biller;

  /// The item exactly as the server sent it. OBDX sends this back as the
  /// DELETE body (manage-bill-payments-list/hooks.js:40-49).
  final Map<String, dynamic>? raw;

  String get displayBillerName => billerName ?? biller?.name ?? '';
  bool get isApproved => (registrationStatus ?? '').toUpperCase() == 'APPROVED';
  bool get isPending => (registrationStatus ?? '').toUpperCase() == 'PENDING';

  static RegisteredBiller? fromJson(dynamic json) {
    if (json is! Map) return null;
    final map = ObdxApiUtils.asMap(json);
    final id = _str(map['id']);
    if (id == null) return null;
    final rels = map['relationshipDetails'];
    return RegisteredBiller(
      id: id,
      billerId: _str(map['billerId']) ?? '',
      nickname: _str(map['billerNickName']) ?? '',
      type: BillerType.fromCode(map['billerType']),
      billerName: _str(map['billerName']),
      customerName: _str(map['customerName']),
      registrationStatus: _str(map['registrationStatus']),
      autopay: map['autopay'] == true,
      schedulePayment: map['schedulePayment'] == true,
      autopayInstructions: AutopayInstructions.fromJson(map['autopayInstructions']),
      category: BillerCategory.fromJson(map['category']),
      location: BillerLocation.fromJson(map['location']),
      relationships: rels is List
          ? rels.map(BillerRelationship.fromJson).toList()
          : const [],
      ebill: EBill.fromJson(map['ebill']),
      biller: BillerInfo.fromJson(map['biller']),
      raw: map,
    );
  }

  /// Body of `GET registeredBillers`: `{ billerRegistrationDTOs: [...] }`.
  static List<RegisteredBiller> listFromPayload(Map<String, dynamic> body) {
    final items = body['billerRegistrationDTOs'];
    if (items is! List) return const [];
    return items.map(fromJson).whereType<RegisteredBiller>().toList();
  }

  /// Body of `GET registeredBillers/{id}`: `{ billerRegistration: {...} }`.
  static RegisteredBiller? fromDetailPayload(Map<String, dynamic> body) =>
      fromJson(body['billerRegistration']);

  /// OBDX `validateSchedulePay` (hooks.js:213-221): a scheduled payment is
  /// still active if today is on/before its end date, else its start date.
  bool hasActiveSchedule(DateTime today) {
    final day = _day(today);
    final end = autopayInstructions?.endDate;
    if (end != null && !day.isAfter(_day(end))) return true;
    final start = autopayInstructions?.startDate;
    if (start != null && !day.isAfter(_day(start))) return true;
    return false;
  }

  /// OBDX `setBillPaymentStatus` (hooks.js:223-266). Null = no badge.
  BillerPaymentStatus? paymentStatus(DateTime today) {
    if (!isApproved) return null;
    final due = ebill?.dueDate;
    if (ebill != null && due != null && _day(due).isBefore(_day(today))) {
      return BillerPaymentStatus.overdue;
    }
    switch (type) {
      case BillerType.presentment:
        return autopay ? BillerPaymentStatus.autopay : null;
      case BillerType.presentmentPayment:
        if (autopay) return BillerPaymentStatus.autopay;
        return schedulePayment && hasActiveSchedule(today)
            ? BillerPaymentStatus.scheduledPay
            : null;
      case BillerType.payment:
      case BillerType.recharge:
      case BillerType.unknown:
        return schedulePayment && hasActiveSchedule(today)
            ? BillerPaymentStatus.scheduledPay
            : null;
    }
  }

  /// "Bills Due" / "No Bills Due" — shown for presented billers only.
  bool get hasBillDue => ebill != null;

  /// Edit is refused while a change is awaiting bank approval
  /// (hooks.js:476-479).
  bool get canEdit => !isPending;

  /// Has an Auto Pay or Scheduled Pay instruction. OBDX's Edit Biller then
  /// opens on that Payment Type (modify-biller/hooks.js:715-725); the app
  /// only edits Manual billers so far (bill-payments.md §6.4).
  bool get hasPaymentInstruction => autopay || schedulePayment;

  /// Delete is refused while auto pay or an active scheduled payment exists
  /// (hooks.js:491-499).
  bool canDelete(DateTime today) =>
      !autopay && !(schedulePayment && hasActiveSchedule(today));
}

/// OBDX `displayBillerDetails` (hooks.js:296-336): keeps billers that have
/// relationship details, puts each in its [BillerType.groups] bucket and
/// sorts by nickname, case-insensitive. Every group is returned, even when
/// empty, so the UI can show OBDX's per-group empty message.
Map<BillerType, List<RegisteredBiller>> groupBillers(
  Iterable<RegisteredBiller> billers,
) {
  final groups = {for (final g in BillerType.groups) g: <RegisteredBiller>[]};
  for (final biller in billers) {
    if (biller.relationships.isEmpty) continue;
    final BillerType? group = switch (biller.type) {
      BillerType.presentment => BillerType.presentment,
      BillerType.recharge => BillerType.recharge,
      BillerType.payment => BillerType.payment,
      BillerType.presentmentPayment =>
        biller.ebill != null ? BillerType.presentment : BillerType.payment,
      BillerType.unknown => null,
    };
    if (group != null) groups[group]!.add(biller);
  }
  for (final list in groups.values) {
    list.sort((a, b) => a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase()));
  }
  return groups;
}

/// Result of `DELETE registeredBillers/{id}` — same shape as payee delete,
/// because the response (200 / 202 / 417) is not yet seen in UAT.
class BillerDeleteOutcome {
  const BillerDeleteOutcome.deleted({this.reference, this.pendingApproval = false})
      : challenge = null,
        invalidOtp = false;

  const BillerDeleteOutcome.otpRequired(ObdxChallenge this.challenge, {this.invalidOtp = false})
      : reference = null,
        pendingApproval = false;

  final String? reference;

  /// 202 — sent to the bank for approval.
  final bool pendingApproval;
  final ObdxChallenge? challenge;

  /// The OTP sent with this attempt was not accepted.
  final bool invalidOtp;
}

String? _str(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _date(dynamic value) {
  final text = _str(value);
  return text == null ? null : DateTime.tryParse(text);
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

/// Add Billers — the `POST registeredBillers` body for Payment Type
/// **Manual**, in the exact shape OBDX sends (UAT capture; built in
/// add-biller-review/hooks.js:58-92). Auto Pay / Scheduled Pay are not
/// built yet, so `autopayInstructions` goes with every field null, as
/// OBDX sends it for Manual.
class AddBillerRequest {
  const AddBillerRequest({
    required this.biller,
    required this.nickname,
    required this.customerName,
    required this.relationshipValues,
  });

  final BillerInfo biller;
  final String nickname;
  final String customerName;

  /// Spec id → value. Empty values are left out, like OBDX (stage1.js:349).
  final Map<String, String> relationshipValues;

  Map<String, dynamic> toJson() => {
        'billerId': biller.id,
        'billerNickName': nickname.trim(),
        'billerType': biller.type.code,
        'customerName': customerName.trim(),
        'category': {'id': biller.categoryId},
        // OBDX sends `subcategory` only when the biller has one.
        if (biller.subcategory != null) 'subcategory': biller.subcategory,
        'location': {'id': biller.operationalAreaId},
        'relationshipDetails': [
          for (final spec in biller.specifications)
            if ((relationshipValues[spec.id] ?? '').trim().isNotEmpty)
              {'value': relationshipValues[spec.id]!.trim(), 'labelId': spec.id},
        ],
        'autopay': false,
        'schedulePayment': false,
        'autopayInstructions': {
          'paymentType': null,
          'debitAccount': {'displayValue': null, 'value': null},
          'limitAmount': {'currency': null, 'amount': null},
          'startDate': null,
          'endDate': null,
          'frequency': null,
        },
      };
}

/// Why a field was refused; the screen maps each to OBDX's message.
enum BillerFieldError { required, tooLong, alphanumeric, numeric, text, invalid }

/// Add Billers field rules, using OBDX's own patterns
/// (resources/nls/data-types.js) — docs/obdx/features/bill-payments.md §4.2.
abstract final class BillerFieldRules {
  static const nicknameMaxLength = 20;
  static const customerNameMaxLength = 35;

  /// `ALPHANUMERIC_WITH_SPECIAL` — nickname and customer name.
  static final _withSpecial = RegExp(r"^[a-zA-Z0-9 %&:;/,)(._'\-]*$");
  static final _alphanumeric = RegExp(r'^[a-zA-Z0-9]*$');
  static final _numbers = RegExp(r'^[0-9]*$');
  static final _alphabets = RegExp(r'^[a-zA-Z]*$');

  /// `ALPHANUMERIC_WITH_ALL_SPECIAL` — any other spec datatype.
  static final _allSpecial = RegExp(r"^[a-zA-Z0-9\- %=&#*+:,)@(.!$_|'`?\[\]\/]*$");

  static BillerFieldError? nickname(String value) =>
      _named(value, nicknameMaxLength);

  static BillerFieldError? customerName(String value) =>
      _named(value, customerNameMaxLength);

  /// `ALPHANUMERIC_WITH_SPACE` — Edit Biller's nickname rule, stricter than
  /// Add Billers' (modify-biller.html; data-types.js:4).
  static final _withSpace = RegExp(r'^[a-zA-Z0-9 ]*$');

  /// Edit Biller nickname: required, 1-20, letters, digits and spaces.
  static BillerFieldError? editNickname(String value) {
    final v = value.trim();
    if (v.isEmpty) return BillerFieldError.required;
    if (v.length > nicknameMaxLength) return BillerFieldError.tooLong;
    return _withSpace.hasMatch(v) ? null : BillerFieldError.invalid;
  }

  static BillerFieldError? _named(String value, int max) {
    final v = value.trim();
    if (v.isEmpty) return BillerFieldError.required;
    if (v.length > max) return BillerFieldError.tooLong;
    return _withSpecial.hasMatch(v) ? null : BillerFieldError.invalid;
  }

  /// OBDX `getFieldValidator` (add-biller-stage1/hooks.js:703-737).
  static BillerFieldError? spec(BillerSpec spec, String value) {
    final v = value.trim();
    if (v.isEmpty) return spec.required ? BillerFieldError.required : null;
    final max = spec.maxLength;
    if (max != null && max > 0 && v.length > max) return BillerFieldError.tooLong;
    if (spec.allowedValues.isNotEmpty) {
      return spec.allowedValues.contains(v) ? null : BillerFieldError.invalid;
    }
    switch (spec.datatype) {
      case 'ALPHANUMERIC':
        return _alphanumeric.hasMatch(v) ? null : BillerFieldError.alphanumeric;
      case 'NUMERIC':
        return _numbers.hasMatch(v) ? null : BillerFieldError.numeric;
      case 'TEXT':
        return _alphabets.hasMatch(v) ? null : BillerFieldError.text;
      default:
        return _allSpecial.hasMatch(v) ? null : BillerFieldError.invalid;
    }
  }
}

/// Result of Add Billers' `POST registeredBillers`. OBDX answers 201 when
/// OTP and approval are off (UAT capture); like every OBDX call it may
/// instead ask for an OTP (417) or send the request for approval
/// (202 / `APPROVAL_STATUS: INITIATED`) — see docs/obdx/SOURCE.md.
class BillerAddOutcome {
  const BillerAddOutcome.added({this.biller, this.reference, this.pendingApproval = false})
      : challenge = null,
        invalidOtp = false;

  const BillerAddOutcome.otpRequired(ObdxChallenge this.challenge, {this.invalidOtp = false})
      : biller = null,
        reference = null,
        pendingApproval = false;

  /// The new registration, when the server returned it.
  final RegisteredBiller? biller;
  final String? reference;

  /// Sent to the bank for approval; not added yet.
  final bool pendingApproval;
  final ObdxChallenge? challenge;

  /// The OTP sent with this attempt was not accepted.
  final bool invalidOtp;
}

/// Edit Biller — the `PUT registeredBillers/{id}` body for a **Manual**
/// biller, in the shape OBDX builds (modify-biller-review/model.js:27-50,
/// hooks.js:18-55). `paymentType` is the registration's, else the biller's
/// first payment method, as OBDX sets it (modify-biller/hooks.js:991-996).
class EditBillerRequest {
  const EditBillerRequest({required this.biller, required this.nickname});

  final RegisteredBiller biller;
  final String nickname;

  String? get paymentType =>
      biller.autopayInstructions?.paymentType ??
      ((biller.biller?.paymentTypes.isNotEmpty ?? false) ? biller.biller!.paymentTypes.first : null);

  Map<String, dynamic> toJson() => {
        'billerRegistrationId': biller.id,
        'billerNickName': nickname.trim(),
        'autopay': false,
        'schedulePayment': false,
        'autopayInstructions': {
          'debitAccount': {'displayValue': null, 'value': null},
          'limitAmount': {'currency': null, 'amount': null},
          'startDate': null,
          'frequency': null,
          'paymentType': paymentType,
          'endDate': null,
        },
        'cardExpiryDate': null,
        'paymentEndDate': null,
      };
}

/// Result of Edit Biller's PUT — same outcomes as add and delete.
class BillerEditOutcome {
  const BillerEditOutcome.updated({this.reference, this.pendingApproval = false})
      : challenge = null,
        invalidOtp = false;

  const BillerEditOutcome.otpRequired(ObdxChallenge this.challenge, {this.invalidOtp = false})
      : reference = null,
        pendingApproval = false;

  final String? reference;

  /// Sent to the bank for approval; not changed yet.
  final bool pendingApproval;
  final ObdxChallenge? challenge;

  /// The OTP sent with this attempt was not accepted.
  final bool invalidOtp;
}
