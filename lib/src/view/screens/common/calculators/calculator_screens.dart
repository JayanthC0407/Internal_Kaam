import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/calculators/calculator_models.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/common/calculator_providers.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/obdx_write_runner.dart';

/// The four OBDX calculators (docs/obdx/features/calculators.md). The server
/// does every calculation. The app asks again when a slider is let go or
/// typing pauses (decision 2b), and at once when the defaults load (1b).
/// Inputs are a slider and a number box kept in step: for amounts the box
/// leads, for tenure and rate the slider does.

/// Typing pause before a new calculation.
const _debounce = Duration(milliseconds: 400);

String _plain(double v, int decimals) {
  final s = v.toStringAsFixed(decimals);
  return decimals == 0 || !s.contains('.') ? s : s.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// A slider and a number box showing one value. [onChanged] follows every
/// move; [onCommit] fires when the slider is let go or typing pauses, with
/// the value kept inside [min]..[max].
class LinkedSliderField extends StatefulWidget {
  const LinkedSliderField({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onCommit,
    this.step = 1,
    this.decimals = 0,
    this.currency,
    this.suffix,
    this.boxFirst = false,
  });

  final String label;
  final double value;
  final double min;
  final double max;

  /// Slider step (OBDX: amounts 10, tenure 1, rates 1 percentage point).
  final double step;
  final int decimals;

  /// Amounts: the currency shown on the box.
  final String? currency;
  final String? suffix;

  /// Amounts: the box is the main control (full width, above the slider).
  final bool boxFirst;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onCommit;

  @override
  State<LinkedSliderField> createState() => _LinkedSliderFieldState();
}

class _LinkedSliderFieldState extends State<LinkedSliderField> {
  late final _text = TextEditingController(text: _plain(widget.value, widget.decimals));
  Timer? _timer;
  bool _outOfRange = false;

  /// The last change came from typing: the box keeps what was typed (a
  /// first digit below the minimum must not be replaced by the minimum).
  bool _fromBox = false;

  @override
  void didUpdateWidget(LinkedSliderField old) {
    super.didUpdateWidget(old);
    // The slider moved: keep the box in step.
    if (!_fromBox && old.value != widget.value) _text.text = _plain(widget.value, widget.decimals);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  double _clamp(double v) => v < widget.min ? widget.min : (v > widget.max ? widget.max : v);

  void _typed(String text) {
    _fromBox = true;
    final v = double.tryParse(text.replaceAll(',', ''));
    setState(() => _outOfRange = v != null && (v < widget.min || v > widget.max));
    _timer?.cancel();
    if (v == null) return;
    widget.onChanged(_clamp(v));
    _timer = Timer(_debounce, () {
      // The pause: an out-of-range entry becomes the nearest limit (still
      // flagged until the next edit).
      if (_outOfRange && mounted) _text.text = _plain(_clamp(v), widget.decimals);
      widget.onCommit(_clamp(v));
    });
  }

  void _slid(double v, {required bool end}) {
    _fromBox = false;
    _timer?.cancel();
    if (_outOfRange) setState(() => _outOfRange = false);
    end ? widget.onCommit(_stepped(v)) : widget.onChanged(_stepped(v));
  }

  double _stepped(double v) {
    if (widget.step <= 0) return v;
    final n = ((v - widget.min) / widget.step).round();
    return _clamp(widget.min + n * widget.step);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final secondary = HomeColors.textSecondary(context);
    final hint = l10n.calcRangeHint(_plain(widget.min, widget.decimals), _plain(widget.max, widget.decimals));
    final formatters = [
      FilteringTextInputFormatter.allow(RegExp(widget.decimals == 0 ? r'[0-9]' : r'[0-9.]')),
    ];

    final box = widget.currency != null
        ? PayAmountField(
            controller: _text,
            currency: widget.currency!,
            error: _outOfRange ? hint : null,
            onChanged: _typed,
            compact: true,
          )
        : SizedBox(
            width: 110,
            child: TextField(
              controller: _text,
              textAlign: TextAlign.end,
              keyboardType: TextInputType.numberWithOptions(decimal: widget.decimals > 0),
              inputFormatters: formatters,
              onChanged: _typed,
              decoration: InputDecoration(
                isDense: true,
                suffixText: widget.suffix,
                errorText: _outOfRange ? '' : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          );

    final span = widget.max - widget.min;
    final divisions = widget.step > 0 && span > 0 && span / widget.step <= 1000 ? (span / widget.step).round() : null;
    final slider = Slider(
      value: _clamp(widget.value),
      min: widget.min,
      max: widget.max <= widget.min ? widget.min + 1 : widget.max,
      divisions: divisions,
      label: _plain(widget.value, widget.decimals),
      onChanged: span <= 0 ? null : (v) => _slid(v, end: false),
      onChangeEnd: span <= 0 ? null : (v) => _slid(v, end: true),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.boxFirst) ...[
          PayFieldLabel(widget.label),
          box,
        ] else
          Row(
            children: [
              Expanded(child: PayFieldLabel(widget.label)),
              box,
            ],
          ),
        Semantics(label: widget.label, child: slider),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(_plain(widget.min, widget.decimals), style: TextStyle(fontSize: 11.5, color: secondary)),
              const Spacer(),
              if (_outOfRange && widget.currency == null)
                Text(hint, style: TextStyle(fontSize: 11.5, color: HomeColors.error(context))),
              const Spacer(),
              Text(_plain(widget.max, widget.decimals), style: TextStyle(fontSize: 11.5, color: secondary)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Calculation state shared by the four screens: one call at a time in
/// effect (an older answer arriving late is dropped), loading, error.
mixin _Calculation<W extends ConsumerStatefulWidget, T> on ConsumerState<W> {
  T? result;
  String? error;
  bool loading = false;
  int _request = 0;

  /// Runs [call] with OBDX's OTP / approval handling (decision 3a).
  Future<void> calculate(
    Future<ResponseHandler<CalcOutcome<T>>> Function(ObdxChallenge? challenge, String? otp) call,
  ) async {
    final l10n = AppLocalizations.of(context);
    final id = ++_request;
    setState(() {
      loading = true;
      error = null;
    });
    final r = await runWithOtp(context, call);
    if (!mounted || id != _request) return;
    setState(() {
      loading = false;
      if (obdxWriteDone(r)) {
        result = (r as Success<CalcOutcome<T>>).data!.result;
      } else if (r is! Success<CalcOutcome<T>>) {
        error = r.resolveUserMessage(l10n: l10n, fallback: l10n.calcFailed);
      }
    });
  }

  /// A local check stopped the call (OBDX shows the message, no request).
  void blocked(String message) => setState(() {
        _request++;
        loading = false;
        result = null;
        error = message;
      });
}

/// Fields on the left and the result on the right (web), or stacked (phone).
class _CalcPage extends StatelessWidget {
  const _CalcPage({required this.title, required this.onBack, required this.body});

  final String title;
  final VoidCallback? onBack;
  final Widget Function(bool wide) body;

  @override
  Widget build(BuildContext context) =>
      PayMenuPage(title: title, subtitle: AppLocalizations.of(context).calcTitle, onBack: onBack, builder: (_, wide) => body(wide));
}

Widget _split(bool wide, Widget fields, Widget result) => wide
    ? Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(flex: 3, child: fields), const SizedBox(width: 16), Expanded(flex: 2, child: result)],
      )
    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [fields, const SizedBox(height: 14), result]);

/// The result card: one or more labelled figures, a spinner while asking,
/// or the error with Retry.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.rows, required this.loading, required this.error, required this.onRetry});

  final List<(String, String)> rows;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final secondary = HomeColors.textSecondary(context);
    final message = error;
    if (!loading && message != null) {
      // A failed call can be retried; a local check (e.g. income ≤
      // expenses) only explains why nothing was asked.
      final retry = onRetry;
      return retry != null
          ? PayErrorRetry(message: message, onRetry: retry)
          : PayCard(child: Text(message, style: TextStyle(color: HomeColors.error(context), height: 1.4)));
    }
    return PayCard(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: loading
            ? const Padding(
                key: ValueKey('loading'),
                padding: EdgeInsets.all(18),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                    key: ValueKey(rows.map((r) => r.$2).join()),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, (label, value)) in rows.indexed) ...[
                        if (i > 0) const SizedBox(height: 14),
                        Text(label, style: TextStyle(fontSize: 13, color: secondary)),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: TextStyle(fontSize: i == 0 ? 26 : 16, fontWeight: FontWeight.w700, color: i == 0 ? brand : HomeColors.textPrimary(context)),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }
}

String _money(MoneyAmount? m, String fallbackCurrency) =>
    m == null ? '-' : MoneyFormat.format(m.amount, currencyCode: m.currency ?? fallbackCurrency);

Widget _loading() => const PayCard(child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())));

Widget _loadFailed(BuildContext context, Object e, VoidCallback retry) => PayErrorRetry(
      message: e is CalcLoadError && e.message != null ? e.message! : AppLocalizations.of(context).calcLoadFailed,
      onRetry: retry,
    );

// ── Term Deposit Calculator ──

class TdCalculatorScreen extends ConsumerStatefulWidget {
  const TdCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<TdCalculatorScreen> createState() => _TdCalculatorScreenState();
}

class _TdCalculatorScreenState extends ConsumerState<TdCalculatorScreen> with _Calculation<TdCalculatorScreen, TdMaturity> {
  final _amount = TextEditingController();
  final _years = TextEditingController(text: '1');
  final _months = TextEditingController(text: '0');
  final _days = TextEditingController(text: '0');

  /// Percent; OBDX starts empty and asks for it ("Please enter valid Interest").
  double _interest = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_amount, _years, _months, _days]) {
      c.dispose();
    }
    super.dispose();
  }

  int _int(TextEditingController c) => int.tryParse(c.text) ?? 0;
  double get _amountValue => double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;

  void _later() {
    _timer?.cancel();
    _timer = Timer(_debounce, _run);
  }

  void _run() {
    final ccy = ref.read(calcLocalCurrencyProvider).valueOrNull;
    if (ccy == null || _amountValue <= 0) return;
    if (_interest <= 0) return blocked(AppLocalizations.of(context).calcEnterValidInterest);
    final body = tdMaturityBody(
      currency: ccy,
      amount: _amountValue,
      years: _int(_years),
      months: _int(_months),
      days: _int(_days),
      interestPercent: _interest,
    );
    final repo = ref.read(calculatorsRepositoryProvider);
    calculate((c, otp) => repo.tdMaturity(body, challenge: c, otp: otp));
  }

  /// − / + in steps of 0.25%, as OBDX (minus stops at 1%; hooks.js:87-103).
  void _nudge(double delta) {
    final next = (_interest + delta).clamp(0.0, 25.0);
    if (delta < 0 && _interest <= 1) return;
    setState(() => _interest = (next * 100).roundToDouble() / 100);
    _run();
  }

  Widget _tenureBox(String label, TextEditingController c, int max) => Expanded(
        child: TextField(
          controller: c,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, _MaxIntFormatter(max)],
          onChanged: (_) => _later(),
          decoration: InputDecoration(
            labelText: label,
            helperText: '0 - $max',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _CalcPage(
      title: l10n.calcTd,
      onBack: widget.onBack,
      body: (wide) => ref.watch(calcLocalCurrencyProvider).when(
            loading: _loading,
            error: (e, _) => _loadFailed(context, e, () => ref.invalidate(calcLocalCurrencyProvider)),
            data: (ccy) => _split(
              wide,
              PayCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PayFieldLabel(l10n.calcDepositAmount, required: true),
                    PayAmountField(controller: _amount, currency: ccy, onChanged: (_) => _later()),
                    const SizedBox(height: 16),
                    PayFieldLabel(l10n.calcDepositTenure),
                    Row(
                      children: [
                        _tenureBox(l10n.calcYears, _years, 120),
                        const SizedBox(width: 10),
                        _tenureBox(l10n.calcMonths, _months, 12),
                        const SizedBox(width: 10),
                        _tenureBox(l10n.calcDays, _days, 31),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinkedSliderField(
                      label: l10n.calcInterestRate,
                      value: _interest,
                      min: 0,
                      max: 25,
                      step: 0.25,
                      decimals: 2,
                      suffix: '%',
                      onChanged: (v) => setState(() => _interest = v),
                      onCommit: (v) {
                        setState(() => _interest = v);
                        _run();
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.outlined(tooltip: l10n.calcDecrease, onPressed: () => _nudge(-0.25), icon: const Icon(Icons.remove)),
                        const SizedBox(width: 16),
                        IconButton.outlined(tooltip: l10n.calcIncrease, onPressed: () => _nudge(0.25), icon: const Icon(Icons.add)),
                      ],
                    ),
                  ],
                ),
              ),
              _ResultCard(
                rows: [(l10n.calcMaturityAmount, _money(result?.maturityAmount, ccy))],
                loading: loading,
                error: error,
                onRetry: error == null ? null : _run,
              ),
            ),
          ),
    );
  }
}

