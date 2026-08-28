import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Monetary amount as returned by OBDX (number or `{ amount, currency }`).
class MoneyAmount {
  const MoneyAmount({
    required this.amount,
    this.currency,
  });

  final double amount;
  final String? currency;

  factory MoneyAmount.fromJson(dynamic json, {String? fallbackCurrency}) {
    if (json == null) {
      return MoneyAmount(amount: 0, currency: fallbackCurrency);
    }
    if (json is num) {
      return MoneyAmount(amount: json.toDouble(), currency: fallbackCurrency);
    }
    if (json is String) {
      final parsed = double.tryParse(json.replaceAll(',', '')) ?? 0;
      return MoneyAmount(amount: parsed, currency: fallbackCurrency);
    }
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      final raw = map['amount'] ?? map['value'] ?? map['availableBalance'] ?? 0;
      final amount = raw is num
          ? raw.toDouble()
          : double.tryParse(raw.toString().replaceAll(',', '')) ?? 0;
      final currency = (map['currency'] ??
              map['currencyCode'] ??
              map['currencyId'] ??
              fallbackCurrency)
          ?.toString();
      return MoneyAmount(amount: amount, currency: currency);
    }
    return MoneyAmount(amount: 0, currency: fallbackCurrency);
  }
}

/// CASA demand-deposit account from `GET /digx-common/dda/v1/demandDeposit`.
///
/// Field names follow the Offshore Postman collection (`accounts[]`, `id.value`,
/// `id.displayValue`, `status`, `currencyCode`) plus common OBDX balance shapes.
class CasaAccount {
  const CasaAccount({
    required this.id,
    required this.displayNumber,
    required this.status,
    required this.currencyCode,
    this.accountType,
    this.nickname,
    this.productName,
    this.availableBalance,
    this.currentBalance,
  });

  /// Complex OBDX account id (`id.value`), used for subsequent detail/statement calls.
  final String id;

  /// Maskable display account number (`id.displayValue`).
  final String displayNumber;

  final String status;
  final String currencyCode;
  final String? accountType;
  final String? nickname;
  final String? productName;
  final MoneyAmount? availableBalance;
  final MoneyAmount? currentBalance;

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isDormant => status.toUpperCase() == 'DORMANT';

  /// Preferred balance for dashboard tiles (available, else current).
  MoneyAmount? get displayBalance => availableBalance ?? currentBalance;

  String get title {
    final nick = nickname?.trim();
    if (nick != null && nick.isNotEmpty) return nick;
    final product = productName?.trim();
    if (product != null && product.isNotEmpty) return product;
    final type = accountType?.trim();
    if (type != null && type.isNotEmpty) return type;
    return displayNumber;
  }

  String get maskedNumber {
    final digits = displayNumber.replaceAll(RegExp(r'\s+'), '');
    if (digits.length <= 4) return digits;
    return '${'*' * (digits.length - 4)}${digits.substring(digits.length - 4)}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CasaAccount && other.id == id;

  @override
  int get hashCode => id.hashCode;

  factory CasaAccount.fromJson(Map<String, dynamic> json) {
    final idMap = ObdxApiUtils.asMap(json['id']);
    final id = (idMap['value'] ?? json['accountId'] ?? '').toString().trim();
    final display = (idMap['displayValue'] ??
            json['accountNumber'] ??
            json['displayValue'] ??
            id)
        .toString()
        .trim();

    final currencyCode = (json['currencyCode'] ??
            json['currency'] ??
            ObdxApiUtils.asMap(json['availableBalance'])['currency'] ??
            ObdxApiUtils.asMap(json['availableBalance'])['currencyCode'] ??
            '')
        .toString()
        .trim();

    final product = ObdxApiUtils.asMap(
      json['productDTO'] ?? json['product'] ?? json['productDetails'],
    );
    final productName = (product['description'] ??
            product['name'] ??
            product['displayValue'] ??
            json['productDescription'])
        ?.toString()
        .trim();

    final accountType = (json['accountType'] ??
            json['type'] ??
            ObdxApiUtils.asMap(json['accountTypeDTO'])['code'] ??
            ObdxApiUtils.asMap(json['accountTypeDTO'])['description'])
        ?.toString()
        .trim();

    return CasaAccount(
      id: id,
      displayNumber: display,
      status: (json['status'] ?? '').toString().trim(),
      currencyCode: currencyCode,
      accountType: accountType?.isEmpty == true ? null : accountType,
      nickname: (json['accountNickname'] ?? json['nickname'] ?? json['alias'])
          ?.toString()
          .trim(),
      productName: productName?.isEmpty == true ? null : productName,
      availableBalance: readBalance(
        json,
        const [
          'availableBalance',
          'availableBal',
          'availBalance',
          'clearedBalance',
        ],
        currencyCode,
      ),
      currentBalance: readBalance(
        json,
        const [
          'currentBalance',
          'ledgerBalance',
          'bookBalance',
          'balance',
        ],
        currencyCode,
      ),
    );
  }

  /// Reads the first present monetary field from [keys].
  static MoneyAmount? readBalance(
    Map<String, dynamic> json,
    List<String> keys,
    String currencyCode,
  ) {
    for (final key in keys) {
      if (!json.containsKey(key) || json[key] == null) continue;
      return MoneyAmount.fromJson(json[key], fallbackCurrency: currencyCode);
    }
    return null;
  }

  /// Parses `{ "accounts": [ ... ] }` or wrapped HTTP body maps.
  static List<CasaAccount> listFromPayload(dynamic data) {
    final root = rootMap(data);
    if (root == null) return const [];

    final rawList = root['accounts'] ??
        root['demandDepositAccounts'] ??
        root['accountDTOs'] ??
        root['items'];
    if (rawList is! List) return const [];

    final accounts = <CasaAccount>[];
    for (final item in rawList) {
      if (item is! Map) continue;
      final account = CasaAccount.fromJson(Map<String, dynamic>.from(item));
      if (account.id.isEmpty && account.displayNumber.isEmpty) continue;
      accounts.add(account);
    }
    return accounts;
  }

  /// Unwrapped demandDeposit JSON map (`accounts` / `summary` level).
  static Map<String, dynamic>? rootMap(dynamic data) => _unwrap(data);

  static Map<String, dynamic>? _unwrap(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map.containsKey('accounts') ||
        map.containsKey('demandDepositAccounts') ||
        map.containsKey('accountDTOs') ||
        map.containsKey('summary')) {
      return map;
    }
    final body = map['body'];
    if (body is Map) return _unwrap(body);
    return map;
  }
}

