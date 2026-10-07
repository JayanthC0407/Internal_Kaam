import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/export_bill.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/export_lc/tf_filter_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';

/// The View Export Bill search form (manual ch. 14, step 1) — the fields
/// the web client's bill search sends. A bottom sheet on a phone, a dialog
/// on a wider screen; returns the search to run, or null when dismissed.
class ExportBillFilterPanel extends StatefulWidget {
  const ExportBillFilterPanel({super.key, required this.initial});

  final ExportBillSearch initial;

  static Future<ExportBillSearch?> show(
    BuildContext context,
    ExportBillSearch initial,
  ) {
    if (MediaQuery.sizeOf(context).width < 600) {
      return showModalBottomSheet<ExportBillSearch>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: CorpColors.card(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.88,
          child: ExportBillFilterPanel(initial: initial),
        ),
      );
    }
    return showDialog<ExportBillSearch>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: CorpColors.card(context),
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
          child: ExportBillFilterPanel(initial: initial),
        ),
      ),
    );
  }

  @override
  State<ExportBillFilterPanel> createState() => _ExportBillFilterPanelState();
}

class _ExportBillFilterPanelState extends State<ExportBillFilterPanel> {
  late String _billNumber = widget.initial.billNumber ?? '';
  late String _importer = widget.initial.importerName ?? '';
  late ExportBillStatus? _status = widget.initial.status;
  late String _currency = widget.initial.currency ?? '';
  late String _fromAmount = _amountText(widget.initial.fromAmount);
  late String _toAmount = _amountText(widget.initial.toAmount);
  late DateTime? _dateFrom = widget.initial.dateFrom;
  late DateTime? _dateTo = widget.initial.dateTo;
  int _generation = 0;
  String? _error;

  static String _amountText(double? v) {
    if (v == null) return '';
    return v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
  }

  void _clear() => setState(() {
        _billNumber = '';
        _importer = '';
        _status = null;
        _currency = '';
        _fromAmount = '';
        _toAmount = '';
        _dateFrom = null;
        _dateTo = null;
        _error = null;
        _generation++;
      });

  void _search() {
    final from = double.tryParse(_fromAmount.trim());
    final to = double.tryParse(_toAmount.trim());
    String? error;
    if (from != null && to != null && from > to) {
      error = 'The "from" amount is more than the "to" amount.';
    } else if (_dateFrom != null &&
        _dateTo != null &&
        _dateFrom!.isAfter(_dateTo!)) {
      error = 'The bill date range ends before it starts.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(
      ExportBillSearch(
        billNumber: _billNumber,
        importerName: _importer,
        status: _status,
        currency: _currency.trim().toUpperCase(),
        fromAmount: from,
        toAmount: to,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final twoColumns = MediaQuery.sizeOf(context).width >= 480;
    Widget pair(Widget a, Widget b) => twoColumns
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: a),
              const SizedBox(width: 12),
              Expanded(child: b),
            ],
          )
        : Column(children: [a, b]);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Search export bills',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: CorpColors.textPrimary(context),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            key: ValueKey(_generation),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            children: [
              pair(
                LcTextField(
                  label: 'Bill reference number',
                  initialValue: _billNumber,
                  uppercase: true,
                  onChanged: (v) => _billNumber = v,
                ),
                LcTextField(
                  label: 'Importer name',
                  initialValue: _importer,
                  onChanged: (v) => _importer = v,
                ),
              ),
              TfChoiceGroup<ExportBillStatus>(
                label: 'Status',
                options: ExportBillStatus.values,
                labelOf: (v) => v.label,
                selected: _status,
                onChanged: (v) => setState(() => _status = v),
              ),
              pair(
                LcTextField(
                  label: 'Bill amount from',
                  initialValue: _fromAmount,
                  numeric: true,
                  onChanged: (v) => _fromAmount = v,
                ),
                LcTextField(
                  label: 'Bill amount to',
                  initialValue: _toAmount,
                  numeric: true,
                  onChanged: (v) => _toAmount = v,
                ),
              ),
              LcTextField(
                label: 'Currency',
                hint: 'e.g. GBP',
                initialValue: _currency,
                uppercase: true,
                maxLength: 3,
                onChanged: (v) => _currency = v,
              ),
              pair(
                TfClearableDate(
                  label: 'Bill date from',
                  value: _dateFrom,
                  onChanged: (d) => setState(() => _dateFrom = d),
                ),
                TfClearableDate(
                  label: 'Bill date to',
                  value: _dateTo,
                  onChanged: (d) => setState(() => _dateTo = d),
                ),
              ),
              if (_error != null) LcMessageBanner(message: _error!),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: CorpColors.divider(context))),
          ),
          child: Row(
            children: [
              Expanded(
                child: LcSecondaryButton(label: 'Clear', onPressed: _clear),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LcPrimaryButton(
                  label: 'Search',
                  icon: Icons.search_rounded,
                  onPressed: _search,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
