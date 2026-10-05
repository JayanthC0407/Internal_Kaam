import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_lc_initiate_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';

// Building blocks of the Initiate LC sections (design: "Initiate Letter of
// Credit" — SWIFT-tagged field cards, radio rows, info boxes and tables).

/// Section heading ("LC Details", "Goods & Shipment Details"…).
class LcSectionHeading extends StatelessWidget {
  const LcSectionHeading(this.title, {super.key, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: CorpColors.textPrimary(context),
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                fontSize: 12,
                color: CorpColors.textSecondary(context),
              ),
            ),
        ],
      ),
    );
  }
}

/// A field card headed by its SWIFT tag — "50  Applicant Name".
class LcTagCard extends StatelessWidget {
  const LcTagCard({
    super.key,
    required this.title,
    required this.children,
    this.tag,
    this.trailing,
  });

  final String? tag;
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      decoration: BoxDecoration(
        color: CorpColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CorpColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (tag != null) ...[
                Text(
                  tag!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: brand,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: CorpColors.textPrimary(context),
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// Labelled row of radio options. Drawn with icons so it does not depend on
/// the `Radio` group API, which changed across Flutter releases.
class LcRadioGroup<T> extends StatelessWidget {
  const LcRadioGroup({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final List<(T, String)> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    final secondary = CorpColors.textSecondary(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: CorpColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 18,
            children: [
              for (final option in options)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: enabled ? () => onChanged(option.$1) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          option.$1 == value
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: !enabled
                              ? secondary.withValues(alpha: 0.4)
                              : (option.$1 == value ? brand : secondary),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          option.$2,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: option.$1 == value
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: enabled
                                ? CorpColors.textPrimary(context)
                                : secondary.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

const List<(bool, String)> lcYesNoOptions = [(true, 'Yes'), (false, 'No')];
const List<(bool, String)> lcAllowedOptions = [
  (true, 'Allowed'),
  (false, 'Not Allowed'),
];

/// Tinted information box — "Product rules", "Address", hints.
class LcInfoBox extends StatelessWidget {
  const LcInfoBox({super.key, this.title, required this.text, this.action});

  final String? title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: brand.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: brand.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: brand,
              ),
            ),
          if (title != null) const SizedBox(height: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: CorpColors.textPrimary(context),
            ),
          ),
          if (action != null) ...[const SizedBox(height: 4), action!],
        ],
      ),
    );
  }
}

/// Outlined "+ Add …" button used in card headers.
class LcAddButton extends StatelessWidget {
  const LcAddButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: brand,
        side: BorderSide(color: brand.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// A table column — label and relative width.
class LcGridColumn {
  const LcGridColumn(this.label, {this.flex = 2});

  final String label;
  final int flex;
}

/// Bordered table with a tinted header. Scrolls sideways when the space is
/// narrower than [minWidth] (phones), so columns never squash.
class LcGridTable extends StatelessWidget {
  const LcGridTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyText = 'Nothing added yet.',
    this.minWidth = 640,
  });

  final List<LcGridColumn> columns;
  final List<List<Widget>> rows;
  final String emptyText;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final divider = CorpColors.divider(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, box) {
          final width = math.max(box.maxWidth, minWidth);
          final table = SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: CorpColors.tableHeaderBg(context),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      for (final c in columns)
                        Expanded(
                          flex: c.flex,
                          child: Text(
                            c.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: CorpColors.textSecondary(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      emptyText,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: CorpColors.textSecondary(context),
                      ),
                    ),
                  ),
                for (var r = 0; r < rows.length; r++)
                  Container(
                    decoration: BoxDecoration(
                      border: r == 0
                          ? null
                          : Border(top: BorderSide(color: divider)),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Row(
                      children: [
                        for (var i = 0; i < columns.length; i++)
                          Expanded(
                            flex: columns[i].flex,
                            child: i < rows[r].length
                                ? rows[r][i]
                                : const SizedBox.shrink(),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: divider),
                borderRadius: BorderRadius.circular(10),
              ),
              child: box.maxWidth >= minWidth
                  ? table
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: table,
                    ),
            ),
          );
        },
      ),
    );
  }
}

/// Plain table cell text.
class LcCell extends StatelessWidget {
  const LcCell(this.text, {super.key, this.bold = false, this.color});

