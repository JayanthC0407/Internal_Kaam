import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/src/core/models/common/preferences/preferences_models.dart';
import 'package:ubci_bank/src/core/models/common/service_requests/service_request_models.dart';
import 'package:ubci_bank/src/core/models/corp/corp_loans_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_loans_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/widgets/preferences_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/loans/corp_loans_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/design_page.dart';

enum _Step { form, review, result }

/// One contract on the form.
class _Line {
  _Line(this.loan) : amount = TextEditingController(text: loan.outstanding?.amount.toStringAsFixed(2) ?? '');

  final CorpLoan loan;
  final TextEditingController amount;
  final dealReference = TextEditingController();
  bool selected = false;
  bool allocating = false;
  List<CorpRepaymentComponent>? components;
  String? allocationError;
  SrAccount? principal;
  SrAccount? interest;
  SrAccount? charges;
  String? error;

  double? get value => double.tryParse(amount.text.replaceAll(',', ''));

  CorpRepaymentLine toLine() {
    Map<String, dynamic>? id(SrAccount? a) => a == null ? null : {'value': a.value, 'displayValue': a.displayValue};
    return CorpRepaymentLine(
      loan: loan,
      amount: value!,
      principalAccount: id(principal)!,
      interestAccount: id(interest),
      chargesAccount: id(charges),
      dealReference: dealReference.text.trim().isEmpty ? null : dealReference.text.trim(),
      components: components ?? const [],
    );
  }

  void dispose() {
    amount.dispose();
    dealReference.dispose();
  }
}

/// Multiple Loan Repayment (OBDX flow `obcl-multi-loan-repayment`): a
/// Bulk Reference Number, the company, a filter and Get Contracts; tick the
/// contracts, set each one's Repayment Amount (Allocate shows how it is
/// split), Source Accounts and Deal Reference; review; confirm sends one
/// repayment per contract under the bulk reference and lists how each went.
class CorpMultiLoanRepaymentScreen extends ConsumerStatefulWidget {
  const CorpMultiLoanRepaymentScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<CorpMultiLoanRepaymentScreen> createState() => _CorpMultiLoanRepaymentScreenState();
}

class _CorpMultiLoanRepaymentScreenState extends ConsumerState<CorpMultiLoanRepaymentScreen> {
  _Step _step = _Step.form;
  String? _bulkReference;
  bool _bulkFailed = false;

  final _currency = TextEditingController();
  final _product = TextEditingController();
  final _amountFrom = TextEditingController();
  final _amountTo = TextEditingController();
  DateTime? _disbursedFrom;
  DateTime? _disbursedTo;
  DateTime? _maturityFrom;
  DateTime? _maturityTo;

  bool _loadingContracts = false;
  String? _contractsError;
  List<_Line>? _lines;
  String? _formError;

  bool _submitting = false;
  List<CorpRepaymentResult> _results = const [];

  @override
  void initState() {
    super.initState();
    _loadBulkReference();
  }

