import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/models/casa_transaction.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';

class CasaTransactionsTable extends StatelessWidget {
  const CasaTransactionsTable({super.key, required this.transactions});

  final List<CasaTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: colors.textSecondary,
    );
    final cellStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: colors.textPrimary,
      height: 1.35,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.sizeOf(context).width - 56,
          ),
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 56,
            headingRowColor: const WidgetStatePropertyAll(Colors.white),
            dividerThickness: 0.6,
            headingTextStyle: headerStyle,
            dataTextStyle: cellStyle,
            columns: [
              DataColumn(label: Text(l10n.casaColTxnDate)),
              DataColumn(label: Text(l10n.casaColDescription)),
              DataColumn(label: Text(l10n.casaColReference)),
              DataColumn(label: Text(l10n.casaColType)),
              DataColumn(label: Text(l10n.casaColAmount), numeric: true),
              DataColumn(label: Text(l10n.casaColBalance), numeric: true),
            ],
            rows: [
              for (final txn in transactions)
                DataRow(
                  cells: [
                    DataCell(
                      Text(_formatDate(txn.transactionDate ?? txn.dateTime)),
                    ),
                    DataCell(
                      SizedBox(
                        width: 180,
                        child: Text(
                          txn.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 140,
                        child: Text(
                          txn.reference ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        txn.isCredit
                            ? l10n.casaTxnTypeCredit
                            : l10n.casaTxnTypeDebit,
                      ),
                    ),
                    DataCell(Text(_money(txn.amount))),
                    DataCell(
                      Text(
                        txn.runningBalance == null
                            ? '—'
                            : _money(txn.runningBalance!),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _money(MoneyAmount amount) {
    return MoneyFormat.format(
      amount.amount,
      currencyCode: amount.currency ?? '',
    );
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = (local.year % 100).toString().padLeft(2, '0');
    return '$day/$month/$year';
  }
}
