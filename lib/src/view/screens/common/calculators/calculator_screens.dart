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
import 'package:ubci_bank/src/view/widgets/design_page.dart';
import 'package:ubci_bank/src/view/widgets/obdx_write_runner.dart';

/// The four OBDX calculators (docs/obdx/features/calculators.md) on one
/// "Financial Calculator" page, a tab each, in the app's design: boxed
/// fields, and the result in a tinted panel. The server does every
/// calculation. The app asks again when typing pauses (decision 2b), and
/// at once when the defaults load (1b).

/// Typing pause before a new calculation.
const _debounce = Duration(milliseconds: 400);

String _plain(double v, int decimals) {
  final s = v.toStringAsFixed(decimals);
  return decimals == 0 || !s.contains('.') ? s : s.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// The four tabs, in the design's order.
enum CalcTab { termDeposit, loanInstallment, loanEligibility, forex }

class FinancialCalculatorScreen extends StatefulWidget {
  const FinancialCalculatorScreen({super.key, this.initialTab = CalcTab.termDeposit, this.onBack});

  final CalcTab initialTab;
  final VoidCallback? onBack;

  @override
  State<FinancialCalculatorScreen> createState() => _FinancialCalculatorScreenState();
}

class _FinancialCalculatorScreenState extends State<FinancialCalculatorScreen> {
  late CalcTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DesignPage(
      title: l10n.fcTitle,
      onBack: widget.onBack,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Tabs(selected: _tab, onSelect: (t) => setState(() => _tab = t)),
          const SizedBox(height: 28),
          // Each calculator keeps its own state while it is shown.
          KeyedSubtree(
            key: ValueKey(_tab),
            child: switch (_tab) {
              CalcTab.termDeposit => const _TdCalculator(),
              CalcTab.loanInstallment => const _LoanInstallmentCalculator(),
              CalcTab.loanEligibility => const _LoanEligibilityCalculator(),
              CalcTab.forex => const _ForexCalculator(),
            },
          ),
        ],
      ),
    );
  }
}

/// Opens Financial Calculator on Term Deposit (the old page's name).
class TdCalculatorScreen extends StatelessWidget {
  const TdCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => FinancialCalculatorScreen(onBack: onBack);
}

/// Opens Financial Calculator on Loan Installment.
class LoanInstallmentScreen extends StatelessWidget {
  const LoanInstallmentScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => FinancialCalculatorScreen(initialTab: CalcTab.loanInstallment, onBack: onBack);
}

/// Opens Financial Calculator on Loan Eligibility.
class LoanEligibilityScreen extends StatelessWidget {
  const LoanEligibilityScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => FinancialCalculatorScreen(initialTab: CalcTab.loanEligibility, onBack: onBack);
}

/// Opens Financial Calculator on Forex.
class ForexCalculatorScreen extends StatelessWidget {
  const ForexCalculatorScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => FinancialCalculatorScreen(initialTab: CalcTab.forex, onBack: onBack);
}

