import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:demo_bank/src/core/models/corp/liquidity_charges_models.dart';
import 'package:demo_bank/src/infra/network/response_handler.dart';
import 'package:demo_bank/src/view/providers/corp/corp_liquidity_providers.dart';
import 'package:demo_bank/src/view/screens/corp/corp_colors.dart';
import 'package:demo_bank/src/view/screens/corp/credit_facility/cf_widgets.dart';
import 'package:demo_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:demo_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// Charges Inquiry — OBDX `liquidity-management/lm-charges-inquiry`: the
/// search form (Charge Description, Collection Status, From / To Date),
/// then the Charges List with Download (CSV) and a per-row details popup.
/// Evidence: docs/obdx/features/liquidity-management.md §10.
class ChargesInquiryPage extends ConsumerStatefulWidget {
  const ChargesInquiryPage({super.key, required this.onCancel});

  /// Cancel: leave the screen (OBDX asks to switch module).
  final VoidCallback onCancel;

  /// Width from which the form has two columns and the list is a table.
  static const wideWidth = 720.0;

  @override
  ConsumerState<ChargesInquiryPage> createState() => _ChargesInquiryPageState();
}

class _ChargesInquiryPageState extends ConsumerState<ChargesInquiryPage> {
  String? _code;
  String? _status;
  DateTime? _from;
  DateTime? _to;
  bool _showErrors = false;
  String? _rangeError;

  /// Bumped by Reset so the pickers rebuild empty.
  int _formKey = 0;

  bool _searching = false;
  List<LmCharge>? _rows;
  String? _searchError;

  /// Collection Date and the two period dates are sortable, as in OBDX.
  int? _sortColumn;
  bool _ascending = true;

  LmChargeQuery get _query => LmChargeQuery(code: _code, status: _status, from: _from, to: _to);

  /// Required dates and the 30-day limit; true when Search may go on.
  bool _validate() {
    final missing = _from == null || _to == null;
    setState(() {
      _showErrors = missing;
      _rangeError = !missing && _query.tooLong
          ? 'The date range to search charges cannot be more than $lmChargeMaxDays days.'
          : null;
    });
    return !missing && _rangeError == null;
  }

