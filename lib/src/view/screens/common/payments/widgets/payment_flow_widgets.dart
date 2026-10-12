import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/src/core/models/retail/casa_account.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/view/providers/common/network_transfer_providers.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/auth/otp_pin_input.dart';

/// Building blocks shared by the transfer screens (payee transfers, repeat
/// transfers, International Low Value Payment, multiple transfers): a
/// details → review → done flow.
///
/// The flow measures the space it is given, not the window — beside the
/// web sidebar it can be much narrower than the screen:
///  - wide (≥ [kPayWideFlow]): the step on the left, a live summary on the
///    right, the step's button at the end of the step;
///  - narrow: one column, the button pinned to the bottom within thumb
///    reach, with the running amount above it.

/// Below this width the flow is a single column.
const double kPayWideFlow = 900;

// ── Formatting ───────────────────────────────────────────────────────────

String payAmount(double? amount, String currency) => amount == null
    ? '—'
    : MoneyFormat.format(amount, currencyCode: currency);

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String payDate(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

double? payParseAmount(String text) =>
    double.tryParse(text.replaceAll(',', '').trim());

/// `•••• 1022` — the last four characters of an account number, however
/// the bank masked the rest.
String payMask(String number) {
  final plain = number.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
  if (plain.isEmpty) return number;
  final tail = plain.length <= 4 ? plain : plain.substring(plain.length - 4);
  return '•••• $tail';
}

/// What a person calls their account: its nickname, else its product.
String payAccountName(CasaAccount a) =>
    a.nickname ??
    a.productName ??
    (a.isSaving
        ? 'Savings account'
        : a.isCurrent
            ? 'Current account'
            : 'Account');

// ── Flow shell ───────────────────────────────────────────────────────────

class PayFlowScaffold extends StatelessWidget {
  const PayFlowScaffold({
    super.key,
    required this.title,
    required this.step,
    required this.child,
    this.subtitle,
    this.summary,
    this.action,
    this.actionCaption,
    this.onBackStep,
    this.onExit,
    this.steps = const ['Details', 'Review', 'Done'],
  });

  final String title;
  final String? subtitle;

  /// 0 details, 1 review, 2 done.
  final int step;

  /// The step: usually a column of [PaySection]s.
  final Widget child;

  /// A live summary, beside the step on wide layouts (narrow ones show
  /// [actionCaption] instead).
  final Widget? summary;

  /// The step's main button — pinned to the bottom on narrow layouts.
  final Widget? action;

  /// A line above the pinned [action] on narrow layouts, e.g. the total.
  final String? actionCaption;

  /// Back from review to details.
  final VoidCallback? onBackStep;

  /// Leaves the flow from the details step — the embedded dashboard's
  /// back; a pushed route pops when null.
  final VoidCallback? onExit;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= kPayWideFlow;
            final header = _FlowHeader(
              title: title,
              subtitle: subtitle,
              step: step,
              steps: steps,
              wide: wide,
              onBack: step == 2
                  ? null
                  : step == 1
                      ? onBackStep
                      : onExit ?? () => Navigator.of(context).maybePop(),
            );
            if (wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(32, 8, 32, 40),
                      child: _Centered(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  child,
                                  if (action != null) ...[
                                    const SizedBox(height: 20),
                                    Align(
                                      alignment: AlignmentDirectional.centerEnd,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(minWidth: 260),
                                        child: action,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (summary != null && step < 2) ...[
                              const SizedBox(width: 24),
                              SizedBox(width: 340, child: summary),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      action == null ? 24 + MediaQuery.viewPaddingOf(context).bottom : 16,
                    ),
                    children: [child],
                  ),
                ),
                if (action != null) _ActionBar(caption: actionCaption, child: action!),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The flow's content width on wide layouts.
class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: child,
        ),
      );
}

class _FlowHeader extends StatelessWidget {
  const _FlowHeader({
    required this.title,
    required this.subtitle,
    required this.step,
    required this.steps,
    required this.wide,
    required this.onBack,
    this.showSteps = true,
  });

  final String title;
  final String? subtitle;
  final int step;
  final List<String> steps;
  final bool wide;
  final VoidCallback? onBack;

  /// Menus have no steps.
  final bool showSteps;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Row(
      children: [
        if (onBack != null) ...[
          _BackButton(onTap: onBack),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: wide ? 24 : 18,
                  fontWeight: FontWeight.w700,
                  color: HomeColors.textPrimary(context),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: wide ? 13.5 : 12.5,
                    color: HomeColors.textSecondary(context),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (wide && showSteps) ...[
          const SizedBox(width: 16),
          _StepDots(step: step, labels: steps),
        ],
      ],
    );
    if (wide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
        child: _Centered(child: titleBlock),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleBlock,
          if (showSteps) ...[
            const SizedBox(height: 12),
            _StepBar(step: step, labels: steps),
          ],
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: HomeColors.card(context),
        shape: CircleBorder(side: BorderSide(color: HomeColors.divider(context))),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Tooltip(
            message: 'Back',
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: HomeColors.textPrimary(context),
              ),
            ),
          ),
        ),
      );
}