/// The tab strip: equal tabs in a bordered bar, the chosen one tinted.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelect});

  final CalcTab selected;
  final ValueChanged<CalcTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brand = HomeColors.brand(context);
    String label(CalcTab t) => switch (t) {
          CalcTab.termDeposit => l10n.fcTabTd,
          CalcTab.loanInstallment => l10n.fcTabLoanInstallment,
          CalcTab.loanEligibility => l10n.fcTabLoanEligibility,
          CalcTab.forex => l10n.fcTabForex,
        };
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 640;
        Widget tab(CalcTab t) {
          final on = t == selected;
          return Semantics(
            selected: on,
            button: true,
            child: Material(
              color: on ? brand.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => onSelect(t),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    label(t),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                      color: on ? brand : HomeColors.textPrimary(context),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: HomeColors.card(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: HomeColors.divider(context)),
          ),
          child: narrow
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [for (final t in CalcTab.values) tab(t)]),
                )
              : Row(
                  children: [
                    for (final t in CalcTab.values) ...[
                      SizedBox(width: (c.maxWidth - 16) / 5.2, child: tab(t)),
                      const SizedBox(width: 18),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

/// Calculation state shared by the four tabs: one call at a time in effect
/// (an older answer arriving late is dropped), loading, error.
mixin _Calculation<W extends ConsumerStatefulWidget, T> on ConsumerState<W> {
  T? result;
  String? error;
  bool loading = false;
  int _request = 0;

  /// The last error came from a local check (no call was made), so there
  /// is nothing to retry.
  bool blockedLocally = false;

  /// Runs [call] with OBDX's OTP / approval handling (decision 3a).
  Future<void> calculate(
    Future<ResponseHandler<CalcOutcome<T>>> Function(ObdxChallenge? challenge, String? otp) call,
  ) async {
    final l10n = AppLocalizations.of(context);
    final id = ++_request;
    setState(() {
      loading = true;
      error = null;
      blockedLocally = false;
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
        blockedLocally = true;
      });
}

String _money(MoneyAmount? m, String fallbackCurrency) =>
    m == null ? '-' : MoneyFormat.format(m.amount, currencyCode: m.currency ?? fallbackCurrency);

Widget _loading() => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));

Widget _loadFailed(BuildContext context, Object e, VoidCallback retry) => PayErrorRetry(
      message: e is CalcLoadError && e.message != null ? e.message! : AppLocalizations.of(context).calcLoadFailed,
      onRetry: retry,
    );

/// The calculator card: its title, a line under it, then [children]. The
/// fields take the left of a wide card, as in the design.
class _CalcCard extends StatelessWidget {
  const _CalcCard({required this.children, this.title, this.subtitle});

  final String? title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DesignCard(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 870),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null)
                  Text(title!, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context))),
                if (subtitle != null) ...[
                  const SizedBox(height: 10),
                  Text(subtitle!, style: TextStyle(fontSize: 11.5, color: HomeColors.textSecondary(context))),
                ],
                if (title != null || subtitle != null) const SizedBox(height: 14),
                ...children,
              ],
            ),
          ),
        ),
      );
}

/// Two side by side on a wide card (each half the fields column), stacked
/// on a phone.
Widget _row(BuildContext context, List<Widget> cells, {bool halfWidth = true}) => LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final (i, w) in cells.indexed) ...[if (i > 0) const SizedBox(height: 12), w]],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, w) in cells.indexed) ...[
              if (i > 0) const SizedBox(width: 18),
              Expanded(child: w),
            ],
            // A lone field keeps the design's half width.
            if (halfWidth && cells.length == 1) ...[const SizedBox(width: 18), const Expanded(child: SizedBox.shrink())],
          ],
        );
      },
    );

/// A number in a design box. It follows [value] unless the user is typing;
/// typing reports through [onChanged] at once and [onCommit] after a pause,
/// with a value outside [min]..[max] flagged and then moved to the limit.
class _NumberBox extends StatefulWidget {
  const _NumberBox({
    required this.label,
    required this.value,
    required this.onCommit,
    this.onChanged,
    this.min,
    this.max,
    this.decimals = 0,
    this.suffix,
    this.grouped = false,
  });

  final String label;
  final double? value;
  final double? min;
  final double? max;
  final int decimals;
  final String? suffix;

  /// "10,000" as in the design.
  final bool grouped;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double> onCommit;

  @override
  State<_NumberBox> createState() => _NumberBoxState();
}

class _NumberBoxState extends State<_NumberBox> {
  late final _text = TextEditingController(text: _show(widget.value));
  Timer? _timer;
  bool _outOfRange = false;

  String _show(double? v) {
    if (v == null) return '';
    final plain = _plain(v, widget.decimals);
    if (!widget.grouped) return plain;
    final parts = plain.split('.');
    final whole = parts.first.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return parts.length > 1 ? '$whole.${parts[1]}' : whole;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    super.dispose();
  }

  double _clamp(double v) {
    if (widget.min != null && v < widget.min!) return widget.min!;
    if (widget.max != null && v > widget.max!) return widget.max!;
    return v;
  }

  void _typed(String text) {
    final v = double.tryParse(text.replaceAll(',', ''));
    setState(() => _outOfRange = v != null && v != _clamp(v));
    _timer?.cancel();
    if (v == null) return;
    widget.onChanged?.call(_clamp(v));
    _timer = Timer(_debounce, () {
      // The pause: an out-of-range entry becomes the nearest limit (still
      // flagged until the next edit).
      if (_outOfRange && mounted) _text.text = _show(_clamp(v));
      widget.onCommit(_clamp(v));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final range = widget.min != null && widget.max != null
        ? l10n.calcRangeHint(_plain(widget.min!, widget.decimals), _plain(widget.max!, widget.decimals))
        : null;
    return DesignBoxField(
      label: widget.label,
      controller: _text,
      hint: l10n.fcEnterValue,
      error: _outOfRange ? range : null,
      suffixText: widget.suffix,
      keyboardType: TextInputType.numberWithOptions(decimal: widget.decimals > 0),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(widget.decimals == 0 ? r'[0-9,]' : r'[0-9.,]'))],
      onChanged: _typed,
    );
  }
}

