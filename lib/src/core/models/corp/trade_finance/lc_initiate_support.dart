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
    this.isTermDeposit = false,
  });

  final TfId id;
  /// From `corporateDeposit` (term deposit) rather than `demandDeposit`.
  final bool isTermDeposit;
  final String? displayName;
  final String? currency;
  final MoneyAmount? availableBalance;
  final String? productName;

  String get label => [
        id.displayValue ?? id.value ?? '',
        if (currency != null) currency!,
        if (productName != null) productName!,
      ].join(' · ');

  /// `accounts[]` of `demandDeposit` (H3 #67/#73). [termDeposits] reads a
  /// `corporateDeposit` answer instead (H5 Linkages — 500 on pre-sales, so
  /// its list key is NOT CAPTURED; the usual names are tried).
  static List<LcAccount> listFromPayload(
    dynamic data, {
    bool termDeposits = false,
  }) {
    final root = TfJson.root(data);
    final raw = root['accounts'] ??
        root['termDepositDTOs'] ??
        root['depositDTOs'] ??
        root['corporateDepositDTOs'];
    return [
      for (final map in TfJson.maps(raw))
        if (TfId.fromJson(map['id']) case final id when !id.isEmpty)
          LcAccount(
            id: id,
            displayName: TfJson.str(map['displayName']),
            currency: TfJson.str(map['currencyCode']) ??
                TfJson.str(map['currency']),
            availableBalance: map['availableBalance'] != null
                ? MoneyAmount.fromJson(map['availableBalance'])
                : (map['principalAmount'] == null
                    ? null
                    : MoneyAmount.fromJson(map['principalAmount'])),
            productName:
                TfJson.str(TfJson.map(map['productDTO'])['description']),
            isTermDeposit: termDeposits,
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
        'depositType': account.isTermDeposit ? 'TD' : 'CASA',
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

// ── 01 LC Details ───────────────────────────────────────────────────────

/// A party the user may initiate for, from `me/party/relations`
/// (`partyToPartyRelationship`, empty in H5 LC Details). Entry names are
/// NOT CAPTURED and read tolerantly.
class LcRelatedParty {
  const LcRelatedParty({required this.id, required this.name});

  final TfId id;
  final String name;

  static List<LcRelatedParty> listFromPayload(dynamic data) {
    final root = TfJson.root(data);
    final result = <LcRelatedParty>[];
    for (final map in TfJson.maps(root['partyToPartyRelationship'])) {
      final related = map['relatedParty'] ?? map['relatedPartyId'] ?? map['party'];
      final id = related is Map ? TfId.fromJson(related) : TfId(value: TfJson.str(related));
      final name = TfJson.str(map['relatedPartyName']) ??
          TfJson.str(map['partyName']) ??
          TfJson.str(map['name']);
      if (id.isEmpty) continue;
      result.add(LcRelatedParty(id: id, name: name ?? id.displayValue ?? id.value!));
    }
    return result;
  }
}

/// `branchdate/{branch}` (H5 LC Details) — the bank's business date, used
/// as the earliest expiry date. 400 on pre-sales, so the field name is NOT
/// CAPTURED; the usual names are tried.
class LcBranchDate {
  LcBranchDate._();

  static DateTime? fromPayload(dynamic data) {
    final root = TfJson.root(data);
    final inner = TfJson.map(root['branchDate'] ?? root['branchDateDTO']);
    for (final source in [inner, root]) {
      for (final key in ['currentWorkingDate', 'currentDate', 'date', 'businessDate']) {
        final date = TfJson.date(source[key]);
        if (date != null) return DateTime(date.year, date.month, date.day);
      }
    }
    return null;
  }
}

/// Standard instructions text from `customerInstructions` (H5
/// Instructions; 500 on pre-sales, so the shape is NOT CAPTURED).
class LcStandardInstructions {
  LcStandardInstructions._();

  static List<String> fromPayload(dynamic data) {
    final root = TfJson.root(data);
    final raw = root['customerInstructionsDTOs'] ??
        root['customerInstructions'] ??
        root['instructions'] ??
        root['list'];
    return [
      for (final map in TfJson.maps(raw))
        if ((TfJson.str(map['instructionText']) ??
                TfJson.str(map['description']) ??
                TfJson.str(map['instruction']) ??
                TfJson.str(map['value'])) case final text?)
          text,
    ];
  }
}

// ── 08 Attachments ──────────────────────────────────────────────────────

/// A file picked on the Attachments section.
class LcAttachment {
  const LcAttachment({
    required this.key,
    required this.fileName,
    required this.bytes,
    required this.mimeType,
    this.category,
    this.documentType,
    this.contentId,
    this.uploading = false,
    this.error,
  });

  /// Local identity (the same file name may be picked twice).
  final String key;
  final String fileName;
  final List<int> bytes;
  final String mimeType;

  /// `documentCategoryDTOList[].category` / `.type[].type` (H5).
  final String? category;
  final String? documentType;

  /// Host content id once uploaded ('' when the answer carried none).
  final String? contentId;
  final bool uploading;
  final String? error;

  int get size => bytes.length;
  bool get isUploaded => contentId != null;

  /// Allowed by the design's upload rules: JPEG, PNG, DOC, PDF, TXT.
  static const allowedExtensions = ['jpg', 'jpeg', 'png', 'doc', 'docx', 'pdf', 'txt'];

  /// 5 MB per file.
  static const maxBytes = 5 * 1024 * 1024;

  /// Alphanumeric, dot, underscore and space only.
  static final fileNamePattern = RegExp(r'^[A-Za-z0-9._ ]+$');

  static String mimeFor(String fileName) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'application/octet-stream',
    };
  }

  /// Why [fileName] / [size] break the upload rules, or null.
  static String? ruleViolation(String fileName, int size) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    if (!allowedExtensions.contains(ext)) {
      return '$fileName: only JPEG, PNG, DOC, PDF and TXT files are supported.';
    }
    if (size > maxBytes) return '$fileName is larger than 5 MB.';
    if (!fileNamePattern.hasMatch(fileName)) {
      return '$fileName: use only letters, numbers, dot, underscore and space.';
    }
    return null;
  }

  /// Content id from the upload answer. NOT CAPTURED — the usual OBDX
  /// content fields are read; null when none is present.
  static String? contentIdFrom(dynamic data) {
    final root = TfJson.root(data);
    final list = root['contentDTOList'];
    final first = list is List && list.isNotEmpty ? list.first : null;
    for (final source in [
      TfJson.map(first),
      TfJson.map(root['contentDTO']),
      root,
    ]) {
      final id = source['contentId'];
      final text = id is Map ? TfJson.str(id['value']) : TfJson.str(id);
      if (text != null) return text;
    }
    return null;
  }

  LcAttachment copyWith({
    String? category,
    String? documentType,
    String? contentId,
    bool? uploading,
    String? error,
    bool clearError = false,
  }) =>
      LcAttachment(
        key: key,
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
        category: category ?? this.category,
        documentType: documentType ?? this.documentType,
        contentId: contentId ?? this.contentId,
        uploading: uploading ?? this.uploading,
        error: clearError ? null : (error ?? this.error),
      );

}

