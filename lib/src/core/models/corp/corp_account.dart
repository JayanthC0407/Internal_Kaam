import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// OBDX account-type codes returned on `accounts[].type` and
/// `summary.items[].accountType` by `GET /digx-common/account/v1/accounts`
/// (Corporate "LOGIN to DASHBOARD" capture, entry #68).
class CorpAccountTypeCode {
  CorpAccountTypeCode._();

  /// Current & Savings (demand deposit).
  static const String casa = 'CSA';

  /// Term / recurring deposit.
  static const String deposit = 'TRD';

  /// Loans & finances.
  static const String loan = 'LON';
}

/// Which dashboard product group an account belongs to.
enum CorpAccountGroup {
  casa,
  deposit,
  loan,
  other;

  static CorpAccountGroup fromCode(String? code) {
    switch ((code ?? '').trim().toUpperCase()) {
      case CorpAccountTypeCode.casa:
        return CorpAccountGroup.casa;
      case CorpAccountTypeCode.deposit:
        return CorpAccountGroup.deposit;
      case CorpAccountTypeCode.loan:
        return CorpAccountGroup.loan;
      default:
        return CorpAccountGroup.other;
    }
  }
}

/// A single corporate account from `GET /digx-common/account/v1/accounts`.
///
/// This is the Corporate counterpart of the Retail `CasaAccount`. It is kept
/// separate because the corporate dashboard reads the *aggregated* accounts
/// endpoint (all product groups in one response, plus a per-group `summary`
/// block) rather than Retail's `dda/v1/demandDeposit`, and because the
/// corporate Account Summary grid needs fields Retail never shows —
/// `partyName`, `partyId` and the product description as "Account Type".
class CorpAccount {
  const CorpAccount({
    required this.id,
    required this.displayNumber,
    required this.status,
    required this.currencyCode,
    required this.group,
    this.typeCode,
    this.partyId,
    this.partyName,
    this.displayName,
    this.nickname,
    this.productName,
    this.productId,
    this.branchCode,
    this.module,
    this.ddaAccountType,
    this.holdingPattern,
    this.openingDate,
    this.isDefault = false,
    this.availableBalance,
    this.currentBalance,
    this.equivalentAvailableBalance,
    this.outstandingBalance,
    this.maturityAmount,
    this.principalAmount,
  });

  /// Complex OBDX account id (`id.value`) — required for any follow-up
  /// detail / transaction / statement call.
  final String id;

  /// Maskable display account number (`id.displayValue`), e.g.
  /// `xxxxxxxxxxxx1022`.
  final String displayNumber;

  final String status;
  final String currencyCode;

  /// Product group this account belongs to (CASA / Deposit / Loan).
  final CorpAccountGroup group;

  /// Raw `accounts[].type` code as returned by the host (`CSA`, `TRD`, `LON`).
  final String? typeCode;

  /// `partyId.value` — the owning corporate party.
  final String? partyId;

  /// `partyName` — shown in the Account Summary grid's "Party Name" column.
  final String? partyName;

  /// `displayName` — account title as configured on the host.
  final String? displayName;

  final String? nickname;

  /// `productDTO.description`, e.g. "Current Accounts - Regular". This is
  /// what the design labels "Account Type".
  final String? productName;

  final String? productId;
  final String? branchCode;

  /// `CON` conventional / `ISL` Islamic.
  final String? module;

  /// `ddaAccountType` — `CURRENT` / `SAVING` for CASA accounts.
  final String? ddaAccountType;

  final String? holdingPattern;
  final String? openingDate;

  /// `defaultAccount` — drives the "Primary Account" tag on the hero card.
  final bool isDefault;

  final MoneyAmount? availableBalance;
  final MoneyAmount? currentBalance;

  /// Balance converted to the bank's calculation currency
  /// (`equivalentAvailableBalance`) — used for cross-currency totals.
  final MoneyAmount? equivalentAvailableBalance;

  /// Loan-only.
  final MoneyAmount? outstandingBalance;

  /// Deposit-only.
  final MoneyAmount? maturityAmount;

  /// Deposit-only (`principalAmount` / `investmentAmount`).
  final MoneyAmount? principalAmount;

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isDormant => status.toUpperCase() == 'DORMANT';
  bool get isClosed => status.toUpperCase() == 'CLOSED';

  bool get isSaving => (ddaAccountType ?? '').toUpperCase().contains('SAV');
  bool get isCurrent => (ddaAccountType ?? '').toUpperCase().contains('CUR');

