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

  double get totalBorrowing {
    final currency = primaryCurrency;
    if (currency == null) return 0;
    return borrowingByCurrency[currency] ?? 0;
  }

  double get totalOutstanding {
    final currency = primaryCurrency;
    if (currency == null) return 0;
    return outstandingByCurrency[currency] ?? 0;
  }

  /// Outstanding as a fraction of borrowing (0–1).
  double get outstandingRatio {
    final borrowing = totalBorrowing;
    if (borrowing <= 0) return 0;
    final ratio = totalOutstanding / borrowing;
    if (ratio.isNaN || ratio.isInfinite) return 0;
    return ratio.clamp(0.0, 1.0);
  }

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
      borrowingByCurrency:
          summaryBorrowing.isNotEmpty ? summaryBorrowing : clientBorrowing,
      outstandingByCurrency: summaryOutstanding.isNotEmpty
          ? summaryOutstanding
          : clientOutstanding,
    );
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