/// Wide layouts: `① Details — ② Review — ③ Done` beside the title.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.labels});

  final int step;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Container(
              width: 28,
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: i <= step ? brand : HomeColors.divider(context),
            ),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= step ? brand : HomeColors.card(context),
              border: Border.all(color: i <= step ? brand : HomeColors.divider(context)),
            ),
            child: i < step
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: i == step ? Colors.white : HomeColors.textSecondary(context),
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Text(
            labels[i],
            style: TextStyle(
              fontSize: 13,
              fontWeight: i == step ? FontWeight.w700 : FontWeight.w500,
              color: i <= step
                  ? HomeColors.textPrimary(context)
                  : HomeColors.textSecondary(context),
            ),
          ),
        ],
      ],
    );
  }
}

/// Narrow layouts: a segmented progress bar and "Step 1 of 3 · Details".
class _StepBar extends StatelessWidget {
  const _StepBar({required this.step, required this.labels});

  final int step;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= step ? HomeColors.brand(context) : HomeColors.divider(context),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Step ${step + 1} of ${labels.length} · ${labels[step]}',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: HomeColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}

/// The pinned bottom bar of narrow layouts.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.child, this.caption});

  final Widget child;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.viewPaddingOf(context).bottom),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        border: Border(top: BorderSide(color: HomeColors.divider(context))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (caption != null) ...[
            Text(
              caption!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: HomeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

// ── Cards & text ─────────────────────────────────────────────────────────

BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
      color: HomeColors.card(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: HomeColors.divider(context)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );

class PayCard extends StatelessWidget {
  const PayCard({super.key, required this.child, this.padding = 20});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(padding),
        decoration: _cardDecoration(context),
        child: child,
      );
}

/// One group of a step — "To", "From", "Amount"… — as its own card.
class PaySection extends StatelessWidget {
  const PaySection({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.padding = 18,
  });

  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: HomeColors.brand(context)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: HomeColors.textPrimary(context),
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// A person or bank as initials in a tinted circle — the same colour for
/// the same name everywhere.
class PayAvatar extends StatelessWidget {
  const PayAvatar({super.key, required this.name, this.size = 40, this.icon});

  final String name;
  final double size;

  /// Shown instead of initials.
  final IconData? icon;

  static const _palette = [
    Color(0xFF0E7490),
    Color(0xFF7C5CFC),
    Color(0xFF059669),
    Color(0xFFE5793B),
    Color(0xFFD9467C),
    Color(0xFF2563EB),
  ];

  static String initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    final first = words.first.characters.first;
    final second = words.length > 1 ? words.last.characters.first : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final seed = name.codeUnits.fold<int>(0, (s, c) => (s * 31 + c) & 0x7fffffff);
    final color = icon != null ? HomeColors.brand(context) : _palette[seed % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        shape: BoxShape.circle,
      ),
      child: icon != null
          ? Icon(icon, size: size * 0.48, color: color)
          : Text(
              initials(name),
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
    );
  }
}

/// The live summary of a flow: what the transfer is so far, its total.
class PaySummaryCard extends StatelessWidget {
  const PaySummaryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.rows = const [],
    this.total,
    this.note,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<(String, String)> rows;

  /// The bottom line, highlighted.
  final (String, String)? total;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    return PaySection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: brand, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: HomeColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: HomeColors.divider(context)),
          const SizedBox(height: 6),
          if (rows.isEmpty && total == null)
            PayMuted(note ?? 'Details appear here as you fill in the form.')
          else
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        value,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: HomeColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          if (total != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: brand.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    total!.$1,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: HomeColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      total!.$2,
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: brand),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (note != null && (rows.isNotEmpty || total != null)) ...[
            const SizedBox(height: 10),
            Text(note!, style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context))),
          ],
        ],
      ),
    );
  }
}

