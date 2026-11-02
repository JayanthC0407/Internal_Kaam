import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/corp/credit_facility_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_credit_facility_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/cf_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/export_lc/tf_filter_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// Collateral Summary — OBDX `credit-facility/collateral-overview`: one
/// list of the collaterals in no group, then the collateral groups (each
/// with its Linked Collateral), with search ("Description") and the
/// Collateral Summary filter. Evidence: docs/obdx/features/credit-facility.md §6.
class CollateralSummaryPage extends ConsumerStatefulWidget {
  const CollateralSummaryPage({super.key, this.onOpen});

  /// A collateral code: Collateral Details. Null when not allowed.
  final ValueChanged<String>? onOpen;

  @override
  ConsumerState<CollateralSummaryPage> createState() => _CollateralSummaryPageState();
}

class _CollateralSummaryPageState extends ConsumerState<CollateralSummaryPage> {
  String _query = '';
  CfCollateralFilter _filter = CfCollateralFilter.none;

  /// Groups whose Linked Collateral is open.
  final _open = <String>{};

  Future<void> _openFilter(CfCollateralSummary data) async {
    final picked = await _CollateralFilterSheet.show(context, initial: _filter, types: data.types);
    if (picked != null && mounted) setState(() => _filter = picked);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(cfCollateralSummaryProvider);
    final data = async.valueOrNull;
    return CorpCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Description',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Badge(
                isLabelVisible: _filter.isActive,
                label: const Text('1'),
                backgroundColor: CorpColors.brand(context),
                child: IconButton(
                  tooltip: 'Collateral Summary Filter',
                  icon: Icon(Icons.tune_rounded, color: CorpColors.textSecondary(context)),
                  onPressed: data == null ? null : () => _openFilter(data),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => CfFailed(
              message: cfError(e, 'We couldn\'t load the collaterals.'),
              onRetry: () => ref.invalidate(cfCollateralSummaryProvider),
            ),
            data: (data) {
              final rows = _filter.apply(data.entries).where((r) => _query.trim().isEmpty || r.matches(_query)).toList();
              // OBDX renders nothing at all when there are no groups (card
              // §8.14); the app lists what there is, or says it is empty.
              if (rows.isEmpty) {
                return const LcEmptyState(icon: Icons.inventory_2_outlined, title: 'No collaterals to show.');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final r in rows)
                    switch (r) {
                      CfGroupEntry(:final group) => _GroupCard(
                          group: group,
                          open: _open.contains(group.poolId),
                          onToggle: () => setState(
                              () => _open.contains(group.poolId) ? _open.remove(group.poolId) : _open.add(group.poolId)),
                          onOpen: widget.onOpen,
                        ),
                      CfLooseEntry(:final collateral) => _CollateralCard(collateral: collateral, onOpen: widget.onOpen),
                    },
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A collateral group (type `P`).
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.open, required this.onToggle, this.onOpen});

  final CfCollateralGroup group;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    final g = group;
    MoneyAmount m(double v) => MoneyAmount(amount: v, currency: g.groupAmount?.currency);
    final pct = g.utilizedPercent;
    return CfPanel(
      header: Row(children: [
        Flexible(
          child: Text(g.poolId, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CorpColors.textPrimary(context))),
        ),
        const SizedBox(width: 10),
        const CfTag('Group'),
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LcInfoGrid(items: [
            ('Collateral Group Amount', cfMoney(g.groupAmount)),
            ('Utilized Amount', cfMoney(m(g.shownUtilized))),
            ('Block Amount', cfMoney(m(g.shownBlock))),
            ('Available Amount', cfMoney(g.availableAmount)),
          ]),
          const SizedBox(height: 12),
          CfUtilizedBar(percent: pct, label: '${pct == pct.roundToDouble() ? pct.round() : pct}% Utilized'),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: g.linked.isEmpty ? null : onToggle,
              icon: Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded),
              label: const Text('Linked Collateral'),
            ),
          ),
          if (open)
            for (final c in g.linked) CfLinkedCollateralCard(collateral: c, onOpen: onOpen),
        ],
      ),
    );
  }
}

/// A collateral in no group (type `C`).
class _CollateralCard extends StatelessWidget {
  const _CollateralCard({required this.collateral, this.onOpen});

  final CfCollateral collateral;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    final c = collateral;
    return CfPanel(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CfLink(label: c.code, onTap: onOpen == null ? null : () => onOpen!(c.code), size: 16),
              const CfTag('Not a part of any group'),
            ],
          ),
          // OBDX tests the wrong field, so this never shows there (card §8.13).
          if (c.description != null)
            Text(c.description!, style: TextStyle(fontSize: 12.5, color: CorpColors.textSecondary(context))),
        ],
      ),
      child: LcInfoGrid(items: [
        ('Collateral Value', cfMoney(c.value)),
        ('Collateral Amount(After Haircut)', cfMoney(c.limitContribution)),
        ('End Date', cfDateOr(c.endDate, '-')),
        ('Margin', cfPercent(c.lendableMargin)),
      ]),
    );
  }
}

