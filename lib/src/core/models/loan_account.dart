import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Single loan from `GET /digx-common/loan/v1/loan`.
class LoanAccount {
  const LoanAccount({
    required this.id,
    required this.displayNumber,
    required this.currencyCode,
    this.productName,
    this.nickname,
    this.status,
    this.holderName,
    this.sanctionedAmount,
    this.outstandingAmount,
    this.module,
  });

  final String id;
  final String displayNumber;
  final String currencyCode;
  final String? productName;
  final String? nickname;
  final String? status;

  /// Primary account holder's name, when the list endpoint includes one
  /// (best-effort — many OBDX hosts only return this on the detail call).
  final String? holderName;
  final MoneyAmount? sanctionedAmount;
  final MoneyAmount? outstandingAmount;

  /// OBDX loan module (`CON` conventional / `ISL` Islamic) — required by the
  /// detail, schedule, outstanding and disbursement endpoints.
  final String? module;

  /// Preferred label for list tiles.
  String get title {
    final nick = nickname?.trim();
    if (nick != null && nick.isNotEmpty) return nick;
    final product = productName?.trim();
    if (product != null && product.isNotEmpty) return product;
    return displayNumber;
  }

  factory LoanAccount.fromJson(Map<String, dynamic> json) {
    final idMap = ObdxApiUtils.asMap(json['id']);
    final id = (idMap['value'] ??
            json['loanAccountId'] ??
            json['accountId'] ??
            json['loanId'] ??
            '')
        .toString()
        .trim();
    final display = (idMap['displayValue'] ??
            json['accountNumber'] ??
            json['displayValue'] ??
            id)
        .toString()
        .trim();

    final currencyCode = (json['currencyCode'] ??
            json['currency'] ??
            ObdxApiUtils.asMap(json['outstandingAmount'])['currency'] ??
            ObdxApiUtils.asMap(json['sanctionedAmount'])['currency'] ??
            '')
        .toString()
        .trim();

    final product = ObdxApiUtils.asMap(
      json['productDTO'] ?? json['product'] ?? json['productDetails'],
    );

    return LoanAccount(
      id: id,
      displayNumber: display,
      currencyCode: currencyCode,
      productName: _firstNonEmpty([
        product['description'],
        product['name'],
        product['displayValue'],
        json['productDescription'],
        json['productName'],
      ]),
      nickname: _firstNonEmpty([
        json['accountNickname'],
        json['nickname'],
        json['alias'],
      ]),
      status: _firstNonEmpty([json['status'], json['accountStatus']]),
      holderName: _firstNonEmpty([
        json['accountHolderName'],
        json['customerName'],
        json['primaryHolderName'],
        json['partyName'],
        json['holderName'],
      ]),
      module: _firstNonEmpty([json['module']]),
      sanctionedAmount: CasaAccount.readBalance(
        json,
        const [
          'sanctionedAmount',
          'sanctionedLoanAmount',
          'loanAmount',
          'amountFinanced',
          'principalAmount',
          'approvedAmount',
          'borrowingAmount',
          'totalBorrowing',
        ],
        currencyCode,
      ),
      outstandingAmount: CasaAccount.readBalance(
        json,
        const [
          'outstandingAmount',
          'outstandingBalance',
          'netOutstanding',
          'netOutstandingBalance',
          'currentOutstanding',
          'totalOutstanding',
          'outstandingPrincipal',
          'osbal',
        ],
        currencyCode,
      ),
    );
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

/// Aggregated loan tracker totals for the dashboard card.
///
/// Totals are computed per currency and never mixed. Prefer API summary when
/// present; otherwise sum each loan's sanctioned / outstanding amounts.
class LoanAccountsSummary {
  const LoanAccountsSummary({
    required this.loans,
    required this.borrowingByCurrency,
    required this.outstandingByCurrency,
  });

  final List<LoanAccount> loans;
  final Map<String, double> borrowingByCurrency;
  final Map<String, double> outstandingByCurrency;

  bool get isEmpty => loans.isEmpty && borrowingByCurrency.isEmpty;

  /// Every currency that appears across the loans and/or the aggregated
  /// totals, sorted alphabetically so tab order is stable across refreshes.
  List<String> get currencies {
    final set = <String>{};
    for (final loan in loans) {
      final code = loan.currencyCode.trim();
      if (code.isNotEmpty) set.add(code);
    }
    set.addAll(borrowingByCurrency.keys);
    set.addAll(outstandingByCurrency.keys);
    final list = set.toList()..sort();
    return list;
  }

  /// True when the customer holds loans in more than one currency — totals
  /// can no longer be shown as a single number and need a currency tab/
  /// selector instead.
  bool get isMultiCurrency => currencies.length > 1;

  String? get primaryCurrency {
    for (final loan in loans) {
      if (loan.currencyCode.isNotEmpty) return loan.currencyCode;
    }
    if (borrowingByCurrency.isNotEmpty) return borrowingByCurrency.keys.first;
    if (outstandingByCurrency.isNotEmpty) {
      return outstandingByCurrency.keys.first;
    }
    return null;
  }

  double get totalBorrowing => totalBorrowingFor(primaryCurrency);

  double get totalOutstanding => totalOutstandingFor(primaryCurrency);

  /// Total borrowing for a single currency only — never mixes currencies.
  double totalBorrowingFor(String? currency) {
    if (currency == null) return 0;
    return borrowingByCurrency[currency] ?? 0;
  }

  /// Total outstanding for a single currency only — never mixes currencies.
  double totalOutstandingFor(String? currency) {
    if (currency == null) return 0;
    return outstandingByCurrency[currency] ?? 0;
  }

  /// Only the loans denominated in [currency].
  List<LoanAccount> loansFor(String? currency) {
    if (currency == null) return loans;
    return loans.where((loan) => loan.currencyCode.trim() == currency).toList();
  }

  /// Outstanding as a fraction of borrowing (0–1) for a single currency.
  double outstandingRatioFor(String? currency) {
    final borrowing = totalBorrowingFor(currency);
    if (borrowing <= 0) return 0;
    final ratio = totalOutstandingFor(currency) / borrowing;
    if (ratio.isNaN || ratio.isInfinite) return 0;
    return ratio.clamp(0.0, 1.0);
  }

  int outstandingPercentFor(String? currency) =>
      (outstandingRatioFor(currency) * 100).round();

  /// Outstanding as a fraction of borrowing (0–1).
  double get outstandingRatio => outstandingRatioFor(primaryCurrency);

  int get outstandingPercent => (outstandingRatio * 100).round();

  factory LoanAccountsSummary.fromPayload(dynamic data) {
    final root = _unwrap(data) ?? {};
    final loans = _parseLoans(root);
    final clientBorrowing = <String, double>{};
    final clientOutstanding = <String, double>{};

    for (final loan in loans) {
      final currency = loan.currencyCode.trim();
      if (currency.isEmpty) continue;
      final sanctioned = loan.sanctionedAmount;
      if (sanctioned != null) {
        clientBorrowing.update(
          currency,
          (v) => v + sanctioned.amount,
          ifAbsent: () => sanctioned.amount,
        );
      }
      final outstanding = loan.outstandingAmount;
      if (outstanding != null) {
        clientOutstanding.update(
          currency,
          (v) => v + outstanding.amount,
          ifAbsent: () => outstanding.amount,
        );
      }
    }

    final summaryBorrowing = _totalsFromSummary(
      root,
      const [
        'totalBorrowing',
        'totalSanctionedAmount',
        'totalLoanAmount',
        'totalAmountFinanced',
      ],
    );
    final summaryOutstanding = _totalsFromSummary(
      root,
      const [
        'totalOutstanding',
        'totalOutstandingAmount',
        'totalOutstandingBalance',
        'netOutstanding',
      ],
    );

    return LoanAccountsSummary(
      loans: loans,
      // Merge, don't replace: some OBDX hosts only return `summary.total*`
      // for one currency (often just the customer's primary/base currency)
      // even when the loan list itself spans several currencies. Starting
      // from the per-loan client sums guarantees every currency present in
      // `loans` gets a total; overlaying the API summary on top keeps its
      // numbers authoritative wherever it *does* report a currency (it may
      // include fees/accruals a raw sum of loan amounts wouldn't).
      borrowingByCurrency: _mergeTotals(clientBorrowing, summaryBorrowing),
      outstandingByCurrency: _mergeTotals(clientOutstanding, summaryOutstanding),
    );
  }

  /// Combines client-computed per-loan totals with the API's own summary
  /// totals, keyed by currency. The summary's value wins for any currency it
  /// reports; the client sum fills in any currency the summary is silent on
  /// (this is what previously made e.g. AED show as 0 outstanding whenever
  /// the summary block only covered a single other currency).
  static Map<String, double> _mergeTotals(
    Map<String, double> clientTotals,
    Map<String, double> summaryTotals,
  ) {
    return {...clientTotals, ...summaryTotals};
  }

  static List<LoanAccount> _parseLoans(Map<String, dynamic> root) {
    final rawList = root['loans'] ??
        root['loanAccounts'] ??
        root['loanAccountDTOs'] ??
        root['accounts'] ??
        root['items'];
    if (rawList is! List) return const [];

    final loans = <LoanAccount>[];
    for (final item in rawList) {
      if (item is! Map) continue;
      final loan = LoanAccount.fromJson(Map<String, dynamic>.from(item));
      if (loan.id.isEmpty && loan.displayNumber.isEmpty) continue;
      loans.add(loan);
    }
    return loans;
  }

  static Map<String, double> _totalsFromSummary(
    Map<String, dynamic> root,
    List<String> keys,
  ) {
    final summary = ObdxApiUtils.asMap(root['summary']);
    final sources = <Map<String, dynamic>>[root, summary];
    final items = summary['items'];
    if (items is List) {
      for (final item in items) {
        if (item is Map) sources.add(Map<String, dynamic>.from(item));
      }
    }

    final totals = <String, double>{};
    for (final source in sources) {
      for (final key in keys) {
        if (!source.containsKey(key) || source[key] == null) continue;
        final money = MoneyAmount.fromJson(source[key]);
        final currency = (money.currency ?? '').trim();
        if (currency.isEmpty) continue;
        totals.update(
          currency,
          (v) => v + money.amount,
          ifAbsent: () => money.amount,
        );
      }
    }
    return totals;
  }

  static Map<String, dynamic>? _unwrap(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    for (final key in const [
      'loanDTO',
      'loanAccountDTO',
      'loanAccountsDTO',
      'body',
    ]) {
      final nested = map[key];
      if (nested is Map) {
        final unwrapped = _unwrap(nested);
        if (unwrapped != null) return unwrapped;
      }
    }
    if (map.containsKey('loans') ||
        map.containsKey('loanAccounts') ||
        map.containsKey('loanAccountDTOs') ||
        map.containsKey('accounts') ||
        map.containsKey('summary') ||
        map.containsKey('items')) {
      return map;
    }
    final body = map['body'];
    if (body is Map) return _unwrap(body);
    return map;
  }
}