class PaySectionLabel extends StatelessWidget {
  const PaySectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: HomeColors.textPrimary(context),
        ),
      );
}

class PayFieldLabel extends StatelessWidget {
  const PayFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: HomeColors.textSecondary(context),
          ),
        ),
      );
}

class PayFieldError extends StatelessWidget {
  const PayFieldError(this.text, {super.key});

  final String? text;

  @override
  Widget build(BuildContext context) => text == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, size: 15, color: HomeColors.error(context)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  text!,
                  style: TextStyle(fontSize: 12, color: HomeColors.error(context)),
                ),
              ),
            ],
          ),
        );
}

class PayMuted extends StatelessWidget {
  const PayMuted(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          style: TextStyle(fontSize: 13, color: HomeColors.textSecondary(context)),
        ),
      );
}

/// A soft notice.
class PayNote extends StatelessWidget {
  const PayNote(this.text, {super.key, this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HomeColors.brand(context).withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: HomeColors.brand(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12.5,
                  color: HomeColors.textPrimary(context),
                ),
              ),
            ),
          ],
        ),
      );
}

class PayPrimaryButton extends StatelessWidget {
  const PayPrimaryButton({
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
        disabledBackgroundColor: HomeColors.brand(context).withValues(alpha: loading ? 0.85 : 0.35),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
    );
  }
}

class PaySecondaryButton extends StatelessWidget {
  const PaySecondaryButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: HomeColors.brand(context),
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          side: BorderSide(color: HomeColors.brand(context).withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

class PayErrorRetry extends StatelessWidget {
  const PayErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HomeColors.error(context).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, size: 18, color: HomeColors.error(context)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 12.5, color: HomeColors.textPrimary(context)),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}

// ── Inputs ───────────────────────────────────────────────────────────────

InputDecoration payInputDecoration(
  BuildContext context, {
  String? hint,
  String? prefix,
  String? helper,
  Widget? suffix,
  Widget? prefixIcon,
  bool hasError = false,
}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: w),
      );
  final idle = hasError ? HomeColors.error(context) : HomeColors.divider(context);
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: HomeColors.textSecondary(context).withValues(alpha: 0.7)),
    helperText: helper,
    helperMaxLines: 2,
    prefixText: prefix == null ? null : '$prefix  ',
    prefixIcon: prefixIcon,
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    suffixIcon: suffix,
    filled: true,
    fillColor: HomeColors.card(context),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    border: border(idle),
    enabledBorder: border(idle),
    focusedBorder: border(HomeColors.brand(context), 1.6),
  );
}

/// A labelled text field with its error.
class PayTextField extends StatelessWidget {
  const PayTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
    this.suffix,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? error;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;
  final Widget? suffix;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PayFieldLabel(label),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            textCapitalization: textCapitalization,
            maxLines: maxLines,
            decoration: payInputDecoration(
              context,
              hint: hint,
              suffix: suffix,
              hasError: error != null,
            ),
          ),
          PayFieldError(error),
        ],
      );
}

/// The amount — large, with its currency as a chip and hints below.
class PayAmountField extends StatelessWidget {
  const PayAmountField({
    super.key,
    required this.controller,
    required this.currency,
    this.error,
    this.helper,
    this.onChanged,
    this.compact = false,
  });

  final TextEditingController controller;
  final String currency;
  final String? error;
  final String? helper;
  final ValueChanged<String>? onChanged;

  /// A smaller field, for lists of amounts.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          onChanged: onChanged,
          style: TextStyle(
            fontSize: compact ? 16 : 28,
            fontWeight: FontWeight.w700,
            color: HomeColors.textPrimary(context),
          ),
          decoration: payInputDecoration(
            context,
            hint: '0.00',
            hasError: error != null,
            prefixIcon: currency.isEmpty
                ? null
                : Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: brand.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        currency,
                        style: TextStyle(
                          fontSize: compact ? 12 : 13,
                          fontWeight: FontWeight.w700,
                          color: brand,
                        ),
                      ),
                    ),
                  ),
          ).copyWith(
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 13 : 18),
          ),
        ),
        if (error != null)
          PayFieldError(error)
        else if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              helper!,
              style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context)),
            ),
          ),
      ],
    );
  }
}

