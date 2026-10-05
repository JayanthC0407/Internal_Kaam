import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/lc_common.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/lc_product.dart';

/// Reference data used only by the Initiate LC sections, loaded once when
/// the form opens. Captures: `LC_inititation complete flow.har` (**H3 #n**).
///
/// Every list tolerates its own endpoint failing (it stays empty), as
/// pre-sales answers some of these with 500 (`corporateDeposit`, H3 #65).

// ── 42C Drafts ──────────────────────────────────────────────────────────

/// One `billingDrafts[]` entry — field names from the H3 #74 skeleton.
class LcBillingDraft {
  const LcBillingDraft({
    this.tenor,
    this.creditDays,
    this.creditDaysType,
    this.draweeBankCode,
    this.draweeBank,
    this.amount,
  });

  /// Tenor in days.
  final int? tenor;
  final int? creditDays;

  /// What the credit days run from (e.g. invoice / shipment date).
  final String? creditDaysType;
  final String? draweeBankCode;

  /// Resolved from `tradeBicCodes` when the code was verified.
  final TradeBank? draweeBank;
  final double? amount;

  String get draweeLabel =>
      draweeBank?.name ?? draweeBankCode ?? '—';

  factory LcBillingDraft.fromJson(dynamic json) {
    final map = TfJson.map(json);
    final bank = TfJson.map(map['draweeBankDetails']);
    final code = TfJson.str(map['draweeBankId']) ?? TfJson.str(bank['swiftCode']);
    return LcBillingDraft(
      tenor: TfJson.integer(map['tenor']),
      creditDays: TfJson.integer(map['creditDays']),
      creditDaysType: TfJson.str(map['creditDaysType']) ??
          TfJson.str(map['creditDaysFromdate']),
      draweeBankCode: code,
      draweeBank: code == null
          ? null
          : TradeBank(
              code: code,
              name: TfJson.str(bank['name']),
              address: LcAddress.fromJson(bank['branchAddress']),
              customerNo: TfJson.str(bank['customerNo']),
            ),
      amount: TfJson.dbl(TfJson.map(map['amount'])['amount']),
    );
  }

  Map<String, dynamic> toJson(String? currency) => {
        'id': null,
        'tenor': tenor,
        'creditDaysFromdate': null,
        'amount': {'currency': currency, 'amount': amount},
        'creditDays': creditDays,
        'otherInformation': null,
        'draweeBankId': draweeBank?.code ?? draweeBankCode,
        'draweeBankDetails': {
          'customerNo': draweeBank?.customerNo,
          'branchAddress': (draweeBank?.address ?? LcAddress.empty).toJson(),
          'name': draweeBank?.name,
          'swiftCode': draweeBank?.code ?? draweeBankCode,
        },
        'creditDaysType': creditDaysType,
      };
}

// ── 40A Trade structure (revolving) ─────────────────────────────────────

/// `revolvingDetails` — field names from the H3 #74 skeleton.
class LcRevolvingDetails {
  const LcRevolvingDetails({
    this.autoReinstatement = false,
    this.type = 'VALUE',
    this.frequency,
    this.frequencyUnit = 'DAYS',
    this.cumulative = false,
  });

  final bool autoReinstatement;

  /// `VALUE` / `TIME`.
  final String type;
  final int? frequency;

  /// `DAYS` / `MONTHS`.
  final String frequencyUnit;
  final bool cumulative;

  static const empty = LcRevolvingDetails();

  factory LcRevolvingDetails.fromJson(dynamic json) {
    final map = TfJson.map(json);
    return LcRevolvingDetails(
      autoReinstatement: TfJson.boolean(map['autoReinstatement']),
      type: TfJson.str(map['type'])?.toUpperCase() ?? 'VALUE',
      frequency: TfJson.integer(map['frequency']),
      frequencyUnit: TfJson.str(map['frequencyUnit'])?.toUpperCase() ?? 'DAYS',
      cumulative: TfJson.boolean(map['cumulativeFrequency']),
    );
  }

