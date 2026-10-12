import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/own_account_transfer.dart';
import 'package:ubci_bank/src/core/models/retail/casa_account.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Transfers to payees — existing, adhoc and repeat — as the OBDX 22.2
/// payments server defines them (read from its REST resources and DTOs in
/// `digx-payments.war`):
///
///  - one-time: `POST …/payments/pay/network` (`NetworkPaymentDTO`);
///  - repeat: `POST …/payments/pay/networkInstruction`
///    (`NetworkPaymentInstructionDTO` — the same body plus a schedule).
///
/// An existing payee is sent by id with a `source`: the server then loads
/// the payee and fills `beneficiary[]` itself (`enrichPayeeDetails`). An
/// adhoc payee is sent with `adhocPayment: true` and `beneficiary[]` filled.

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty || s.toLowerCase() == 'null' ? null : s;
}

double? _dbl(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', ''));
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// OBDX dates in request bodies: `yyyy-MM-ddT00:00:00`, as the captured
/// own-account transfer sends them.
String obdxPaymentDate(DateTime d) => '${_ymd(d)}T00:00:00';

/// Who the money goes to.
enum TransferKind {
  /// Another account at this bank.
  internal('INTERNAL', 'INTERNAL_SI', ['INTERNAL']),

  /// An account at another bank in the country.
  domestic('DOMESTIC', 'DOMESTIC_SI', ['GENERICDOMESTIC', 'DOMESTIC']),

  /// An account abroad.
  international(
    'INTERNATIONAL',
    'INTERNATIONAL_SI',
    ['INTERNATIONAL'],
  );

  const TransferKind(this.paymentType, this.repeatPaymentType, this.payeeTypes);

  /// `paymentType` of a one-time transfer.
  final String paymentType;

  /// `paymentType` of a repeat transfer (`NetworkPaymentInstructionHelper`).
  final String repeatPaymentType;

  /// The payee types (`PayeeType`) this kind pays.
  final List<String> payeeTypes;

  String get label => switch (this) {
        TransferKind.internal => 'Within the bank',
        TransferKind.domestic => 'Domestic',
        TransferKind.international => 'International',
      };

  static TransferKind? forPayeeType(String? type) {
    final t = type?.toUpperCase();
    for (final kind in values) {
      if (kind.payeeTypes.contains(t)) return kind;
    }
    return null;
  }
}

/// The International Low Value Payment network — SWIFT GPI. The server's
/// GPI policy runs only for this code (`InternationalPayoutGPI`).
const String kGpiNetworkCode = 'INTERNATIONALSWIFTGPI';

/// One currency's limits on a network.
class NetworkCurrencyLimit {
  const NetworkCurrencyLimit({required this.currency, this.min, this.max});

  final String currency;
  final double? min;
  final double? max;
}

/// A payment network (`GET …/fetchNetwork` → `network[]`).
class TransferNetwork {
  const TransferNetwork({
    required this.code,
    this.description,
    this.paymentType,
    this.taskCode,
    this.taskCodeAdhoc,
    this.hasStandingInstruction = false,
    this.limits = const [],
  });

  final String code;
  final String? description;

  /// `SELF` / `INTERNAL` / `DOMESTIC` / `INTERNATIONAL`.
  final String? paymentType;

  /// Task codes for eligible debit accounts — saved / adhoc payee.
  final String? taskCode;
  final String? taskCodeAdhoc;

  /// Whether repeat transfers run on this network.
  final bool hasStandingInstruction;
  final List<NetworkCurrencyLimit> limits;

  String get label => description ?? code;

  NetworkCurrencyLimit? limitFor(String currency) {
    for (final l in limits) {
      if (l.currency == currency) return l;
    }
    return null;
  }

  factory TransferNetwork.fromJson(Map<String, dynamic> json) {
    final currencies = json['networkCurrency'];
    return TransferNetwork(
      code: _str(json['code']) ?? _str(json['networkCode']) ?? '',
      description: _str(json['description']),
      paymentType: _str(json['paymentType']),
      taskCode: _str(json['taskCode']),
      taskCodeAdhoc: _str(json['taskCodeAdhoc']),
      hasStandingInstruction: json['hasStandingInstruction'] == true ||
          _str(json['hasStandingInstruction'])?.toLowerCase() == 'true',
      limits: [
        if (currencies is List)
          for (final c in currencies)
            if (c is Map)
              if (_str(c['currency']) case final currency?)
                NetworkCurrencyLimit(
                  currency: currency,
                  min: _dbl(ObdxApiUtils.asMap(c['minAmount'])['amount'] ??
                      c['minAmount']),
                  max: _dbl(ObdxApiUtils.asMap(c['maxAmount'])['amount'] ??
                      c['maxAmount']),
                ),
      ],
    );
  }

  static List<TransferNetwork> listFromPayload(dynamic data) {
    final root = ObdxApiUtils.asMap(data);
    final list = root['network'] ?? root['networks'];
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map) TransferNetwork.fromJson(Map<String, dynamic>.from(item)),
    ].where((n) => n.code.isNotEmpty).toList();
  }
}