/// A tappable field showing the current choice.
class PayPickerField extends StatelessWidget {
  const PayPickerField({
    super.key,
    required this.placeholder,
    required this.onTap,
    this.title,
    this.subtitle,
    this.icon = Icons.account_balance_wallet_outlined,
    this.leading,
    this.trailingText,
    this.error,
    this.loading = false,
  });

  final String placeholder;
  final String? title;
  final String? subtitle;
  final IconData icon;

  /// Shown instead of [icon] once chosen, e.g. a [PayAvatar].
  final Widget? leading;

  /// A value at the end, e.g. a balance.
  final String? trailingText;
  final VoidCallback? onTap;
  final String? error;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final chosen = title != null && !loading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: HomeColors.card(context),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: error != null ? HomeColors.error(context) : HomeColors.divider(context),
                ),
              ),
              child: Row(
                children: [
                  if (chosen && leading != null)
                    leading!
                  else
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: brand.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: loading
                          ? Padding(
                              padding: const EdgeInsets.all(11),
                              child: CircularProgressIndicator(strokeWidth: 2, color: brand),
                            )
                          : Icon(icon, size: 19, color: brand),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          loading ? 'Loading…' : (title ?? placeholder),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: chosen ? FontWeight.w600 : FontWeight.w500,
                            color: chosen
                                ? HomeColors.textPrimary(context)
                                : HomeColors.textSecondary(context),
                          ),
                        ),
                        if (subtitle != null && !loading) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: HomeColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailingText != null && chosen) ...[
                    const SizedBox(width: 8),
                    Text(
                      trailingText!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: HomeColors.textPrimary(context),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(
                    chosen ? Icons.swap_vert_rounded : Icons.expand_more_rounded,
                    size: 20,
                    color: HomeColors.textSecondary(context),
                  ),
                ],
              ),
            ),
          ),
        ),
        PayFieldError(error),
      ],
    );
  }
}

/// One row of a [showPayPicker] list.
class PayOption<T> {
  const PayOption({
    required this.value,
    required this.title,
    this.subtitle,
    this.trailing,
    this.icon,
    this.avatar,
  });

  final T value;
  final String title;
  final String? subtitle;
  final String? trailing;
  final IconData? icon;

  /// A name to show as a [PayAvatar] instead of [icon].
  final String? avatar;
}

/// Chooses one of [options]: a bottom sheet on a phone, a dialog on a wide
/// screen, with a search box once the list is long.
Future<T?> showPayPicker<T>(
  BuildContext context, {
  required String title,
  required List<PayOption<T>> options,
  T? selected,
  String empty = 'Nothing to choose from.',
  bool? searchable,
}) {
  final panel = _PickerPanel<T>(
    title: title,
    options: options,
    selected: selected,
    empty: empty,
    searchable: searchable ?? options.length > 6,
  );
  if (MediaQuery.sizeOf(context).width >= 768) {
    return showDialog<T>(
      context: context,
      builder: (dialog) => Dialog(
        backgroundColor: HomeColors.card(dialog),
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.sizeOf(dialog).height * 0.7,
          ),
          child: panel,
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheet) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.8),
        decoration: BoxDecoration(
          color: HomeColors.card(sheet),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(top: false, child: panel),
      ),
    ),
  );
}

class _PickerPanel<T> extends StatefulWidget {
  const _PickerPanel({
    required this.title,
    required this.options,
    required this.selected,
    required this.empty,
    required this.searchable,
  });

  final String title;
  final List<PayOption<T>> options;
  final T? selected;
  final String empty;
  final bool searchable;

  @override
  State<_PickerPanel<T>> createState() => _PickerPanelState<T>();
}