  LcRevolvingDetails copyWith({
    bool? autoReinstatement,
    String? type,
    int? frequency,
    String? frequencyUnit,
    bool? cumulative,
  }) =>
      LcRevolvingDetails(
        autoReinstatement: autoReinstatement ?? this.autoReinstatement,
        type: type ?? this.type,
        frequency: frequency ?? this.frequency,
        frequencyUnit: frequencyUnit ?? this.frequencyUnit,
        cumulative: cumulative ?? this.cumulative,
      );

  /// Booleans go out as `"true"` / `"false"` strings, as the web sends them.
  Map<String, dynamic> toJson({required bool revolving}) => revolving
      ? {
          'frequency': frequency ?? 0,
          'autoReinstatement': '$autoReinstatement',
          'cumulativeFrequency': '$cumulative',
          'reinstatementDate': null,
          'type': type,
          'frequencyUnit': frequencyUnit,
        }
      : {
          'frequency': null,
          'autoReinstatement': null,
          'cumulativeFrequency': null,
          'reinstatementDate': null,
          'type': null,
          'frequencyUnit': null,
        };
}

// ── Banks (advising, advise-through, available with) ────────────────────

/// A bank entered either by SWIFT code (verified via `tradeBicCodes`) or
/// by name and address — the two options the Instructions section offers.
class LcBankSelection {
  const LcBankSelection({
    this.byName = false,
    this.swiftCode,
    this.resolved,
    this.name,
    this.address = LcAddress.empty,
  });

  final bool byName;
  final String? swiftCode;

  /// Set once [swiftCode] was verified.
  final TradeBank? resolved;
  final String? name;
  final LcAddress address;

  static const empty = LcBankSelection();

  bool get isEmpty => byName
      ? (name == null || name!.trim().isEmpty)
      : (code == null);

  /// Upper-cased SWIFT code, or null when entered by name or blank.
  String? get code {
    if (byName) return null;
    final text = (resolved?.code ?? swiftCode)?.trim();
    return (text == null || text.isEmpty) ? null : text.toUpperCase();
  }

  String get summary {
    if (byName) return (name == null || name!.isEmpty) ? '—' : name!;
    final bank = resolved;
    if (bank != null) {
      return [bank.code, if (bank.name != null) bank.name!, bank.address.singleLine]
          .where((s) => s != '—')
          .join(' • ');
    }
    return code ?? '—';
  }

  /// Seeds from a saved LC / draft: `{role}BankCode` + `{role}BankDetails`.
  factory LcBankSelection.fromLc(dynamic code, dynamic details) {
    final swift = TfJson.str(code);
    final map = TfJson.map(details);
    final name = TfJson.str(map['name']);
    final address = LcAddress.fromJson(map['branchAddress']);
    if (swift == null && name != null) {
      return LcBankSelection(byName: true, name: name, address: address);
    }
    if (swift == null) return empty;
    return LcBankSelection(
      swiftCode: swift,
      resolved: name == null
          ? null
          : TradeBank(
              code: swift,
              name: name,
              address: address,
              customerNo: TfJson.str(map['customerNo']),
            ),
    );
  }

  LcBankSelection copyWith({
    bool? byName,
    String? swiftCode,
    TradeBank? resolved,
    bool clearResolved = false,
    String? name,
    LcAddress? address,
  }) =>
      LcBankSelection(
        byName: byName ?? this.byName,
        swiftCode: swiftCode ?? this.swiftCode,
        resolved: clearResolved ? null : (resolved ?? this.resolved),
        name: name ?? this.name,
        address: address ?? this.address,
      );

  /// `…BankDetails` block.
  Map<String, dynamic> toDetailsJson() {
    if (byName) {
      return {
        'customerNo': null,
        'branchAddress': address.toJson(),
        'name': name,
      };
    }
    final bank = resolved;
    return {
      'customerNo': bank?.customerNo,
      'branchAddress': (bank?.address ?? LcAddress.empty).toJson(),
      'name': bank?.name,
    };
  }
}

// ── 59 Beneficiary ──────────────────────────────────────────────────────

