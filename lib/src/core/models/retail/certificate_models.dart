import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// OBDX Certificates — Interest, Balance and TDS (Accounts → Certificates).
/// Evidence for every request and rule: docs/obdx/features/certificates.md.

/// Interest Certificates' Account Category, from the user's roles
/// (interest-certificate-all/hooks.js:639-673): its account list, its
/// task code and the label OBDX shows.
enum CertificateCategory {
  /// "Current & Savings": `dda demandDeposit?taskCode=CH_I_IC`.
  casa('CH_I_IC'),

  /// "Deposits": `td deposit?module=CON&module=ISL&taskCode=TD_I_IC`.
  deposits('TD_I_IC'),

  /// "Loans & Finances": `loan loan?taskCode=LN_I_IC`.
  loans('LN_I_IC');

  const CertificateCategory(this.taskCode);

  final String taskCode;

  /// OBDX's roles → categories: `CASARole`, the first of `TDRole`/`RDRole`,
  /// `LoanRole` (case as sent). The screen sorts them by label.
  static List<CertificateCategory> fromRoles(Iterable<String> roles) {
    final set = roles.map((r) => r.toUpperCase()).toSet();
    return [
      if (set.contains('CASAROLE')) casa,
      if (set.contains('TDROLE') || set.contains('RDROLE')) deposits,
      if (set.contains('LOANROLE')) loans,
    ];
  }
}

/// An account in the certificate's account list.
class CertificateAccount {
  const CertificateAccount({required this.id, required this.display, this.module, this.isDefault = false});

  /// `id.value`.
  final String id;

  /// `id.displayValue` (masked).
  final String display;

  /// A deposit's `module` (CON / ISL) — OBDX sends it with TD single
  /// (`deposit/{id}/paidInterest?module=`).
  final String? module;
  final bool isDefault;

  static List<CertificateAccount> listFromPayload(Map<String, dynamic> body) {
    final raw = body['accounts'] ?? body['loans'] ?? body['loanAccounts'] ?? body['loanAccountDTOs'];
    if (raw is! List) return const [];
    return [
      for (final r in raw)
        if (r is Map)
          if (_id(ObdxApiUtils.asMap(r)['id']) case final id?)
            CertificateAccount(
              id: id.$1,
              display: id.$2,
              module: _str(ObdxApiUtils.asMap(r)['module']),
              isDefault: '${ObdxApiUtils.asMap(r)['defaultAccount']}'.toLowerCase() == 'true',
            ),
    ];
  }

  /// OBDX's account-input starts on the default account, else the first.
  static CertificateAccount? initial(List<CertificateAccount> list) =>
      list.where((a) => a.isDefault).firstOrNull ?? list.firstOrNull;
}

/// A financial year (April–March), by its start year.
class FinancialYear {
  const FinancialYear(this.startYear);

  final int startYear;

  /// "{from}-{to}", as OBDX labels it.
  String get label => '$startYear-${startYear + 1}';

  /// The three OBDX offers, oldest first (interest-certificate-all/
  /// hooks.js:700-730): from a branch date in January–March the three
  /// years before the current FY's start, else the last two and the current.
  static List<FinancialYear> list(DateTime branchDate) {
    final current = branchDate.month <= 3 ? branchDate.year - 1 : branchDate.year;
    return [for (var y = current - 2; y <= current; y++) FinancialYear(y)];
  }

  /// `fromDate` / `toDate` for this year: 1 April .. 31 March; for the
  /// current FY the end is today (OBDX sends it unpadded, e.g. `2026-1-5`;
  /// the app pads it like every other date).
  (String, String) range(DateTime branchDate) {
    final from = DateTime(startYear, 4, 1);
    final end = DateTime(startYear + 1, 3, 31);
    final to = branchDate.isBefore(end) ? branchDate : end;
    return (certificateDate(from), certificateDate(to));
  }

  @override
  bool operator ==(Object other) => other is FinancialYear && other.startYear == startYear;

  @override
  int get hashCode => startYear.hashCode;
}

/// `YYYY-MM-DD`, the format OBDX's date inputs give (Duration).
String certificateDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The earliest From Date for Duration: 1 April of the oldest offered FY
/// (hooks.js:702, 717).
DateTime certificateEarliestDate(DateTime branchDate) => DateTime(FinancialYear.list(branchDate).first.startYear, 4, 1);

/// Balance Certificates' months: the current month and the five before
/// it (balance-certificate/hooks.js:226-268). OBDX's `setMonth(m-1)` skips
/// months from the 29th to the 31st; the app always gives six.
List<DateTime> balanceCertificateMonths(DateTime branchDate) =>
    [for (var i = 0; i < 6; i++) DateTime(branchDate.year, branchDate.month - i)];

/// One Interest Certificates row (any category).
class InterestRow {
  const InterestRow({required this.account, this.productName, this.date, this.amount});

  final String account;
  final String? productName;
  final DateTime? date;
  final MoneyAmount? amount;

  static InterestRow? fromJson(Map<String, dynamic> m) {
    final account = _id(m['accountId'])?.$2 ?? _str(m['accountId']);
    if (account == null) return null;
    return InterestRow(
      account: account,
      productName: _str(m['productName']),
      date: DateTime.tryParse(_str(m['date']) ?? ''),
      amount: m['interestAmount'] == null ? null : MoneyAmount.fromJson(m['interestAmount']),
    );
  }

