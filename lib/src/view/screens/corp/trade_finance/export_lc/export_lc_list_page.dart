import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/export_lc_search.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/core/utils/common/statement_file_saver.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_export_lc_view_providers.dart';
import 'package:ubci_bank/src/view/routes/corp/corp_routes_const.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/export_lc/export_lc_filter_panel.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// View Export Letter of Credit — search and results (manual ch. 11,
/// steps 1–5): Export LCs issued in the user's favour as beneficiary.
///
/// Results are a table where there is room for the manual's columns, and
/// cards on a phone.
class ExportLcListPage extends ConsumerStatefulWidget {
  const ExportLcListPage({super.key});

  /// Width from which results show as a table.
  static const double tableFrom = 760;

  @override
  ConsumerState<ExportLcListPage> createState() => _ExportLcListPageState();
}

class _ExportLcListPageState extends ConsumerState<ExportLcListPage> {
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(corpExportLcSearchProvider.notifier).ensureLoaded();
    });
  }

  ExportLcSearchNotifier get _notifier =>
      ref.read(corpExportLcSearchProvider.notifier);

  Future<void> _openFilters(ExportLcSearch current) async {
    final picked = await ExportLcFilterPanel.show(context, current);
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

  void _open(CorpLetterOfCredit lc) {
    Navigator.of(context).pushNamed(
      CorpRoutesConst.exportLcDetailScreen,
      arguments: LcDetailArgs(lcId: lc.id, lcType: LcType.exportLc),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(corpExportLcSearchProvider);
    final criteria = state.criteria;
    final count = criteria.activeCount;

    return CorpCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CorpCardHeader(
            title: state.loaded
                ? '${state.items.length} export LC'
                    '${state.items.length == 1 ? '' : 's'}'
                : 'Export letters of credit',
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
            _ActiveFilters(
              criteria: criteria,
              onRemove: (f) => _notifier.search(criteria.without(f)),
              onClearAll: () => _notifier.search(ExportLcSearch.none),
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
              icon: Icons.north_east_rounded,
              title: count > 0
                  ? 'No export LCs match these filters'
                  : 'No export letters of credit',
              message: count > 0
                  ? null
                  : 'LCs your bank receives in your favour, as beneficiary, '
                      'appear here.',
            )
          else ...[
            if (state.isLoading) const LinearProgressIndicator(minHeight: 2),
            LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth >= ExportLcListPage.tableFrom
                      ? _ResultsTable(items: state.items, onOpen: _open)
                      : _ResultCards(items: state.items, onOpen: _open),
            ),
          ],
        ],
      ),
    );
  }
}

/// The filters in force, each removable — the search at a glance.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.criteria,
    required this.onRemove,
    required this.onClearAll,
  });

  final ExportLcSearch criteria;
  final ValueChanged<ExportLcFilter> onRemove;
  final VoidCallback onClearAll;

  String _label(ExportLcFilter f) {
    String range(String name, Object? from, Object? to) {
      String show(Object? v) => v is DateTime
          ? TfDate.display(v)
          : v is double
              ? (v == v.truncateToDouble() ? v.toInt().toString() : '$v')
              : '$v';
      if (from != null && to != null) return '$name ${show(from)}–${show(to)}';
      if (from != null) return '$name from ${show(from)}';
      return '$name to ${show(to)}';
    }

    return switch (f) {
      ExportLcFilter.lcNumber => 'LC ${criteria.lcNumber!.trim()}',
      ExportLcFilter.applicant =>
        'Applicant: ${criteria.applicantName!.trim()}',
      ExportLcFilter.status => 'Status: ${criteria.status!.label}',
      ExportLcFilter.drawingStatus =>
        'Drawing: ${criteria.drawingStatus!.label}',
      ExportLcFilter.amount =>
        range('Amount', criteria.fromAmount, criteria.toAmount),
      ExportLcFilter.issueDate =>
        range('Issued', criteria.issueFrom, criteria.issueTo),
      ExportLcFilter.expiryDate =>
        range('Expiry', criteria.expiryFrom, criteria.expiryTo),
      ExportLcFilter.expiry => criteria.expiry!.label,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final f in criteria.activeFilters)
          InputChip(
            label: Text(_label(f), style: const TextStyle(fontSize: 12)),
            onDeleted: () => onRemove(f),
            deleteButtonTooltipMessage: 'Remove filter',
            visualDensity: VisualDensity.compact,
          ),
        TextButton(onPressed: onClearAll, child: const Text('Clear all')),
      ],
    );
  }
}