/// A maintained beneficiary — `beneficiaries?transactionType=LETTEROFCREDIT`
/// (H3 #49). The capture returned an empty `beneficiaryDTOs`, so the entry
/// shape is read tolerantly (ASSUMPTION: OBDX `BeneficiaryDTO` names).
class LcBeneficiary {
  const LcBeneficiary({
    required this.id,
    required this.name,
    this.address = LcAddress.empty,
  });

  final String id;
  final String name;
  final LcAddress address;

  static List<LcBeneficiary> listFromPayload(dynamic data) {
    final root = TfJson.root(data);
    final result = <LcBeneficiary>[];
    for (final map in TfJson.maps(root['beneficiaryDTOs'])) {
      final id = TfJson.str(map['id']) ?? TfJson.str(map['beneId']);
      final name = TfJson.str(map['beneName']) ??
          TfJson.str(map['name']) ??
          TfJson.str(map['beneficiaryName']);
      if (id == null || name == null) continue;
      final rawAddress = map['address'] ?? map['beneAddress'];
      var address = LcAddress.fromJson(rawAddress);
      final country = TfJson.str(map['country']);
      if (address.country == null && country != null) {
        address = LcAddress(
          line1: address.line1,
          line2: address.line2,
          line3: address.line3,
          city: address.city,
          zipCode: address.zipCode,
          country: country,
        );
      }
      result.add(LcBeneficiary(id: id, name: name, address: address));
    }
    return result;
  }

  @override
  bool operator ==(Object other) => other is LcBeneficiary && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ── 06 Insurance ────────────────────────────────────────────────────────

/// `insurancePolicies?partyId=` — H3 #72.
class LcInsurancePolicy {
  const LcInsurancePolicy({
    required this.policyNumber,
    required this.raw,
    this.companyCode,
    this.companyName,
    this.country,
    this.startDate,
    this.expiryDate,
    this.amount,
    this.utilizedAmount,
    this.status,
  });

  final String policyNumber;
  final String? companyCode;
  final String? companyName;
  final String? country;

  /// Cover date (`policyStartDate`).
  final DateTime? startDate;
  final DateTime? expiryDate;
  final MoneyAmount? amount;
  final MoneyAmount? utilizedAmount;
  final String? status;

  /// The policy as returned — sent back unchanged in `policyDTOs`.
  final Map<String, dynamic> raw;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [policyNumber, companyName, companyCode, country]
        .any((s) => s != null && s.toLowerCase().contains(q));
  }

