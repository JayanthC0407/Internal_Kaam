import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/corp_account.dart';
import 'package:ubci_bank/src/core/utils/corp/corp_money_format.dart';
import 'package:ubci_bank/src/core/utils/common/statement_file_saver.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_accounts_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// Which column the Account Summary grid is sorted by.
enum CorpAccountSummaryColumn { partyName, accountNumber, accountType, balance }

/// "Account Summary" grid — the full-width panel at the bottom of the
/// corporate dashboard.
///
/// Rows are every account from the aggregated `account/v1/accounts` load
/// (plus any Deposits / Loans already merged in by the card above), so the
/// grid and the card never disagree. All four columns sort, and the
/// download action exports exactly the rows currently shown.
class CorpAccountSummaryCard extends ConsumerStatefulWidget {
  const CorpAccountSummaryCard({super.key, this.onAccountTap});

  final ValueChanged<CorpAccount>? onAccountTap;

  @override
  ConsumerState<CorpAccountSummaryCard> createState() =>
      _CorpAccountSummaryCardState();
}

class _CorpAccountSummaryCardState
    extends ConsumerState<CorpAccountSummaryCard> {
  /// Minimum width the four columns need before they start to crowd; below
  /// this the grid scrolls horizontally rather than squeezing.
  static const double _minTableWidth = 720;

  CorpAccountSummaryColumn _sortColumn = CorpAccountSummaryColumn.partyName;
  bool _ascending = true;

  void _sortBy(CorpAccountSummaryColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _ascending = !_ascending;
      } else {
        _sortColumn = column;
        _ascending = true;
      }
    });
  }

  List<CorpAccount> _sorted(List<CorpAccount> accounts) {
    final rows = [...accounts];
    rows.sort((a, b) {
      final comparison = switch (_sortColumn) {
        CorpAccountSummaryColumn.partyName =>
          a.partyLabel.toLowerCase().compareTo(b.partyLabel.toLowerCase()),
        CorpAccountSummaryColumn.accountNumber =>
          a.displayNumber.compareTo(b.displayNumber),
        CorpAccountSummaryColumn.accountType => a.accountTypeLabel
            .toLowerCase()
            .compareTo(b.accountTypeLabel.toLowerCase()),
        CorpAccountSummaryColumn.balance => (a.displayBalance?.amount ?? 0)
            .compareTo(b.displayBalance?.amount ?? 0),
      };
      return _ascending ? comparison : -comparison;
    });
    return rows;
  }

  Future<void> _download(List<CorpAccount> rows) async {
    final messenger = ScaffoldMessenger.of(context);
    if (rows.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nothing to export yet.')),
      );
      return;
    }

    final csv = _toCsv(rows);
    final stamp = DateTime.now().toIso8601String().split('T').first;
    try {
      await StatementFileSaver.saveStatement(
        // UTF-8, not `codeUnits` — party names are host-supplied and can
        // carry non-ASCII characters.
        bytes: utf8.encode(csv),
        fileName: 'account_summary_$stamp.csv',
        mimeType: 'text/csv',
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save the account summary.')),
      );
    }
  }

  /// Exports the rows exactly as displayed — masked account numbers
  /// included, so the file never carries a full account number the screen
  /// itself does not show.
  static String _toCsv(List<CorpAccount> rows) {
    String escape(String value) {
      final needsQuotes = value.contains(RegExp(r'[",\n]'));
      final escaped = value.replaceAll('"', '""');
      return needsQuotes ? '"$escaped"' : escaped;
    }

    final buffer = StringBuffer(
      'Party Name,Account Number,Account Type,Currency,Balance\n',
    );
    for (final row in rows) {
      final balance = row.displayBalance;
      buffer.writeln([
        escape(row.partyLabel),
        escape(row.groupedMaskedNumber),
        escape(row.accountTypeLabel),
        escape(balance?.currency ?? row.currencyCode),
        balance == null ? '' : balance.amount.toStringAsFixed(2),
      ].join(','));
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(corpAccountsProvider);
    final rows = _sorted(state.summary.accounts);

    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CorpCardHeader(
            title: 'Account Summary',
            trailing: IconButton(
              tooltip: 'Download account summary (CSV)',
              onPressed: state.isLoading ? null : () => _download(rows),
              icon: Icon(
                Icons.download_rounded,
                size: 22,
                color: CorpColors.textSecondary(context),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildTable(context, state, rows),
        ],
      ),
    );
  }

  Widget _buildTable(
    BuildContext context,
    CorpAccountsState state,
    List<CorpAccount> rows,
  ) {
    if (state.isLoading && rows.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.errorMessage != null && rows.isEmpty) {
      return _SummaryMessage(
        message: state.errorMessage!,
        onRetry: () => ref.read(corpAccountsProvider.notifier).refresh(),
      );
    }

    if (rows.isEmpty) {
      return const _SummaryMessage(
        message: 'No accounts available for this party.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final needsScroll = constraints.maxWidth < _minTableWidth;
        final table = SizedBox(
          width: needsScroll ? _minTableWidth : constraints.maxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderRow(
                sortColumn: _sortColumn,
                ascending: _ascending,
                onSort: _sortBy,
              ),
              Divider(height: 1, color: CorpColors.divider(context)),
              for (final account in rows)
                _AccountRow(
                  account: account,
                  onTap: widget.onAccountTap == null
                      ? null
                      : () => widget.onAccountTap!(account),
                ),
            ],
          ),
        );

        if (!needsScroll) return table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: table,
        );
      },
    );
  }
}