/// Keeps a whole number at or below [max] (OBDX's input ranges).
class _MaxIntFormatter extends TextInputFormatter {
  const _MaxIntFormatter(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final v = int.tryParse(newValue.text);
    return v != null && v > max ? oldValue : newValue;
  }
}

// ── Loan Installment Calculator ──

class LoanInstallmentScreen extends ConsumerStatefulWidget {
  const LoanInstallmentScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<LoanInstallmentScreen> createState() => _LoanInstallmentScreenState();
}

class _LoanInstallmentScreenState extends ConsumerState<LoanInstallmentScreen>
    with _Calculation<LoanInstallmentScreen, LoanInstallment> {
  double? _principal;
  double? _tenure;
  double? _interest;

  void _run(String ccy) {
    final repo = ref.read(calculatorsRepositoryProvider);
    final body = loanScheduleBody(
      currency: ccy,
      principal: _principal!,
      years: _tenure!.round(),
      interestPercent: _interest!,
    );
    calculate((c, otp) => repo.loanInstallment(body, challenge: c, otp: otp));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ccy = ref.watch(calcLocalCurrencyProvider);
    final ranges = ref.watch(calcRangesProvider(CalcKind.loanInstallment));
    return _CalcPage(
      title: l10n.calcLoanInstallment,
      onBack: widget.onBack,
      body: (wide) {
        if (ccy.hasError) return _loadFailed(context, ccy.error!, () => ref.invalidate(calcLocalCurrencyProvider));
        if (ranges.hasError) {
          return _loadFailed(context, ranges.error!, () => ref.invalidate(calcRangesProvider(CalcKind.loanInstallment)));
        }
        final currency = ccy.valueOrNull;
        final r = ranges.valueOrNull;
        if (currency == null || r == null) return _loading();
        final amount = r['PRINCIPALAMOUNT']!, tenure = r['TENURE']!, rate = r['INTERESTRATE']!;
        if (_principal == null) {
          // Defaults loaded: show a result at once (decision 1b).
          _principal = amount.defaultValue;
          _tenure = tenure.defaultValue;
          _interest = rate.defaultValue;
          WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _run(currency) : null);
        }
        return _split(
          wide,
          PayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinkedSliderField(
                  label: l10n.calcLoanAmount,
                  value: _principal!,
                  min: amount.min,
                  max: amount.max,
                  step: 10,
                  currency: currency,
                  boxFirst: true,
                  onChanged: (v) => setState(() => _principal = v),
                  onCommit: (v) {
                    setState(() => _principal = v);
                    _run(currency);
                  },
                ),
                const SizedBox(height: 12),
                LinkedSliderField(
                  label: l10n.calcLoanTenureYears,
                  value: _tenure!,
                  min: tenure.min,
                  max: tenure.max,
                  onChanged: (v) => setState(() => _tenure = v),
                  onCommit: (v) {
                    setState(() => _tenure = v);
                    _run(currency);
                  },
                ),
                const SizedBox(height: 12),
                LinkedSliderField(
                  label: l10n.calcInterestRate,
                  value: _interest!,
                  min: rate.min,
                  max: rate.max,
                  decimals: 2,
                  suffix: '%',
                  onChanged: (v) => setState(() => _interest = v),
                  onCommit: (v) {
                    setState(() => _interest = v);
                    _run(currency);
                  },
                ),
              ],
            ),
          ),
          _ResultCard(
            rows: [(l10n.calcInstallmentAmount, _money(result?.installment, currency))],
            loading: loading,
            error: error,
            onRetry: error == null ? null : () => _run(currency),
          ),
        );
      },
    );
  }
}

