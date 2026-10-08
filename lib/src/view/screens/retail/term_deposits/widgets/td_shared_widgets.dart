import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/retail/term_deposit.dart';
import 'package:ubci_bank/src/core/models/retail/term_deposit_actions.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/core/utils/common/responsive.dart';
import 'package:ubci_bank/src/view/providers/retail/term_deposit_providers.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/casa_shared_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/auth/otp_pin_input.dart';

// ── Formatting ───────────────────────────────────────────────────────────

String tdMoney(MoneyAmount? money, {String? currency, bool hidden = false}) {
  if (money == null) return '—';
  return MoneyFormat.format(
    money.amount,
    currencyCode: money.currency ?? currency ?? '',
    hidden: hidden,
  );
}

String tdAmount(double? amount, String currency) =>
    amount == null ? '—' : MoneyFormat.format(amount, currencyCode: currency);

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "20 Jun 2023", as the loan screens show dates.
String tdDate(DateTime? date) {
  if (date == null) return '—';
  return '${date.day.toString().padLeft(2, '0')} '
      '${_months[date.month - 1]} ${date.year}';
}

/// "10%" / "7.25%". OBDX sends the rate as a percentage already.
String tdRate(double? rate) {
  if (rate == null) return '—';
  final text = rate == rate.roundToDouble()
      ? rate.toStringAsFixed(0)
      : rate.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  return '$text%';
}

/// The roll-over code's description from [options], else its OBDX
/// default.
String tdRollOverLabel(String? code, List<TdEnumOption> options) {
  if (code == null) return '—';
  for (final o in options) {
    if (o.code == code) return o.description;
  }
  return TdRollOver.fallbackLabels[code] ?? code;
}

/// Amount typed in a field: digits with an optional decimal point.
double? tdParseAmount(String text) =>
    double.tryParse(text.replaceAll(',', '').trim());

final tdAmountInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
];

// ── Cards & grids ────────────────────────────────────────────────────────

/// The elevated card the account screens wrap their content in.
class TdOuterCard extends StatelessWidget {
  const TdOuterCard({super.key, required this.child, this.padding = 20});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeColors.divider(context)),
        boxShadow: [
          BoxShadow(
            color: HomeColors.brandLight(context).withValues(alpha: 0.30),
            blurRadius: 15,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A bordered inner panel with an optional title.
class TdPanel extends StatelessWidget {
  const TdPanel({super.key, this.title, this.trailing, required this.child});

  final String? title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(child: TdSectionLabel(title!)),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// Label / value pairs laid out in [columns] columns.
class TdInfoGrid extends StatelessWidget {
  const TdInfoGrid({super.key, required this.items, required this.columns});

  final List<(String, String)> items;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          children: [
            for (final (label, value) in items)
              SizedBox(
                width: width,
                child: CasaDetailField(label: label, value: value),
              ),
          ],
        );
      },
    );
  }
}

class TdSectionLabel extends StatelessWidget {
  const TdSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: HomeColors.textPrimary(context),
        ),
      );
}

/// A status pill — green when active, grey when closed; white on the
/// brand banners ([onDark]), where green would not read.
class TdStatusPill extends StatelessWidget {
  const TdStatusPill({super.key, required this.status, this.onDark = false});

  final String status;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final active = status.toUpperCase() == 'ACTIVE';
    final tone = onDark
        ? Colors.white
        : active
            ? HomeColors.success(context)
            : HomeColors.textSecondary(context);
    final label = status.isEmpty
        ? status
        : status[0].toUpperCase() + status.substring(1).toLowerCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: onDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: tone,
        ),
      ),
    );
  }
}

class TdMuted extends StatelessWidget {
  const TdMuted(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: HomeColors.textSecondary(context),
          ),
        ),
      );
}

/// Error message with a retry button.
class TdErrorRetry extends StatelessWidget {
  const TdErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: HomeColors.textSecondary(context),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: HomeColors.textSecondary(context)),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: Text(l10n.accountsRetry)),
        ],
      ),
    );
  }
}