/// Column widths, shared by the header and the data rows so they line up.
const _columnFlex = <int>[3, 3, 3, 2];

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.sortColumn,
    required this.ascending,
    required this.onSort,
  });

  final CorpAccountSummaryColumn sortColumn;
  final bool ascending;
  final ValueChanged<CorpAccountSummaryColumn> onSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CorpColors.tableHeaderBg(context),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          _HeaderCell(
            label: 'Party Name',
            flex: _columnFlex[0],
            column: CorpAccountSummaryColumn.partyName,
            sortColumn: sortColumn,
            ascending: ascending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Account Number',
            flex: _columnFlex[1],
            column: CorpAccountSummaryColumn.accountNumber,
            sortColumn: sortColumn,
            ascending: ascending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Account Type',
            flex: _columnFlex[2],
            column: CorpAccountSummaryColumn.accountType,
            sortColumn: sortColumn,
            ascending: ascending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Balance',
            flex: _columnFlex[3],
            column: CorpAccountSummaryColumn.balance,
            sortColumn: sortColumn,
            ascending: ascending,
            onSort: onSort,
            alignEnd: true,
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    required this.flex,
    required this.column,
    required this.sortColumn,
    required this.ascending,
    required this.onSort,
    this.alignEnd = false,
  });

  final String label;
  final int flex;
  final CorpAccountSummaryColumn column;
  final CorpAccountSummaryColumn sortColumn;
  final bool ascending;
  final ValueChanged<CorpAccountSummaryColumn> onSort;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final isActive = column == sortColumn;
    final children = [
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: CorpColors.textPrimary(context),
          ),
        ),
      ),
      const SizedBox(width: 6),
      _SortIndicator(active: isActive, ascending: ascending),
    ];

    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => onSort(column),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment:
                alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// The paired up/down chevrons from the design — the active direction is
/// highlighted, the other stays muted.
class _SortIndicator extends StatelessWidget {
  const _SortIndicator({required this.active, required this.ascending});

  final bool active;
  final bool ascending;

  @override
  Widget build(BuildContext context) {
    final on = CorpColors.textPrimary(context);
    final off = CorpColors.navInactive(context).withValues(alpha: 0.55);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: const Offset(0, 2),
          child: Icon(
            Icons.keyboard_arrow_up_rounded,
            size: 13,
            color: active && ascending ? on : off,
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -2),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 13,
            color: active && !ascending ? on : off,
          ),
        ),
      ],
    );
  }
}

class _AccountRow extends StatefulWidget {
  const _AccountRow({required this.account, this.onTap});

  final CorpAccount account;
  final VoidCallback? onTap;

  @override
  State<_AccountRow> createState() => _AccountRowState();
}

class _AccountRowState extends State<_AccountRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final balance = account.displayBalance;
    final balanceText = CorpMoneyFormat.formatAmount(
      balance,
      fallbackCurrency: account.currencyCode,
    );
    final balanceColor = balance == null
        ? CorpColors.textSecondary(context)
        : balance.isNegative
            ? CorpColors.negativeBalance(context)
            : CorpColors.positiveBalance(context);

    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: account.groupedMaskedNumber));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account number copied')),
          );
        },
        child: Container(
          color: _hovered && widget.onTap != null
              ? CorpColors.tableRowHover(context)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
          child: Row(
            children: [
              Expanded(
                flex: _columnFlex[0],
                child: Text(
                  account.partyLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: CorpColors.textPrimary(context),
                  ),
                ),
              ),
              Expanded(
                flex: _columnFlex[1],
                child: Text(
                  account.groupedMaskedNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    letterSpacing: 0.4,
                    color: CorpColors.textSecondary(context),
                  ),
                ),
              ),
              Expanded(
                flex: _columnFlex[2],
                child: Text(
                  account.accountTypeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: CorpColors.textSecondary(context),
                  ),
                ),
              ),
              Expanded(
                flex: _columnFlex[3],
                child: Text(
                  balanceText,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: balanceColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryMessage extends StatelessWidget {
  const _SummaryMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.table_rows_outlined,
              size: 28,
              color: CorpColors.navInactive(context),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: CorpColors.textSecondary(context),
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 10),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
