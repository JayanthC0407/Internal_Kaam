import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/core/utils/corp/corp_money_format.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';
import 'package:ubci_bank/src/view/widgets/simple_option_picker_sheet.dart';

/// Shared building blocks for the Letter of Credit screens.
///
/// Everything here resolves colours through [CorpColors] and sits in
/// [CorpCardShell], so the LC screens read as part of the corporate
/// dashboard in both light and dark themes.

String lcMoney(MoneyAmount? money) => CorpMoneyFormat.formatAmount(money);

String lcAmount(double? amount, String? currency) => amount == null
    ? '—'
    : CorpMoneyFormat.format(amount, currencyCode: currency);

String lcOrDash(String? value) =>
    (value == null || value.trim().isEmpty) ? '—' : value;

String lcYesNo(bool value) => value ? 'Allowed' : 'Not allowed';

// ── Page scaffold ───────────────────────────────────────────────────────

/// Full-screen scaffold for LC routes pushed over the dashboard: corporate
/// background, a plain app bar, a centred max-width body and an optional
/// pinned bottom action bar.
class LcScreenScaffold extends StatelessWidget {
  const LcScreenScaffold({
    super.key,
    required this.title,
    required this.body,
    this.bottomBar,
    this.actions,
    this.subtitle,
  });

  final String title;
  final Widget body;
  final Widget? bottomBar;
  final List<Widget>? actions;

  /// An optional small line under the title, e.g. OBDX's "Party | ***801".
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CorpColors.bg(context),
      appBar: AppBar(
        backgroundColor: CorpColors.card(context),
        foregroundColor: CorpColors.textPrimary(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: _title(context),
        actions: actions,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: body,
          ),
        ),
      ),
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: CorpColors.card(context),
                  border: Border(
                    top: BorderSide(color: CorpColors.divider(context)),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Align(
                  alignment: Alignment.center,
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: bottomBar,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _title(BuildContext context) {
    final heading = Text(
      title,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: CorpColors.textPrimary(context),
      ),
    );
    if (subtitle == null) return heading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        heading,
        Text(
          subtitle!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: CorpColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}

// ── Cards & rows ────────────────────────────────────────────────────────

class LcSectionCard extends StatelessWidget {
  const LcSectionCard({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: CorpCardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CorpCardHeader(title: title, trailing: trailing),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Label / value pairs laid out two-up on wide screens, stacked on phones.
class LcInfoGrid extends StatelessWidget {
  const LcInfoGrid({super.key, required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            for (final (label, value) in items)
              SizedBox(
                width: width,
                child: LcInfoItem(label: label, value: value),
              ),
          ],
        );
      },
    );
  }
}

class LcInfoItem extends StatelessWidget {
  const LcInfoItem({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: CorpColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: CorpColors.textPrimary(context),
          ),
        ),
      ],
    );
  }
}

class LcStatusChip extends StatelessWidget {
  const LcStatusChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = CorpColors.of(context);
    final upper = label.toUpperCase();
    final Color tone;
    if (upper.contains('ACTIVE') || upper.contains('APPROVED')) {
      tone = colors.success;
    } else if (upper.contains('EXPIRED') ||
        upper.contains('REJECT') ||
        upper.contains('CLOSED') ||
        upper.contains('CANCEL')) {
      tone = colors.error;
    } else {
      tone = colors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: tone,
        ),
      ),
    );
  }
}

class LcMessageBanner extends StatelessWidget {
  const LcMessageBanner({
    super.key,
    required this.message,
    this.isError = true,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = CorpColors.of(context);
    final tone = isError ? colors.error : colors.info;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            size: 18,
            color: tone,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: CorpColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LcEmptyState extends StatelessWidget {
  const LcEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: CorpColors.brand(context).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: CorpColors.brand(context), size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: CorpColors.textPrimary(context),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: CorpColors.textSecondary(context),
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

// ── Buttons ─────────────────────────────────────────────────────────────

class LcPrimaryButton extends StatelessWidget {
  const LcPrimaryButton({
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
    final brand = CorpColors.brand(context);
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        disabledBackgroundColor: brand.withValues(alpha: 0.45),
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
                Text(label),
              ],
            ),
    );
  }
}

class LcSecondaryButton extends StatelessWidget {
  const LcSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: brand,
        side: BorderSide(color: brand.withValues(alpha: 0.6)),
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      child: loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: brand),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
                Text(label),
              ],
            ),
    );
  }
}

// ── Form fields ─────────────────────────────────────────────────────────

InputDecoration lcInputDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  String? helper,
  Widget? suffix,
}) {
  final colors = CorpColors.of(context);
  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 2,
    isDense: true,
    filled: true,
    fillColor: colors.inputBackground,
    labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13.5),
    hintStyle: TextStyle(color: colors.inputHint, fontSize: 13.5),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    suffixIcon: suffix,
    border: border(colors.inputBorder),
    enabledBorder: border(colors.inputBorder),
    focusedBorder: border(colors.brand),
  );
}

/// Text input that owns its controller, so parents can rebuild freely
/// without resetting the caret. [initialValue] is read once.
class LcTextField extends StatefulWidget {
  const LcTextField({
    super.key,
    required this.label,
    required this.onChanged,
    this.initialValue,
    this.hint,
    this.helper,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.uppercase = false,
    this.numeric = false,
    this.suffix,
    this.enabled = true,
  });

  final String label;
  final ValueChanged<String> onChanged;
  final String? initialValue;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final bool uppercase;

  /// Digits and a single decimal point only.
  final bool numeric;
  final Widget? suffix;
  final bool enabled;