  Future<void> _search() async {
    if (!_validate()) return;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    final result = await ref.read(corpLiquidityRepositoryProvider).fetchCharges(_query);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _sortColumn = null;
      if (result is Success<List<LmCharge>>) {
        _rows = result.data ?? const [];
      } else {
        // OBDX shows an empty table; the app also says why.
        _rows = const [];
        final message = result is Error<List<LmCharge>> ? result.error : null;
        _searchError = message?.trim().isNotEmpty == true ? message : 'We couldn\'t load the charges.';
      }
    });
  }

  void _reset() => setState(() {
        _code = null;
        _status = null;
        _from = null;
        _to = null;
        _showErrors = false;
        _rangeError = null;
        _formKey++;
      });

  List<LmCharge> _sorted(List<LmCharge> rows) {
    final column = _sortColumn;
    if (column == null) return rows;
    DateTime? key(LmCharge c) => switch (column) {
          0 => c.fromDate,
          1 => c.toDate,
          _ => c.collectionDate,
        };
    final out = [...rows]..sort((a, b) {
        final x = key(a), y = key(b);
        if (x == null || y == null) return x == null ? (y == null ? 0 : -1) : 1;
        return x.compareTo(y);
      });
    return _ascending ? out : out.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(lmChargeSetupProvider);
    final s = setup.valueOrNull ?? const LmChargeSetup();
    final rows = _rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CorpCardShell(
          child: LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth >= ChargesInquiryPage.wideWidth;
            Widget pair(Widget a, Widget b) => wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: a),
                    const SizedBox(width: 16),
                    Expanded(child: b),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 12), b]);
            return Column(
              key: ValueKey(_formKey),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                pair(
                  LcPickerField<String>(
                    label: 'Charge Description',
                    options: [for (final d in s.definitions) d.code],
                    labelOf: (c) => s.definitions.firstWhere((d) => d.code == c).description,
                    selected: _code,
                    onSelected: (c) => setState(() => _code = c),
                  ),
                  LcPickerField<String>(
                    label: 'Collection Status',
                    options: [for (final d in s.statuses) d.code],
                    labelOf: s.statusText,
                    selected: _status,
                    onSelected: (c) => setState(() => _status = c),
                  ),
                ),
                const SizedBox(height: 12),
                // OBDX shows the dates once `maintenances` has answered.
                if (setup.isLoading)
                  const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
                else
                  pair(
                    LcDateField(
                      label: 'From Date',
                      value: _from,
                      firstDate: DateTime(2000),
                      lastDate: _to ?? DateTime(2100),
                      helper: _showErrors && _from == null ? 'From Date is required.' : null,
                      onChanged: (d) => setState(() => _from = d),
                    ),
                    LcDateField(
                      label: 'To Date',
                      value: _to,
                      firstDate: _from ?? DateTime(2000),
                      lastDate: DateTime(2100),
                      helper: _showErrors && _to == null ? 'To Date is required.' : null,
                      onChanged: (d) => setState(() => _to = d),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: CorpColors.textSecondary(context)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Difference between From Date and To Date should not be greater than $lmChargeMaxDays days.',
                        style: TextStyle(fontSize: 12.5, color: CorpColors.textSecondary(context)),
                      ),
                    ),
                  ],
                ),
                if (_rangeError != null) ...[const SizedBox(height: 10), LcMessageBanner(message: _rangeError!)],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    LcPrimaryButton(label: 'Search', onPressed: setup.isLoading || _searching ? null : _search),
                    LcSecondaryButton(label: 'Reset', onPressed: _reset),
                    // After results, OBDX moves Cancel below the table.
                    if (rows == null) LcSecondaryButton(label: 'Cancel', onPressed: widget.onCancel),
                  ],
                ),
              ],
            );
          }),
        ),
        if (_searching)
          const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
        else if (rows != null) ...[
          const SizedBox(height: 14),
          CorpCardShell(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Charges List',
                          style:
                              TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CorpColors.textPrimary(context))),
                    ),
                    CfDownloadButton(
                      fileName: 'ChargesList.csv',
                      mimeType: 'text/csv',
                      enabled: rows.isNotEmpty,
                      download: () async {
                        if (!_validate()) return ResponseHandler.error(0, 'Please correct the search fields.');
                        return ref.read(corpLiquidityRepositoryProvider).downloadCharges(_query);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_searchError != null) ...[LcMessageBanner(message: _searchError!), const SizedBox(height: 10)],
                if (rows.isEmpty)
                  const LcEmptyState(icon: Icons.receipt_long_outlined, title: 'No charges to show.')
                else
                  LayoutBuilder(
                    builder: (context, box) => box.maxWidth >= ChargesInquiryPage.wideWidth
                        ? _table(context, _sorted(rows), s)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [for (final c in _sorted(rows)) _card(context, c, s)],
                          ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: LcSecondaryButton(label: 'Cancel', onPressed: widget.onCancel),
          ),
        ],
      ],
    );
  }

  static String _rate(double? r) {
    if (r == null) return '--';
    final fixed = r.toStringAsFixed(2);
    return fixed.endsWith('.00')
        ? fixed.substring(0, fixed.length - 3)
        : fixed.endsWith('0')
            ? fixed.substring(0, fixed.length - 1)
            : fixed;
  }

  static String _account(LmCharge c) => [c.account, c.accountName].whereType<String>().join(' / ').ifEmpty('--');

  void _details(LmCharge c) {
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: SizedBox(
          width: 380,
          child: LcInfoGrid(items: [
            ('Additional Info', c.additionalInfo ?? '--'),
            if (c.errorDescription != null) ('Error Description', c.errorDescription!),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('Close'))],
      ),
    );
  }

  Widget _more(LmCharge c) => IconButton(
        tooltip: 'Click for more details',
        icon: const Icon(Icons.more_vert_rounded),
        onPressed: () => _details(c),
      );

  Widget _table(BuildContext context, List<LmCharge> rows, LmChargeSetup s) {
    void sort(int column, bool ascending) => setState(() {
          _sortColumn = column;
          _ascending = ascending;
        });
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: switch (_sortColumn) { null => null, 0 => 0, 1 => 1, _ => 7 },
        sortAscending: _ascending,
        headingTextStyle: TextStyle(fontWeight: FontWeight.w700, color: CorpColors.textSecondary(context), fontSize: 12.5),
        columns: [
          DataColumn(label: const Text('From Date'), onSort: (_, a) => sort(0, a)),
          DataColumn(label: const Text('To Date'), onSort: (_, a) => sort(1, a)),
          const DataColumn(label: Text('Description')),
          const DataColumn(label: Text('Amount'), numeric: true),
          const DataColumn(label: Text('Account No. & Name')),
          const DataColumn(label: Text('Collection Amount'), numeric: true),
          const DataColumn(label: Text('Exchange Rate')),
          DataColumn(label: const Text('Collection Date'), onSort: (_, a) => sort(2, a)),
          const DataColumn(label: Text('Collection Status')),
          const DataColumn(label: SizedBox.shrink()),
        ],
        rows: [
          for (final c in rows)
            DataRow(cells: [
              DataCell(Text(cfDateOr(c.fromDate, '--'))),
              DataCell(Text(cfDateOr(c.toDate, '--'))),
              DataCell(Text(c.description ?? '--')),
              DataCell(Text(cfMoney(c.amount))),
              DataCell(Text(_account(c))),
              DataCell(Text(cfMoney(c.collectionAmount))),
              DataCell(Text(_rate(c.exchangeRate))),
              DataCell(Text(cfDateOr(c.collectionDate, '--'))),
              DataCell(Text(s.statusText(c.collectionStatus))),
              DataCell(_more(c)),
            ]),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, LmCharge c, LmChargeSetup s) => CfPanel(
        header: Row(
          children: [
            Expanded(
              child: Text(c.description ?? '--',
                  style: TextStyle(fontWeight: FontWeight.w700, color: CorpColors.textPrimary(context))),
            ),
            _more(c),
          ],
        ),
        child: LcInfoGrid(items: [
          ('From Date', cfDateOr(c.fromDate, '--')),
          ('To Date', cfDateOr(c.toDate, '--')),
          ('Amount', cfMoney(c.amount)),
          ('Account No. & Name', _account(c)),
          ('Collection Amount', cfMoney(c.collectionAmount)),
          ('Exchange Rate', _rate(c.exchangeRate)),
          ('Collection Date', cfDateOr(c.collectionDate, '--')),
          ('Collection Status', s.statusText(c.collectionStatus)),
        ]),
      );
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