// ── Loan Eligibility Calculator ──

class LoanEligibilityScreen extends ConsumerStatefulWidget {
  const LoanEligibilityScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<LoanEligibilityScreen> createState() => _LoanEligibilityScreenState();
}

class _LoanEligibilityScreenState extends ConsumerState<LoanEligibilityScreen>
    with _Calculation<LoanEligibilityScreen, LoanEligibility> {
  double? _income;
  double? _expenses;
  double? _tenure;
  double? _interest;

  void _run(String ccy) {
    // OBDX makes no call when income ≤ expenses (hooks.js:216-218).
    if (!eligibilityInputsValid(_income!, _expenses!)) return blocked(AppLocalizations.of(context).calcExpensesHigh);
    final repo = ref.read(calculatorsRepositoryProvider);
    final body = loanEligibilityBody(
      currency: ccy,
      monthlyIncome: _income!,
      monthlyExpenses: _expenses!,
      years: _tenure!.round(),
      interestPercent: _interest!,
    );
    calculate((c, otp) => repo.loanEligibility(body, challenge: c, otp: otp));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ccy = ref.watch(calcLocalCurrencyProvider);
    final ranges = ref.watch(calcRangesProvider(CalcKind.loanEligibility));
    return _CalcPage(
      title: l10n.calcLoanEligibility,
      onBack: widget.onBack,
      body: (wide) {
        if (ccy.hasError) return _loadFailed(context, ccy.error!, () => ref.invalidate(calcLocalCurrencyProvider));
        if (ranges.hasError) {
          return _loadFailed(context, ranges.error!, () => ref.invalidate(calcRangesProvider(CalcKind.loanEligibility)));
        }
        final currency = ccy.valueOrNull;
        final r = ranges.valueOrNull;
        if (currency == null || r == null) return _loading();
        final income = r['GROSSMONTHLYINCOME']!, expenses = r['MONTHLYEXPENSES']!, tenure = r['TENURE']!, rate = r['INTERESTRATE']!;
        if (_income == null) {
          _income = income.defaultValue;
          _expenses = expenses.defaultValue;
          _tenure = tenure.defaultValue;
          _interest = rate.defaultValue;
          WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _run(currency) : null);
        }
        void commit(VoidCallback set) {
          setState(set);
          _run(currency);
        }

        final monthly = result?.monthlyInstallment;
        return _split(
          wide,
          PayCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinkedSliderField(
                  label: l10n.calcGrossIncome,
                  value: _income!,
                  min: income.min,
                  max: income.max,
                  step: 10,
                  currency: currency,
                  boxFirst: true,
                  onChanged: (v) => setState(() => _income = v),
                  onCommit: (v) => commit(() => _income = v),
                ),
                const SizedBox(height: 12),
                LinkedSliderField(
                  label: l10n.calcTotalExpenses,
                  value: _expenses!,
                  min: expenses.min,
                  max: expenses.max,
                  step: 10,
                  currency: currency,
                  boxFirst: true,
                  onChanged: (v) => setState(() => _expenses = v),
                  onCommit: (v) => commit(() => _expenses = v),
                ),
                const SizedBox(height: 12),
                LinkedSliderField(
                  label: l10n.calcLoanTenureYears,
                  value: _tenure!,
                  min: tenure.min,
                  max: tenure.max,
                  onChanged: (v) => setState(() => _tenure = v),
                  onCommit: (v) => commit(() => _tenure = v),
                ),
                const SizedBox(height: 12),
                LinkedSliderField(
                  label: l10n.calcInterestRateIn,
                  value: _interest!,
                  min: rate.min,
                  max: rate.max,
                  decimals: 2,
                  suffix: '%',
                  onChanged: (v) => setState(() => _interest = v),
                  onCommit: (v) => commit(() => _interest = v),
                ),
              ],
            ),
          ),
          _ResultCard(
            rows: [
              (l10n.calcEligibleAmount, _money(result?.eligibleAmount, currency)),
              (l10n.calcAverageInstallment, monthly == null ? '-' : l10n.calcPerMonth(_money(monthly, currency))),
            ],
            loading: loading,
            error: error,
            onRetry: error == null ? null : () => _run(currency),
          ),
        );
      },
    );
  }
}

