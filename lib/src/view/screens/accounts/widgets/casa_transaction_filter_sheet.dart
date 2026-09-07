import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/models/casa_transaction.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/view/screens/accounts/widgets/casa_shared_widgets.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/app_bottom_sheet.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_form_styles.dart';

class CasaTransactionFilterResult {
  const CasaTransactionFilterResult({
    required this.accountId,
    required this.query,
  });

  final String accountId;
  final CasaTransactionQuery query;
}

String casaPeriodLabel(AppLocalizations l10n, CasaTransactionPeriod period) {
  switch (period) {
    case CasaTransactionPeriod.currentMonth:
      return l10n.casaViewCurrentMonth;
    case CasaTransactionPeriod.specificDay:
      return l10n.casaViewSpecificDay;
    case CasaTransactionPeriod.previousDay:
      return l10n.casaViewPreviousDay;
    case CasaTransactionPeriod.dateRange:
      return l10n.casaViewDateRange;
    case CasaTransactionPeriod.previousMonth:
      return l10n.casaViewPreviousMonth;
    case CasaTransactionPeriod.previousQuarter:
      return l10n.casaViewPreviousQuarter;
    case CasaTransactionPeriod.last10:
      return l10n.casaViewLast10;
  }
}

String casaCreditDebitLabel(
  AppLocalizations l10n,
  CasaCreditDebitFilter filter,
) {
  switch (filter) {
    case CasaCreditDebitFilter.all:
      return l10n.casaFilterAll;
    case CasaCreditDebitFilter.credits:
      return l10n.casaFilterCreditsOnly;
    case CasaCreditDebitFilter.debits:
      return l10n.casaFilterDebitsOnly;
  }
}

/// Short "active filter" summary shown above the transaction list, e.g.
/// `Specific Day · Credits Only · Ref: INV1234`.
String casaFilterSummary(AppLocalizations l10n, CasaTransactionQuery query) {
  final parts = <String>[
    casaPeriodLabel(l10n, query.period),
    if (query.creditDebit != CasaCreditDebitFilter.all)
      casaCreditDebitLabel(l10n, query.creditDebit),
    if ((query.fromAmount ?? '').trim().isNotEmpty ||
        (query.toAmount ?? '').trim().isNotEmpty)
      '${query.fromAmount?.trim() ?? ''}–${query.toAmount?.trim() ?? ''}',
    if ((query.referenceNumber ?? '').trim().isNotEmpty)
      query.referenceNumber!.trim(),
  ];
  return parts.join('  ·  ');
}

Future<CasaTransactionFilterResult?> showCasaTransactionFilter({
  required BuildContext context,
  required List<CasaAccount> accounts,
  required String selectedAccountId,
  required CasaTransactionQuery query,
}) {
  return AppBottomSheet.custom<CasaTransactionFilterResult>(
    context: context,
    builder: (ctx) => _CasaTransactionFilterForm(
      accounts: accounts,
      selectedAccountId: selectedAccountId,
      query: query,
    ),
  );
}

class _CasaTransactionFilterForm extends StatefulWidget {
  const _CasaTransactionFilterForm({
    required this.accounts,
    required this.selectedAccountId,
    required this.query,
  });

  final List<CasaAccount> accounts;
  final String selectedAccountId;
  final CasaTransactionQuery query;

  @override
  State<_CasaTransactionFilterForm> createState() =>
      _CasaTransactionFilterFormState();
}

class _CasaTransactionFilterFormState extends State<_CasaTransactionFilterForm> {
  late String _accountId;
  late CasaTransactionPeriod _period;
  late CasaCreditDebitFilter _creditDebit;
  DateTime? _specificDate;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  late final TextEditingController _fromAmountController;
  late final TextEditingController _toAmountController;
  late final TextEditingController _referenceController;

  @override
  void initState() {
    super.initState();
    _accountId = widget.selectedAccountId;
    _period = widget.query.period;
    _creditDebit = widget.query.creditDebit;
    _specificDate = widget.query.specificDate;
    _rangeStart = widget.query.rangeStart;
    _rangeEnd = widget.query.rangeEnd;
    _fromAmountController =
        TextEditingController(text: widget.query.fromAmount ?? '');
    _toAmountController =
        TextEditingController(text: widget.query.toAmount ?? '');
    _referenceController =
        TextEditingController(text: widget.query.referenceNumber ?? '');
  }