/// Collateral Summary filter (collateral-overview-filter): Apply Filter
/// chooses the fields; Apply keeps the matching rows, Reset shows all.
class _CollateralFilterSheet extends StatefulWidget {
  const _CollateralFilterSheet({required this.initial, required this.types});

  final CfCollateralFilter initial;
  final List<String> types;

  static Future<CfCollateralFilter?> show(
    BuildContext context, {
    required CfCollateralFilter initial,
    required List<String> types,
  }) {
    final sheet = _CollateralFilterSheet(initial: initial, types: types);
    if (MediaQuery.sizeOf(context).width >= 700) {
      return showDialog<CfCollateralFilter>(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: sheet),
        ),
      );
    }
    return showModalBottomSheet<CfCollateralFilter>(context: context, isScrollControlled: true, builder: (_) => sheet);
  }

  @override
  State<_CollateralFilterSheet> createState() => _CollateralFilterSheetState();
}

class _CollateralFilterSheetState extends State<_CollateralFilterSheet> {
  late CfCollateralFilterMode? _mode = widget.initial.mode;
  late String _groupId = widget.initial.groupId ?? '';
  late String _collateralId = widget.initial.collateralId ?? '';
  late String? _type = widget.initial.type;
  late String _amountMin = _fmt(widget.initial.amountMin);
  late String _amountMax = _fmt(widget.initial.amountMax);
  late String _availableMin = _fmt(widget.initial.availableMin);
  late String _availableMax = _fmt(widget.initial.availableMax);
  bool _showErrors = false;

  static String _fmt(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());

  static final _amount = RegExp(r'^\d*\.?\d+$');

  bool _invalid(String v) => v.trim().isNotEmpty && !_amount.hasMatch(v.trim());

  static String? _text(String v) => v.trim().isEmpty ? null : v.trim();

  void _apply() {
    if ([_amountMin, _amountMax, _availableMin, _availableMax].any(_invalid)) {
      setState(() => _showErrors = true);
      return;
    }
    final mode = _mode;
    if (mode == null) return Navigator.of(context).pop(CfCollateralFilter.none);
    Navigator.of(context).pop(CfCollateralFilter(
      mode: mode,
      groupId: mode == CfCollateralFilterMode.byGroup ? _text(_groupId) : null,
      collateralId: mode == CfCollateralFilterMode.byGroup ? null : _text(_collateralId),
      type: mode == CfCollateralFilterMode.byCollateral ? _type : null,
      amountMin: double.tryParse(_amountMin.trim()),
      amountMax: double.tryParse(_amountMax.trim()),
      availableMin: double.tryParse(_availableMin.trim()),
      availableMax: double.tryParse(_availableMax.trim()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mode = _mode;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Collateral Summary',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: CorpColors.textPrimary(context)),
              ),
              const SizedBox(height: 14),
              TfChoiceGroup<CfCollateralFilterMode>(
                label: 'Apply Filter',
                options: CfCollateralFilterMode.values,
                labelOf: (m) => m.label,
                selected: mode,
                onChanged: (v) => setState(() => _mode = v),
              ),
              if (mode == CfCollateralFilterMode.byCollateral && widget.types.isNotEmpty) ...[
                const SizedBox(height: 12),
                LcPickerField<String>(
                  label: 'Collateral Type',
                  options: widget.types,
                  labelOf: (v) => v,
                  selected: _type,
                  onSelected: (v) => setState(() => _type = v),
                ),
              ],
              if (mode == CfCollateralFilterMode.byGroup) ...[
                const SizedBox(height: 12),
                LcTextField(label: 'Group ID', initialValue: _groupId, onChanged: (v) => _groupId = v),
              ],
              if (mode != null && mode != CfCollateralFilterMode.byGroup) ...[
                const SizedBox(height: 12),
                LcTextField(label: 'Collateral ID', initialValue: _collateralId, onChanged: (v) => _collateralId = v),
              ],
              if (mode != null) ...[
                _range(
                  mode == CfCollateralFilterMode.byCollateral ? 'Collateral Amount Range' : 'Group Amount Range',
                  _amountMin,
                  _amountMax,
                  (v) => _amountMin = v,
                  (v) => _amountMax = v,
                ),
                _range('Available Amount Range', _availableMin, _availableMax, (v) => _availableMin = v,
                    (v) => _availableMax = v),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: LcSecondaryButton(
                      label: 'Reset',
                      onPressed: () => Navigator.of(context).pop(CfCollateralFilter.none),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: LcPrimaryButton(label: 'Apply', onPressed: _apply)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _range(String label, String min, String max, ValueChanged<String> onMin, ValueChanged<String> onMax) {
    Widget field(String value, ValueChanged<String> onChanged) => TextFormField(
          initialValue: value,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            errorText: _showErrors && _invalid(value) ? 'Invalid Number' : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: CorpColors.textSecondary(context))),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: field(min, onMin)),
              const Padding(padding: EdgeInsets.fromLTRB(10, 14, 10, 0), child: Text('-')),
              Expanded(child: field(max, onMax)),
            ],
          ),
        ],
      ),
    );
  }
}