/// An error under the result: Retry for a failed call, the reason alone
/// for a local check.
Widget _errorLine(BuildContext context, String? error, VoidCallback? retry) {
  if (error == null) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 10),
    child: retry != null
        ? PayErrorRetry(message: error, onRetry: retry)
        : Text(error, style: TextStyle(color: HomeColors.error(context), fontSize: 12.5, height: 1.4)),
  );
}

// ── Term Deposit Calculator ──

class _TdCalculator extends ConsumerStatefulWidget {
  const _TdCalculator();

  @override
  ConsumerState<_TdCalculator> createState() => _TdCalculatorState();
}

class _TdCalculatorState extends ConsumerState<_TdCalculator> with _Calculation<_TdCalculator, TdMaturity> {
  double _amount = 0;
  final _years = TextEditingController(text: '1');
  final _months = TextEditingController(text: '0');
  final _days = TextEditingController(text: '0');

  /// Percent; OBDX starts empty and asks for it ("Please enter valid Interest").
  double _interest = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_years, _months, _days]) {
      c.dispose();
    }
    super.dispose();
  }

  int _int(TextEditingController c) => int.tryParse(c.text) ?? 0;

  void _later() {
    _timer?.cancel();
    _timer = Timer(_debounce, _run);
  }

  void _run() {
    final ccy = ref.read(calcLocalCurrencyProvider).valueOrNull;
    if (ccy == null || _amount <= 0) return;
    if (_interest <= 0) return blocked(AppLocalizations.of(context).calcEnterValidInterest);
    final body = tdMaturityBody(
      currency: ccy,
      amount: _amount,
      years: _int(_years),
      months: _int(_months),
      days: _int(_days),
      interestPercent: _interest,
    );
    final repo = ref.read(calculatorsRepositoryProvider);
    calculate((c, otp) => repo.tdMaturity(body, challenge: c, otp: otp));
  }

  /// One part of the tenure: a small label over a bare number, as designed.
  Widget _tenure(String label, TextEditingController c, int max) {
    final secondary = HomeColors.textSecondary(context);
    return SizedBox(
      width: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: secondary)),
          TextField(
            controller: c,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, _MaxIntFormatter(max)],
            onChanged: (_) => _later(),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: HomeColors.brand(context))),
              contentPadding: const EdgeInsets.only(top: 2, bottom: 2),
              hintText: '0 - $max',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ref.watch(calcLocalCurrencyProvider).when(
          loading: _loading,
          error: (e, _) => _loadFailed(context, e, () => ref.invalidate(calcLocalCurrencyProvider)),
          data: (ccy) => _CalcCard(
            title: l10n.fcTdTitle,
            subtitle: l10n.fcTdSubtitle,
            children: [
              _row(context, [
                _NumberBox(
                  label: l10n.calcDepositAmount,
                  value: null,
                  decimals: 2,
                  onChanged: (v) => _amount = v,
                  onCommit: (v) {
                    _amount = v;
                    _run();
                  },
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.calcDepositTenure,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: HomeColors.textSecondary(context)),
                    ),
                    Row(
                      children: [
                        _tenure(l10n.calcYears, _years, 120),
                        const SizedBox(width: 14),
                        _tenure(l10n.calcMonths, _months, 12),
                        const SizedBox(width: 14),
                        _tenure(l10n.calcDays, _days, 31),
                      ],
                    ),
                  ],
                ),
              ]),
              const SizedBox(height: 34),
              _row(
                context,
                [
                  _NumberBox(
                    label: l10n.calcInterestRate,
                    value: null,
                    min: 0,
                    max: 25,
                    decimals: 2,
                    suffix: '%',
                    onChanged: (v) => _interest = v,
                    onCommit: (v) {
                      setState(() => _interest = v);
                      _run();
                    },
                  ),
                ],
                halfWidth: false,
              ),
              const SizedBox(height: 18),
              DesignResultPanel(
                caption: l10n.calcMaturityAmount,
                value: _money(result?.maturityAmount, ccy),
                loading: loading,
                lines: [if (_interest > 0) (l10n.fcInterest, '${_plain(_interest, 2)}%')],
              ),
              _errorLine(context, error, blockedLocally ? null : _run),
            ],
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