  @override
  void dispose() {
    _fromAmountController.dispose();
    _toAmountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  bool get _needsSpecificDate => _period == CasaTransactionPeriod.specificDay;
  bool get _needsDateRange => _period == CasaTransactionPeriod.dateRange;

  CasaTransactionQuery _buildQuery() {
    return CasaTransactionQuery(
      period: _period,
      creditDebit: _creditDebit,
      specificDate: _needsSpecificDate ? _specificDate : null,
      rangeStart: _needsDateRange ? _rangeStart : null,
      rangeEnd: _needsDateRange ? _rangeEnd : null,
      fromAmount: _fromAmountController.text.trim().isEmpty
          ? null
          : _fromAmountController.text.trim(),
      toAmount: _toAmountController.text.trim().isEmpty
          ? null
          : _toAmountController.text.trim(),
      referenceNumber: _referenceController.text.trim().isEmpty
          ? null
          : _referenceController.text.trim(),
    );
  }

  void _apply() {
    Navigator.of(context).pop(
      CasaTransactionFilterResult(
        accountId: _accountId,
        query: _buildQuery(),
      ),
    );
  }

  void _reset() {
    Navigator.of(context).pop(
      CasaTransactionFilterResult(
        accountId: _accountId,
        query: const CasaTransactionQuery(),
      ),
    );
  }

  Future<void> _pickSpecificDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _specificDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _specificDate = picked);
  }

  Future<void> _pickRangeStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _rangeStart ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: _rangeEnd ?? now,
    );
    if (picked == null) return;
    setState(() {
      _rangeStart = picked;
      if (_rangeEnd != null && _rangeEnd!.isBefore(picked)) {
        _rangeEnd = picked;
      }
    });
  }

  Future<void> _pickRangeEnd() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _rangeEnd ?? now,
      firstDate: _rangeStart ?? DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _rangeEnd = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.filter,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: HomeColors.textPrimary(context),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.cancel,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: HomeColors.textSecondary(context),
                  ),
                ),
              ],
            ),
            _FieldLabel(label: l10n.casaAccountNumberLabel),
            const SizedBox(height: 8),
            CasaAccountDropdown(
              accounts: widget.accounts,
              selectedId: _accountId,
              onChanged: (id) {
                if (id == null || id.isEmpty) return;
                setState(() => _accountId = id);
              },
              enabledWhenSingle: true,
              showSubtitle: true,
            ),
            const SizedBox(height: 16),
            _FieldLabel(label: l10n.casaFilterViewOptions),
            const SizedBox(height: 8),
            _EnumDropdown<CasaTransactionPeriod>(
              value: _period,
              items: CasaTransactionPeriod.values,
              labelOf: (value) => casaPeriodLabel(l10n, value),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _period = value);
              },
            ),
            if (_needsSpecificDate) ...[
              const SizedBox(height: 16),
              _FieldLabel(label: l10n.casaFilterDate),
              const SizedBox(height: 8),
              _DateField(
                value: _specificDate,
                onTap: _pickSpecificDate,
              ),
            ],
            if (_needsDateRange) ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel(label: l10n.casaFilterFromDate),
                        const SizedBox(height: 8),
                        _DateField(value: _rangeStart, onTap: _pickRangeStart),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel(label: l10n.casaFilterToDate),
                        const SizedBox(height: 8),
                        _DateField(value: _rangeEnd, onTap: _pickRangeEnd),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _FieldLabel(label: l10n.casaFilterTransactions),
            const SizedBox(height: 8),
            _EnumDropdown<CasaCreditDebitFilter>(
              value: _creditDebit,
              items: CasaCreditDebitFilter.values,
              labelOf: (value) => casaCreditDebitLabel(l10n, value),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _creditDebit = value);
              },
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel(label: l10n.casaFilterFromAmount),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _fromAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: AuthFormStyles.inputDecoration(colors: colors),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel(label: l10n.casaFilterToAmount),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _toAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: AuthFormStyles.inputDecoration(colors: colors),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _FieldLabel(label: l10n.casaFilterReferenceNumber),
            const SizedBox(height: 8),
            TextField(
              controller: _referenceController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _apply(),
              decoration: AuthFormStyles.inputDecoration(colors: colors),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _apply,
                    style: FilledButton.styleFrom(
                      backgroundColor: HomeColors.brand(context),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: Text(l10n.casaFilterApply),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HomeColors.textPrimary(context),
                      side: BorderSide(color: HomeColors.divider(context)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: Text(l10n.casaFilterReset),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: HomeColors.textSecondary(context),
      ),
    );
  }
}

/// Read-only field that opens [showDatePicker] on tap. Shown inline (not
/// as a modal route) so it fits inside the filter sheet's own scroll view.
class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onTap});

  final DateTime? value;
  final VoidCallback onTap;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _label {
    final date = value;
    if (date == null) return '';
    final day = date.day.toString().padLeft(2, '0');
    return '$day ${_months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: HomeColors.card(context),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: HomeColors.divider(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: HomeColors.divider(context)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: value == null
                      ? HomeColors.textSecondary(context)
                      : HomeColors.textPrimary(context),
                ),
              ),
            ),
            Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: HomeColors.textSecondary(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnumDropdown<T> extends StatelessWidget {
  const _EnumDropdown({
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  final T value;
  final List<T> items;
  final String Function(T value) labelOf;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        filled: true,
        fillColor: HomeColors.card(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: HomeColors.divider(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: HomeColors.divider(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: HomeColors.brand(context), width: 1.2),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          isDense: true,
          value: value,
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item,
                child: Text(labelOf(item), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: HomeColors.textPrimary(context),
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: HomeColors.textSecondary(context),
          ),
          borderRadius: BorderRadius.circular(8),
          menuMaxHeight: 320,
        ),
      ),
    );
  }
}