class TdPrimaryButton extends StatelessWidget {
  const TdPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: HomeColors.brand(context),
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8)
                ],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
  }
}

// ── The three-step action flow ───────────────────────────────────────────

/// Form → review → done, as the loan repayment flow lays it out: on a
/// phone one column with a step bar; from the wide breakpoint a summary
/// panel and vertical stepper on the left, the step card on the right.
class TdFlowScaffold extends StatelessWidget {
  const TdFlowScaffold({
    super.key,
    required this.title,
    required this.step,
    required this.summary,
    required this.child,
    this.onBackStep,
  });

  final String title;

  /// 0 form, 1 review, 2 done.
  final int step;

  /// What the action is on — the left panel on wide screens, the top of
  /// the form on phones.
  final Widget summary;
  final Widget child;

  /// Back from the review to the form.
  final VoidCallback? onBackStep;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = Responsive.of(context).useWideLayout;
    final steps = [l10n.tdStepDetails, l10n.tdStepReview, l10n.tdStepDone];

    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        wide ? 28 : 16,
        wide ? 24 : 12,
        wide ? 28 : 16,
        8,
      ),
      child: Row(
        children: [
          if (step != 2) ...[
            CasaBackButton(onPressed: step == 1 ? onBackStep : null),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: wide ? 22 : 15,
                fontWeight: FontWeight.w700,
                color: HomeColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );

    final Widget body;
    if (wide) {
      body = SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  summary,
                  const SizedBox(height: 16),
                  TdOuterCard(
                    padding: 16,
                    child: Column(
                      children: [
                        for (var i = 0; i < steps.length; i++)
                          _StepTile(
                            index: i,
                            label: steps[i],
                            current: step,
                            last: i == steps.length - 1,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 28),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: TdOuterCard(child: child),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          _StepBar(step: step, labels: steps),
          const SizedBox(height: 14),
          if (step == 0) ...[summary, const SizedBox(height: 14)],
          TdOuterCard(padding: 16, child: child),
        ],
      );
    }

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, Expanded(child: body)],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.label,
    required this.current,
    required this.last,
  });

  final int index;
  final String label;
  final int current;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final done = index < current;
    final active = index == current;
    final brand = HomeColors.brand(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done || active ? brand : HomeColors.divider(context),
              ),
              child: done
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: Colors.white)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? Colors.white
                            : HomeColors.textSecondary(context),
                      ),
                    ),
            ),
            if (!last)
              Container(
                width: 2,
                height: 22,
                color: done ? brand : HomeColors.divider(context),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active || done
                  ? HomeColors.textPrimary(context)
                  : HomeColors.textSecondary(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.step, required this.labels});

  final int step;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= step
                        ? HomeColors.brand(context)
                        : HomeColors.divider(context),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: i == step ? FontWeight.w700 : FontWeight.w500,
                    color: i <= step
                        ? HomeColors.textPrimary(context)
                        : HomeColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          if (i < labels.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

/// The deposit an action is on, for the flow's summary.
class TdDepositSummaryCard extends StatelessWidget {
  const TdDepositSummaryCard({
    super.key,
    required this.deposit,
    this.extra = const [],
  });

  final TermDeposit deposit;
  final List<(String, String)> extra;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [HomeColors.brand(context), HomeColors.brandDark(context)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${l10n.tdTermDeposit} ••${deposit.lastFour}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.tdCurrentBalance,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tdMoney(deposit.currentValue, currency: deposit.currencyCode),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final (label, value) in [
              (l10n.tdInterestRate, tdRate(deposit.interestRate)),
              (l10n.tdMaturityDate, tdDate(deposit.maturityDate)),
              ...extra,
            ])
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A review line.
class TdReviewRow extends StatelessWidget {
  const TdReviewRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: HomeColors.divider(context))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: HomeColors.textSecondary(context),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: emphasize ? 15 : 13.5,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                color: emphasize
                    ? HomeColors.brand(context)
                    : HomeColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The done step.
class TdResultView extends StatelessWidget {
  const TdResultView({
    super.key,
    required this.title,
    required this.message,
    required this.rows,
    required this.onDone,
    this.reference,
  });

  final String title;
  final String message;
  final String? reference;
  final List<(String, String)> rows;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: HomeColors.success(context).withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              size: 36,
              color: HomeColors.success(context),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: HomeColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: HomeColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 16),
        if (reference != null)
          TdReviewRow(label: l10n.tdReferenceNumber, value: reference!),
        for (final (label, value) in rows)
          TdReviewRow(label: label, value: value),
        const SizedBox(height: 20),
        TdPrimaryButton(label: l10n.tdDone, onPressed: onDone),
      ],
    );
  }
}