  @override
  void dispose() {
    for (final c in [_currency, _product, _amountFrom, _amountTo]) {
      c.dispose();
    }
    for (final l in _lines ?? const <_Line>[]) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _loadBulkReference() async {
    setState(() => _bulkFailed = false);
    final r = await ref.read(corpLoansRepositoryProvider).generateBulkReference();
    if (!mounted) return;
    setState(() {
      _bulkReference = r is Success<String> ? r.data : null;
      _bulkFailed = _bulkReference == null;
    });
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', ''));

  String? _text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _getContracts() async {
    setState(() {
      _loadingContracts = true;
      _contractsError = null;
      _formError = null;
    });
    final r = await ref.read(corpLoansRepositoryProvider).fetchContracts(
          CorpLoanContractFilter(
            currency: _text(_currency)?.toUpperCase(),
            product: _text(_product),
            amountFrom: _num(_amountFrom),
            amountTo: _num(_amountTo),
            disbursedFrom: _disbursedFrom,
            disbursedTo: _disbursedTo,
            maturityFrom: _maturityFrom,
            maturityTo: _maturityTo,
          ),
        );
    if (!mounted) return;
    setState(() {
      _loadingContracts = false;
      if (r is Success<List<CorpLoan>> && r.data != null) {
        for (final l in _lines ?? const <_Line>[]) {
          l.dispose();
        }
        _lines = [for (final l in r.data!) _Line(l)];
      } else {
        _contractsError = (r is Error<List<CorpLoan>> ? r.error : null) ?? 'Contracts could not be loaded.';
      }
    });
  }

  void _resetFilter() => setState(() {
        for (final c in [_currency, _product, _amountFrom, _amountTo]) {
          c.clear();
        }
        _disbursedFrom = _disbursedTo = _maturityFrom = _maturityTo = null;
      });

  Future<void> _allocate(_Line line) async {
    final amount = line.value;
    if (amount == null || amount <= 0) {
      setState(() => line.error = 'Please enter the repayment amount.');
      return;
    }
    setState(() {
      line.allocating = true;
      line.allocationError = null;
      line.error = null;
    });
    final r = await ref.read(corpLoansRepositoryProvider).fetchAllocation(line.loan, amount);
    if (!mounted) return;
    setState(() {
      line.allocating = false;
      if (r is Success<List<CorpRepaymentComponent>> && r.data != null) {
        line.components = r.data;
      } else {
        line.allocationError = (r is Error<List<CorpRepaymentComponent>> ? r.error : null) ?? 'The allocation could not be loaded.';
      }
    });
  }

  Future<void> _pickAccount(String title, SrAccount? selected, ValueChanged<SrAccount> onPicked) async {
    final accounts = ref.read(corpRepaymentSourceAccountsProvider).valueOrNull;
    if (accounts == null) return;
    final picked = await showPayPicker<String>(
      context,
      title: title,
      selected: selected?.value,
      empty: 'You have no accounts to pay from.',
      options: [for (final a in accounts) PayOption(value: a.value, title: a.displayValue, icon: Icons.account_balance_wallet_outlined)],
    );
    if (picked != null && mounted) setState(() => onPicked(accounts.firstWhere((a) => a.value == picked)));
  }

  Future<void> _pickDate(DateTime? current, ValueChanged<DateTime> onPicked) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? today,
      firstDate: DateTime(today.year - 30),
      lastDate: DateTime(today.year + 30),
    );
    if (picked != null && mounted) setState(() => onPicked(picked));
  }

  List<_Line> get _selected => [
        for (final l in _lines ?? const <_Line>[])
          if (l.selected) l
      ];

  void _continue() {
    var ok = _bulkReference != null;
    setState(() {
      _formError = _bulkReference == null
          ? 'The bulk reference number is not available yet.'
          : (_selected.isEmpty ? 'Please select at least one contract.' : null);
      for (final l in _selected) {
        final amount = l.value;
        l.error = amount == null || amount <= 0
            ? 'Please enter the repayment amount.'
            : (l.principal == null ? 'Please select the principal source account.' : null);
        if (l.error != null) ok = false;
      }
    });
    if (ok && _formError == null) setState(() => _step = _Step.review);
  }

  Future<void> _confirm() async {
    setState(() => _submitting = true);
    final repo = ref.read(corpLoansRepositoryProvider);
    final results = <CorpRepaymentResult>[];
    for (final l in _selected) {
      final line = l.toLine();
      final r = await runPrefWrite(context, (challenge, otp) => repo.repay(line, _bulkReference!, challenge: challenge, otp: otp));
      if (!mounted) return;
      if (r is Success<PrefWriteOutcome> && prefWriteDone(r)) {
        final outcome = r.data!;
        results.add(CorpRepaymentResult(
          loan: l.loan,
          status: outcome.pendingApproval ? 'pending' : 'success',
          reference: outcome.reference,
        ));
      } else {
        results.add(CorpRepaymentResult(
          loan: l.loan,
          status: 'failure',
          message: (r is Error<PrefWriteOutcome> ? r.error : null) ?? 'Cancelled.',
        ));
      }
    }
    setState(() {
      _submitting = false;
      _results = results;
      _step = _Step.result;
    });
  }