  /// Balance to show on cards / in the summary grid, picked per product
  /// group so a loan shows what it owes and a deposit what it holds.
  MoneyAmount? get displayBalance {
    switch (group) {
      case CorpAccountGroup.loan:
        return outstandingBalance ?? currentBalance ?? availableBalance;
      case CorpAccountGroup.deposit:
        return principalAmount ?? availableBalance ?? currentBalance;
      case CorpAccountGroup.casa:
      case CorpAccountGroup.other:
        return availableBalance ?? currentBalance;
    }
  }

  /// "Party Name" column value, falling back to the account's own title.
  String get partyLabel {
    final party = partyName?.trim();
    if (party != null && party.isNotEmpty) return party;
    final display = displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    return '—';
  }

  /// "Account Type" column value — the product description, falling back to
  /// the raw DDA type and finally the group code.
  String get accountTypeLabel {
    final product = productName?.trim();
    if (product != null && product.isNotEmpty) return product;
    final dda = ddaAccountType?.trim();
    if (dda != null && dda.isNotEmpty) return dda;
    return typeCode?.trim().isNotEmpty == true ? typeCode!.trim() : '—';
  }

  /// Card title — nickname, else the host display name, else the product.
  String get title {
    final nick = nickname?.trim();
    if (nick != null && nick.isNotEmpty) return nick;
    final display = displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    return accountTypeLabel;
  }

  /// `XXXX XXXX XXXX 1022` — the grid's masked "Account Number" format.
  String get groupedMaskedNumber {
    final raw = displayNumber.replaceAll(RegExp(r'\s+'), '');
    if (raw.isEmpty) return '—';
    final visible = raw.length >= 4 ? raw.substring(raw.length - 4) : raw;
    final maskedLength = raw.length - visible.length;
    final combined = ('X' * maskedLength) + visible;

    final groups = <String>[];
    for (var i = 0; i < combined.length; i += 4) {
      final end = (i + 4).clamp(0, combined.length);
      groups.add(combined.substring(i, end));
    }
    return groups.join(' ');
  }