/// Wires a flow screen to [tdSubmissionProvider]: opens the OTP sheet on
/// OBDX's challenge, shows failures in a snackbar, and calls [onDone] with
/// the result.
void tdListenToSubmission(
  WidgetRef ref,
  BuildContext context, {
  required ValueChanged<TdSubmitted> onDone,
}) {
  ref.listen<TdSubmissionState>(tdSubmissionProvider, (previous, next) {
    if (next.result != null && previous?.result != next.result) {
      HapticFeedback.mediumImpact();
      onDone(next.result!);
    }
    if (next.errorMessage != null &&
        next.errorMessage != previous?.errorMessage) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
    }
    if (next.challenge != null && previous?.challenge == null) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        constraints: const BoxConstraints(maxWidth: 480),
        builder: (_) => const TdOtpSheet(),
      );
    }
  });
}

/// The OTP sheet for a TD confirm.
class TdOtpSheet extends ConsumerStatefulWidget {
  const TdOtpSheet({super.key});

  @override
  ConsumerState<TdOtpSheet> createState() => _TdOtpSheetState();
}

class _TdOtpSheetState extends ConsumerState<TdOtpSheet> {
  final _otp = TextEditingController();
  final _focus = FocusNode();
  String? _localError;
  bool _closed = false;

  @override
  void dispose() {
    _otp.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final otp = _otp.text.trim();
    if (otp.isEmpty) {
      setState(() =>
          _localError = AppLocalizations.of(context).loanRepaymentOtpEmpty);
      return;
    }
    setState(() => _localError = null);
    ref.read(tdSubmissionProvider.notifier).verifyOtp(otp);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(tdSubmissionProvider);
    ref.listen<TdSubmissionState>(tdSubmissionProvider, (_, next) {
      if (next.result != null && !_closed) {
        _closed = true;
        Navigator.of(context).pop();
      }
    });
    final error = state.otpError ?? _localError;
    final attempts = state.challenge?.attemptsLeft;
    final bottom = MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: HomeColors.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: HomeColors.divider(context),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.tdOtpTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: HomeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.tdOtpSubtitle,
              style: TextStyle(
                fontSize: 13,
                color: HomeColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 20),
            OtpPinInput(
              controller: _otp,
              focusNode: _focus,
              obscuringCharacter: '*',
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 12, color: HomeColors.error(context)),
              ),
            ],
            if (attempts != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.loanRepaymentOtpAttemptsLeft(attempts),
                style: TextStyle(
                  fontSize: 12,
                  color: HomeColors.textSecondary(context),
                ),
              ),
            ],
            const SizedBox(height: 20),
            TdPrimaryButton(
              label: l10n.tdOtpVerify,
              loading: state.isSubmitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Form fields ──────────────────────────────────────────────────────────

class TdFieldLabel extends StatelessWidget {
  const TdFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: HomeColors.textPrimary(context),
          ),
        ),
      );
}

class TdFieldError extends StatelessWidget {
  const TdFieldError(this.text, {super.key});

  final String? text;

  @override
  Widget build(BuildContext context) => text == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            text!,
            style: TextStyle(fontSize: 12, color: HomeColors.error(context)),
          ),
        );
}

