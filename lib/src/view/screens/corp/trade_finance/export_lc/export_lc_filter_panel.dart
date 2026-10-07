import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/export_lc_search.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/export_lc/tf_filter_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';

/// The View Export LC search form (manual ch. 11, step 1).
///
/// A bottom sheet on a phone, a dialog on a wider screen; returns the
/// search to run, or null when dismissed.
class ExportLcFilterPanel extends StatefulWidget {
  const ExportLcFilterPanel({super.key, required this.initial});

  final ExportLcSearch initial;

  /// Width below which the form opens as a bottom sheet.
  static const double sheetBelow = 600;

  static Future<ExportLcSearch?> show(
    BuildContext context,
    ExportLcSearch initial,
  ) {
    if (MediaQuery.sizeOf(context).width < sheetBelow) {
      return showModalBottomSheet<ExportLcSearch>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: CorpColors.card(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.92,
          child: ExportLcFilterPanel(initial: initial),
        ),
      );
    }
    return showDialog<ExportLcSearch>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: CorpColors.card(context),
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
          child: ExportLcFilterPanel(initial: initial),
        ),
      ),
    );
  }

  @override
  State<ExportLcFilterPanel> createState() => _ExportLcFilterPanelState();
}

class _ExportLcFilterPanelState extends State<ExportLcFilterPanel> {
  late String _lcNumber = widget.initial.lcNumber ?? '';
  late String _applicant = widget.initial.applicantName ?? '';
  late ExportLcStatus? _status = widget.initial.status;
  late ExportLcDrawingStatus? _drawing = widget.initial.drawingStatus;
  late String _fromAmount = _amountText(widget.initial.fromAmount);
  late String _toAmount = _amountText(widget.initial.toAmount);
  late DateTime? _issueFrom = widget.initial.issueFrom;
  late DateTime? _issueTo = widget.initial.issueTo;
  late DateTime? _expiryFrom = widget.initial.expiryFrom;
  late DateTime? _expiryTo = widget.initial.expiryTo;
  late ExportLcExpiry? _expiry = widget.initial.expiry;

  /// Bumped by Clear so the text fields rebuild empty.
  int _generation = 0;
  String? _error;

  static String _amountText(double? v) {
    if (v == null) return '';
    return v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
  }

  void _clear() => setState(() {
        _lcNumber = '';
        _applicant = '';
        _status = null;
        _drawing = null;
        _fromAmount = '';
        _toAmount = '';
        _issueFrom = null;
        _issueTo = null;
        _expiryFrom = null;
        _expiryTo = null;
        _expiry = null;
        _error = null;
        _generation++;
      });

  void _search() {
    final from = double.tryParse(_fromAmount.trim());
    final to = double.tryParse(_toAmount.trim());
    String? error;
    if (from != null && to != null && from > to) {
      error = 'The "from" amount is more than the "to" amount.';
    } else if (_issueFrom != null &&
        _issueTo != null &&
        _issueFrom!.isAfter(_issueTo!)) {
      error = 'The issue date range ends before it starts.';
    } else if (_expiryFrom != null &&
        _expiryTo != null &&
        _expiryFrom!.isAfter(_expiryTo!)) {
      error = 'The expiry date range ends before it starts.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(
      ExportLcSearch(
        lcNumber: _lcNumber,
        applicantName: _applicant,
        status: _status,
        drawingStatus: _drawing,
        fromAmount: from,
        toAmount: to,
        issueFrom: _issueFrom,
        issueTo: _issueTo,
        expiryFrom: _expiryFrom,
        expiryTo: _expiryTo,
        expiry: _expiry,
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
                  'Search export LCs',
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
                  label: 'LC number',
                  initialValue: _lcNumber,
                  uppercase: true,
                  onChanged: (v) => _lcNumber = v,
                ),
                LcTextField(
                  label: 'Applicant name',
                  initialValue: _applicant,
                  onChanged: (v) => _applicant = v,
                ),
              ),
              TfChoiceGroup<ExportLcStatus>(
                label: 'LC status',
                options: ExportLcStatus.values,
                labelOf: (v) => v.label,
                selected: _status,
                onChanged: (v) => setState(() => _status = v),
              ),
              TfChoiceGroup<ExportLcDrawingStatus>(
                label: 'Drawing status',
                options: ExportLcDrawingStatus.values,
                labelOf: (v) => v.label,
                selected: _drawing,
                onChanged: (v) => setState(() => _drawing = v),
              ),
              pair(
                LcTextField(
                  label: 'LC amount from',
                  initialValue: _fromAmount,
                  numeric: true,
                  onChanged: (v) => _fromAmount = v,
                ),
                LcTextField(
                  label: 'LC amount to',
                  initialValue: _toAmount,
                  numeric: true,
                  onChanged: (v) => _toAmount = v,
                ),
              ),
              pair(
                TfClearableDate(
                  label: 'Issue date from',
                  value: _issueFrom,
                  onChanged: (d) => setState(() => _issueFrom = d),
                ),
                TfClearableDate(
                  label: 'Issue date to',
                  value: _issueTo,
                  onChanged: (d) => setState(() => _issueTo = d),
                ),
              ),
              pair(
                TfClearableDate(
                  label: 'Expiry date from',
                  value: _expiryFrom,
                  onChanged: (d) => setState(() => _expiryFrom = d),
                ),
                TfClearableDate(
                  label: 'Expiry date to',
                  value: _expiryTo,
                  onChanged: (d) => setState(() => _expiryTo = d),
                ),
              ),
              TfChoiceGroup<ExportLcExpiry>(
                label: 'Expiry status',
                options: ExportLcExpiry.values,
                labelOf: (v) => v.label,
                selected: _expiry,
                onChanged: (v) => setState(() => _expiry = v),
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
