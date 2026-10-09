import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/bank_guarantee_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_bank_guarantee_providers.dart';
import 'package:ubci_bank/src/view/routes/corp/corp_routes_const.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/bank_guarantee/bg_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/bank_guarantee/bg_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// Guarantee (or Kafalah)/Stand By LC Amend Acceptance
/// (`inward-guarantee-amendment[-islamic]`, BG #52 / #64).
///
/// Amendments and cancellations awaiting the beneficiary's answer
/// (BG #62 / #67). The user ticks one or more, writes the special
/// instructions (required, up to 210 characters, as on the web) and
/// approves or rejects them together; the decision is confirmed on the
/// review screen before anything is sent.
class BgAmendmentAcceptancePage extends ConsumerStatefulWidget {
  const BgAmendmentAcceptancePage({
    super.key,
    required this.category,
    required this.onCancel,
  });

  final BgCategory category;
  final VoidCallback onCancel;

  static const double tableFrom = 860;
  static const int instructionsMax = 210;

  @override
  ConsumerState<BgAmendmentAcceptancePage> createState() =>
      _BgAmendmentAcceptancePageState();
}

class _BgAmendmentAcceptancePageState
    extends ConsumerState<BgAmendmentAcceptancePage> {
  final Set<String> _selected = {};
  String _query = '';
  String _instructions = '';
  String? _actionError;
  int _formGeneration = 0;

  BgAmendmentsNotifier get _notifier =>
      ref.read(corpBgAmendmentsProvider(widget.category).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifier.refresh();
    });
  }

  List<CorpBgAmendment> _visible(List<CorpBgAmendment> items) {
    final q = _query.toLowerCase();
    if (q.isEmpty) return items;
    return [
      for (final a in items)
        if ([a.bgId, a.applicantName, a.productLabel, a.id]
            .any((v) => v?.toLowerCase().contains(q) ?? false))
          a,
    ];
  }

  void _toggle(CorpBgAmendment a, bool on) => setState(() {
        on ? _selected.add(a.key) : _selected.remove(a.key);
        _actionError = null;
      });

  void _toggleAll(List<CorpBgAmendment> visible, bool on) => setState(() {
        for (final a in visible) {
          on ? _selected.add(a.key) : _selected.remove(a.key);
        }
        _actionError = null;
      });

  Future<void> _decide(List<CorpBgAmendment> all, bool accept) async {
    final picked = [for (final a in all) if (_selected.contains(a.key)) a];
    String? error;
    if (picked.isEmpty) {
      error = 'Select at least one amendment to continue.';
    } else if (_instructions.trim().isEmpty) {
      error = 'Add special instructions for the bank before you '
          '${accept ? 'approve' : 'reject'}.';
    }
    setState(() => _actionError = error);
    if (error != null) return;

    final sent = await Navigator.of(context).pushNamed(
      CorpRoutesConst.bgAcceptanceReviewScreen,
      arguments: BgAcceptanceReviewArgs(
        request: BgAcceptanceRequest(
          category: widget.category,
          amendments: picked,
          accept: accept,
          instructions: _instructions.trim(),
        ),
      ),
    );
    // The review screen pops `true` once the responses were sent; the
    // list itself refreshes from the acceptance notifier.
    if (sent == true && mounted) {
      setState(() {
        _selected.clear();
        _instructions = '';
        _formGeneration++;
      });
    }
  }

  void _view(CorpBgAmendment a) {
    Navigator.of(context).pushNamed(
      CorpRoutesConst.bgAmendmentScreen,
      arguments: BgAmendmentArgs(amendment: a),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(corpBgAmendmentsProvider(widget.category));
    final lookups =
        ref.watch(bgLookupsProvider(false)).valueOrNull ?? BgLookups.empty;
    final noun = widget.category.lowerNoun;

    // Drop ticks for rows that are no longer pending.
    final keys = {for (final a in state.items) a.key};
    _selected.removeWhere((k) => !keys.contains(k));

    final visible = _visible(state.items);
    final allTicked =
        visible.isNotEmpty && visible.every((a) => _selected.contains(a.key));
    final busy = state.isLoading;

    final search = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BgQuickSearch(
        hint: 'Search by $noun number, applicant or product',
        onChanged: (q) => setState(() => _query = q),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CorpCardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CorpCardHeader(
                title: state.loaded
                    ? '${state.items.length} pending acceptance'
                        '${state.items.length == 1 ? '' : 's'}'
                    : 'Pending acceptances',
                trailing: IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded),
                  color: CorpColors.textSecondary(context),
                  onPressed: busy ? null : _notifier.refresh,
                ),
              ),
              const SizedBox(height: 12),
              if (lookups.hasRelatedParties)
                LayoutBuilder(
                  builder: (context, c) {
                    final party = BgPartyField(
                      label: 'Select party',
                      parties: lookups.parties,
                      selectedId: state.partyId,
                      onChanged: _notifier.setParty,
                    );
                    return c.maxWidth >= 600
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: party),
                              const SizedBox(width: 12),
                              Expanded(child: search),
                            ],
                          )
                        : Column(children: [party, search]);
                  },
                )
              else
                search,
              if (state.errorMessage != null)
                LcMessageBanner(message: state.errorMessage!),
              if (busy && state.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (visible.isEmpty && state.errorMessage == null)
                LcEmptyState(
                  icon: Icons.fact_check_outlined,
                  title: _query.isEmpty
                      ? 'Nothing awaiting your answer'
                      : 'No results for "$_query"',
                  message: _query.isEmpty
                      ? 'When an issuing bank amends or cancels one of your '
                          '${noun}s, it appears here for you to approve or '
                          'reject.'
                      : null,
                )
              else if (visible.isNotEmpty) ...[
                if (busy) const LinearProgressIndicator(minHeight: 2),
                LayoutBuilder(
                  builder: (context, c) =>
                      c.maxWidth >= BgAmendmentAcceptancePage.tableFrom
                          ? _Table(
                              items: visible,
                              selected: _selected,
                              allTicked: allTicked,
                              onToggle: _toggle,
                              onToggleAll: (on) => _toggleAll(visible, on),
                              onView: _view,
                            )
                          : _Cards(
                              items: visible,
                              selected: _selected,
                              allTicked: allTicked,
                              onToggle: _toggle,
                              onToggleAll: (on) => _toggleAll(visible, on),
                              onView: _view,
                            ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        CorpCardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CorpCardHeader(title: 'Special instructions'),
              const SizedBox(height: 12),
              LcTextField(
                key: ValueKey(_formGeneration),
                label: 'Instructions to the bank',
                hint: 'Sent with your answer to every selected amendment',
                maxLines: 3,
                maxLength: BgAmendmentAcceptancePage.instructionsMax,
                onChanged: (v) => setState(() {
                  _instructions = v;
                  _actionError = null;
                }),
              ),
              if (_actionError != null) LcMessageBanner(message: _actionError!),
              Text(
                _selected.isEmpty
                    ? 'No amendments selected'
                    : '${_selected.length} selected',
                style: TextStyle(
                  fontSize: 12.5,
                  color: CorpColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 140,
                    child: LcPrimaryButton(
                      label: 'Approve',
                      icon: Icons.check_rounded,
                      onPressed: () => _decide(state.items, true),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: LcSecondaryButton(
                      label: 'Reject',
                      icon: Icons.close_rounded,
                      onPressed: () => _decide(state.items, false),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextButton(
                      onPressed: widget.onCancel,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        foregroundColor: CorpColors.textSecondary(context),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const BgInfoNote(BgInfoNote.indicative),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({
    required this.items,
    required this.selected,
    required this.allTicked,
    required this.onToggle,
    required this.onToggleAll,
    required this.onView,
  });

  final List<CorpBgAmendment> items;
  final Set<String> selected;
  final bool allTicked;
  final void Function(CorpBgAmendment, bool) onToggle;
  final ValueChanged<bool> onToggleAll;
  final ValueChanged<CorpBgAmendment> onView;

  static const _columns = <(String, double, Alignment)>[
    ('', 0.45, Alignment.center),
    ('Amendment', 1.3, Alignment.centerLeft),
    ('Product', 1.4, Alignment.centerLeft),
    ('Applicant', 1.4, Alignment.centerLeft),
    ('Number', 1.4, Alignment.centerLeft),
    ('Undertaking', 1.3, Alignment.centerRight),
    ('Equivalent', 1.3, Alignment.centerRight),
    ('Type', 0.9, Alignment.centerLeft),
    ('', 0.6, Alignment.centerRight),
  ];

  @override
  Widget build(BuildContext context) {
    final head = bgHeadStyle(context);
    final cell = bgCellStyle(context);
    final divider = BoxDecoration(
      border: Border(bottom: BorderSide(color: CorpColors.divider(context))),
    );
    Widget pad(Widget child, int i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Align(alignment: _columns[i].$3, child: child),
        );

    return Table(
      columnWidths: {
        for (var i = 0; i < _columns.length; i++)
          i: FlexColumnWidth(_columns[i].$2),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: divider,
          children: [
            pad(
              Checkbox(
                value: allTicked,
                onChanged: (v) => onToggleAll(v ?? false),
                semanticLabel: 'Select all',
              ),
              0,
            ),
            for (var i = 1; i < _columns.length; i++)
              pad(Text(_columns[i].$1, style: head), i),
          ],
        ),
        for (final a in items)
          TableRow(
            decoration: divider,
            children: [
              pad(
                Checkbox(
                  value: selected.contains(a.key),
                  onChanged: (v) => onToggle(a, v ?? false),
                  semanticLabel: 'Select amendment ${a.id} of ${a.bgId}',
                ),
                0,
              ),
              pad(
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(a.id, style: cell.copyWith(fontWeight: FontWeight.w700)),
                    BgAmendmentKindChip(amendment: a),
                  ],
                ),
                1,
              ),
              pad(Text(a.productLabel, style: cell), 2),
              pad(Text(lcOrDash(a.applicantName), style: cell), 3),
              pad(Text(a.bgId, style: cell), 4),
              pad(Text(lcMoney(a.newAmount), style: cell), 5),
              pad(Text(lcMoney(a.equivalentAmount), style: cell), 6),
              pad(Text(lcOrDash(a.typeLabel), style: cell), 7),
              pad(
                TextButton(onPressed: () => onView(a), child: const Text('View')),
                8,
              ),
            ],
          ),
      ],
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards({
    required this.items,
    required this.selected,
    required this.allTicked,
    required this.onToggle,
    required this.onToggleAll,
    required this.onView,
  });

  final List<CorpBgAmendment> items;
  final Set<String> selected;
  final bool allTicked;
  final void Function(CorpBgAmendment, bool) onToggle;
  final ValueChanged<bool> onToggleAll;
  final ValueChanged<CorpBgAmendment> onView;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(
      fontSize: 12,
      color: CorpColors.textSecondary(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          value: allTicked,
          onChanged: (v) => onToggleAll(v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('Select all', style: muted.copyWith(fontSize: 13)),
        ),
        for (final a in items)
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: CorpColors.divider(context)),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: selected.contains(a.key),
                  onChanged: (v) => onToggle(a, v ?? false),
                  semanticLabel: 'Select amendment ${a.id} of ${a.bgId}',
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: () => onToggle(a, !selected.contains(a.key)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${a.bgId} · ${a.kindLabel} ${a.id}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: CorpColors.textPrimary(context),
                                ),
                              ),
                            ),
                            BgAmendmentKindChip(amendment: a),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${a.productLabel} · ${lcOrDash(a.applicantName)}',
                          style: muted,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: LcInfoItem(
                                label: 'Undertaking',
                                value: lcMoney(a.newAmount),
                              ),
                            ),
                            Expanded(
                              child: LcInfoItem(
                                label: 'Equivalent',
                                value: lcMoney(a.equivalentAmount),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(onPressed: () => onView(a), child: const Text('View')),
              ],
            ),
          ),
      ],
    );
  }
}