  /// Last four digits, used where space is tight.
  String get lastFour {
    final raw = displayNumber.replaceAll(RegExp(r'\D'), '');
    if (raw.length <= 4) return raw;
    return raw.substring(raw.length - 4);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CorpAccount && other.id == id && other.group == group;

  @override
  int get hashCode => Object.hash(id, group);

  factory CorpAccount.fromJson(
    Map<String, dynamic> json, {
    CorpAccountGroup? groupOverride,
  }) {
    final idMap = ObdxApiUtils.asMap(json['id']);
    final id = (idMap['value'] ??
            json['accountId'] ??
            json['loanAccountId'] ??
            json['depositId'] ??
            '')
        .toString()
        .trim();
    final display = (idMap['displayValue'] ??
            json['accountNumber'] ??
            json['displayValue'] ??
            id)
        .toString()
        .trim();

    final typeCode = _firstNonEmpty([json['type'], json['accountType']]);

    final currencyCode = _firstNonEmpty([
          json['currencyCode'],
          json['currency'],
          ObdxApiUtils.asMap(json['availableBalance'])['currency'],
          ObdxApiUtils.asMap(json['currentBalance'])['currency'],
          ObdxApiUtils.asMap(json['outstandingBalance'])['currency'],
          ObdxApiUtils.asMap(json['principalAmount'])['currency'],
        ]) ??
        '';

    final product = ObdxApiUtils.asMap(
      json['productDTO'] ?? json['product'] ?? json['productDetails'],
    );

    final partyIdMap = ObdxApiUtils.asMap(json['partyId']);

    final defaultAccountRaw = json['defaultAccount'];

    return CorpAccount(
      id: id,
      displayNumber: display,
      status: (json['status'] ?? '').toString().trim(),
      currencyCode: currencyCode,
      group: groupOverride ?? CorpAccountGroup.fromCode(typeCode),
      typeCode: typeCode,
      partyId: _firstNonEmpty([partyIdMap['value'], json['partyId']]),
      partyName: _firstNonEmpty([json['partyName'], json['customerName']]),
      displayName: _firstNonEmpty([json['displayName'], json['accountName']]),
      nickname: _firstNonEmpty([
        json['accountNickname'],
        json['nickname'],
        json['alias'],
      ]),
      productName: _firstNonEmpty([
        product['description'],
        product['name'],
        product['displayValue'],
        json['productDescription'],
        json['productName'],
      ]),
      productId: _firstNonEmpty([product['productId'], product['code']]),
      branchCode: _firstNonEmpty([json['branchCode'], json['branch']]),
      module: _firstNonEmpty([json['module']]),
      ddaAccountType: _firstNonEmpty([
        json['ddaAccountType'],
        json['depositType'],
        json['schemeType'],
      ]),
      holdingPattern: _firstNonEmpty([json['holdingPattern']]),
      openingDate: _firstNonEmpty([
        json['openingDate'],
        json['accountOpenDate'],
        json['valueDate'],
      ]),
      isDefault: defaultAccountRaw == true ||
          defaultAccountRaw?.toString().trim().toLowerCase() == 'true',
      availableBalance: MoneyAmount.readFirst(
        json,
        const [
          'availableBalance',
          'availableBal',
          'clearedBalance',
          'balance',
        ],
        currencyCode,
      ),
      currentBalance: MoneyAmount.readFirst(
        json,
        const ['currentBalance', 'ledgerBalance', 'bookBalance'],
        currencyCode,
      ),
      equivalentAvailableBalance: MoneyAmount.readFirst(
        json,
        const ['equivalentAvailableBalance', 'equivalentCurrentBalance'],
        currencyCode,
      ),
      outstandingBalance: MoneyAmount.readFirst(
        json,
        const [
          'outstandingBalance',
          'outstandingAmount',
          'netOutstandingBalance',
          'totalOutstanding',
        ],
        currencyCode,
      ),
      maturityAmount: MoneyAmount.readFirst(
        json,
        const ['maturityAmount', 'maturityValue'],
        currencyCode,
      ),
      principalAmount: MoneyAmount.readFirst(
        json,
        const [
          'principalAmount',
          'investmentAmount',
          'depositAmount',
          'originalPrincipalAmount',
        ],
        currencyCode,
      ),
    );
  }

  /// Parses `{ "accounts": [ … ] }` (optionally still wrapped in the
  /// `{ statusCode, headers, body }` envelope produced by
  /// `ObdxApiUtils.wrapHttpResponse`).
  static List<CorpAccount> listFromPayload(
    dynamic data, {
    CorpAccountGroup? groupOverride,
  }) {
    final root = rootMap(data);
    if (root == null) return const [];

    final rawList = root['accounts'] ??
        root['accountDTOs'] ??
        root['deposits'] ??
        root['loans'] ??
        root['items'];
    if (rawList is! List) return const [];

    final accounts = <CorpAccount>[];
    for (final item in rawList) {
      if (item is! Map) continue;
      final account = CorpAccount.fromJson(
        Map<String, dynamic>.from(item),
        groupOverride: groupOverride,
      );
      if (account.id.isEmpty && account.displayNumber.isEmpty) continue;
      accounts.add(account);
    }
    return accounts;
  }

  static Map<String, dynamic>? rootMap(dynamic data) => _unwrap(data);

  static Map<String, dynamic>? _unwrap(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map.containsKey('accounts') ||
        map.containsKey('accountDTOs') ||
        map.containsKey('deposits') ||
        map.containsKey('loans') ||
        map.containsKey('summary')) {
      return map;
    }
    final body = map['body'];
    if (body is Map) return _unwrap(body);
    return map;
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
}

/// One entry of `summary.items[]` from the accounts response — the host's
/// own per-product-group roll-up, already converted to the bank's
/// calculation currency (GBP in the captured environment).
class CorpAccountGroupSummary {
  const CorpAccountGroupSummary({
    required this.group,
    required this.count,
    this.typeCode,
    this.partyName,
    this.totalAvailableBalance,
    this.totalActiveAvailableBalance,
    this.totalOutstandingBalance,
    this.totalMaturityAmount,
    this.totalInvestmentAmount,
  });

  final CorpAccountGroup group;
  final String? typeCode;
  final int count;
  final String? partyName;
  final MoneyAmount? totalAvailableBalance;
  final MoneyAmount? totalActiveAvailableBalance;
  final MoneyAmount? totalOutstandingBalance;
  final MoneyAmount? totalMaturityAmount;
  final MoneyAmount? totalInvestmentAmount;

  /// Headline total for this group.
  MoneyAmount? get headlineTotal {
    switch (group) {
      case CorpAccountGroup.loan:
        return totalOutstandingBalance;
      case CorpAccountGroup.deposit:
        return totalInvestmentAmount ??
            totalMaturityAmount ??
            totalActiveAvailableBalance;
      case CorpAccountGroup.casa:
      case CorpAccountGroup.other:
        return totalActiveAvailableBalance ?? totalAvailableBalance;
    }
  }