  final String text;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          color: color ?? CorpColors.textPrimary(context),
        ),
      ),
    );
  }
}

/// Red bin icon for a table "Action" column.
class LcRemoveIcon extends StatelessWidget {
  const LcRemoveIcon({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        tooltip: 'Remove',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.delete_outline_rounded, size: 20),
        color: CorpColors.of(context).error,
        onPressed: onPressed,
      ),
    );
  }
}

/// A bank entered by SWIFT code (verified via `tradeBicCodes`) or, when
/// [allowByName], by name and address. Used for the advising bank, the
/// advise-through bank and "Credit available with".
class LcBankBlock extends ConsumerStatefulWidget {
  const LcBankBlock({
    super.key,
    required this.role,
    required this.label,
    this.allowByName = true,
  });

  final LcBankRole role;
  final String label;
  final bool allowByName;

  @override
  ConsumerState<LcBankBlock> createState() => _LcBankBlockState();
}

class _LcBankBlockState extends ConsumerState<LcBankBlock> {
  /// Bumped on Reset so the text fields start empty again.
  int _generation = 0;

  CorpLcInitiateNotifier get _notifier =>
      ref.read(corpLcInitiateProvider.notifier);

  LcBankSelection get _bank => _notifier.bankOf(widget.role);

  void _set(LcBankSelection bank) => _notifier.setBank(widget.role, bank);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(corpLcInitiateProvider);
    final bank = _notifier.bankOf(widget.role);
    final looking = state.bankLookups.contains(widget.role);
    final message = state.bankMessages[widget.role];
    final key = '${widget.role.name}-$_generation';

    void reset() {
      setState(() => _generation++);
      _set(LcBankSelection(byName: _bank.byName));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.allowByName)
          LcRadioGroup<bool>(
            label: widget.label,
            options: const [(false, 'SWIFT Code'), (true, 'Name and Address')],
            value: bank.byName,
            onChanged: (v) => _set(_bank.copyWith(byName: v)),
          ),
        if (!bank.byName) ...[
          LcTextField(
            key: ValueKey('swift-$key'),
            label: 'SWIFT Code',
            hint: 'Enter SWIFT Code',
            uppercase: true,
            maxLength: 11,
            initialValue: bank.swiftCode,
            onChanged: (v) =>
                _set(_bank.copyWith(swiftCode: v, clearResolved: true)),
            suffix: looking
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: () => _notifier.lookupBank(
                      widget.role,
                      _bank.swiftCode ?? '',
                    ),
                    child: const Text('Verify'),
                  ),
          ),
          if (bank.resolved != null)
            LcInfoBox(
              title: widget.label,
              text: bank.summary,
              action: _ResetLink(onTap: reset),
            )
          else if (message != null)
            LcMessageBanner(message: message),
        ] else ...[
          LcTextField(
            key: ValueKey('name-$key'),
            label: 'Bank Name',
            initialValue: bank.name,
            onChanged: (v) => _set(_bank.copyWith(name: v)),
          ),
          LcTextField(
            key: ValueKey('a1-$key'),
            label: 'Address line 1',
            initialValue: bank.address.line1,
            onChanged: (v) => _set(
              _bank.copyWith(address: _bank.address.copyWith(line1: v)),
            ),
          ),
          LcFieldRow(children: [
            LcTextField(
              key: ValueKey('a2-$key'),
              label: 'Address line 2',
              initialValue: bank.address.line2,
              onChanged: (v) => _set(
                _bank.copyWith(address: _bank.address.copyWith(line2: v)),
              ),
            ),
            LcTextField(
              key: ValueKey('a3-$key'),
              label: 'Address line 3',
              initialValue: bank.address.line3,
              onChanged: (v) => _set(
                _bank.copyWith(address: _bank.address.copyWith(line3: v)),
              ),
            ),
          ]),
        ],
      ],
    );
  }
}

class _ResetLink extends StatelessWidget {
  const _ResetLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, size: 15, color: CorpColors.brand(context)),
            const SizedBox(width: 4),
            Text(
              'Reset',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: CorpColors.brand(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small +/- counter used in the document copies dialog.
class LcCounter extends StatelessWidget {
  const LcCounter({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: CorpColors.textSecondary(context),
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 24,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: CorpColors.textPrimary(context),
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: value < 9 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
