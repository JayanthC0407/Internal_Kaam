import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:demo_bank/src/core/models/corp/credit_facility_models.dart';
import 'package:demo_bank/src/infra/repositories/corp/corp_credit_facility_repository.dart';
import 'package:demo_bank/src/view/providers/corp/corp_credit_facility_providers.dart';
import 'package:demo_bank/src/view/screens/corp/corp_colors.dart';
import 'package:demo_bank/src/view/screens/corp/credit_facility/cf_menu.dart';
import 'package:demo_bank/src/view/screens/corp/credit_facility/cf_widgets.dart';
import 'package:demo_bank/src/view/screens/corp/trade_finance/export_lc/tf_filter_widgets.dart';
import 'package:demo_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:demo_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// Facility Summary — OBDX `credit-facility/facility-overview`: Selected
/// Party, the facilities as cards (default) or a tree table, search on the
/// line key, the Facility Summary Filter (client-side), Load More, Download
/// (PDF) and View Hierarchy. Evidence: docs/obdx/features/credit-facility.md §4.
class FacilitySummaryPage extends ConsumerStatefulWidget {
  const FacilitySummaryPage({super.key, required this.onOpen});

  /// A facility link or a kebab option: Facility Details on [tab].
  final void Function(String key, CfDetailTab? tab) onOpen;

  /// Cards shown before Load More (hooks.js:49-69).
  static const pageSize = 5;

  @override
  ConsumerState<FacilitySummaryPage> createState() => _FacilitySummaryPageState();
}

class _FacilitySummaryPageState extends ConsumerState<FacilitySummaryPage> {
  /// OBDX starts with no party: the first load sends `partyId=` (card §4.1).
  String _party = '';
  bool _cards = true;
  String _query = '';
  CfFilter _filter = CfFilter.none;
  int _shown = FacilitySummaryPage.pageSize;
  final _expanded = <String>{};

  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  List<CfFacility> _visible(CfFacilities data) {
    final filtered = _filter.apply(data.all, _today, partyId: _party);
    final q = _query.trim().toLowerCase();
    return q.isEmpty ? filtered : filtered.where((f) => f.key.toLowerCase().contains(q)).toList();
  }

  Future<void> _openFilter(CfFacilities data, CfLookups lookups) async {
    final picked = await _FilterSheet.show(context, initial: _filter, facilities: data.all, currencies: lookups.currencies);
    if (picked != null && mounted) {
      setState(() {
        _filter = picked;
        _shown = FacilitySummaryPage.pageSize;
      });
    }
  }

