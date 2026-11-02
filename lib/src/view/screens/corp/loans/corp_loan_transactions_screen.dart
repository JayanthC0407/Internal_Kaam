import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:demo_bank/src/core/models/corp/corp_loans_models.dart';
import 'package:demo_bank/src/view/providers/corp/corp_loans_providers.dart';
import 'package:demo_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:demo_bank/src/view/screens/corp/loans/corp_loans_widgets.dart';
import 'package:demo_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:demo_bank/src/view/widgets/design_page.dart';

const _periodLabels = {
  CorpLoanPeriod.currentMonth: 'Current Month',
  CorpLoanPeriod.currentDay: 'Current Day',
  CorpLoanPeriod.previousDay: 'Previous Day',
  CorpLoanPeriod.previousMonth: 'Previous Month',
  CorpLoanPeriod.currentAndPreviousMonth: 'Current & Previous Month',
  CorpLoanPeriod.previousQuarter: 'Previous Quarter',
  CorpLoanPeriod.dateRange: 'Date Range',
  CorpLoanPeriod.lastTen: 'Last 10 Transactions',
};

const _typeLabels = {
  CorpLoanTxnType.all: 'All',
  CorpLoanTxnType.credits: 'Credits Only',
  CorpLoanTxnType.debits: 'Debits Only',
};

/// Corporate Loans Transactions (OBDX `loans/obcl-loan-transactions`, CORP
/// segment): Loan Account, View Options (Current Month by default; From /
/// To Date for Date Range), Transactions (All / Credits / Debits), Amount
/// and Party Reference Number; Apply shows the statement, the filter
/// reopens the search.
class CorpLoanTransactionsScreen extends ConsumerStatefulWidget {
  const CorpLoanTransactionsScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<CorpLoanTransactionsScreen> createState() => _CorpLoanTransactionsScreenState();
}

class _CorpLoanTransactionsScreenState extends ConsumerState<CorpLoanTransactionsScreen> {
  CorpLoan? _loan;
  CorpLoanPeriod _period = CorpLoanPeriod.currentMonth;
  CorpLoanTxnType _type = CorpLoanTxnType.all;
  DateTime? _from;
  DateTime? _to;
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  String? _loanError;
  String? _fromError;
  String? _toError;

  /// The applied search; null shows the form.
  (CorpLoan, CorpLoanTxnQuery)? _applied;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  void _apply() {
    setState(() {
      _loanError = _loan == null ? 'Please select a loan account.' : null;
      final range = _period == CorpLoanPeriod.dateRange;
      _fromError = range && _from == null ? 'Please select From Date.' : null;
      _toError = range && _to == null
          ? 'Please select To Date.'
          : (range && _from != null && _to!.isBefore(_from!) ? 'To Date cannot be before From Date.' : null);
    });
    if (_loanError != null || _fromError != null || _toError != null) return;
    final amount = double.tryParse(_amount.text.replaceAll(',', ''));
    setState(() => _applied = (
          _loan!,
          CorpLoanTxnQuery(
            period: _period,
            type: _type,
            from: _from,
            to: _to,
            amount: amount,
            reference: _reference.text.trim().isEmpty ? null : _reference.text.trim(),
          ),
        ));
  }

  void _reset() => setState(() {
        _period = CorpLoanPeriod.currentMonth;
        _type = CorpLoanTxnType.all;
        _from = null;
        _to = null;
        _amount.clear();
        _reference.clear();
        _fromError = null;
        _toError = null;
      });

  Future<void> _pick<T>(String title, Map<T, String> options, T selected, ValueChanged<T> onPicked) async {
    final picked = await showPayPicker<T>(
      context,
      title: title,
      selected: selected,
      options: [for (final e in options.entries) PayOption(value: e.key, title: e.value)],
    );
    if (picked != null && mounted) setState(() => onPicked(picked));
  }

