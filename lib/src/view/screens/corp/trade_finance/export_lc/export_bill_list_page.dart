import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/export_bill.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/export_lc_search.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/core/utils/common/statement_file_saver.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_export_bill_providers.dart';
import 'package:ubci_bank/src/view/routes/corp/corp_routes_const.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/export_lc/export_bill_filter_panel.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// Opens one export bill.
void openExportBill(BuildContext context, CorpExportBill bill) {
  Navigator.of(context).pushNamed(
    CorpRoutesConst.exportBillDetailScreen,
    arguments: ExportBillArgs(billId: bill.id),
  );
}

/// View Export Bill — search and results (manual ch. 14, steps 1–5): the
/// bills presented under the user's export LCs.
class ExportBillListPage extends ConsumerStatefulWidget {
  const ExportBillListPage({super.key});

  static const double tableFrom = 760;

  @override
  ConsumerState<ExportBillListPage> createState() => _ExportBillListPageState();
}

class _ExportBillListPageState extends ConsumerState<ExportBillListPage> {
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(corpExportBillSearchProvider.notifier).ensureLoaded();
    });
  }

  ExportBillSearchNotifier get _notifier =>
      ref.read(corpExportBillSearchProvider.notifier);

  Future<void> _openFilters(ExportBillSearch current) async {
    final picked = await ExportBillFilterPanel.show(context, current);
    if (picked != null && mounted) _notifier.search(picked);
  }

  Future<void> _download(TfListFormat format) async {
    setState(() => _downloading = true);
    final result = await _notifier.download(format);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (result.bytes != null) {
      try {
        final box = context.findRenderObject() as RenderBox?;
        await StatementFileSaver.saveStatement(
          bytes: result.bytes!,
          fileName: result.fileName,
          mimeType: format.media,
          sharePositionOrigin: box != null && box.hasSize
              ? box.localToGlobal(Offset.zero) & box.size
              : null,
        );
        messenger.showSnackBar(
          SnackBar(content: Text('Downloaded ${result.fileName}')),
        );
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not save the file.')),
        );
      }
    } else {
      messenger.showSnackBar(SnackBar(content: Text(result.error!)));
    }
    if (mounted) setState(() => _downloading = false);
  }

  String _filterLabel(ExportBillSearch c, ExportBillFilter f) {
    String n(double v) => v == v.truncateToDouble() ? '${v.toInt()}' : '$v';
    String range(String name, String? from, String? to) {
      if (from != null && to != null) return '$name $from–$to';
      if (from != null) return '$name from $from';
      return '$name to $to';
    }

    return switch (f) {
      ExportBillFilter.billNumber => 'Bill ${c.billNumber!.trim()}',
      ExportBillFilter.importer => 'Importer: ${c.importerName!.trim()}',
      ExportBillFilter.status => 'Status: ${c.status!.label}',
      ExportBillFilter.currency => c.currency!.trim(),
      ExportBillFilter.amount => range(
          'Amount',
          c.fromAmount == null ? null : n(c.fromAmount!),
          c.toAmount == null ? null : n(c.toAmount!),
        ),
      ExportBillFilter.billDate => range(
          'Bill date',
          c.dateFrom == null ? null : TfDate.display(c.dateFrom),
          c.dateTo == null ? null : TfDate.display(c.dateTo),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(corpExportBillSearchProvider);
    final criteria = state.criteria;
    final count = criteria.activeCount;

    return CorpCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CorpCardHeader(
            title: state.loaded
                ? '${state.items.length} export bill'
                    '${state.items.length == 1 ? '' : 's'}'
                : 'Export bills',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  backgroundColor: CorpColors.brand(context),
                  child: IconButton(
                    tooltip: 'Search & filter',
                    icon: const Icon(Icons.tune_rounded),
                    color: CorpColors.textSecondary(context),
                    onPressed: () => _openFilters(criteria),
                  ),
                ),
                PopupMenuButton<TfListFormat>(
                  tooltip: 'Download list',
                  enabled: !_downloading && state.items.isNotEmpty,
                  onSelected: _download,
                  itemBuilder: (_) => [
                    for (final f in TfListFormat.values)
                      PopupMenuItem(
                        value: f,
                        child: Text('Download as ${f.label}'),
                      ),
                  ],
                  icon: _downloading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.download_rounded,
                          color: CorpColors.textSecondary(context),
                        ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded),
                  color: CorpColors.textSecondary(context),
                  onPressed: _notifier.refresh,
                ),
              ],
            ),
          ),
          if (count > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final f in criteria.activeFilters)
                  InputChip(
                    label: Text(
                      _filterLabel(criteria, f),
                      style: const TextStyle(fontSize: 12),
                    ),
                    onDeleted: () => _notifier.search(criteria.without(f)),
                    deleteButtonTooltipMessage: 'Remove filter',
                    visualDensity: VisualDensity.compact,
                  ),
                TextButton(
                  onPressed: () => _notifier.search(ExportBillSearch.none),
                  child: const Text('Clear all'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (state.errorMessage != null)
            LcMessageBanner(message: state.errorMessage!),
          if (state.isLoading && state.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.items.isEmpty && state.errorMessage == null)
            LcEmptyState(
              icon: Icons.receipt_long_outlined,
              title: count > 0
                  ? 'No export bills match these filters'
                  : 'No export bills',
              message: count > 0
                  ? null
                  : 'Bills you present under your export LCs appear here.',
            )
          else ...[
            if (state.isLoading) const LinearProgressIndicator(minHeight: 2),
            LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth >= ExportBillListPage.tableFrom
                      ? _BillsTable(bills: state.items)
                      : ExportBillCards(bills: state.items),
            ),
          ],
        ],
      ),
    );
  }
}