// ── Forex Calculator ──

class ForexCalculatorScreen extends ConsumerStatefulWidget {
  const ForexCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<ForexCalculatorScreen> createState() => _ForexCalculatorScreenState();
}

class _ForexCalculatorScreenState extends ConsumerState<ForexCalculatorScreen>
    with _Calculation<ForexCalculatorScreen, ForexQuote> {
  final _amount = TextEditingController(text: '1');
  String? _from;
  String? _to;

  /// OBDX multiplies the user's Amount by 1000 when the result is below
  /// 0.01 and asks again; the app shows the result for the amount typed
  /// (decision 4b).
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _amount.dispose();
    super.dispose();
  }

  double get _amountValue => double.tryParse(_amount.text.replaceAll(',', '')) ?? 0;

  void _run() {
    final l10n = AppLocalizations.of(context);
    if (_from == null || _to == null) return;
    if (_amountValue <= 0) return blocked(l10n.calcValidAmount);
    final repo = ref.read(calculatorsRepositoryProvider);
    final amount = _amountValue;
    final body = forexBody(from: _from!, to: _to!, amount: amount);
    calculate((c, otp) => repo.forex(body, challenge: c, otp: otp));
  }

  Future<void> _pick(String title, List<String> options, String? selected, ValueChanged<String> onPicked) async {
    final picked = await showPayPicker<String>(
      context,
      title: title,
      selected: selected,
      options: [for (final o in options) PayOption(value: o, title: o, icon: Icons.currency_exchange_rounded)],
    );
    if (picked != null && mounted) onPicked(picked);
  }

  String _rate(double v) => _plain(v, 6);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _CalcPage(
      title: l10n.calcForex,
      onBack: widget.onBack,
      body: (wide) => ref.watch(forexPairsProvider).when(
            loading: _loading,
            error: (e, _) => _loadFailed(context, e, () => ref.invalidate(forexPairsProvider)),
            data: (pairs) {
              final q = result;
              return _split(
                wide,
                PayCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PayFieldLabel(l10n.calcFromCurrency, required: true),
                      PayPickerField(
                        placeholder: l10n.calcForeignCurrency,
                        title: _from,
                        icon: Icons.currency_exchange_rounded,
                        onTap: () => _pick(l10n.calcFromCurrency, pairs.fromCurrencies, _from, (v) {
                          // OBDX: a new From resets Amount to 1 and clears To.
                          setState(() {
                            _from = v;
                            _to = null;
                            _amount.text = '1';
                            result = null;
                            error = null;
                          });
                        }),
                      ),
                      const SizedBox(height: 14),
                      PayFieldLabel(l10n.calcAmount, required: true),
                      PayAmountField(
                        controller: _amount,
                        currency: _from ?? '',
                        onChanged: (_) {
                          _timer?.cancel();
                          _timer = Timer(_debounce, _run);
                        },
                      ),
                      const SizedBox(height: 14),
                      PayFieldLabel(l10n.calcToCurrency, required: true),
                      PayPickerField(
                        placeholder: l10n.calcForeignCurrency,
                        title: _to,
                        icon: Icons.currency_exchange_rounded,
                        onTap: _from == null
                            ? null
                            : () => _pick(l10n.calcToCurrency, pairs.toFor(_from!), _to, (v) {
                                  setState(() => _to = v);
                                  _run();
                                }),
                      ),
                    ],
                  ),
                ),
                _from == null || _to == null
                    ? PayCard(child: PayMuted(l10n.calcSelectCurrency))
                    : _ResultCard(
                        rows: [
                          (
                            l10n.calcAmount,
                            q == null ? '-' : MoneyFormat.format(q.converted, currencyCode: _to!),
                          ),
                          if (q != null) ('', l10n.calcRate(_from!, _rate(q.rate), _to!)),
                          if (q != null) ('', l10n.calcRate(_to!, _rate(q.reverseRate), _from!)),
                        ],
                        loading: loading,
                        error: error,
                        onRetry: error == null ? null : _run,
                      ),
              );
            },
          ),
    );
  }
}