class _PickerPanelState<T> extends State<_PickerPanel<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.options
        : widget.options
            .where((o) =>
                o.title.toLowerCase().contains(q) ||
                (o.subtitle?.toLowerCase().contains(q) ?? false))
            .toList();
    final brand = HomeColors.brand(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
          child: Row(
            children: [
              Expanded(child: PaySectionLabel(widget.title)),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: HomeColors.textSecondary(context)),
              ),
            ],
          ),
        ),
        if (widget.searchable)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: payInputDecoration(
                context,
                hint: 'Search',
                prefixIcon: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
                  child: Icon(Icons.search_rounded, size: 20, color: HomeColors.textSecondary(context)),
                ),
              ),
            ),
          ),
        if (widget.options.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: PayMuted(widget.empty),
          )
        else if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: PayMuted('No matches.'),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final o = shown[i];
                final isSelected = o.value == widget.selected;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  selected: isSelected,
                  selectedTileColor: brand.withValues(alpha: 0.07),
                  leading: o.avatar != null
                      ? PayAvatar(name: o.avatar!)
                      : o.icon == null
                          ? null
                          : PayAvatar(name: o.title, icon: o.icon),
                  title: Text(
                    o.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: HomeColors.textPrimary(context),
                    ),
                  ),
                  subtitle: o.subtitle == null
                      ? null
                      : Text(
                          o.subtitle!,
                          style: TextStyle(color: HomeColors.textSecondary(context)),
                        ),
                  trailing: o.trailing != null
                      ? Text(
                          o.trailing!,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: HomeColors.textPrimary(context),
                          ),
                        )
                      : isSelected
                          ? Icon(Icons.check_circle_rounded, color: brand)
                          : null,
                  onTap: () => Navigator.of(context).pop(o.value),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// A date field opening the date picker.
class PayDateField extends StatelessWidget {
  const PayDateField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.first,
    this.last,
    this.placeholder = 'Choose a date',
    this.error,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime first;
  final DateTime? last;
  final String placeholder;
  final String? error;

  @override
  Widget build(BuildContext context) => PayPickerField(
        placeholder: placeholder,
        title: value == null ? null : payDate(value),
        icon: Icons.event_outlined,
        error: error,
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? first,
            firstDate: first,
            lastDate: last ?? DateTime(first.year + 10),
          );
          if (picked != null) onChanged(picked);
        },
      );
}

/// A segmented switch.
class PaySegmented<T> extends StatelessWidget {
  const PaySegmented({
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
        // A tinted track, so the white chip of the choice stands out.
        color: HomeColors.textSecondary(context).withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final (value, label) in options)
            Expanded(
              child: Semantics(
                selected: value == selected,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    constraints: const BoxConstraints(minHeight: 40),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == selected ? HomeColors.card(context) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: value == selected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: value == selected ? FontWeight.w700 : FontWeight.w500,
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

// ── Choosing a way to pay ────────────────────────────────────────────────

/// A way to pay — a tile on the Transfer hub and the transfer menus.
class PayOptionTile extends StatelessWidget {
  const PayOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.comingSoon = false,
    this.horizontal = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// Shown greyed with a "Soon" tag, and does nothing.
  final bool comingSoon;

  /// Icon beside the text (lists) rather than above it (grids).
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final muted = comingSoon;
    final iconBox = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: (muted ? HomeColors.textSecondary(context) : brand).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 22, color: muted ? HomeColors.textSecondary(context) : brand),
    );
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: muted ? HomeColors.textSecondary(context) : HomeColors.textPrimary(context),
                ),
              ),
            ),
            if (comingSoon) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: HomeColors.divider(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Soon',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: HomeColors.textSecondary(context),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context)),
        ),
      ],
    );
    return Semantics(
      button: !comingSoon,
      enabled: !comingSoon,
      child: Material(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: comingSoon ? null : onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: HomeColors.divider(context)),
            ),
            child: horizontal
                ? Row(
                    children: [
                      iconBox,
                      const SizedBox(width: 14),
                      Expanded(child: texts),
                      if (!comingSoon)
                        Icon(Icons.chevron_right_rounded, color: HomeColors.textSecondary(context)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [iconBox, const SizedBox(height: 14), texts],
                  ),
          ),
        ),
      ),
    );
  }
}