  void _kebab(CfFacility f, _CardAction action) {
    switch (action) {
      case _CardAction.addSubFacility:
      case _CardAction.amendFacility:
        cfSnack(context, cfComingSoon);
      case _CardAction.collateralGroups:
        widget.onOpen(f.key, CfDetailTab.collateralGroups);
      case _CardAction.covenants:
        widget.onOpen(f.key, CfDetailTab.covenants);
      case _CardAction.utilization:
        widget.onOpen(f.key, CfDetailTab.transactionSummary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookups = ref.watch(cfLookupsProvider).valueOrNull ?? CfLookups.empty;
    final perms = ref.watch(cfPermissionsProvider);
    final async = ref.watch(cfFacilitiesProvider(_party));
    final data = async.valueOrNull;

    return CorpCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lookups.groupCorporate != null || lookups.parties.isNotEmpty) ...[
            _PartyRow(
              lookups: lookups,
              party: _party,
              onParty: (id) => setState(() {
                _party = id;
                _shown = FacilitySummaryPage.pageSize;
                _expanded.clear();
              }),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() {
                    _query = v;
                    _shown = FacilitySummaryPage.pageSize;
                  }),
                  decoration: InputDecoration(
                    hintText: 'Search..',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Summary List View',
                isSelected: _cards,
                icon: const Icon(Icons.view_agenda_outlined),
                selectedIcon: Icon(Icons.view_agenda_rounded, color: CorpColors.brand(context)),
                onPressed: () => setState(() => _cards = true),
              ),
              IconButton(
                tooltip: 'Facility Overview',
                isSelected: !_cards,
                icon: const Icon(Icons.table_rows_outlined),
                selectedIcon: Icon(Icons.table_rows_rounded, color: CorpColors.brand(context)),
                onPressed: () => setState(() => _cards = false),
              ),
              Badge(
                isLabelVisible: _filter.count > 0,
                label: Text('${_filter.count}'),
                backgroundColor: CorpColors.brand(context),
                child: IconButton(
                  tooltip: 'Facility Summary Filter',
                  icon: Icon(Icons.tune_rounded, color: CorpColors.textSecondary(context)),
                  onPressed: data == null ? null : () => _openFilter(data, lookups),
                ),
              ),
              CfDownloadButton(
                fileName: 'FacilitySummary.pdf',
                enabled: data != null && data.roots.isNotEmpty,
                download: () => ref.read(corpCreditFacilityRepositoryProvider).downloadFacilities(_party),
              ),
            ],
          ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LcMessageBanner(message: e is CfLoadError && e.message != null ? e.message! : 'We couldn\'t load the facilities.'),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => ref.invalidate(cfFacilitiesProvider(_party)),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            ),
            data: (data) {
              final rows = _visible(data);
              if (rows.isEmpty) {
                return const LcEmptyState(icon: Icons.account_tree_outlined, title: 'No facilities to show.');
              }
              if (!_cards) {
                return _FacilityTable(
                  roots: data.roots,
                  visible: {for (final f in rows) f.key},
                  expanded: _expanded,
                  onToggle: (key) => setState(() => _expanded.contains(key) ? _expanded.remove(key) : _expanded.add(key)),
                  onExpandAll: () => setState(() => _expanded.addAll([for (final f in data.all) f.key])),
                  onCollapseAll: () => setState(_expanded.clear),
                );
              }
              final shown = rows.take(_shown).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final f in shown)
                    _FacilityCard(
                      facility: f,
                      perms: perms,
                      onOpen: () => widget.onOpen(f.key, null),
                      onHierarchy: () => _Hierarchy.show(context, data.roots, f),
                      onAction: (a) => _kebab(f, a),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    '(Showing ${shown.length} out of ${rows.length} items)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: CorpColors.textSecondary(context)),
                  ),
                  if (shown.length < rows.length)
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => _shown += FacilitySummaryPage.pageSize),
                        child: const Text('Load More'),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PartyRow extends StatelessWidget {
  const _PartyRow({required this.lookups, required this.party, required this.onParty});

  final CfLookups lookups;
  final String party;
  final ValueChanged<String> onParty;

  @override
  Widget build(BuildContext context) {
    final group = lookups.groupCorporate == null ? null : LcInfoItem(label: 'Group Corporate Id', value: lookups.groupCorporate!);
    final picker = lookups.parties.isEmpty
        ? null
        : LcPickerField<CfParty>(
            label: 'Selected Party',
            options: lookups.parties,
            labelOf: (p) => p.label,
            selected: lookups.parties.where((p) => p.id == party).firstOrNull,
            onSelected: (p) => onParty(p.id),
          );
    return LayoutBuilder(
      builder: (context, c) {
        final parts = [if (group != null) group, if (picker != null) picker];
        if (c.maxWidth < 640 || parts.length < 2) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final (i, p) in parts.indexed) ...[if (i > 0) const SizedBox(height: 10), p]],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: parts[0]), const SizedBox(width: 20), Expanded(child: parts[1])],
        );
      },
    );
  }
}

enum _CardAction { addSubFacility, amendFacility, collateralGroups, covenants, utilization }

/// One facility in the summary list view (facility-overview.html:31-83).
class _FacilityCard extends StatelessWidget {
  const _FacilityCard({
    required this.facility,
    required this.perms,
    required this.onOpen,
    required this.onHierarchy,
    required this.onAction,
  });

  final CfFacility facility;
  final CfPermissions perms;
  final VoidCallback onOpen;
  final VoidCallback onHierarchy;
  final ValueChanged<_CardAction> onAction;

  @override
  Widget build(BuildContext context) {
    final f = facility;
    final pct = f.utilizedPercent;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CorpColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CfTag(f.isMainLine ? 'Main line' : 'Sub Line'),
              const Spacer(),
              PopupMenuButton<_CardAction>(
                tooltip: 'More actions',
                onSelected: onAction,
                itemBuilder: (_) => [
                  const PopupMenuItem(value: _CardAction.addSubFacility, child: Text('Add Sub-facility')),
                  const PopupMenuItem(value: _CardAction.amendFacility, child: Text('Amend Facility')),
                  if (perms.collateralGroups)
                    const PopupMenuItem(value: _CardAction.collateralGroups, child: Text('View Collateral Groups')),
                  const PopupMenuItem(value: _CardAction.covenants, child: Text('View Covenants')),
                  if (perms.utilization) const PopupMenuItem(value: _CardAction.utilization, child: Text('View Utilization')),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Wrap(
              spacing: 16,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CfLink(label: f.key, onTap: onOpen, size: 16),
                CfLink(label: 'View Hierarchy', onTap: onHierarchy, size: 13),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: LcInfoGrid(items: [
              ('Revolving Line', cfYesNo(f.revolving)),
              ('Sanctioned Amount', cfMoney(f.effectiveAmount)),
              ('Utilized Amount', cfMoney(f.utilizedAmount)),
              ('Available Amount', cfMoney(f.availableAmount)),
              ('Expiry Date', cfDateOr(f.expiryDate, 'Not Applicable')),
            ]),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: CfUtilizedBar(
              percent: pct,
              label: '${pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 2)} % Utilized',
            ),
          ),
        ],
      ),
    );
  }
}