/// A saved payee (`GET …/payeesv3` → `listPayees[]`, `PayeeDTO`).
class TransferPayee {
  const TransferPayee({
    required this.id,
    required this.name,
    required this.payeeType,
    this.nickName,
    this.groupId,
    this.accountNumber,
    this.currency,
    this.bankName,
  });

  final String id;
  final String name;
  final String payeeType;
  final String? nickName;
  final String? groupId;
  final String? accountNumber;
  final String? currency;
  final String? bankName;

  TransferKind? get kind => TransferKind.forPayeeType(payeeType);

  String get title => nickName ?? name;

  /// `••1234`, from [accountNumber].
  String get maskedAccount {
    final n = accountNumber;
    if (n == null || n.isEmpty) return '';
    return n.length <= 4 ? n : '••${n.substring(n.length - 4)}';
  }

  /// From a payee row. Only rows with an id and a payee type are usable.
  static TransferPayee? fromJson(Map<String, dynamic> json) {
    final id = _str(json['id']) ?? _str(json['payeeId']);
    final type = _str(json['payeeType']);
    if (id == null || type == null) return null;
    final name = _str(json['name']) ??
        _str(json['accountName']) ??
        _str(json['nickName']) ??
        '—';
    return TransferPayee(
      id: id,
      name: name,
      payeeType: type,
      nickName: _str(json['nickName']),
      groupId: _str(json['groupId']),
      accountNumber: _str(json['accountNumber']),
      currency: _str(json['currency']),
      bankName: _str(json['bankName']) ??
          _str(ObdxApiUtils.asMap(json['bankDetails'])['name']),
    );
  }

  /// The `payee` object of a transfer to this payee.
  Map<String, dynamic> toPaymentJson() => {
        'id': id,
        'name': name,
        if (nickName != null) 'nickName': nickName,
        'payeeType': payeeType,
        if (groupId != null) 'groupId': groupId,
        if (accountNumber != null) 'accountNumber': accountNumber,
      };
}

/// How a bank is identified on an adhoc payee (`bankDetailsType`).
enum BankCodeType {
  /// SWIFT / BIC (`SWI`).
  swift('SWI'),

  /// National clearing code — IFSC, sort code… (`NAC`).
  national('NAC'),

  /// Bank name and address only (`SPE`).
  nameAndAddress('SPE');

  const BankCodeType(this.code);

  final String code;
}

/// A payee entered for one transfer, not saved.
class AdhocBeneficiary {
  const AdhocBeneficiary({
    required this.kind,
    required this.accountNumber,
    required this.name,
    this.bankCode,
    this.bankName,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.country,
  });

  final TransferKind kind;
  final String accountNumber;
  final String name;