class _LoanInstallmentCalculator extends ConsumerStatefulWidget {
  const _LoanInstallmentCalculator();

  @override
  ConsumerState<_LoanInstallmentCalculator> createState() => _LoanInstallmentCalculatorState();
}

class _LoanInstallmentCalculatorState extends ConsumerState<_LoanInstallmentCalculator>
    with _Calculation<_LoanInstallmentCalculator, LoanInstallment> {
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
    void commit(VoidCallback set) {
      setState(set);
      _run(currency);
    }

    // Repaid over the tenure, and the interest in that.
    final installment = result?.installment;
    final total = installment == null ? null : installment.amount * _tenure!.round() * 12;
    return _CalcCard(
      title: l10n.fcLoanInstallmentTitle,
      subtitle: l10n.fcLoanInstallmentSubtitle,
      children: [
        _row(context, [
          _NumberBox(
            label: l10n.calcLoanAmount,
            value: _principal,
            min: amount.min,
            max: amount.max,
            grouped: true,
            onCommit: (v) => commit(() => _principal = v),
          ),
          _NumberBox(
            label: l10n.calcLoanTenureYears,
            value: _tenure,
            min: tenure.min,
            max: tenure.max,
            onCommit: (v) => commit(() => _tenure = v),
          ),
        ]),
        const SizedBox(height: 28),
        _row(context, [
          _NumberBox(
            label: l10n.calcInterestRate,
            value: _interest,
            min: rate.min,
            max: rate.max,
            decimals: 2,
            suffix: '%',
            onCommit: (v) => commit(() => _interest = v),
          ),
        ]),
        const SizedBox(height: 12),
        DesignResultPanel(
          caption: l10n.fcMonthlyInstallment,
          value: _money(installment, currency),
          loading: loading,
          lines: [
            if (total != null) (l10n.fcTotalRepayment, MoneyFormat.format(total, currencyCode: installment!.currency ?? currency)),
            if (total != null)
              (l10n.fcInterest, MoneyFormat.format(total - _principal!, currencyCode: installment!.currency ?? currency)),
          ],
        ),
        _errorLine(context, error, error == null ? null : () => _run(currency)),
      ],
    );
  }
}

// ── Loan Eligibility Calculator ──

class _LoanEligibilityCalculator extends ConsumerStatefulWidget {
  const _LoanEligibilityCalculator();

  @override
  ConsumerState<_LoanEligibilityCalculator> createState() => _LoanEligibilityCalculatorState();
}

class _LoanEligibilityCalculatorState extends ConsumerState<_LoanEligibilityCalculator>
    with _Calculation<_LoanEligibilityCalculator, LoanEligibility> {
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

    final eligible = result;
    final disposable = _income! - _expenses!;
    return _CalcCard(
      title: l10n.fcLoanEligibilityTitle,
      subtitle: l10n.fcLoanEligibilitySubtitle,
      children: [
        _row(context, [
          _NumberBox(
            label: l10n.calcGrossIncome,
            value: _income,
            min: income.min,
            max: income.max,
            grouped: true,
            onChanged: (v) => setState(() => _income = v),
            onCommit: (v) => commit(() => _income = v),
          ),
          _NumberBox(
            label: l10n.calcTotalExpenses,
            value: _expenses,
            min: expenses.min,
            max: expenses.max,
            grouped: true,
            onChanged: (v) => setState(() => _expenses = v),
            onCommit: (v) => commit(() => _expenses = v),
          ),
        ]),
        const SizedBox(height: 18),
        _row(context, [
          _NumberBox(
            label: l10n.calcLoanTenureYears,
            value: _tenure,
            min: tenure.min,
            max: tenure.max,
            onCommit: (v) => commit(() => _tenure = v),
          ),
          _NumberBox(
            label: l10n.calcInterestRateIn,
            value: _interest,
            min: rate.min,
            max: rate.max,
            decimals: 2,
            onCommit: (v) => commit(() => _interest = v),
          ),
        ]),
        const SizedBox(height: 18),
        // The design leads with what is left each month; the bank's own
        // eligible amount follows once it has answered.
        DesignResultPanel(
          caption: l10n.fcDisposableIncome,
          value: MoneyFormat.format(disposable < 0 ? 0 : disposable, currencyCode: currency),
          minHeight: 110,
          lines: [
            if (eligible != null) (l10n.calcEligibleAmount, _money(eligible.eligibleAmount, currency)),
            if (eligible?.monthlyInstallment != null)
              (l10n.calcAverageInstallment, l10n.calcPerMonth(_money(eligible!.monthlyInstallment, currency))),
          ],
          note: eligible == null && !loading ? l10n.fcEligibilityNote : null,
        ),
        if (loading) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator(minHeight: 2)),
        _errorLine(context, error, blockedLocally ? null : () => _run(currency)),
      ],
    );
  }
}