  Future<void> _date({required bool from}) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? today,
      firstDate: from ? DateTime(today.year - 10) : (_from ?? DateTime(today.year - 10)),
      lastDate: from ? (_to ?? today) : today,
    );
    if (picked != null && mounted) setState(() => from ? (_from = picked, _fromError = null) : (_to = picked, _toError = null));
  }

  Widget _form(bool wide) {
    Widget pair(Widget a, Widget b) => wide
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 24), Expanded(child: b)])
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 12), b]);
    Widget withError(Widget field, String? error) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [field, if (error != null) Padding(padding: const EdgeInsets.only(top: 4), child: PayFieldError(error))],
        );
    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          withError(
            CorpLoanAccountField(
                selected: _loan,
                onChanged: (l) => setState(() {
                      _loan = l;
                      _loanError = null;
                    })),
            _loanError,
          ),
          const SizedBox(height: 16),
          pair(
            DesignBoxSelect(
              label: 'View Options',
              value: _periodLabels[_period],
              onTap: () => _pick('View Options', _periodLabels, _period, (v) => _period = v),
            ),
            DesignBoxSelect(
              label: 'Transactions',
              value: _typeLabels[_type],
              onTap: () => _pick('Transactions', _typeLabels, _type, (v) => _type = v),
            ),
          ),
          if (_period == CorpLoanPeriod.dateRange) ...[
            const SizedBox(height: 16),
            pair(
              withError(
                DesignBoxSelect(
                  label: 'From Date',
                  value: _from == null ? null : payDate(_from),
                  placeholder: 'From Date',
                  trailingIcon: Icons.calendar_month_outlined,
                  onTap: () => _date(from: true),
                ),
                _fromError,
              ),
              withError(
                DesignBoxSelect(
                  label: 'To Date',
                  value: _to == null ? null : payDate(_to),
                  placeholder: 'To Date',
                  trailingIcon: Icons.calendar_month_outlined,
                  onTap: () => _date(from: false),
                ),
                _toError,
              ),
            ),
          ],
          const SizedBox(height: 16),
          pair(
            DesignBoxField(
              label: 'Amount',
              controller: _amount,
              hint: 'Enter value',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            ),
            DesignBoxField(label: 'Party Reference Number', controller: _reference, hint: 'Enter value'),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _reset,
                style: TextButton.styleFrom(foregroundColor: HomeColors.brand(context)),
                child: const Text('Reset'),
              ),
              const SizedBox(width: 12),
              SizedBox(width: 150, child: PayPrimaryButton(label: 'Apply', onPressed: _apply)),
            ],
          ),
        ],
      ),
    );
  }

  /// OBDX's filter strip: account, period, type, amount, reference.
  Widget _summary(CorpLoan loan, CorpLoanTxnQuery q) {
    final parts = [
      loan.displayNumber,
      q.period == CorpLoanPeriod.dateRange && q.from != null && q.to != null
          ? '${payDate(q.from)} - ${payDate(q.to)}'
          : _periodLabels[q.period]!,
      _typeLabels[q.type]!,
      if (q.amount != null) q.amount!.toStringAsFixed(2),
      if (q.reference != null) q.reference!,
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      color: HomeColors.brand(context).withValues(alpha: 0.12),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 36,
              runSpacing: 6,
              children: [
                for (final (i, p) in parts.indexed)
                  Text(
                    p,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: i == 0 ? HomeColors.brand(context) : HomeColors.textPrimary(context),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Filter',
            icon: Icon(Icons.filter_list_rounded, color: HomeColors.brand(context)),
            onPressed: () => setState(() => _applied = null),
          ),
        ],
      ),
    );
  }

  Widget _results(bool wide, CorpLoan loan, CorpLoanTxnQuery q) => ref.watch(corpLoanTransactionsProvider((loan.id, q))).when(
        loading: corpLoading,
        error: (e, _) => corpFailed(e, () => ref.invalidate(corpLoanTransactionsProvider((loan.id, q)))),
        data: (data) {
          final rows = data.items;
          if (rows.isEmpty) return const DesignCard(child: CorpEmpty('No Activity found for the specified period.'));
          final flex = [3, if (data.showValueDate) 3, 5, 4, 3, 3];
          final heads = [
            'Transaction Date',
            if (data.showValueDate) 'Value Date',
            'Description',
            'Reference Number',
            'Transaction Type',
            'Amount',
          ];
          final text = TextStyle(fontSize: 13, color: HomeColors.textPrimary(context));
          return DesignCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (wide) CorpTableHeader(cells: heads, flex: flex),
                for (final (i, t) in rows.indexed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: i == rows.length - 1 ? null : Border(bottom: BorderSide(color: HomeColors.divider(context))),
                    ),
                    child: wide
                        ? Row(
                            children: [
                              Expanded(flex: 3, child: Text(payDate(t.date), style: text)),
                              if (data.showValueDate) Expanded(flex: 3, child: Text(payDate(t.valueDate), style: text)),
                              Expanded(flex: 5, child: Text(t.description, style: text)),
                              Expanded(flex: 4, child: Text(t.reference.isEmpty ? '-' : t.reference, style: text)),
                              Expanded(flex: 3, child: Text(t.isCredit ? 'Credit' : 'Debit', style: text)),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  corpMoney(t.amount, loan.currency),
                                  style: text.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: t.isCredit ? HomeColors.success(context) : HomeColors.textPrimary(context),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.description, style: text.copyWith(fontWeight: FontWeight.w600)),
                                    Text(
                                      '${payDate(t.date)}${t.reference.isEmpty ? '' : ' · ${t.reference}'}',
                                      style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context)),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${corpMoney(t.amount, loan.currency)} ${t.isCredit ? 'Cr' : 'Dr'}',
                                style: text.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: t.isCredit ? HomeColors.success(context) : HomeColors.textPrimary(context),
                                ),
                              ),
                            ],
                          ),
                  ),
              ],
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final applied = _applied;
    return DesignPage(
      title: 'Corporate Loans Transactions',
      onBack: widget.onBack,
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 720;
          if (applied == null) return _form(wide);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_summary(applied.$1, applied.$2), const SizedBox(height: 14), _results(wide, applied.$1, applied.$2)],
          );
        },
      ),
    );
  }
}