  /// SWIFT (international) or clearing code (domestic); none internally.
  final String? bankCode;
  final String? bankName;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;

  /// Two-letter country code.
  final String? country;

  BankCodeType get codeType => switch (kind) {
        TransferKind.international =>
          bankCode == null ? BankCodeType.nameAndAddress : BankCodeType.swift,
        _ => BankCodeType.national,
      };

  /// A `NetworkBeneficiaryDomainDTO`. Bank details are sent only for
  /// payees at other banks: SWIFT for international, the clearing code
  /// for domestic (in `nationalClringCod` and, as the NEFT assembler reads
  /// it, `bic2`).
  Map<String, dynamic> toJson({required String network}) {
    final address = {
      'line1': addressLine1,
      'line2': addressLine2,
      'line3': null,
      'city': city,
      'country': country,
    };
    final bank = <String, dynamic>{
      'bankDetailsType': codeType.code,
      if (codeType == BankCodeType.swift) 'swiftCode': bankCode,
      if (codeType == BankCodeType.national) ...{
        'nationalClringCodType': network,
        'nationalClringCod': bankCode,
        'bic2': bankCode,
      },
      if (bankName != null) 'beneBankBranchDTO': [
        {'namBank': bankName},
      ],
    };
    return {
      'creditAccountId': accountNumber,
      'beneficiaryName': name,
      if (kind != TransferKind.internal) 'beneficiaryBankDetails': [bank],
      if (kind == TransferKind.international) 'addressDTO': [address],
    };
  }
}

/// A purpose allowed on a network (`networkPurposeMapping` → `purposes[]`).
class TransferPurpose {
  const TransferPurpose({required this.code, required this.description});

  final String code;
  final String description;

  static List<TransferPurpose> listFromPayload(dynamic data) {
    final root = ObdxApiUtils.asMap(data);
    final list = root['purposes'];
    if (list is! List) return const [];
    return [
      for (final p in list)
        if (p is Map)
          if (_str(p['purposeCode']) case final code?)
            TransferPurpose(
              code: code,
              description: _str(p['purposeDescription']) ?? code,
            ),
    ];
  }
}

/// An International Low Value Payment currency, with its limits
/// (`GET …/pay/network/currencies`).
class GpiCurrency {
  const GpiCurrency({required this.code, this.description, this.min, this.max});

  final String code;
  final String? description;
  final double? min;
  final double? max;

  static List<GpiCurrency> listFromPayload(dynamic data) {
    final root = ObdxApiUtils.asMap(data);
    final list = root['currencyList'] ??
        root['currencies'] ??
        root['currencyDetails'] ??
        root['items'];
    if (list is! List) return const [];
    return [
      for (final c in list)
        if (c is Map)
          if (_str(c['code']) ?? _str(c['currency']) ?? _str(c['currencyCode'])
              case final code?)
            GpiCurrency(
              code: code,
              description: _str(c['description']) ?? _str(c['name']),
              min: _dbl(ObdxApiUtils.asMap(c['minAmount'])['amount'] ??
                  c['minAmount']),
              max: _dbl(ObdxApiUtils.asMap(c['maxAmount'])['amount'] ??
                  c['maxAmount']),
            ),
    ];
  }
}

/// A bank found by clearing code or BIC (`FinancialInstitutionResponse`).
class TransferBank {
  const TransferBank({required this.name, this.branchName, this.address});

  final String name;
  final String? branchName;
  final String? address;

  static TransferBank? fromPayload(dynamic data) {
    final root = ObdxApiUtils.asMap(data);
    // Some lookups wrap the institution; read it either way.
    final dto = root['name'] != null
        ? root
        : ObdxApiUtils.asMap(root['financialInstitution'] ??
            root['bankDetails'] ??
            root['bicCodeDetails']);
    final name = _str(dto['name']) ?? _str(dto['bankName']);
    if (name == null) return null;
    final address = dto['branchAddress'];
    return TransferBank(
      name: name,
      branchName: _str(dto['branchName']),
      address: address is Map
          ? [
              address['line1'],
              address['line2'],
              address['city'],
              address['country'],
            ].map(_str).whereType<String>().join(', ')
          : _str(address),
    );
  }
}