/// A page that lists ways to pay — the transfer menus — with the flows'
/// header: two columns of [tiles] when there is room, one on a phone; or
/// [builder]'s own content, given whether the page is wide.
class PayMenuPage extends StatelessWidget {
  const PayMenuPage({
    super.key,
    required this.title,
    this.tiles = const [],
    this.builder,
    this.subtitle,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final List<Widget> tiles;

  /// Content instead of [tiles].
  final Widget Function(BuildContext context, bool wide)? builder;

  /// Back when embedded in the dashboard; a pushed route pops when null.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= kPayWideFlow;
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                _FlowHeader(
                  title: title,
                  subtitle: subtitle,
                  step: 0,
                  steps: const [],
                  wide: wide,
                  showSteps: false,
                  onBack: onBack ?? () => Navigator.of(context).maybePop(),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(wide ? 32 : 16, 4, wide ? 32 : 16, 32),
                  child: _Centered(
                    child: builder?.call(context, wide) ??
                        PayGrid(
                          columns: constraints.maxWidth >= 700 ? 2 : 1,
                          children: tiles,
                        ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Lays [children] out in [columns] equal columns.
class PayGrid extends StatelessWidget {
  const PayGrid({super.key, required this.columns, required this.children, this.gap = 12});

  final int columns;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      if (i > 0) rows.add(SizedBox(height: gap));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < columns; j++) ...[
                if (j > 0) SizedBox(width: gap),
                Expanded(
                  child: i + j < children.length ? children[i + j] : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

// ── Review, result, OTP ──────────────────────────────────────────────────

class PayReviewRow extends StatelessWidget {
  const PayReviewRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.last = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  /// No divider below.
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: HomeColors.divider(context).withValues(alpha: 0.7))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: emphasize ? 14 : 13,
                  fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
                  color: emphasize ? HomeColors.textPrimary(context) : HomeColors.textSecondary(context),
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
                  fontSize: emphasize ? 17 : 13.5,
                  fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                  color: emphasize ? HomeColors.brand(context) : HomeColors.textPrimary(context),
                ),
              ),
            ),
          ],
        ),
      );
}

/// The top of a review: who gets how much.
class PayReceiptHero extends StatelessWidget {
  const PayReceiptHero({
    super.key,
    required this.amount,
    required this.toName,
    this.toDetail,
    this.caption = "You're sending",
    this.avatarIcon,
  });

  final String amount;
  final String toName;
  final String? toDetail;
  final String caption;
  final IconData? avatarIcon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            PayAvatar(name: toName, size: 56, icon: avatarIcon),
            const SizedBox(height: 12),
            Text(caption, style: TextStyle(fontSize: 13, color: HomeColors.textSecondary(context))),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                amount,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: HomeColors.textPrimary(context),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'to $toName',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: HomeColors.textPrimary(context),
              ),
            ),
            if (toDetail != null && toDetail!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                toDetail!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context)),
              ),
            ],
          ],
        ),
      );
}

class PayResultView extends StatelessWidget {
  const PayResultView({
    super.key,
    required this.title,
    required this.message,
    required this.rows,
    required this.onDone,
    this.reference,
    this.amount,
    this.doneLabel = 'Done',
    this.onAnother,
    this.anotherLabel = 'Make another transfer',
    this.warning = false,
  });

  final String title;
  final String message;
  final String? reference;

  /// Shown large under the title.
  final String? amount;
  final List<(String, String)> rows;
  final VoidCallback onDone;
  final String doneLabel;
  final VoidCallback? onAnother;
  final String anotherLabel;

  /// Not everything went through: an amber badge instead of the tick.
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final tone = warning ? HomeColors.warning(context) : HomeColors.success(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaySection(
          padding: 24,
          child: Column(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    warning ? Icons.priority_high_rounded : Icons.check_rounded,
                    size: 40,
                    color: tone,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: HomeColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: HomeColors.textSecondary(context)),
              ),
              if (amount != null) ...[
                const SizedBox(height: 14),
                Text(
                  amount!,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: HomeColors.textPrimary(context),
                  ),
                ),
              ],
              if (reference != null && reference!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _ReferenceChip(reference: reference!),
              ],
            ],
          ),
        ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 16),
          PaySection(
            title: 'Details',
            child: Column(
              children: [
                for (final (i, (label, value)) in rows.indexed)
                  PayReviewRow(label: label, value: value, last: i == rows.length - 1),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, c) {
            final done = PayPrimaryButton(label: doneLabel, onPressed: onDone);
            final another = onAnother == null
                ? null
                : PaySecondaryButton(
                    label: anotherLabel,
                    icon: Icons.refresh_rounded,
                    onPressed: onAnother,
                  );
            if (c.maxWidth >= 520 && another != null) {
              return Row(
                children: [
                  Expanded(child: another),
                  const SizedBox(width: 12),
                  Expanded(child: done),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                done,
                if (another != null) ...[const SizedBox(height: 10), another],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReferenceChip extends StatelessWidget {
  const _ReferenceChip({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      decoration: BoxDecoration(
        color: brand.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Reference ',
            style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context)),
          ),
          Flexible(
            child: Text(
              reference,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: HomeColors.textPrimary(context),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy reference',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.copy_rounded, size: 18, color: brand),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: reference));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Reference copied')));
            },
          ),
        ],
      ),
    );
  }
}