/// The tree table: Expand All / Collapse All, then one row per facility
/// with its sub-facilities under it (hooks.js:663-694). No links, as in OBDX.
class _FacilityTable extends StatelessWidget {
  const _FacilityTable({
    required this.roots,
    required this.visible,
    required this.expanded,
    required this.onToggle,
    required this.onExpandAll,
    required this.onCollapseAll,
  });

  final List<CfFacility> roots;

  /// Keys left by the filter and search; a parent stays when a child does.
  final Set<String> visible;
  final Set<String> expanded;
  final ValueChanged<String> onToggle;
  final VoidCallback onExpandAll;
  final VoidCallback onCollapseAll;

  static const _widths = [44.0, 170.0, 150.0, 110.0, 150.0, 150.0, 150.0, 120.0];

  bool _keeps(CfFacility f) => visible.contains(f.key) || f.children.any(_keeps);

  @override
  Widget build(BuildContext context) {
    final rows = <(CfFacility, int)>[];
    void walk(List<CfFacility> list, int depth) {
      for (final f in list) {
        if (!_keeps(f)) continue;
        rows.add((f, depth));
        if (expanded.contains(f.key)) walk(f.children, depth + 1);
      }
    }

    walk(roots, 0);
    final head = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CorpColors.textSecondary(context));
    final cell = TextStyle(fontSize: 13, color: CorpColors.textPrimary(context));
    Widget box(int i, Widget child) => SizedBox(width: _widths[i], child: child);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(onPressed: onExpandAll, icon: const Icon(Icons.unfold_more_rounded), label: const Text('Expand All')),
            TextButton.icon(onPressed: onCollapseAll, icon: const Icon(Icons.unfold_less_rounded), label: const Text('Collapse All')),
          ],
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: CorpColors.divider(context).withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  box(0, const SizedBox.shrink()),
                  for (final (i, h) in const [
                    'Line Code',
                    'Facility Category',
                    'Revolving Line',
                    'Sanctioned Amount',
                    'Utilized Amount',
                    'Available Amount',
                    'Expiry Date',
                  ].indexed)
                    box(i + 1, Text(h, style: head)),
                ]),
              ),
              for (final (f, depth) in rows)
                Container(
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: CorpColors.divider(context)))),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    box(
                      0,
                      f.children.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: expanded.contains(f.key) ? 'Collapse' : 'Expand',
                              icon: Icon(expanded.contains(f.key) ? Icons.expand_more_rounded : Icons.chevron_right_rounded),
                              onPressed: () => onToggle(f.key),
                            ),
                    ),
                    box(1, Padding(padding: EdgeInsets.only(left: depth * 14.0), child: Text(f.lineCode, style: cell))),
                    box(2, Text(f.category ?? '—', style: cell)),
                    box(3, Text(f.revolving ? 'YES' : 'NO', style: cell)),
                    box(4, Text(cfMoney(f.effectiveAmount), style: cell)),
                    box(5, Text(cfMoney(f.utilizedAmount), style: cell)),
                    box(6, Text(cfMoney(f.availableAmount), style: cell)),
                    box(7, Text(cfDateOr(f.expiryDate, 'Not Applicable'), style: cell)),
                  ]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// View Hierarchy: the main line holding the facility as an indented tree,
/// the chosen facility highlighted; each node with its Sanctioned Amount
/// (`limitAmount`). OBDX draws a diagram; no node opens anything.
class _Hierarchy {
  static Future<void> show(BuildContext context, List<CfFacility> roots, CfFacility chosen) {
    final main = CfFacility.mainLineOf(roots, chosen.key) ?? chosen;
    return showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('${chosen.key} Hierarchy'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(child: _Node(facility: main, chosen: chosen.key, depth: 0)),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('Close'))],
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.facility, required this.chosen, required this.depth});

  final CfFacility facility;
  final String chosen;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    final selected = facility.key == chosen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: EdgeInsets.only(left: depth * 22.0, bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? brand.withValues(alpha: 0.10) : CorpColors.card(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? brand : CorpColors.divider(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(
                    facility.key,
                    style: TextStyle(fontWeight: FontWeight.w700, color: CorpColors.textPrimary(context)),
                  ),
                ),
                if (depth == 0) ...[const SizedBox(width: 8), const CfTag('Main Line')],
              ]),
              const SizedBox(height: 4),
              Text(
                'Sanctioned Amount: ${cfMoney(facility.limitAmount)}',
                style: TextStyle(fontSize: 12.5, color: CorpColors.textSecondary(context)),
              ),
            ],
          ),
        ),
        for (final c in facility.children) _Node(facility: c, chosen: chosen, depth: depth + 1),
      ],
    );
  }
}