  static List<LcInsurancePolicy> listFromPayload(dynamic data) {
    final root = TfJson.root(data);
    return [
      for (final map in TfJson.maps(root['insurancePolicies']))
        if (TfJson.str(map['policyNumber']) case final number?)
          LcInsurancePolicy(
            policyNumber: number,
            raw: map,
            companyCode: TfJson.str(map['companyCode']),
            companyName: TfJson.str(map['companyName']),
            country: TfJson.str(map['country']),
            startDate: TfJson.date(map['policyStartDate']),
            expiryDate: TfJson.date(map['expiryDate']),
            amount: map['amount'] == null ? null : MoneyAmount.fromJson(map['amount']),
            utilizedAmount: map['utilizedAmount'] == null
                ? null
                : MoneyAmount.fromJson(map['utilizedAmount']),
            status: TfJson.str(map['status']),
          ),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is LcInsurancePolicy && other.policyNumber == policyNumber;

  @override
  int get hashCode => policyNumber.hashCode;
}

// ── 04 Linkages / 07 Charges ────────────────────────────────────────────

/// A CASA account from `dda/v1/demandDeposit` — H3 #67 (all accounts, used
/// for deposit linkages) and H3 #73 (`taskCode=TF_AF_CLC`, the accounts
/// allowed as LC charge accounts).
class LcAccount {
  const LcAccount({
    required this.id,
    this.displayName,
    this.currency,
    this.availableBalance,
    this.productName,
  });

  final TfId id;
  final String? displayName;
  final String? currency;
  final MoneyAmount? availableBalance;
  final String? productName;

  String get label => [
        id.displayValue ?? id.value ?? '',
        if (currency != null) currency!,
        if (productName != null) productName!,
      ].join(' · ');

  static List<LcAccount> listFromPayload(dynamic data) {
    final root = TfJson.root(data);
    return [
      for (final map in TfJson.maps(root['accounts']))
        if (TfId.fromJson(map['id']) case final id when !id.isEmpty)
          LcAccount(
            id: id,
            displayName: TfJson.str(map['displayName']),
            currency: TfJson.str(map['currencyCode']),
            availableBalance: map['availableBalance'] == null
                ? null
                : MoneyAmount.fromJson(map['availableBalance']),
            productName:
                TfJson.str(TfJson.map(map['productDTO'])['description']),
          ),
    ];
  }

  @override
  bool operator ==(Object other) => other is LcAccount && other.id.value == id.value;

  @override
  int get hashCode => id.value.hashCode;
}

/// One `depositLinkages[]` entry.
///
/// ASSUMPTION: the capture never added a linkage (the array went out
/// empty, H3 #74), so the entry follows OBDX's `DepositLinkageDTO` naming.
/// Confirm with a capture that links a deposit.
class LcDepositLinkage {
  const LcDepositLinkage({required this.account, this.amount});

  final LcAccount account;
  final double? amount;

  LcDepositLinkage copyWith({double? amount}) =>
      LcDepositLinkage(account: account, amount: amount ?? this.amount);

  factory LcDepositLinkage.fromJson(dynamic json) {
    final map = TfJson.map(json);
    final money = TfJson.map(map['linkedAmount']);
    return LcDepositLinkage(
      account: LcAccount(
        id: TfId.fromJson(map['accountId'] ?? map['depositId']),
        currency: TfJson.str(map['accountCurrency']) ?? TfJson.str(money['currency']),
      ),
      amount: TfJson.dbl(money['amount']),
    );
  }

  Map<String, dynamic> toJson() => {
        'accountId': account.id.toJson(),
        'depositType': 'CASA',
        'accountCurrency': account.currency,
        'linkedAmount': {'currency': account.currency, 'amount': amount},
      };
}

// ── 08 Attachments ──────────────────────────────────────────────────────

/// `documentcontent/documentcategories` — H3 #75.
class LcDocumentCategory {
  const LcDocumentCategory({required this.category, this.types = const []});

  final String category;

  /// `(type, mandatory)`.
  final List<(String, bool)> types;

  bool get hasMandatory => types.any((t) => t.$2);

  static List<LcDocumentCategory> listFromPayload(dynamic data) {
    final root = TfJson.root(data);
    return [
      for (final map in TfJson.maps(root['documentCategoryDTOList']))
        if (TfJson.str(map['category']) case final category?)
          LcDocumentCategory(
            category: category,
            types: [
              for (final t in TfJson.maps(map['type']))
                if (TfJson.str(t['type']) case final type?)
                  (type, TfJson.boolean(t['mandatory'])),
            ],
          ),
    ];
  }
}

// ── Aggregate ───────────────────────────────────────────────────────────

class LcInitiateSupport {
  const LcInitiateSupport({
    this.beneficiaries = const [],
    this.tradeDocuments = const [],
    this.insurancePolicies = const [],
    this.chargeAccounts = const [],
    this.linkageAccounts = const [],
    this.documentCategories = const [],
    this.confirmationParties = const [],
    this.maintainedConditions = const [],
  });

  /// H3 #49.
  final List<LcBeneficiary> beneficiaries;

  /// Document master for "+ Add Document" — H3 #58.
  final List<LcDocument> tradeDocuments;

  /// H3 #72.
  final List<LcInsurancePolicy> insurancePolicies;

  /// H3 #73.
  final List<LcAccount> chargeAccounts;

  /// H3 #67.
  final List<LcAccount> linkageAccounts;

  /// H3 #75.
  final List<LcDocumentCategory> documentCategories;

  /// `tradeEnumerations/confirmationParty` — H3 #70.
  final List<TradeCode> confirmationParties;

  /// Party-maintained additional conditions — H3 #63.
  final List<TradeCode> maintainedConditions;

  static const empty = LcInitiateSupport();
}