// ── Per-section reference data ──────────────────────────────────────────
//
// Each section loads its own data the first time it opens, as the web does
// (H5 captures). Lookups that fail leave their lists empty and add a
// [warnings] line, so a section always opens.

/// 01 LC Details — `me/party`, `beneficiaries`, `me/party/relations`,
/// `branchdate/{branch}`.
class LcDetailsSectionData {
  const LcDetailsSectionData({
    this.beneficiaries = const [],
    this.relatedParties = const [],
    this.branchDate,
    this.warnings = const [],
  });

  final List<LcBeneficiary> beneficiaries;
  final List<LcRelatedParty> relatedParties;
  final DateTime? branchDate;
  final List<String> warnings;
}

/// 03 Documents & Conditions — `tradeDocument`,
/// `additionalConditionMaintenance` (conditions and incoterms come with
/// the LC lookups).
class LcDocumentsSectionData {
  const LcDocumentsSectionData({
    this.tradeDocuments = const [],
    this.maintainedConditions = const [],
    this.warnings = const [],
  });

  final List<LcDocument> tradeDocuments;
  final List<TradeCode> maintainedConditions;
  final List<String> warnings;
}

/// 04 Linkages — `corporateDeposit`, `tradeEnumerations/currencies`,
/// `demandDeposit`.
class LcLinkagesSectionData {
  const LcLinkagesSectionData({
    this.accounts = const [],
    this.currencies = const [],
    this.warnings = const [],
  });

  /// CASA accounts first, then term deposits.
  final List<LcAccount> accounts;
  final List<TradeCode> currencies;
  final List<String> warnings;
}

/// 05 Instructions — `confirmationInstruction`, `confirmationParty`,
/// `customerInstructions`.
class LcInstructionsSectionData {
  const LcInstructionsSectionData({
    this.confirmationInstructions = const [],
    this.confirmationParties = const [],
    this.standardInstructions = const [],
    this.warnings = const [],
  });

  final List<TradeCode> confirmationInstructions;
  final List<TradeCode> confirmationParties;
  final List<String> standardInstructions;
  final List<String> warnings;
}