/// A repeat frequency (`InstructionFrequency`). Labels and the end-date
/// rule (`D`/`W`/`M` × count) follow the server's `calculateEndDate`.
class TransferFrequency {
  const TransferFrequency(this.code, this.label, this.unit, this.every);

  final String code;
  final String label;

  /// `D` days, `W` weeks, `M` months.
  final String unit;
  final int every;

  /// The server's constants (FORNIGHT is its spelling).
  static const all = [
    TransferFrequency('DAILY', 'Daily', 'D', 1),
    TransferFrequency('WEEKLY', 'Weekly', 'W', 1),
    TransferFrequency('FORNIGHT', 'Fortnightly', 'W', 2),
    TransferFrequency('MONTHLY', 'Monthly', 'M', 1),
    TransferFrequency('BIMONTHLY', 'Every 2 months', 'M', 2),
    TransferFrequency('QUARTERLY', 'Quarterly', 'M', 3),
    TransferFrequency('HALFYEARLY', 'Half-yearly', 'M', 6),
    TransferFrequency('YEARLY', 'Yearly', 'M', 12),
  ];

  static TransferFrequency? byCode(String code) {
    for (final f in all) {
      if (f.code == code) return f;
    }
    return null;
  }

  /// The date of the [n]th transfer (1 = [start]).
  DateTime nth(DateTime start, int n) {
    final steps = (n - 1) * every;
    return switch (unit) {
      'D' => start.add(Duration(days: steps)),
      'W' => start.add(Duration(days: steps * 7)),
      _ => DateTime(start.year, start.month + steps, start.day),
    };
  }
}

/// When a repeat transfer runs.
class RepeatSchedule {
  const RepeatSchedule({
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.instances,
  }) : assert(endDate != null || instances != null);

  final TransferFrequency frequency;
  final DateTime startDate;

  /// Last date, or computed from [instances].
  final DateTime? endDate;
  final int? instances;

  DateTime get lastDate => endDate ?? frequency.nth(startDate, instances!);

  Map<String, dynamic> toJson() => {
        'frequency': frequency.code,
        'startDate': obdxPaymentDate(startDate),
        'endDate': obdxPaymentDate(lastDate),
        if (instances != null) 'instances': instances,
      };
}

/// Charges on an international transfer — the server maps `O` → OUR,
/// `B` → BEN, `U` → SHA.
enum ChargeBearer {
  me('O', 'Paid by me'),
  beneficiary('B', 'Paid by the beneficiary'),
  shared('U', 'Shared');

  const ChargeBearer(this.code, this.label);

  final String code;
  final String label;
}

/// A transfer to a payee — the body of `pay/network`, or with a
/// [schedule] of `pay/networkInstruction`.
class NetworkTransferRequest {
  const NetworkTransferRequest({
    required this.kind,
    required this.network,
    required this.debitAccount,
    required this.amount,
    required this.currency,
    required this.paymentDate,
    this.payee,
    this.adhoc,
    this.remarks,
    this.purpose,
    this.charges = ChargeBearer.me,
    this.schedule,
    this.systemReferenceId,
  }) : assert(payee != null || adhoc != null);

  final TransferKind kind;
  final String network;
  final CasaAccount debitAccount;
  final double amount;
  final String currency;

  /// When a one-time transfer runs (today, or a later date).
  final DateTime paymentDate;
  final TransferPayee? payee;
  final AdhocBeneficiary? adhoc;
  final String? remarks;
  final TransferPurpose? purpose;
  final ChargeBearer charges;

  /// Set for a repeat transfer.
  final RepeatSchedule? schedule;
  final String? systemReferenceId;

