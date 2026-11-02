import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/corp/credit_facility_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_credit_facility_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/cf_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// Collateral Details — OBDX `credit-facility/collateral-details`: from the
/// menu a Choose Collateral dialog comes first; from Collateral Summary or
/// a linked collateral the code is given. Body: the amounts, More
/// Information (the panel for the collateral's type) and the Covenants
/// tab. Evidence: docs/obdx/features/credit-facility.md §7.
class CollateralDetailsPage extends ConsumerStatefulWidget {
  const CollateralDetailsPage({super.key, this.initialCode, required this.onExit});

  /// `collateralCode`; null from the menu.
  final String? initialCode;

  /// Choose Collateral closed without a choice.
  final VoidCallback onExit;

  /// Wide enough for the More Information table (OBDX: not `small`).
  static const tableWidth = 720.0;

  @override
  ConsumerState<CollateralDetailsPage> createState() => _CollateralDetailsPageState();
}

class _CollateralDetailsPageState extends ConsumerState<CollateralDetailsPage> {
  late String? _code = widget.initialCode;
  bool _more = false;
  bool _asked = false;

  Future<void> _choose(List<CfCollateral> options) async {
    String? picked = options.firstOrNull?.code;
    final code = await showDialog<String>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Choose Collateral'),
          content: SizedBox(
            width: 420,
            child: options.isEmpty
                ? const Text('No collaterals to show.')
                : LcPickerField<String>(
                    label: 'Collateral ID',
                    options: [for (final c in options) c.code],
                    labelOf: (c) => c,
                    selected: picked,
                    onSelected: (c) => setDialog(() => picked = c),
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: picked == null ? null : () => Navigator.of(dialog).pop(picked),
              child: const Text('Proceed'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (code == null) return widget.onExit();
    setState(() => _code = code);
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    if (code == null) {
      final options = ref.watch(cfCollateralOptionsProvider);
      final list = options.valueOrNull;
      if (list != null && !_asked) {
        _asked = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _choose(list);
        });
      }
      return CorpCardShell(
        child: options.hasError
            ? CfFailed(
                message: cfError(options.error, 'We couldn\'t load the collaterals.'),
                onRetry: () => ref.invalidate(cfCollateralOptionsProvider),
              )
            : list == null
                ? const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
                : Center(
                    child: TextButton.icon(
                      onPressed: () => _choose(list),
                      icon: const Icon(Icons.article_outlined),
                      label: const Text('Choose Collateral'),
                    ),
                  ),
      );
    }
    return ref.watch(cfCollateralDetailProvider(code)).when(
          loading: () => const CorpCardShell(
            child: Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())),
          ),
          error: (e, _) => CorpCardShell(
            child: CfFailed(
              message: cfError(e, 'We couldn\'t load this collateral.'),
              onRetry: () => ref.invalidate(cfCollateralDetailProvider(code)),
            ),
          ),
          data: (c) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CorpCardShell(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // OBDX puts the collateral id in the page header.
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(c.code,
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: CorpColors.textPrimary(context))),
                        if (c.type != null) CfTag(c.type!),
                      ],
                    ),
                    const SizedBox(height: 14),
                    LcInfoGrid(items: [
                      ('Collateral Value', cfMoney(c.value)),
                      ('Collateral Amount (After Haircut)', cfMoney(c.limitContribution)),
                      ('Utilized Amount', cfMoney(c.utilization)),
                      ('Block Amount', cfMoney(c.block)),
                      ('Available Amount', cfMoney(c.available)),
                    ]),
                    const SizedBox(height: 6),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _more = !_more),
                        icon: Icon(_more ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                        label: Text(_more ? 'Show Less Information' : 'More Information'),
                      ),
                    ),
                    if (_more) _TypePanel(detail: c),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              CorpCardShell(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // OBDX's only tab here (hard-coded label).
                    Text('Covenants',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CorpColors.textPrimary(context))),
                    const SizedBox(height: 14),
                    CfCovenants(covenants: c.covenants),
                  ],
                ),
              ),
            ],
          ),
        );
  }
}

/// One cell of a per-type column: money in its own currency (else the
/// collateral's), a date, or text; `--` when missing.
String _cell(Map<String, dynamic> row, CfColumn column, String? currency) {
  final raw = row[column.field];
  if (raw == null || raw == '') return '--';
  return switch (column.kind) {
    CfColumnKind.money => cfMoney(MoneyAmount.fromJson(raw, fallbackCurrency: currency)),
    CfColumnKind.date => cfDateOr(DateTime.tryParse('$raw'), '--'),
    CfColumnKind.text => raw is Map || raw is List ? '--' : '$raw',
  };
}

/// More Information: `collateralDetails` with the columns of the
/// collateral's type, as a table on wide screens and as rows on phones.
class _TypePanel extends StatelessWidget {
  const _TypePanel({required this.detail});

  final CfCollateralDetail detail;

  @override
  Widget build(BuildContext context) {
    final columns = detail.columns;
    // OBDX shows an empty panel for a type it has no component for.
    if (columns == null || detail.rows.isEmpty) {
      return const LcEmptyState(icon: Icons.info_outline_rounded, title: 'No details to show.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Collateral Details',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CorpColors.textPrimary(context))),
        const SizedBox(height: 8),
        _Rows(rows: detail.rows, columns: columns, currency: detail.currency),
      ],
    );
  }
}

/// Rows under [columns]: a table at [CollateralDetailsPage.tableWidth] and
/// up, else one info grid per row. INVENTORY's products column is a link
/// to the Product Details dialog.
class _Rows extends StatelessWidget {
  const _Rows({required this.rows, required this.columns, required this.currency});

  final List<Map<String, dynamic>> rows;
  final List<CfColumn> columns;
  final String? currency;

  static bool _isProducts(CfColumn c) => c.field == 'products';

  Widget _value(BuildContext context, Map<String, dynamic> row, CfColumn c) {
    if (!_isProducts(c)) return Text(_cell(row, c, currency));
    final products = row['products'] is List
        ? [for (final p in row['products'] as List) if (p is Map) Map<String, dynamic>.from(p)]
        : const <Map<String, dynamic>>[];
    return CfLink(
      label: c.label,
      size: 13.5,
      onTap: products.isEmpty ? null : () => _showProducts(context, products, currency),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= CollateralDetailsPage.tableWidth) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: TextStyle(fontWeight: FontWeight.w700, color: CorpColors.textSecondary(context), fontSize: 12.5),
            columns: [for (final c in columns) DataColumn(label: Text(c.label))],
            rows: [
              for (final r in rows) DataRow(cells: [for (final c in columns) DataCell(_value(context, r, c))]),
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final r in rows)
            CfPanel(
              header: const SizedBox.shrink(),
              child: Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  for (final c in columns)
                    SizedBox(
                      width: 150,
                      child: _isProducts(c)
                          ? _value(context, r, c)
                          : LcInfoItem(label: c.label, value: _cell(r, c, currency)),
                    ),
                ],
              ),
            ),
        ],
      );
    });
  }
}

void _showProducts(BuildContext context, List<Map<String, dynamic>> products, String? currency) {
  showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Product Details'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(child: _Rows(rows: products, columns: cfInventoryProductColumns, currency: currency)),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('Close'))],
    ),
  );
}