  factory CorpAccountGroupSummary.fromJson(Map<String, dynamic> json) {
    final typeCode = json['accountType']?.toString().trim();
    final countRaw = json['count'];
    return CorpAccountGroupSummary(
      group: CorpAccountGroup.fromCode(typeCode),
      typeCode: typeCode?.isEmpty == true ? null : typeCode,
      count: countRaw is num
          ? countRaw.toInt()
          : int.tryParse(countRaw?.toString() ?? '') ?? 0,
      partyName: json['partyName']?.toString().trim(),
      totalAvailableBalance: MoneyAmount.readFirst(
        json,
        const ['totalAvailableBalance'],
        '',
      ),
      totalActiveAvailableBalance: MoneyAmount.readFirst(
        json,
        const ['totalActiveAvailableBalance'],
        '',
      ),
      totalOutstandingBalance: MoneyAmount.readFirst(
        json,
        const ['totalActiveOutstandingBalance', 'totalOutstandingBalance'],
        '',
      ),
      totalMaturityAmount: MoneyAmount.readFirst(
        json,
        const ['totalActiveMaturityAmount', 'totalMaturityAmount'],
        '',
      ),
      totalInvestmentAmount: MoneyAmount.readFirst(
        json,
        const ['totalActiveInvestmentAmount', 'totalInvestmentAmount'],
        '',
      ),
    );
  }
}

/// Full `GET /digx-common/account/v1/accounts` result: every account the
/// corporate user can see, plus the host's per-group summary.
class CorpAccountsSummary {
  const CorpAccountsSummary({
    required this.accounts,
    required this.groupSummaries,
  });

  static const empty = CorpAccountsSummary(
    accounts: <CorpAccount>[],
    groupSummaries: <CorpAccountGroupSummary>[],
  );

  final List<CorpAccount> accounts;
  final List<CorpAccountGroupSummary> groupSummaries;

  bool get isEmpty => accounts.isEmpty;

  List<CorpAccount> get casaAccounts => accountsIn(CorpAccountGroup.casa);
  List<CorpAccount> get depositAccounts =>
      accountsIn(CorpAccountGroup.deposit);
  List<CorpAccount> get loanAccounts => accountsIn(CorpAccountGroup.loan);

  List<CorpAccount> accountsIn(CorpAccountGroup group) =>
      accounts.where((account) => account.group == group).toList();

  CorpAccountGroupSummary? summaryFor(CorpAccountGroup group) {
    for (final item in groupSummaries) {
      if (item.group == group) return item;
    }
    return null;
  }

  /// The first party name present on any account — used as the corporate
  /// entity label when the `me/party` call has not resolved yet.
  String? get primaryPartyName {
    for (final account in accounts) {
      final name = account.partyName?.trim();
      if (name != null && name.isNotEmpty) return name;
    }
    for (final item in groupSummaries) {
      final name = item.partyName?.trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }

  /// Distinct product descriptions across [group], for the card's account
  /// type filter dropdown.
  List<String> productNamesIn(CorpAccountGroup group) {
    final names = <String>{};
    for (final account in accountsIn(group)) {
      final label = account.accountTypeLabel;
      if (label.isNotEmpty && label != '—') names.add(label);
    }
    final sorted = names.toList()..sort();
    return sorted;
  }

  /// Per-currency totals of [accounts] in [group], computed client-side.
  /// Never mixes unlike currencies.
  Map<String, double> totalsByCurrency(CorpAccountGroup group) {
    final totals = <String, double>{};
    for (final account in accountsIn(group)) {
      final balance = account.displayBalance;
      if (balance == null) continue;
      final currency = (balance.currency ?? account.currencyCode).trim();
      if (currency.isEmpty) continue;
      totals.update(
        currency,
        (value) => value + balance.amount,
        ifAbsent: () => balance.amount,
      );
    }
    return totals;
  }

  factory CorpAccountsSummary.fromPayload(dynamic data) {
    final accounts = CorpAccount.listFromPayload(data);
    final root = CorpAccount.rootMap(data);
    return CorpAccountsSummary(
      accounts: accounts,
      groupSummaries: _summariesFromRoot(root),
    );
  }

  /// Merges an extra product group (e.g. deposits fetched from
  /// `td/v1/deposit`) into this result without disturbing the rest.
  CorpAccountsSummary mergeGroup(
    CorpAccountGroup group,
    List<CorpAccount> replacement,
  ) {
    final kept = accounts.where((account) => account.group != group);
    return CorpAccountsSummary(
      accounts: [...kept, ...replacement],
      groupSummaries: groupSummaries,
    );
  }

  static List<CorpAccountGroupSummary> _summariesFromRoot(
    Map<String, dynamic>? root,
  ) {
    if (root == null) return const [];
    final summary = root['summary'];
    if (summary is! Map) return const [];
    final items = summary['items'];
    if (items is! List) return const [];

    final parsed = <CorpAccountGroupSummary>[];
    for (final item in items) {
      if (item is! Map) continue;
      parsed.add(
        CorpAccountGroupSummary.fromJson(Map<String, dynamic>.from(item)),
      );
    }
    return parsed;
  }
}