/// Facility Summary Filter (facility-summary-filter): all client-side.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.facilities, required this.currencies});

  final CfFilter initial;
  final List<CfFacility> facilities;
  final List<String> currencies;

  static Future<CfFilter?> show(
    BuildContext context, {
    required CfFilter initial,
    required List<CfFacility> facilities,
    required List<String> currencies,
  }) {
    final sheet = _FilterSheet(initial: initial, facilities: facilities, currencies: currencies);
    if (MediaQuery.sizeOf(context).width >= 700) {
      return showDialog<CfFilter>(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: sheet),
        ),
      );
    }
    return showModalBottomSheet<CfFilter>(context: context, isScrollControlled: true, builder: (_) => sheet);
  }

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _lineCode = widget.initial.lineCode;
  late String? _category = widget.initial.category;
  late bool? _revolving = widget.initial.revolving;
  late CfExpiry? _expiry = widget.initial.expiry;
  late String _customDays = widget.initial.customDays?.toString() ?? '';
  late String? _currency = widget.initial.currency;
  late String _min = _fmt(widget.initial.minAvailable);
  late String _max = _fmt(widget.initial.maxAvailable);
  bool _showErrors = false;

  static String _fmt(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());

  static final _digits = RegExp(r'^\d+$');
  static final _amount = RegExp(r'^\d*\.?\d+$');

  bool get _customInvalid => _expiry == CfExpiry.customize && !_digits.hasMatch(_customDays.trim());
  bool _amountInvalid(String v) => v.trim().isNotEmpty && !_amount.hasMatch(v.trim());

  void _apply() {
    if (_customInvalid || _amountInvalid(_min) || _amountInvalid(_max)) {
      setState(() => _showErrors = true);
      return;
    }
    Navigator.of(context).pop(CfFilter(
      lineCode: _lineCode,
      category: _category,
      revolving: _revolving,
      expiry: _expiry,
      customDays: _expiry == CfExpiry.customize ? int.tryParse(_customDays.trim()) : null,
      currency: _currency,
      minAvailable: double.tryParse(_min.trim()),
      maxAvailable: double.tryParse(_max.trim()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lineCodes = {for (final f in widget.facilities) f.lineCode}.toList();
    final categories = <String, String>{
      for (final f in widget.facilities)
        if (f.category != null) f.category!: f.categoryDesc ?? f.category!,
    };
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Facility Summary Filter',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: CorpColors.textPrimary(context)),
              ),
              const SizedBox(height: 14),
              LcPickerField<String>(
                label: 'Facility Line Code',
                options: lineCodes,
                labelOf: (v) => v,
                selected: _lineCode,
                onSelected: (v) => setState(() => _lineCode = v),
              ),
              const SizedBox(height: 12),
              LcPickerField<String>(
                label: 'Facility Category',
                options: categories.keys.toList(),
                labelOf: (v) => categories[v] ?? v,
                selected: _category,
                onSelected: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 12),
              TfChoiceGroup<bool>(
                label: 'Revolving Line',
                options: const [true, false],
                labelOf: cfYesNo,
                selected: _revolving,
                onChanged: (v) => setState(() => _revolving = v),
              ),
              const SizedBox(height: 12),
              TfChoiceGroup<CfExpiry>(
                label: 'Expiring In',
                options: CfExpiry.values,
                labelOf: (e) => e.label,
                selected: _expiry,
                onChanged: (v) => setState(() => _expiry = v),
              ),
              if (_expiry == CfExpiry.customize) ...[
                const SizedBox(height: 10),
                LcTextField(
                  label: 'Custom Days',
                  initialValue: _customDays,
                  numeric: true,
                  keyboardType: TextInputType.number,
                  helper: _showErrors && _customInvalid ? 'Invalid Number' : null,
                  onChanged: (v) => _customDays = v,
                ),
              ],
              if (widget.currencies.isNotEmpty) ...[
                const SizedBox(height: 12),
                LcPickerField<String>(
                  label: 'Currency',
                  options: widget.currencies,
                  labelOf: (v) => v,
                  selected: _currency,
                  onSelected: (v) => setState(() => _currency = v),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Available Amount Range',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: CorpColors.textSecondary(context)),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _amountField(_min, (v) => _min = v)),
                  const Padding(padding: EdgeInsets.fromLTRB(10, 14, 10, 0), child: Text('-')),
                  Expanded(child: _amountField(_max, (v) => _max = v)),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: LcSecondaryButton(label: 'Reset', onPressed: () => Navigator.of(context).pop(CfFilter.none))),
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

  Widget _amountField(String initial, ValueChanged<String> onChanged) => TextFormField(
        initialValue: initial,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: 'Available Amount',
          isDense: true,
          errorText: _showErrors && _amountInvalid(initial) ? 'Invalid Number' : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
}