InputDecoration tdInputDecoration(
  BuildContext context, {
  String? hint,
  String? prefix,
  String? helper,
}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    hintText: hint,
    helperText: helper,
    helperMaxLines: 2,
    prefixText: prefix == null ? null : '$prefix  ',
    filled: true,
    fillColor: HomeColors.card(context),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(HomeColors.divider(context)),
    enabledBorder: border(HomeColors.divider(context)),
    focusedBorder: border(HomeColors.brand(context), 1.5),
  );
}

/// A tappable field that opens a picker.
class TdPickerField extends StatelessWidget {
  const TdPickerField({
    super.key,
    required this.placeholder,
    required this.onTap,
    this.title,
    this.subtitle,
    this.icon = Icons.account_balance_wallet_outlined,
    this.hasError = false,
  });

  final String placeholder;
  final String? title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeColors.card(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError
                  ? HomeColors.error(context)
                  : HomeColors.divider(context),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: HomeColors.brand(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ?? placeholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            title == null ? FontWeight.w500 : FontWeight.w600,
                        color: title == null
                            ? HomeColors.textSecondary(context)
                            : HomeColors.textPrimary(context),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: HomeColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: HomeColors.textSecondary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picks one of the customer's CASA accounts — loads them for [taskCode].
class TdPayAccountField extends ConsumerWidget {
  const TdPayAccountField({
    super.key,
    required this.taskCode,
    required this.selected,
    required this.onSelected,
    this.error,
    this.onLoaded,
  });

  final String taskCode;
  final TdPayAccount? selected;
  final ValueChanged<TdPayAccount> onSelected;
  final String? error;

  /// Called with the accounts once loaded, e.g. to preselect one.
  final ValueChanged<List<TdPayAccount>>? onLoaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final accounts = ref.watch(tdPayAccountsProvider(taskCode));
    if (onLoaded != null) {
      ref.listen(tdPayAccountsProvider(taskCode), (_, next) {
        final list = next.valueOrNull;
        if (list != null) onLoaded!(list);
      });
    }
    final a = selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TdPickerField(
          placeholder: accounts.isLoading
              ? l10n.tdLoadingAccounts
              : l10n.tdSelectAccount,
          title: a?.displayNumber,
          subtitle: a == null
              ? null
              : '${l10n.tdAvailable}: ${tdMoney(a.balance, currency: a.currencyCode)}',
          hasError: error != null,
          onTap: accounts.valueOrNull == null
              ? null
              : () async {
                  final picked = await showTdAccountPicker(
                    context,
                    accounts: accounts.value!,
                    selected: a,
                  );
                  if (picked != null) onSelected(picked);
                },
        ),
        if (accounts.hasError)
          TdFieldError(accounts.error.toString())
        else
          TdFieldError(error),
      ],
    );
  }
}

/// Bottom sheet listing [accounts] with their balances.
Future<TdPayAccount?> showTdAccountPicker(
  BuildContext context, {
  required List<TdPayAccount> accounts,
  TdPayAccount? selected,
}) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<TdPayAccount>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (sheetContext) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: HomeColors.card(sheetContext),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: HomeColors.divider(sheetContext),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TdSectionLabel(l10n.tdSelectAccount),
          const SizedBox(height: 8),
          if (accounts.isEmpty)
            TdMuted(l10n.tdNoAccounts)
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final a in accounts)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      selected: a.id == selected?.id,
                      selectedTileColor: HomeColors.brand(sheetContext)
                          .withValues(alpha: 0.08),
                      leading: CircleAvatar(
                        backgroundColor: HomeColors.brand(sheetContext)
                            .withValues(alpha: 0.12),
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 20,
                          color: HomeColors.brand(sheetContext),
                        ),
                      ),
                      title: Text(
                        a.displayNumber,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(a.partyName ?? a.currencyCode),
                      trailing: Text(
                        tdMoney(a.balance, currency: a.currencyCode),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: () => Navigator.of(sheetContext).pop(a),
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// An amount input with its currency.
class TdAmountField extends StatelessWidget {
  const TdAmountField({
    super.key,
    required this.controller,
    required this.currency,
    this.error,
    this.helper,
    this.onChanged,
  });

  final TextEditingController controller;
  final String currency;
  final String? error;
  final String? helper;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: tdAmountInputFormatters,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: HomeColors.textPrimary(context),
          ),
          decoration: tdInputDecoration(
            context,
            hint: '0.00',
            prefix: currency,
            helper: helper,
          ),
        ),
        TdFieldError(error),
      ],
    );
  }
}