class _BillsTable extends StatelessWidget {
  const _BillsTable({required this.bills});

  final List<CorpExportBill> bills;

  static const _columns = <(String, double, Alignment)>[
    ('Bill reference number', 1.6, Alignment.centerLeft),
    ('Importer name', 1.6, Alignment.centerLeft),
    ('Release against', 1.5, Alignment.centerLeft),
    ('Transaction date', 1.2, Alignment.centerLeft),
    ('Bill amount', 1.3, Alignment.centerRight),
    ('Status', 1.1, Alignment.center),
  ];

  @override
  Widget build(BuildContext context) {
    final head = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: CorpColors.textSecondary(context),
    );
    final cell =
        TextStyle(fontSize: 13, color: CorpColors.textPrimary(context));
    Widget pad(Widget child, int i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Align(alignment: _columns[i].$3, child: child),
        );

    return Table(
      columnWidths: {
        for (var i = 0; i < _columns.length; i++)
          i: FlexColumnWidth(_columns[i].$2),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: CorpColors.divider(context)),
            ),
          ),
          children: [
            for (var i = 0; i < _columns.length; i++)
              pad(Text(_columns[i].$1, style: head), i),
          ],
        ),
        for (final b in bills)
          TableRow(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: CorpColors.divider(context)),
              ),
            ),
            children: [
              for (final (i, child) in [
                (
                  0,
                  Text(
                    b.id,
                    style: cell.copyWith(
                      fontWeight: FontWeight.w700,
                      color: CorpColors.brand(context),
                    ),
                  ),
                ),
                (1, Text(lcOrDash(b.importerName), style: cell)),
                (2, Text(lcOrDash(b.productName), style: cell)),
                (3, Text(TfDate.display(b.transactionDate), style: cell)),
                (4, Text(lcMoney(b.amount), style: cell)),
                (5, LcStatusChip(label: b.statusLabel)),
              ])
                TableRowInkWell(
                  onTap: () => openExportBill(context, b),
                  child: pad(child, i),
                ),
            ],
          ),
      ],
    );
  }
}

/// Bills as cards — the phone list, and the Bills tab of an export LC.
class ExportBillCards extends StatelessWidget {
  const ExportBillCards({super.key, required this.bills});

  final List<CorpExportBill> bills;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(
      fontSize: 12,
      color: CorpColors.textSecondary(context),
    );
    return Column(
      children: [
        for (final b in bills)
          InkWell(
            onTap: () => openExportBill(context, b),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: CorpColors.divider(context)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.id,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: CorpColors.brand(context),
                          ),
                        ),
                      ),
                      LcStatusChip(label: b.statusLabel),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Importer: ${lcOrDash(b.importerName)}', style: muted),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: LcInfoItem(
                          label: 'Bill amount',
                          value: lcMoney(b.amount),
                        ),
                      ),
                      Expanded(
                        child: LcInfoItem(
                          label: 'Transaction date',
                          value: TfDate.display(b.transactionDate),
                        ),
                      ),
                    ],
                  ),
                  if (b.productName != null) ...[
                    const SizedBox(height: 6),
                    Text('Release against ${b.productName}', style: muted),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