  bool get isRepeat => schedule != null;
  bool get isAdhoc => adhoc != null;

  String get accountType =>
      (debitAccount.accountType?.trim().isNotEmpty == true)
          ? debitAccount.accountType!.trim()
          : 'CSA';

  String get paymentType =>
      isRepeat ? kind.repeatPaymentType : kind.paymentType;

  /// Who is paid, for review screens.
  String get payeeLabel => payee?.title ?? adhoc!.name;

  NetworkTransferRequest withReference(String reference) =>
      NetworkTransferRequest(
        kind: kind,
        network: network,
        debitAccount: debitAccount,
        amount: amount,
        currency: currency,
        paymentDate: paymentDate,
        payee: payee,
        adhoc: adhoc,
        remarks: remarks,
        purpose: purpose,
        charges: charges,
        schedule: schedule,
        systemReferenceId: reference,
      );

  Map<String, dynamic> toJson() {
    final saved = payee;
    return {
      'partyId': {},
      'amount': {'currency': currency, 'amount': amount},
      'remarks': remarks?.trim().isNotEmpty == true ? remarks!.trim() : null,
      if (purpose != null) ...{
        'purpose': purpose!.code,
        'purposeText': purpose!.description,
      },
      'debitAccountId': {
        'displayValue': debitAccount.displayNumber,
        'value': debitAccount.id,
      },
      'adhocPayment': isAdhoc,
      'accountType': accountType,
      'paymentType': paymentType,
      'paymentDate': obdxPaymentDate(schedule?.startDate ?? paymentDate),
      'charges': charges.code,
      'chargesAccount': {},
      'network': network,
      if (saved != null) ...{
        // Makes the server fill in the beneficiary from the saved payee.
        'source': 'PAYEE',
        'payee': saved.toPaymentJson(),
        'beneficiary': [
          {
            'creditAccountId': saved.accountNumber,
            'beneficiaryName': saved.name,
          },
        ],
      } else
        'beneficiary': [adhoc!.toJson(network: network)],
      'verificationPayeeReport': {},
      'currencyOfTransfer': currency,
      'remittance': {'remittanceInformationStructured': []},
      'otherDetails': {
        'line1': null,
        'line2': null,
        'line3': null,
        'line4': null,
      },
      'documentsList': [],
      'questionDTO': [],
      'currencyExchange': {
        'sourceCurrency': '',
        'targetCurrency': '',
        'exchangeRate': '',
        'instructedAmount': {},
      },
      'paymentChargeDetails': [],
      if (schedule != null) ...schedule!.toJson(),
      if (systemReferenceId?.trim().isNotEmpty == true)
        'systemReferenceId': systemReferenceId!.trim(),
    };
  }
}

/// One transfer's answer inside a Multiple Transfers batch: [value] when the
/// bank took it, otherwise [error] — the bank's reason, ready to show.
class BatchRowResult<T> {
  const BatchRowResult.ok(T this.value, {this.pendingApproval = false})
      : error = null;

  const BatchRowResult.failed(String this.error)
      : value = null,
        pendingApproval = false;

  final T? value;
  final String? error;

  /// Accepted, but waiting for an approver rather than processed.
  final bool pendingApproval;

  bool get ok => value != null;
}

/// A submitted Multiple Transfers batch: every row's outcome, or the OTP
/// the bank wants for the whole batch first.
class BatchSubmitOutcome {
  const BatchSubmitOutcome.done(this.rows)
      : challenge = null,
        invalidOtp = false;

  const BatchSubmitOutcome.otpRequired(
    ObdxChallenge this.challenge, {
    this.invalidOtp = false,
  }) : rows = const [];

  final List<BatchRowResult<TransferSubmitResult>> rows;
  final ObdxChallenge? challenge;

  /// The OTP sent with this attempt was not accepted.
  final bool invalidOtp;
}
