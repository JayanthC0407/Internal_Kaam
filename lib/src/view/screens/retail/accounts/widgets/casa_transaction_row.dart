import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/retail/casa_transaction.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Transactions split into month sections ("July, 2026"), in the order
/// OBDX returns them. Rows without a date go into a final group with no
/// heading.
List<({String? heading, List<CasaTransaction> items})> groupCasaTransactionsByMonth(
  List<CasaTransaction> transactions,
) {
  final groups = <({String? heading, List<CasaTransaction> items})>[];
  final undated = <CasaTransaction>[];
  String? currentKey;
  for (final tx in transactions) {
    final date = tx.dateTime?.toLocal();
    if (date == null) {
      undated.add(tx);
      continue;
    }
    final key = '${_monthNames[date.month - 1]}, ${date.year}';
    if (key != currentKey) {
      groups.add((heading: key, items: <CasaTransaction>[]));
      currentKey = key;
    }
    groups.last.items.add(tx);
  }
  if (undated.isNotEmpty) groups.add((heading: null, items: undated));
  return groups;
}

/// One row of the mobile Transactions list (designer mock): direction
/// icon, description, date / reference, signed amount and the OBDX
/// Transaction Type (Credit / Debit) under it.
class CasaTransactionRow extends StatelessWidget {
  const CasaTransactionRow({
    super.key,
    required this.transaction,
    this.compact = false,
  });

  final CasaTransaction transaction;

  /// Home design: one date line, the signed amount in green / red, no
  /// reference or Credit / Debit label.
  final bool compact;

  static const _creditBg = Color(0xFFECFDF3);
  static const _creditFg = Color(0xFF079455);
  static const _debitBg = Color(0xFFFEF3F2);
  static const _debitFg = Color(0xFFD92D20);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final isCredit = transaction.isCredit;
    final accent = isCredit ? _creditFg : _debitFg;
    final amount = MoneyFormat.format(
      transaction.amount.amount,
      currencyCode: (transaction.amount.currency ?? '').trim(),
    );
    final reference = transaction.reference?.trim() ?? '';
    final date = _dateLabel(transaction.dateTime);
    final details = [
      if (date != null) date,
      if (reference.isNotEmpty && !compact) l10n.casaTransactionRef(reference),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCredit ? _creditBg : _debitBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 20,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: colors.textPrimary,
                  ),
                ),
                // Date (and time) on one line, OBDX Reference Number under it.
                for (final line in details) ...[
                  const SizedBox(height: 3),
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Big amounts, narrow phones or large system text: the amount
          // never takes more than 45% of the row — it shrinks instead of
          // overflowing.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.45),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${isCredit ? '+' : '-'} $amount',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: compact ? accent : colors.textPrimary,
                    ),
                  ),
                ),
                if (!compact) const SizedBox(height: 3),
                if (!compact) Text(
                  isCredit ? l10n.casaTxnTypeCredit : l10n.casaTxnTypeDebit,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  /// "26 Jul 2026", plus the time when OBDX sends one (value dates come
  /// back as midnight, so a 12:00 AM time is left out).
  static String? _dateLabel(DateTime? date) {
    if (date == null) return null;
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final label =
        '$day ${_monthNames[local.month - 1].substring(0, 3)} ${local.year}';
    if (local.hour == 0 && local.minute == 0) return label;
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$label  •  $hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }
}

/// The month-grouped rows every Transactions list uses (Transactions,
/// Account Details, Loan Transactions, Term Deposit, Home). Home passes
/// `showHeadings: false` for its short recent list.
class CasaTransactionGroupList extends StatelessWidget {
  const CasaTransactionGroupList({
    super.key,
    required this.transactions,
    this.showHeadings = true,
    this.compact = false,
  });

  final List<CasaTransaction> transactions;
  final bool showHeadings;

  /// Compact rows (Home design) — see [CasaTransactionRow.compact].
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final groups = showHeadings
        ? groupCasaTransactionsByMonth(transactions)
        : [(heading: null, items: transactions)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups) ...[
          if (group.heading != null)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 2),
              child: Text(
                group.heading!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ),
          for (var i = 0; i < group.items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: colors.divider),
            CasaTransactionRow(transaction: group.items[i], compact: compact),
          ],
        ],
      ],
    );
  }
}