  /// Every row the six responses can carry (hooks.js:164-364): a single
  /// account's `…InterestListResponseDTO.{demandDepositInterestList |
  /// accountInterestDTO | accountInterests}[]`, or the All variants' lists
  /// of those.
  static List<InterestRow> listFromPayload(Map<String, dynamic> body) {
    const lists = ['demandDepositInterestList', 'accountInterestDTO', 'accountInterests'];
    const singles = [
      'demandDepositInterestListResponseDTO',
      'loanAccountInterestListResponseDTO',
      'termDepositInterestListResponseDTO',
    ];
    const alls = ['demandDepositInterestList', 'loanAccountInterestResponseDTOs', 'termDepositInterestResponseDTOs'];
    final rows = <InterestRow>[];
    void fromSingle(Map<String, dynamic> dto) {
      for (final key in lists) {
        final items = dto[key];
        if (items is List) {
          for (final i in items) {
            if (i is Map) {
              if (InterestRow.fromJson(ObdxApiUtils.asMap(i)) case final row?) rows.add(row);
            }
          }
        }
      }
    }

    for (final key in singles) {
      if (body[key] is Map) fromSingle(ObdxApiUtils.asMap(body[key]));
    }
    for (final key in alls) {
      final items = body[key];
      if (items is! List) continue;
      for (final i in items) {
        if (i is! Map) continue;
        final m = ObdxApiUtils.asMap(i);
        for (final s in singles) {
          if (m[s] is Map) fromSingle(ObdxApiUtils.asMap(m[s]));
        }
      }
    }
    return rows;
  }
}

/// Balance Certificates: `demandDeposits[]` and `termDeposits[]`
/// (balance-certificate/hooks.js:65-84).
class BalanceCertificate {
  const BalanceCertificate({this.casa = const [], this.deposits = const []});

  final List<BalanceRow> casa;
  final List<BalanceRow> deposits;

  static BalanceCertificate fromPayload(Map<String, dynamic> body) {
    List<BalanceRow> rows(dynamic raw) => [
          if (raw is List)
            for (final r in raw)
              if (r is Map) BalanceRow.fromJson(ObdxApiUtils.asMap(r)),
        ];
    return BalanceCertificate(casa: rows(body['demandDeposits']), deposits: rows(body['termDeposits']));
  }
}

class BalanceRow {
  const BalanceRow({required this.account, this.depositNumber, this.balance, this.productName});

  final String account;

  /// `depostiNumber` (sic); OBDX shows 1 when absent.
  final String? depositNumber;
  final MoneyAmount? balance;

  /// The design's Product Type, shown only when the response carries one
  /// (OBDX reads none) [UNKNOWN until a UAT capture].
  final String? productName;

  static BalanceRow fromJson(Map<String, dynamic> m) => BalanceRow(
        account: _id(m['account'])?.$2 ?? _str(m['account']) ?? '',
        depositNumber: _str(m['depostiNumber'] ?? m['depositNumber']) ?? '1',
        balance: m['balance'] == null ? null : MoneyAmount.fromJson(m['balance']),
        productName: _str(m['productName'] ?? m['productDescription']),
      );
}

/// TDS Certificates (tax-deduction-at-source/hooks.js:74-100): entries
/// with both totals; account and waiver from `depositTaxPaidDTOs[0]`.
class TdsRow {
  const TdsRow({required this.account, this.interest, this.tax, this.waiverApplied});

  final String account;
  final MoneyAmount? interest;
  final MoneyAmount? tax;

  /// OBDX: false → "-", anything else → "Y".
  final bool? waiverApplied;

  String get waiverLabel => waiverApplied == false ? '-' : 'Y';

  static List<TdsRow> listFromPayload(Map<String, dynamic> body) {
    final raw = body['depositTaxPaidListResponseDTO'];
    if (raw is! List) return const [];
    return [
      for (final r in raw)
        if (r is Map)
          if (ObdxApiUtils.asMap(r) case final m when m['totalInterest'] != null && m['totalTaxPaid'] != null)
            () {
              final dtos = m['depositTaxPaidDTOs'];
              final first = dtos is List && dtos.isNotEmpty ? ObdxApiUtils.asMap(dtos.first) : const <String, dynamic>{};
              final waiver = first['waiverApplied'];
              return TdsRow(
                account: _id(first['accountId'])?.$2 ?? '',
                interest: MoneyAmount.fromJson(m['totalInterest']),
                tax: MoneyAmount.fromJson(m['totalTaxPaid']),
                waiverApplied: waiver == null ? null : '$waiver'.toLowerCase() == 'true',
              );
            }(),
    ];
  }

  /// "TDS For Financial Year {year} was {amount}": the tax summed per
  /// currency (OBDX sums them all and keeps the last currency).
  static Map<String, double> taxByCurrency(List<TdsRow> rows) {
    final out = <String, double>{};
    for (final r in rows) {
      final t = r.tax;
      if (t == null) continue;
      out.update(t.currency ?? '', (v) => v + t.amount, ifAbsent: () => t.amount);
    }
    return out;
  }
}

String? _str(dynamic value) {
  if (value == null || value is Map || value is List) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

(String, String)? _id(dynamic json) {
  if (json is! Map) return null;
  final map = ObdxApiUtils.asMap(json);
  final value = _str(map['value']);
  if (value == null) return null;
  return (value, _str(map['displayValue']) ?? value);
}