  @override
  State<LcTextField> createState() => _LcTextFieldState();
}

class _LcTextFieldState extends State<LcTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _controller,
        enabled: widget.enabled,
        onChanged: widget.onChanged,
        maxLines: widget.maxLines,
        maxLength: widget.maxLength,
        keyboardType: widget.numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : widget.keyboardType,
        textCapitalization: widget.uppercase
            ? TextCapitalization.characters
            : TextCapitalization.sentences,
        inputFormatters: [
          if (widget.numeric)
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          if (widget.uppercase) _UpperCaseFormatter(),
        ],
        style: TextStyle(
          fontSize: 14,
          color: CorpColors.textPrimary(context),
        ),
        decoration: lcInputDecoration(
          context,
          label: widget.label,
          hint: widget.hint,
          helper: widget.helper,
          suffix: widget.suffix,
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// Read-only field that opens a picker on tap.
class LcTapField extends StatelessWidget {
  const LcTapField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon = Icons.expand_more_rounded,
    this.helper,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;
  final IconData icon;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          isEmpty: value == null,
          decoration: lcInputDecoration(
            context,
            label: label,
            helper: helper,
            suffix: Icon(icon, color: CorpColors.textSecondary(context)),
          ),
          child: Text(
            value ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: CorpColors.textPrimary(context),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single-select picker over [options], using the app's shared sheet.
class LcPickerField<T> extends StatelessWidget {
  const LcPickerField({
    super.key,
    required this.label,
    required this.options,
    required this.labelOf,
    required this.onSelected,
    this.selected,
    this.subtitleOf,
    this.helper,
  });

  final String label;
  final List<T> options;
  final String Function(T) labelOf;
  final String Function(T)? subtitleOf;
  final ValueChanged<T> onSelected;
  final T? selected;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final current = selected;
    return LcTapField(
      label: label,
      helper: helper ?? (options.isEmpty ? 'No options available' : null),
      value: current == null ? null : labelOf(current),
      onTap: options.isEmpty
          ? null
          : () async {
              final picked = await SimpleOptionPickerSheet.show<T>(
                context,
                title: label,
                options: options,
                labelBuilder: labelOf,
                subtitleBuilder: subtitleOf,
                selected: current,
              );
              if (picked != null) onSelected(picked);
            },
    );
  }
}

class LcDateField extends StatelessWidget {
  const LcDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.helper,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return LcTapField(
      label: label,
      helper: helper,
      icon: Icons.calendar_today_outlined,
      value: value == null ? null : TfDate.display(value),
      onTap: () async {
        final now = DateTime.now();
        final first = firstDate ?? DateTime(now.year - 1);
        var last = lastDate ?? DateTime(now.year + 5);
        // showDatePicker asserts lastDate >= firstDate (e.g. an LC expiring
        // today bounds "latest shipment date" to before `now`).
        if (last.isBefore(first)) last = first;
        var initial = value ?? now;
        if (initial.isBefore(first)) initial = first;
        if (initial.isAfter(last)) initial = last;
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: first,
          lastDate: last,
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

class LcSwitchField extends StatelessWidget {
  const LcSwitchField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: CorpColors.textPrimary(context),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: CorpColors.textSecondary(context),
                    ),
                  ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: CorpColors.brand(context),
          ),
        ],
      ),
    );
  }
}

/// Two fields side by side on wide layouts, stacked on phones.
class LcFieldRow extends StatelessWidget {
  const LcFieldRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

// ── Charges & result ────────────────────────────────────────────────────

class LcChargesList extends StatelessWidget {
  const LcChargesList({
    super.key,
    required this.charges,
    this.loading = false,
    this.message,
  });

  final List<LcCharge>? charges;
  final bool loading;
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final list = charges ?? const <LcCharge>[];
    if (list.isEmpty) {
      return Text(
        message ?? 'No charges returned by the bank.',
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: CorpColors.textSecondary(context),
        ),
      );
    }
    final totals = LcCharge.totalsByCurrency(list);
    return Column(
      children: [
        for (final c in list)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${c.label}${c.isTax ? ' (tax)' : ''}',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: CorpColors.textPrimary(context),
                    ),
                  ),
                ),
                Text(
                  lcMoney(c.amount),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: CorpColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        Divider(color: CorpColors.divider(context)),
        for (final entry in totals.entries)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: CorpColors.textPrimary(context),
                  ),
                ),
              ),
              Text(
                lcAmount(entry.value, entry.key.isEmpty ? null : entry.key),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: CorpColors.brand(context),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Confirmation panel shown after a successful submit.
class LcResultView extends StatelessWidget {
  const LcResultView({
    super.key,
    required this.title,
    required this.outcome,
    required this.onDone,
    this.summary = const [],
  });

  final String title;
  final LcSubmitted outcome;
  final VoidCallback onDone;
  final List<(String, String)> summary;

  @override
  Widget build(BuildContext context) {
    final colors = CorpColors.of(context);
    final pending = outcome.pendingApproval;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: CorpCardShell(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                pending ? Icons.hourglass_top_rounded : Icons.check_rounded,
                color: colors.success,
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              outcome.hostMessage ??
                  (pending
                      ? 'Your request has been sent for approval as per your corporate approval rules.'
                      : 'Your request has been sent to the bank for processing.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            LcInfoGrid(items: [
              if (outcome.referenceNo != null)
                ('Reference number', outcome.referenceNo!),
              if (outcome.lcId != null) ('Application ID', outcome.lcId!),
              ...summary,
            ]),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: LcPrimaryButton(label: 'Done', onPressed: onDone),
            ),
          ],
        ),
      ),
    );
  }
}