class _ResultsTable extends StatelessWidget {
  const _ResultsTable({required this.items, required this.onOpen});

  final List<CorpLetterOfCredit> items;
  final ValueChanged<CorpLetterOfCredit> onOpen;

  static const _columns = <(String, double, Alignment)>[
    ('LC number', 1.4, Alignment.centerLeft),
    ('Applicant', 1.5, Alignment.centerLeft),
    ('Beneficiary', 1.4, Alignment.centerLeft),
    ('Issue date', 1.1, Alignment.centerLeft),
    ('Date of expiry', 1.1, Alignment.centerLeft),
    ('Status', 1.0, Alignment.center),
    ('LC amount', 1.3, Alignment.centerRight),
    ('Outstanding', 1.3, Alignment.centerRight),
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
        for (final lc in items)
          TableRow(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: CorpColors.divider(context)),
              ),
            ),
            children: [
              TableRowInkWell(
                onTap: () => onOpen(lc),
                child: pad(
                  Text(
                    lc.id,
                    style: cell.copyWith(
                      fontWeight: FontWeight.w700,
                      color: CorpColors.brand(context),
                    ),
                  ),
                  0,
                ),
              ),
              _tap(
                  lc, pad(Text(lcOrDash(lc.counterPartyName), style: cell), 1)),
              _tap(lc, pad(Text(lcOrDash(lc.partyName), style: cell), 2)),
              _tap(
                lc,
                pad(Text(TfDate.display(lc.applicationDate), style: cell), 3),
              ),
              _tap(
                  lc, pad(Text(TfDate.display(lc.expiryDate), style: cell), 4)),
              _tap(lc, pad(_StatusChips(lc: lc), 5)),
              _tap(lc, pad(Text(lcMoney(lc.amount), style: cell), 6)),
              _tap(
                lc,
                pad(Text(lcMoney(lc.outstandingAmount), style: cell), 7),
              ),
            ],
          ),
      ],
    );
  }

  Widget _tap(CorpLetterOfCredit lc, Widget child) =>
      TableRowInkWell(onTap: () => onOpen(lc), child: child);
}

class _ResultCards extends StatelessWidget {
  const _ResultCards({required this.items, required this.onOpen});

  final List<CorpLetterOfCredit> items;
  final ValueChanged<CorpLetterOfCredit> onOpen;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(
      fontSize: 12,
      color: CorpColors.textSecondary(context),
    );
    return Column(
      children: [
        for (final lc in items)
          InkWell(
            onTap: () => onOpen(lc),
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
                          lc.id,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: CorpColors.brand(context),
                          ),
                        ),
                      ),
                      _StatusChips(lc: lc),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Applicant: ${lcOrDash(lc.counterPartyName)}',
                    style: muted,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: LcInfoItem(
                          label: 'LC amount',
                          value: lcMoney(lc.amount),
                        ),
                      ),
                      Expanded(
                        child: LcInfoItem(
                          label: 'Outstanding',
                          value: lcMoney(lc.outstandingAmount),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Issued ${TfDate.display(lc.applicationDate)} · '
                    'Expires ${TfDate.display(lc.expiryDate)}',
                    style: muted,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.lc});

  final CorpLetterOfCredit lc;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      children: [
        LcStatusChip(label: lc.statusLabel),
        if (lc.isExpired) const LcStatusChip(label: 'EXPIRED'),
      ],
    );
  }
}
