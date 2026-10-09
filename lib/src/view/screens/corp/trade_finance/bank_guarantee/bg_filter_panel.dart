import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/bank_guarantee_models.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/export_lc/tf_filter_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';

/// The View Inward Guarantee filter (`bank-guarantee-filter`, BG #45).
///
/// A bottom sheet on a phone, a dialog on a wider screen; returns the
/// search to run, or null when dismissed. The party choice is kept as it
/// was — it has its own selector on the list.
class BgFilterPanel extends StatefulWidget {
  const BgFilterPanel({
    super.key,
    required this.initial,
    required this.category,
    required this.currencies,
  });

  final BgSearch initial;
  final BgCategory category;
  final List<TradeCode> currencies;

  static const double sheetBelow = 600;

  static Future<BgSearch?> show(
    BuildContext context, {
    required BgSearch initial,
    required BgCategory category,
    List<TradeCode> currencies = const [],
  }) {
    final panel = BgFilterPanel(
      initial: initial,
      category: category,
      currencies: currencies,
    );
    if (MediaQuery.sizeOf(context).width < sheetBelow) {
      return showModalBottomSheet<BgSearch>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: CorpColors.card(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => FractionallySizedBox(heightFactor: 0.92, child: panel),
      );
    }
    return showDialog<BgSearch>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: CorpColors.card(context),
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
          child: panel,
        ),
      ),
    );
  }

  @override
  State<BgFilterPanel> createState() => _BgFilterPanelState();
}

class _BgFilterPanelState extends State<BgFilterPanel> {
  late String _applicant = widget.initial.applicantName ?? '';
  late String _issuingBank = widget.initial.issuingBank ?? '';
  late String _issuingRef = widget.initial.issuingBankRefNo ?? '';
  late BgStatus? _status = widget.initial.status;
  late String _currency = widget.initial.currency ?? '';
  late String _from = bgAmountText(widget.initial.fromAmount);
  late String _to = bgAmountText(widget.initial.toAmount);
  late DateTime? _issueFrom = widget.initial.issueFrom;
  late DateTime? _issueTo = widget.initial.issueTo;
  late DateTime? _expiryFrom = widget.initial.expiryFrom;
  late DateTime? _expiryTo = widget.initial.expiryTo;
  late BgUndertakingForm? _form = widget.initial.form;

  int _generation = 0;
  String? _error;

  void _clear() => setState(() {
        _applicant = '';
        _issuingBank = '';
        _issuingRef = '';
        _status = null;
        _currency = '';
        _from = '';
        _to = '';
        _issueFrom = null;
        _issueTo = null;
        _expiryFrom = null;
        _expiryTo = null;
        _form = null;
        _error = null;
        _generation++;
      });

  void _apply() {
    final from = double.tryParse(_from.trim());
    final to = double.tryParse(_to.trim());
    final error = bgRangeError(
      from: from,
      to: to,
      issueFrom: _issueFrom,
      issueTo: _issueTo,
      expiryFrom: _expiryFrom,
      expiryTo: _expiryTo,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(
      BgSearch(
        applicantName: _applicant,
        issuingBank: _issuingBank,
        issuingBankRefNo: _issuingRef,
        status: _status,
        currency: _currency,
        fromAmount: from,
        toAmount: to,
        issueFrom: _issueFrom,
        issueTo: _issueTo,
        expiryFrom: _expiryFrom,
        expiryTo: _expiryTo,
        form: _form,
        guaranteeNumber: widget.initial.guaranteeNumber,
        partyIds: widget.initial.partyIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noun = widget.category.noun;
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
                  'Filter inward ${widget.category.lowerNoun}s',
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
              LcTextField(
                label: 'Applicant name',
                initialValue: _applicant,
                maxLength: 40,
                onChanged: (v) => _applicant = v,
              ),
              TfChoiceGroup<BgStatus>(
                label: 'Inward $noun status',
                options: BgStatus.filterable,
                labelOf: (v) => v.label,
                selected: _status,
                onChanged: (v) => setState(() => _status = v),
              ),
              pair(
                LcTextField(
                  label: 'Issuing bank',
                  initialValue: _issuingBank,
                  maxLength: 40,
                  onChanged: (v) => _issuingBank = v,
                ),
                LcTextField(
                  label: 'Issuing bank reference no.',
                  initialValue: _issuingRef,
                  maxLength: 40,
                  onChanged: (v) => _issuingRef = v,
                ),
              ),
              BgAmountRange(
                currencies: widget.currencies,
                currency: _currency,
                from: _from,
                to: _to,
                onCurrency: (v) => setState(() => _currency = v),
                onFrom: (v) => _from = v,
                onTo: (v) => _to = v,
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
              TfChoiceGroup<BgUndertakingForm>(
                label: 'Transaction type',
                options: BgUndertakingForm.values,
                labelOf: (v) => v.label(widget.category),
                selected: _form,
                onChanged: (v) => setState(() => _form = v),
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
                  label: 'Apply',
                  icon: Icons.check_rounded,
                  onPressed: _apply,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Currency + from / to amount — "Undertaking Amount" on both the filter
/// and the Lodge Claim form. With no currency list (BG #39 came back
/// empty) the currency is typed.
class BgAmountRange extends StatelessWidget {
  const BgAmountRange({
    super.key,
    required this.currencies,
    required this.currency,
    required this.from,
    required this.to,
    required this.onCurrency,
    required this.onFrom,
    required this.onTo,
  });

  final List<TradeCode> currencies;
  final String currency;
  final String from;
  final String to;
  final ValueChanged<String> onCurrency;
  final ValueChanged<String> onFrom;
  final ValueChanged<String> onTo;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 480;
    TradeCode? selected;
    for (final c in currencies) {
      if (c.code == currency) selected = c;
    }
    final currencyField = currencies.isEmpty
        ? LcTextField(
            label: 'Currency',
            initialValue: currency,
            uppercase: true,
            maxLength: 3,
            onChanged: onCurrency,
          )
        : LcPickerField<TradeCode>(
            label: 'Currency',
            options: currencies,
            selected: selected,
            labelOf: (c) => c.code,
            subtitleOf: (c) => c.description ?? '',
            onSelected: (c) => onCurrency(c.code),
          );
    final fromField = LcTextField(
      label: 'Amount from',
      initialValue: from,
      numeric: true,
      onChanged: onFrom,
    );
    final toField = LcTextField(
      label: 'Amount to',
      initialValue: to,
      numeric: true,
      onChanged: onTo,
    );
    if (!wide) return Column(children: [currencyField, fromField, toField]);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: currencyField),
        const SizedBox(width: 12),
        Expanded(child: fromField),
        const SizedBox(width: 12),
        Expanded(child: toField),
      ],
    );
  }
}

String bgAmountText(double? v) {
  if (v == null) return '';
  return v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
}

/// The range checks both guarantee searches make before searching.
String? bgRangeError({
  double? from,
  double? to,
  DateTime? issueFrom,
  DateTime? issueTo,
  DateTime? expiryFrom,
  DateTime? expiryTo,
}) {
  if (from != null && to != null && from > to) {
    return 'The "from" amount is more than the "to" amount.';
  }
  if (issueFrom != null && issueTo != null && issueFrom.isAfter(issueTo)) {
    return 'The issue date range ends before it starts.';
  }
  if (expiryFrom != null && expiryTo != null && expiryFrom.isAfter(expiryTo)) {
    return 'The expiry date range ends before it starts.';
  }
  return null;
}
