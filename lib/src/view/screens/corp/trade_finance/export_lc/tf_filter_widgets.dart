import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';

/// Form pieces the Trade Finance search forms share (Export LCs, Export
/// Bills).

/// A labelled row of choice chips with an "Any" option, so a filter can be
/// set and unset by tapping — on a phone and with a mouse alike.
class TfChoiceGroup<T> extends StatelessWidget {
  const TfChoiceGroup({
    super.key,
    required this.label,
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<T> options;
  final String Function(T) labelOf;
  final T? selected;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String text, bool isSelected, VoidCallback onTap) => ChoiceChip(
          label: Text(text),
          selected: isSelected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          selectedColor: CorpColors.brand(context).withValues(alpha: 0.14),
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? CorpColors.brand(context)
                : CorpColors.textSecondary(context),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: CorpColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              chip('Any', selected == null, () => onChanged(null)),
              for (final o in options)
                chip(labelOf(o), o == selected, () => onChanged(o)),
            ],
          ),
        ],
      ),
    );
  }
}

/// [LcDateField] with a way to take the date off again.
class TfClearableDate extends StatelessWidget {
  const TfClearableDate({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LcDateField(
            label: label,
            value: value,
            firstDate: DateTime(now.year - 20),
            lastDate: DateTime(now.year + 20),
            onChanged: onChanged,
          ),
        ),
        if (value != null)
          IconButton(
            tooltip: 'Clear $label',
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => onChanged(null),
          ),
      ],
    );
  }
}