// ── Forex Calculator ──

class _ForexCalculator extends ConsumerStatefulWidget {
  const _ForexCalculator();

  @override
  ConsumerState<_ForexCalculator> createState() => _ForexCalculatorState();
}

class _ForexCalculatorState extends ConsumerState<_ForexCalculator> with _Calculation<_ForexCalculator, ForexQuote> {
  final _amount = TextEditingController(text: '1');
  String? _from;
  String? _to;

  /// OBDX multiplies the user's Amount by 1000 when the result is below
  /// 0.01 and asks again; the app shows the result for the amount typed
  /// (decision 4b).
  Timer? _timer;

  /// The amount the shown result is for (the "1,000 INR × rate" line).
  double? _quotedAmount;

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
    _quotedAmount = amount;
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
    return ref.watch(forexPairsProvider).when(
          loading: _loading,
          error: (e, _) => _loadFailed(context, e, () => ref.invalidate(forexPairsProvider)),
          data: (pairs) {
            final q = result;
            final from = DesignBoxSelect(
              label: l10n.fcFrom,
              caption: l10n.fcCurrency,
              value: _from,
              placeholder: l10n.calcForeignCurrency,
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
            );
            final to = DesignBoxSelect(
              label: l10n.fcTo,
              caption: l10n.fcCurrency,
              value: _to,
              placeholder: l10n.calcForeignCurrency,
              onTap: _from == null
                  ? null
                  : () => _pick(l10n.calcToCurrency, pairs.toFor(_from!), _to, (v) {
                        setState(() => _to = v);
                        _run();
                      }),
            );
            final amount = DesignBoxField(
              label: l10n.calcAmount,
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              onChanged: (_) {
                _timer?.cancel();
                _timer = Timer(_debounce, _run);
              },
            );
            final rates = Container(
              constraints: const BoxConstraints(minHeight: 70),
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: HomeColors.bg(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: HomeColors.divider(context)),
              ),
              child: q == null || _from == null || _to == null
                  ? Text(
                      l10n.calcSelectCurrency,
                      style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context)),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.calcRate(_from!, _rate(q.rate), _to!),
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
                        ),
                        Text(
                          l10n.calcRate(_to!, _rate(q.reverseRate), _from!),
                          style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context)),
                        ),
                      ],
                    ),
            );
            final arrow = Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: HomeColors.divider(context))),
              child: Icon(Icons.arrow_right_alt_rounded, color: HomeColors.brand(context), size: 28),
            );
            final converted = q == null || _to == null ? '-' : MoneyFormat.format(q.converted, currencyCode: _to!);
            final working = q == null || _from == null || _quotedAmount == null
                ? null
                : '${MoneyFormat.format(_quotedAmount!, currencyCode: '').trim()} ${_from!} × ${_rate(q.rate)}';

            return DesignCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 640;
                  final panel = DesignResultPanel(
                    caption: l10n.fcConvertedAmount,
                    value: converted,
                    loading: loading,
                    minHeight: 120,
                    detail: working,
                  );
                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        from,
                        const SizedBox(height: 12),
                        amount,
                        const SizedBox(height: 12),
                        Center(child: RotatedBox(quarterTurns: 1, child: arrow)),
                        const SizedBox(height: 12),
                        to,
                        const SizedBox(height: 12),
                        rates,
                        const SizedBox(height: 16),
                        panel,
                        _errorLine(context, error, blockedLocally ? null : _run),
                      ],
                    );
                  }
                  return Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 870),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Column(children: [from, const SizedBox(height: 12), amount])),
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 34), child: arrow),
                              Expanded(child: Column(children: [to, const SizedBox(height: 12), rates])),
                            ],
                          ),
                          const SizedBox(height: 16),
                          panel,
                          _errorLine(context, error, blockedLocally ? null : _run),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
  }
}