/// A two-option segmented control.
class TdSegmented<T> extends StatelessWidget {
  const TdSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HomeColors.bg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Row(
        children: [
          for (final (value, label) in options)
            Expanded(
              child: Semantics(
                selected: value == selected,
                button: true,
                child: GestureDetector(
                  onTap: () => onChanged(value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == selected
                          ? HomeColors.card(context)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: value == selected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: value == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: value == selected
                            ? HomeColors.brand(context)
                            : HomeColors.textSecondary(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The payout being entered: own account (picked) or an internal account
/// number (typed).
class TdPayoutDraft {
  const TdPayoutDraft({
    this.type = TdPayoutType.own,
    this.account,
    this.accountNumber = '',
  });

  final TdPayoutType type;
  final TdPayAccount? account;
  final String accountNumber;

  bool get isComplete => type == TdPayoutType.own
      ? account != null
      : accountNumber.trim().length >= 4;

  String? get label => type == TdPayoutType.own
      ? account?.displayNumber
      : (accountNumber.trim().isEmpty ? null : accountNumber.trim());

  TdPayoutDraft copyWith({
    TdPayoutType? type,
    TdPayAccount? account,
    String? accountNumber,
  }) =>
      TdPayoutDraft(
        type: type ?? this.type,
        account: account ?? this.account,
        accountNumber: accountNumber ?? this.accountNumber,
      );
}

/// Builds the [TdPayout] for a complete [draft], looking up the own
/// account's branch name and address (as the web client sends them).
Future<TdPayout?> tdResolvePayout(WidgetRef ref, TdPayoutDraft draft) async {
  if (!draft.isComplete) return null;
  if (draft.type == TdPayoutType.internal) {
    return TdPayout.internal(accountNumber: draft.accountNumber.trim());
  }
  final account = draft.account!;
  final code = account.branchCode;
  final branch = code == null
      ? null
      : await ref.read(tdBranchProvider(code).future).catchError((_) => null);
  return TdPayout.own(account: account, branch: branch);
}

/// Own account / another account at the bank.
class TdPayoutEditor extends StatefulWidget {
  const TdPayoutEditor({
    super.key,
    required this.taskCode,
    required this.value,
    required this.onChanged,
    this.error,
  });

  final String taskCode;
  final TdPayoutDraft value;
  final ValueChanged<TdPayoutDraft> onChanged;
  final String? error;

  @override
  State<TdPayoutEditor> createState() => _TdPayoutEditorState();
}

class _TdPayoutEditorState extends State<TdPayoutEditor> {
  late final _number = TextEditingController(text: widget.value.accountNumber);

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final v = widget.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TdSegmented<TdPayoutType>(
          options: [
            (TdPayoutType.own, l10n.tdPayoutOwnAccount),
            (TdPayoutType.internal, l10n.tdPayoutInternalAccount),
          ],
          selected: v.type,
          onChanged: (t) => widget.onChanged(TdPayoutDraft(type: t)),
        ),
        const SizedBox(height: 12),
        if (v.type == TdPayoutType.own)
          TdPayAccountField(
            taskCode: widget.taskCode,
            selected: v.account,
            error: widget.error,
            onSelected: (a) => widget.onChanged(v.copyWith(account: a)),
          )
        else ...[
          TextField(
            controller: _number,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (t) => widget.onChanged(v.copyWith(accountNumber: t)),
            decoration: tdInputDecoration(
              context,
              hint: l10n.tdAccountNumberHint,
            ),
          ),
          TdFieldError(widget.error),
        ],
      ],
    );
  }
}