/// Wires a screen to [transferSubmissionProvider]: the OTP sheet on the
/// bank's challenge, failures in a snackbar, [onDone] with the result.
void payListenToSubmission(
  WidgetRef ref,
  BuildContext context, {
  required VoidCallback onDone,
}) {
  ref.listen<TransferSubmissionState>(transferSubmissionProvider, (previous, next) {
    if (next.result != null && previous?.result != next.result) {
      HapticFeedback.mediumImpact();
      onDone();
    }
    if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
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
        builder: (_) => const PayOtpSheet(),
      );
    }
  });
}

class PayOtpSheet extends ConsumerStatefulWidget {
  const PayOtpSheet({super.key});

  @override
  ConsumerState<PayOtpSheet> createState() => _PayOtpSheetState();
}

class _PayOtpSheetState extends ConsumerState<PayOtpSheet> {
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
      setState(() => _localError = 'Enter the code to continue.');
      return;
    }
    setState(() => _localError = null);
    ref.read(transferSubmissionProvider.notifier).verifyOtp(otp);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transferSubmissionProvider);
    ref.listen<TransferSubmissionState>(transferSubmissionProvider, (_, next) {
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
              'Verify the transfer',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: HomeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter the one-time password sent to your registered mobile number.',
              style: TextStyle(fontSize: 13, color: HomeColors.textSecondary(context)),
            ),
            const SizedBox(height: 20),
            OtpPinInput(controller: _otp, focusNode: _focus, obscuringCharacter: '*'),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: HomeColors.error(context)),
              ),
            ],
            if (attempts != null) ...[
              const SizedBox(height: 8),
              Text(
                '$attempts attempts left',
                style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context)),
              ),
            ],
            const SizedBox(height: 20),
            PayPrimaryButton(label: 'Verify', loading: state.isSubmitting, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

/// Asks for the OTP of one submit — for flows that submit several
/// transfers in turn. Returns the code, or null if cancelled.
Future<String?> showPayOtpPrompt(
  BuildContext context, {
  required String title,
  String? error,
  int? attemptsLeft,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (_) => _OtpPrompt(title: title, error: error, attemptsLeft: attemptsLeft),
  );
}

class _OtpPrompt extends StatefulWidget {
  const _OtpPrompt({required this.title, this.error, this.attemptsLeft});

  final String title;
  final String? error;
  final int? attemptsLeft;

  @override
  State<_OtpPrompt> createState() => _OtpPromptState();
}

class _OtpPromptState extends State<_OtpPrompt> {
  final _otp = TextEditingController();
  final _focus = FocusNode();
  String? _localError;

  @override
  void dispose() {
    _otp.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _localError ?? widget.error;
    final bottom = MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: HomeColors.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: HomeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter the one-time password sent to your registered mobile number.',
              style: TextStyle(fontSize: 13, color: HomeColors.textSecondary(context)),
            ),
            const SizedBox(height: 20),
            OtpPinInput(controller: _otp, focusNode: _focus, obscuringCharacter: '*'),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: HomeColors.error(context)),
              ),
            ],
            if (widget.attemptsLeft != null) ...[
              const SizedBox(height: 8),
              Text(
                '${widget.attemptsLeft} attempts left',
                style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context)),
              ),
            ],
            const SizedBox(height: 20),
            PayPrimaryButton(
              label: 'Verify',
              onPressed: () {
                final code = _otp.text.trim();
                if (code.isEmpty) {
                  setState(() => _localError = 'Enter the code to continue.');
                  return;
                }
                Navigator.of(context).pop(code);
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