  // ── Form ──────────────────────────────────────────────────────────────

  Widget _info(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context))),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context))),
        ],
      );

  Widget _grid(bool wide, List<Widget> children) {
    final columns = wide ? 3 : 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i += columns) ...[
          if (i > 0) const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var j = 0; j < columns; j++) ...[
                if (j > 0) const SizedBox(width: 20),
                Expanded(child: i + j < children.length ? children[i + j] : const SizedBox.shrink()),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _dateBox(String label, DateTime? value, ValueChanged<DateTime> onPicked) => DesignBoxSelect(
        label: label,
        value: value == null ? null : payDate(value),
        placeholder: label,
        trailingIcon: Icons.calendar_month_outlined,
        onTap: () => _pickDate(value, onPicked),
      );

  Widget _header(bool wide) {
    final party = ref.watch(corpLoansPartyIdProvider);
    return DesignCard(
      child: _grid(wide, [
        _bulkFailed
            ? PayErrorRetry(message: 'The bulk reference number could not be generated.', onRetry: _loadBulkReference)
            : _info('Bulk Reference Number', _bulkReference ?? '…'),
        _info('Party ID', party.valueOrNull ?? (party.isLoading ? '…' : '-')),
      ]),
    );
  }

  Widget _filter(bool wide) {
    final amount = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    const numeric = TextInputType.numberWithOptions(decimal: true);
    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _grid(wide, [
            DesignBoxField(label: 'Currency', controller: _currency, hint: 'e.g. USD'),
            DesignBoxField(label: 'Loan Product', controller: _product, hint: 'Enter value'),
            const SizedBox.shrink(),
            DesignBoxField(label: 'Loan Amount From', controller: _amountFrom, keyboardType: numeric, inputFormatters: amount),
            DesignBoxField(label: 'Loan Amount To', controller: _amountTo, keyboardType: numeric, inputFormatters: amount),
            const SizedBox.shrink(),
            _dateBox('Disbursement From Date', _disbursedFrom, (d) => _disbursedFrom = d),
            _dateBox('Disbursement To Date', _disbursedTo, (d) => _disbursedTo = d),
            const SizedBox.shrink(),
            _dateBox('Maturity From Date', _maturityFrom, (d) => _maturityFrom = d),
            _dateBox('Maturity To Date', _maturityTo, (d) => _maturityTo = d),
          ]),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _resetFilter,
                style: TextButton.styleFrom(foregroundColor: HomeColors.brand(context)),
                child: const Text('Reset'),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 170,
                child: PayPrimaryButton(
                    label: 'Get Contracts', loading: _loadingContracts, onPressed: _loadingContracts ? null : _getContracts),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _components(List<CorpRepaymentComponent> rows, String currency) {
    final text = TextStyle(fontSize: 12.5, color: HomeColors.textPrimary(context));
    const flex = [2, 3, 2, 2, 2, 2];
    return Container(
      decoration: BoxDecoration(border: Border.all(color: HomeColors.divider(context)), borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CorpTableHeader(
                cells: ['Component', 'Component Description', 'Amount Due', 'Over Dues Days', 'Amount Paid', 'Tax Paid'],
                flex: flex,
              ),
              if (rows.isEmpty) const Padding(padding: EdgeInsets.all(14), child: Text('No components.')),
              for (final c in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(flex: flex[0], child: Text(c.component, style: text)),
                      Expanded(flex: flex[1], child: Text(c.description, style: text)),
                      Expanded(flex: flex[2], child: Text(corpMoney(c.due, currency), style: text)),
                      Expanded(flex: flex[3], child: Text('${c.overdueDays ?? '-'}', style: text)),
                      Expanded(flex: flex[4], child: Text(corpMoney(c.paid, currency), style: text)),
                      Expanded(flex: flex[5], child: Text(corpMoney(c.taxPaid, currency), style: text)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contract(bool wide, _Line l) {
    final accounts = ref.watch(corpRepaymentSourceAccountsProvider);
    Widget account(String label, SrAccount? value, ValueChanged<SrAccount> onPicked) => DesignBoxSelect(
          label: label,
          value: value?.displayValue,
          placeholder: 'Please Select',
          loading: accounts.isLoading,
          onTap: accounts.valueOrNull == null ? null : () => _pickAccount(label, value, onPicked),
        );
    final muted = TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context));
    return DesignCard(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Checkbox(
                value: l.selected,
                activeColor: HomeColors.brand(context),
                onChanged: (v) => setState(() {
                  l.selected = v ?? false;
                  _formError = null;
                }),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.loan.displayNumber,
                      style: TextStyle(fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
                    ),
                    if (l.loan.productName != null) Text(l.loan.productName!, style: muted),
                  ],
                ),
              ),
              if (wide) ...[
                SizedBox(width: 180, child: _info('Amount Financed', corpMoney(l.loan.approved, l.loan.currency))),
                SizedBox(width: 180, child: _info('Total Outstanding', corpMoney(l.loan.outstanding, l.loan.currency))),
              ],
            ],
          ),
          if (!wide)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 0, 0),
              child: Row(
                children: [
                  Expanded(child: _info('Amount Financed', corpMoney(l.loan.approved, l.loan.currency))),
                  Expanded(child: _info('Total Outstanding', corpMoney(l.loan.outstanding, l.loan.currency))),
                ],
              ),
            ),
          if (l.selected)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: DesignBoxField(
                          label: 'Repayment Amount',
                          controller: l.amount,
                          prefixText: '${l.loan.currency} ',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                          onChanged: (_) => setState(() => l.components = null),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child:
                            PaySecondaryButton(label: l.allocating ? '…' : 'Allocate', onPressed: l.allocating ? null : () => _allocate(l)),
                      ),
                    ],
                  ),
                  if (l.allocationError != null) Padding(padding: const EdgeInsets.only(top: 6), child: PayFieldError(l.allocationError)),
                  if (l.components != null) ...[const SizedBox(height: 12), _components(l.components!, l.loan.currency)],
                  const SizedBox(height: 14),
                  _grid(wide, [
                    account('Source Account (Principal)', l.principal, (a) => l.principal = a),
                    account('Source Account (Interest)', l.interest, (a) => l.interest = a),
                    account('Source Account (Charges)', l.charges, (a) => l.charges = a),
                    DesignBoxField(label: 'Deal Reference', controller: l.dealReference, hint: 'Enter value'),
                  ]),
                  if (accounts.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: corpFailed(accounts.error!, () => ref.invalidate(corpRepaymentSourceAccountsProvider),
                          fallback: 'Your accounts could not be loaded.'),
                    ),
                  if (l.error != null) Padding(padding: const EdgeInsets.only(top: 8), child: PayFieldError(l.error)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _lines!.remove(l..dispose())),
                      icon: Icon(Icons.delete_outline, color: HomeColors.error(context)),
                      label: Text('Delete', style: TextStyle(color: HomeColors.error(context))),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _form(bool wide) {
    final lines = _lines;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(wide),
        const SizedBox(height: 14),
        _filter(wide),
        if (_contractsError != null) ...[
          const SizedBox(height: 14),
          PayErrorRetry(message: _contractsError!, onRetry: _getContracts),
        ],
        if (lines != null) ...[
          const SizedBox(height: 18),
          const PaySectionLabel('Contracts'),
          const SizedBox(height: 8),
          if (lines.isEmpty) const DesignCard(child: CorpEmpty('No contracts match the filter.')),
          for (final l in lines) ...[_contract(wide, l), const SizedBox(height: 12)],
          if (_formError != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: PayFieldError(_formError)),
          if (lines.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onBack,
                  style: TextButton.styleFrom(foregroundColor: HomeColors.brand(context)),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 150, child: PayPrimaryButton(label: 'Continue', onPressed: _continue)),
              ],
            ),
        ],
      ],
    );
  }

  // ── Review ────────────────────────────────────────────────────────────

  Widget _review() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PayNote('You initiated a request for Multiple Loan Repayment', icon: Icons.info_outline),
          const SizedBox(height: 14),
          DesignCard(child: _info('Bulk Reference Number', _bulkReference ?? '-')),
          const SizedBox(height: 14),
          for (final l in _selected) ...[
            DesignCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PayReviewRow(label: 'Loan Account', value: l.loan.displayNumber),
                  PayReviewRow(label: 'Repayment Amount', value: payAmount(l.value, l.loan.currency)),
                  PayReviewRow(label: 'Source Account (Principal)', value: l.principal?.displayValue ?? '-'),
                  PayReviewRow(label: 'Source Account (Interest)', value: (l.interest ?? l.principal)?.displayValue ?? '-'),
                  PayReviewRow(label: 'Source Account (Charges)', value: (l.charges ?? l.principal)?.displayValue ?? '-'),
                  if (l.dealReference.text.trim().isNotEmpty) PayReviewRow(label: 'Deal Reference', value: l.dealReference.text.trim()),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _submitting ? null : () => setState(() => _step = _Step.form),
                style: TextButton.styleFrom(foregroundColor: HomeColors.brand(context)),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              SizedBox(
                  width: 150, child: PayPrimaryButton(label: 'Confirm', loading: _submitting, onPressed: _submitting ? null : _confirm)),
            ],
          ),
        ],
      );

  // ── Result ────────────────────────────────────────────────────────────

  Widget _result(bool wide) {
    (String, Color) status(CorpRepaymentResult r) => switch (r.status) {
          'success' => ('Success', HomeColors.success(context)),
          'pending' => ('Pending Approval', HomeColors.warning(context)),
          _ => ('Failure', HomeColors.error(context)),
        };
    final text = TextStyle(fontSize: 13, color: HomeColors.textPrimary(context));
    const flex = [3, 3, 3, 2];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesignCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide)
                const CorpTableHeader(cells: ['Loan Account', 'Bulk Reference Number', 'Host Reference Number', 'Status'], flex: flex),
              for (final r in _results)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: HomeColors.divider(context)))),
                  child: wide
                      ? Row(
                          children: [
                            Expanded(flex: flex[0], child: Text(r.loan.displayNumber, style: text)),
                            Expanded(flex: flex[1], child: Text(_bulkReference ?? '-', style: text)),
                            Expanded(flex: flex[2], child: Text(r.reference ?? '-', style: text)),
                            Expanded(
                              flex: flex[3],
                              child: Text(status(r).$1, style: text.copyWith(color: status(r).$2, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(r.loan.displayNumber, style: text.copyWith(fontWeight: FontWeight.w600))),
                                Text(status(r).$1, style: text.copyWith(color: status(r).$2, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Text('Host Reference Number: ${r.reference ?? '-'}',
                                style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context))),
                          ],
                        ),
                ),
              for (final r in _results.where((r) => r.message != null))
                Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 0), child: PayFieldError('${r.loan.displayNumber}: ${r.message}')),
              const SizedBox(height: 10),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Align(
            alignment: Alignment.centerRight,
            child: SizedBox(width: 150, child: PayPrimaryButton(label: 'Done', onPressed: widget.onBack))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => DesignPage(
        title: 'Multiple Loan Repayment',
        onBack: _step == _Step.review ? () => setState(() => _step = _Step.form) : widget.onBack,
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 720;
            return switch (_step) {
              _Step.form => _form(wide),
              _Step.review => _review(),
              _Step.result => _result(wide),
            };
          },
        ),
      );
}