/// Aggregated dashboard totals — never mixes unlike currencies.
class CasaAccountsSummary {
  const CasaAccountsSummary({
    required this.accounts,
    required this.totalsByCurrency,
  });

  final List<CasaAccount> accounts;

  /// Hero totals per ISO currency.
  /// Prefer digx-ui `summary.items[].totalActiveAvailableBalance` when present;
  /// otherwise sum of each account's [CasaAccount.displayBalance].
  final Map<String, double> totalsByCurrency;

  bool get isEmpty => accounts.isEmpty;

  /// Primary currency for hero total: first ACTIVE account currency, else first key.
  String? get primaryCurrency {
    for (final account in accounts) {
      if (account.isActive && account.currencyCode.isNotEmpty) {
        return account.currencyCode;
      }
    }
    if (totalsByCurrency.isNotEmpty) return totalsByCurrency.keys.first;
    for (final account in accounts) {
      if (account.currencyCode.isNotEmpty) return account.currencyCode;
    }
    return null;
  }

  double? get primaryTotal {
    final currency = primaryCurrency;
    if (currency == null) return null;
    return totalsByCurrency[currency];
  }

  bool get hasMultipleCurrencies => totalsByCurrency.length > 1;

  /// Full demandDeposit body: accounts list + optional `summary` (digx-ui).
  factory CasaAccountsSummary.fromPayload(dynamic data) {
    final accounts = CasaAccount.listFromPayload(data);
    final clientTotals = _sumDisplayBalances(accounts);
    final serverTotals = _totalsFromApiSummary(CasaAccount.rootMap(data));
    return CasaAccountsSummary(
      accounts: accounts,
      totalsByCurrency:
          serverTotals.isNotEmpty ? serverTotals : clientTotals,
    );
  }

  factory CasaAccountsSummary.fromAccounts(List<CasaAccount> accounts) {
    return CasaAccountsSummary(
      accounts: accounts,
      totalsByCurrency: _sumDisplayBalances(accounts),
    );
  }

  static Map<String, double> _sumDisplayBalances(List<CasaAccount> accounts) {
    final totals = <String, double>{};
    for (final account in accounts) {
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

  /// digx-ui “Total Net Balance” = `summary.items[].totalActiveAvailableBalance`.
  static Map<String, double> _totalsFromApiSummary(Map<String, dynamic>? root) {
    if (root == null) return const {};
    final summary = root['summary'];
    if (summary is! Map) return const {};
    final items = summary['items'];
    if (items is! List) return const {};

    final totals = <String, double>{};
    for (final item in items) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final raw = map['totalActiveAvailableBalance'] ??
          map['totalAvailableBalance'];
      if (raw == null) continue;
      final money = MoneyAmount.fromJson(raw);
      final currency = (money.currency ?? '').trim();
      if (currency.isEmpty) continue;
      totals.update(
        currency,
        (value) => value + money.amount,
        ifAbsent: () => money.amount,
      );
    }
    return totals;
  }
}
