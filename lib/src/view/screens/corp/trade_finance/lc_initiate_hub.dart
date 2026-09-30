import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_profile_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
import 'package:ubci_bank/src/view/routes/corp/corp_routes_const.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// Import LC → Initiate Letter of Credit (design: "Initiate Letter of
/// Credit — Web", 4 frames).
///
/// Four ways to start an LC, one tab each, plus **Create LC** for a blank
/// form. Every tab ends in the same Initiate wizard (`LcInitiateScreen`),
/// prefilled according to [LcInitiateSource]:
///
/// | Tab             | Data                                   | Opens wizard as |
/// |-----------------|----------------------------------------|-----------------|
/// | By Template     | `GET …/letterofcredits/templates`      | template        |
/// | Copy & Initiate | `GET …/letterofcredits?lcNumber=`      | copy            |
/// | By Drafts       | `GET …/letterofcredits/drafts`         | draft           |
/// | Back to Back LC | `GET …/letterofcredits?lcType=Export…` | backToBack      |
class LcInitiateHub extends ConsumerStatefulWidget {
  const LcInitiateHub({super.key, required this.onBack});

  /// Top-left back arrow: returns the dashboard to the previous screen.
  final VoidCallback onBack;

  @override
  ConsumerState<LcInitiateHub> createState() => _LcInitiateHubState();
}

enum _Tab {
  template('By Template'),
  copy('Copy & Initiate'),
  drafts('By Drafts'),
  backToBack('Back to Back LC');

  const _Tab(this.label);
  final String label;
}

class _LcInitiateHubState extends ConsumerState<LcInitiateHub> {
  _Tab _tab = _Tab.template;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Templates and drafts feed the summary cards, so both load up front.
      ref.read(corpLcListProvider(LcListKind.templates).notifier).refresh();
      ref.read(corpLcListProvider(LcListKind.drafts).notifier).refresh();
      ref.read(corpLcLookupsProvider.notifier).ensureLoaded();
    });
  }

  void _createLc() => _openWizard(context, const LcInitiateArgs());

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(onBack: widget.onBack),
        const SizedBox(height: 18),
        if (_tab == _Tab.template) ...[
          const _SummaryCards(),
          const SizedBox(height: 14),
          Text(
            'Select a template to prefill beneficiary and LC terms',
            style: TextStyle(
              fontSize: 13,
              color: CorpColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 10),
        ],
        _TabBarRow(
          selected: _tab,
          onSelected: (t) => setState(() => _tab = t),
          onCreate: _createLc,
        ),
        const SizedBox(height: 14),
        KeyedSubtree(
          key: ValueKey(_tab),
          child: switch (_tab) {
            _Tab.template => const _TemplatesTab(),
            _Tab.copy => const _CopyTab(),
            _Tab.drafts => const _DraftsTab(),
            _Tab.backToBack => _BackToBackTab(onBack: widget.onBack),
          },
        ),
      ],
    );
  }
}

void _openWizard(BuildContext context, LcInitiateArgs args) {
  Navigator.of(context).pushNamed(
    CorpRoutesConst.lcInitiateScreen,
    arguments: args,
  );
}

// ── Row helpers ─────────────────────────────────────────────────────────

/// `Sight` / `Usance` — list DTOs carry it at the top level or inside the
/// product block.
String _draftsAt(CorpLetterOfCredit lc) {
  final raw = TfJson.str(lc.raw['periodIndicator']) ??
      TfJson.str(TfJson.map(lc.raw['letterOfCreditProductDTO'])['periodIndicator']);
  if (raw == null) return '—';
  return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
}

String _type(CorpLetterOfCredit lc) =>
    lc.revolving ? 'Revolving' : 'Non Revolving';

DateTime? _updated(CorpLetterOfCredit lc) =>
    lc.lastUpdatedDate ?? lc.applicationDate;

String _name(CorpLetterOfCredit lc) => lc.draftName ?? lc.id;

bool _matches(CorpLetterOfCredit lc, String query) {
  if (query.isEmpty) return true;
  final q = query.toLowerCase();
  return [lc.id, lc.draftName, lc.counterPartyName, lc.productName]
      .any((v) => v?.toLowerCase().contains(q) ?? false);
}

/// `null` = all types.
bool _typeMatches(CorpLetterOfCredit lc, bool? revolving) =>
    revolving == null || lc.revolving == revolving;

// ── Header ──────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(corpProfileProvider);
    final entity = profile.entityName;
    final partyRef =
        profile.party?.idDisplay ?? profile.profile?.partyIdDisplay;
    final subtitle = [
      if (entity != null) entity,
      if (partyRef != null) 'Party ID $partyRef',
    ].join('  •  ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: CorpColors.card(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: CorpColors.cardBorder(context)),
          ),
          child: InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(10),
            child: Tooltip(
              message: 'Back',
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 22,
                  color: CorpColors.textPrimary(context),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Initiate Letter of Credit',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: CorpColors.textPrimary(context),
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: CorpColors.textSecondary(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Summary cards (By Template) ─────────────────────────────────────────

class _SummaryCards extends ConsumerWidget {
  const _SummaryCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(corpLcListProvider(LcListKind.templates));
    final drafts = ref.watch(corpLcListProvider(LcListKind.drafts));
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final updated = [...templates.items, ...drafts.items]
        .where((lc) => _updated(lc)?.isAfter(weekAgo) ?? false)
        .length;

    String count(CorpLcListState s, int n) =>
        s.isLoading && !s.loaded ? '–' : '$n';

    final cards = [
      _StatCard(
        value: count(templates, templates.items.length),
        label: 'Templates',
        caption: 'Available',
      ),
      _StatCard(
        value: count(templates, updated),
        label: 'Updated',
        caption: 'This week',
      ),
      _StatCard(
        value: count(drafts, drafts.items.length),
        label: 'Drafts',
        caption: 'Ready to review',
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 720 ? 3 : (c.maxWidth >= 460 ? 2 : 1);
        final fit = (c.maxWidth - (columns - 1) * 12) / columns;
        final width = columns == 3 ? (fit > 320 ? 320.0 : fit) : fit;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final card in cards) SizedBox(width: width, child: card)],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.caption,
  });

  final String value;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return CorpCardShell(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: CorpColors.textPrimary(context),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CorpColors.textPrimary(context),
              ),
            ),
          ),
          Flexible(
            child: Text(
              caption,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: CorpColors.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tabs + Create LC ────────────────────────────────────────────────────

class _TabBarRow extends StatelessWidget {
  const _TabBarRow({
    required this.selected,
    required this.onSelected,
    required this.onCreate,
  });

  final _Tab selected;
  final ValueChanged<_Tab> onSelected;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    final tabs = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in _Tab.values)
            InkWell(
              onTap: () => onSelected(tab),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: tab == selected ? brand : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  tab.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        tab == selected ? FontWeight.w700 : FontWeight.w500,
                    color: tab == selected
                        ? brand
                        : CorpColors.textSecondary(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    final create = LcPrimaryButton(
      label: 'Create LC',
      icon: Icons.add_rounded,
      onPressed: onCreate,
    );

    return LayoutBuilder(
      builder: (context, c) => c.maxWidth < 720
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tabs,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: create),
              ],
            )
          : Row(
              children: [
                Expanded(child: tabs),
                const SizedBox(width: 12),
                create,
              ],
            ),
    );
  }
}

// ── Responsive table ────────────────────────────────────────────────────

class _Col {
  const _Col(this.label, {this.flex = 2, this.end = false});

  final String label;
  final int flex;

  /// Right-align (amounts, actions).
  final bool end;
}

/// Table on wide layouts (header band + rows), stacked cards on phones —
/// the first cell becomes the card title, the rest label/value pairs.
class _LcTable extends StatelessWidget {
  const _LcTable({
    required this.columns,
    required this.rows,
    this.onRowTap,
  });

  final List<_Col> columns;
  final List<List<Widget>> rows;
  final void Function(int index)? onRowTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) =>
          c.maxWidth >= 760 ? _table(context) : _cards(context),
    );
  }

  Widget _cell(Widget child, _Col col) => Expanded(
        flex: col.flex,
        child: Align(
          alignment: col.end ? Alignment.centerRight : Alignment.centerLeft,
          child: child,
        ),
      );

  Widget _table(BuildContext context) {
    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: CorpColors.surface(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (final col in columns)
            _cell(
              Text(
                col.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CorpColors.textSecondary(context),
                ),
              ),
              col,
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        for (var i = 0; i < rows.length; i++)
          InkWell(
            onTap: onRowTap == null ? null : () => onRowTap!(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: CorpColors.divider(context)),
                ),
              ),
              child: Row(
                children: [
                  for (var j = 0; j < columns.length; j++)
                    _cell(rows[i][j], columns[j]),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _cards(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          InkWell(
            onTap: onRowTap == null ? null : () => onRowTap!(i),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: CorpColors.divider(context)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  rows[i][0],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (var j = 1; j < columns.length; j++)
                        columns[j].label == 'Actions' ||
                                columns[j].label == 'Action'
                            ? rows[i][j]
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    columns[j].label,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: CorpColors.textSecondary(context),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  rows[i][j],
                                ],
                              ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

Widget _text(BuildContext context, String value, {bool strong = false}) =>
    Text(
      value,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
        color: CorpColors.textPrimary(context),
      ),
    );

Widget _link(BuildContext context, String value) => Text(
      value,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: CorpColors.brand(context),
      ),
    );

/// "Showing 1–10 of 14" + page buttons. Client-side paging: the list
/// endpoints return the whole set.
class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onPage,
    required this.noun,
  });

  final int page;
  final int pageSize;
  final int total;
  final ValueChanged<int> onPage;
  final String noun;

  int get pages => total == 0 ? 1 : ((total - 1) ~/ pageSize) + 1;

  @override
  Widget build(BuildContext context) {
    final from = total == 0 ? 0 : page * pageSize + 1;
    final to = ((page + 1) * pageSize).clamp(0, total);
    final brand = CorpColors.brand(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        children: [
          Text(
            'Page ${page + 1} of $pages  ($from–$to of $total $noun)',
            style: TextStyle(
              fontSize: 12.5,
              color: CorpColors.textSecondary(context),
            ),
          ),
          if (pages > 1)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: page > 0 ? () => onPage(page - 1) : null,
                ),
                for (var p = 0; p < pages; p++)
                  InkWell(
                    onTap: () => onPage(p),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p == page
                            ? brand.withValues(alpha: 0.10)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${p + 1}',
                        style: TextStyle(
                          fontWeight:
                              p == page ? FontWeight.w700 : FontWeight.w500,
                          color: p == page
                              ? brand
                              : CorpColors.textSecondary(context),
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: page < pages - 1 ? () => onPage(page + 1) : null,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Search box + type filter shared by the Templates and Drafts cards.
class _ListToolbar extends StatelessWidget {
  const _ListToolbar({
    required this.title,
    required this.hint,
    required this.onQuery,
    required this.revolving,
    required this.onRevolving,
  });

  final String title;
  final String hint;
  final ValueChanged<String> onQuery;
  final bool? revolving;
  final ValueChanged<bool?> onRevolving;

  @override
  Widget build(BuildContext context) {
    final titleText = Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: CorpColors.textPrimary(context),
      ),
    );
    final search = SizedBox(
      width: 320,
      child: TextField(
        onChanged: onQuery,
        decoration: lcInputDecoration(
          context,
          label: hint,
          suffix: const Icon(Icons.search_rounded),
        ),
      ),
    );
    final filter = PopupMenuButton<int>(
      tooltip: 'Filter by type',
      onSelected: (v) => onRevolving(v == 0 ? null : v == 1),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 0, child: Text('All types')),
        PopupMenuItem(value: 1, child: Text('Revolving')),
        PopupMenuItem(value: 2, child: Text('Non Revolving')),
      ],
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: CorpColors.of(context).inputBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_rounded,
                size: 18, color: CorpColors.textSecondary(context)),
            const SizedBox(width: 8),
            Text(
              revolving == null
                  ? 'All types'
                  : (revolving! ? 'Revolving' : 'Non Revolving'),
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: CorpColors.textPrimary(context),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded,
                size: 18, color: CorpColors.textSecondary(context)),
          ],
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, c) => c.maxWidth < 680
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleText,
                const SizedBox(height: 10),
                TextField(
                  onChanged: onQuery,
                  decoration: lcInputDecoration(
                    context,
                    label: hint,
                    suffix: const Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: filter),
              ],
            )
          : Row(
              children: [
                Expanded(child: titleText),
                search,
                const SizedBox(width: 10),
                filter,
              ],
            ),
    );
  }
}

/// Loading / error / empty handling around a list tab body.
Widget? _listStatus(
  BuildContext context,
  CorpLcListState state, {
  required String emptyTitle,
  String? emptyMessage,
  required VoidCallback onRetry,
  required bool filteredEmpty,
}) {
  if (state.isLoading && state.items.isEmpty) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(child: CircularProgressIndicator()),
    );
  }
  if (state.errorMessage != null && state.items.isEmpty) {
    return LcEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Could not load',
      message: state.errorMessage,
      action: LcSecondaryButton(
        label: 'Try again',
        icon: Icons.refresh_rounded,
        onPressed: onRetry,
      ),
    );
  }
  if (filteredEmpty) {
    return LcEmptyState(
      icon: Icons.description_outlined,
      title: emptyTitle,
      message: emptyMessage,
    );
  }
  return null;
}

// ── By Template ─────────────────────────────────────────────────────────

class _TemplatesTab extends ConsumerStatefulWidget {
  const _TemplatesTab();

  @override
  ConsumerState<_TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends ConsumerState<_TemplatesTab> {
  static const _pageSize = 10;
  String _query = '';
  bool? _revolving;
  int _page = 0;

  static const _cols = [
    _Col('Name', flex: 3),
    _Col('Beneficiary', flex: 3),
    _Col('Updated'),
    _Col('LC Amount', end: true),
    _Col('Drafts At'),
    _Col('Type'),
    _Col('Status'),
    _Col('Actions', flex: 1, end: true),
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(corpLcListProvider(LcListKind.templates));
    final all = [
      for (final t in state.items)
        if (_matches(t, _query) && _typeMatches(t, _revolving)) t,
    ];
    final pages = all.isEmpty ? 1 : ((all.length - 1) ~/ _pageSize) + 1;
    final page = _page.clamp(0, pages - 1);
    final visible = all.skip(page * _pageSize).take(_pageSize).toList();

    final status = _listStatus(
      context,
      state,
      emptyTitle: state.items.isEmpty
          ? 'No templates saved yet'
          : 'No templates match your search',
      emptyMessage: state.items.isEmpty
          ? 'Templates saved in the bank\'s portal appear here.'
          : null,
      onRetry: () =>
          ref.read(corpLcListProvider(LcListKind.templates).notifier).refresh(),
      filteredEmpty: all.isEmpty,
    );

    return CorpCardShell(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ListToolbar(
            title: 'Templates',
            hint: 'Search templates',
            onQuery: (v) => setState(() {
              _query = v.trim();
              _page = 0;
            }),
            revolving: _revolving,
            onRevolving: (v) => setState(() {
              _revolving = v;
              _page = 0;
            }),
          ),
          const SizedBox(height: 16),
          if (status != null)
            status
          else ...[
            _LcTable(
              columns: _cols,
              onRowTap: (i) => _use(visible[i]),
              rows: [
                for (final t in visible)
                  [
                    _link(context, _name(t)),
                    _text(context, lcOrDash(t.counterPartyName)),
                    _text(context, TfDate.display(_updated(t))),
                    _text(context, lcMoney(t.amount)),
                    _text(context, _draftsAt(t)),
                    _text(context, _type(t)),
                    LcStatusChip(label: (t.status ?? 'ACTIVE').toUpperCase()),
                    _TemplateMenu(onUse: () => _use(t)),
                  ],
              ],
            ),
            _Pager(
              page: page,
              pageSize: _pageSize,
              total: all.length,
              noun: 'templates',
              onPage: (p) => setState(() => _page = p),
            ),
          ],
        ],
      ),
    );
  }

  void _use(CorpLetterOfCredit template) =>
      _openWizard(context, LcInitiateArgs.fromTemplate(template));
}

class _TemplateMenu extends StatelessWidget {
  const _TemplateMenu({required this.onUse});

  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Actions',
      onSelected: (_) => onUse(),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 0, child: Text('Use template')),
      ],
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: CorpColors.divider(context)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.more_horiz_rounded,
          color: CorpColors.textSecondary(context),
        ),
      ),
    );
  }
}

// ── Copy & Initiate ─────────────────────────────────────────────────────

class _CopyTab extends ConsumerStatefulWidget {
  const _CopyTab();

  @override
  ConsumerState<_CopyTab> createState() => _CopyTabState();
}

class _CopyTabState extends ConsumerState<_CopyTab> {
  final _controller = TextEditingController();
  String? _fieldError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final ref0 = _controller.text.trim();
    if (ref0.isEmpty) {
      setState(() => _fieldError = 'Reference number is required to find a previous LC.');
      return;
    }
    setState(() => _fieldError = null);
    final notifier = ref.read(corpLcSearchProvider(LcSearchMode.copy).notifier);
    notifier.update((c) => c.copyWith(lcNumber: ref0));
    notifier.search();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(corpLcSearchProvider(LcSearchMode.copy));
    final results = state.results;

    final field = TextField(
      controller: _controller,
      textCapitalization: TextCapitalization.characters,
      onSubmitted: (_) => _search(),
      decoration: lcInputDecoration(
        context,
        label: 'LC reference number',
        hint: 'e.g. 000ILUN20076BKC0',
        suffix: const Icon(Icons.search_rounded),
      ),
    );
    final button = LcPrimaryButton(
      label: 'Search',
      loading: state.isLoading,
      onPressed: _search,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CorpCardShell(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _CardTitle('Search LC'),
              const SizedBox(height: 4),
              const _CardSubtitle(
                'Look up a previous Letter of Credit by reference number and '
                'duplicate its details into a new application.',
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, c) => c.maxWidth < 560
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [field, const SizedBox(height: 10), button],
                      )
                    : Row(
                        children: [
                          SizedBox(width: 480, child: field),
                          const SizedBox(width: 12),
                          button,
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                _fieldError ??
                    'Reference number is required to find a previous LC.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: _fieldError != null
                      ? CorpColors.of(context).error
                      : CorpColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
        if (results != null) ...[
          const SizedBox(height: 14),
          CorpCardShell(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(child: _CardTitle('Matching LCs')),
                    Text(
                      '${results.length} result${results.length == 1 ? '' : 's'} found',
                      style: TextStyle(
                        fontSize: 13,
                        color: CorpColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (state.errorMessage != null)
                  LcMessageBanner(message: state.errorMessage!)
                else if (results.isEmpty)
                  const LcEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No LC found with this reference',
                  )
                else
                  _LcTable(
                    columns: const [
                      _Col('Reference No', flex: 3),
                      _Col('Beneficiary Name', flex: 3),
                      _Col('Amount', end: true),
                      _Col('Expiry Date'),
                      _Col('Action', end: true),
                    ],
                    rows: [
                      for (final lc in results)
                        [
                          InkWell(
                            onTap: () => Navigator.of(context).pushNamed(
                              CorpRoutesConst.lcDetailScreen,
                              arguments:
                                  LcDetailArgs(lcId: lc.id, lcType: lc.lcType),
                            ),
                            child: _link(context, lc.id),
                          ),
                          _text(context, lcOrDash(lc.counterPartyName)),
                          _text(context, lcMoney(lc.amount), strong: true),
                          _text(context, TfDate.display(lc.expiryDate)),
                          _TonalButton(
                            label: 'Copy LC',
                            onPressed: () =>
                                _openWizard(context, LcInitiateArgs.copyOf(lc)),
                          ),
                        ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── By Drafts ───────────────────────────────────────────────────────────

class _DraftsTab extends ConsumerStatefulWidget {
  const _DraftsTab();

  @override
  ConsumerState<_DraftsTab> createState() => _DraftsTabState();
}

class _DraftsTabState extends ConsumerState<_DraftsTab> {
  static const _pageSize = 10;
  String _query = '';
  bool? _revolving;
  int _page = 0;

  static const _cols = [
    _Col('Name', flex: 3),
    _Col('Beneficiary Name', flex: 3),
    _Col('Updated On'),
    _Col('LC Amount', end: true),
    _Col('Drafts At'),
    _Col('Type'),
    _Col('Actions', flex: 1, end: true),
  ];

  Future<void> _delete(CorpLetterOfCredit draft) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete draft?'),
        content: Text('"${_name(draft)}" will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: CorpColors.of(ctx).error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final error = await ref
        .read(corpLcListProvider(LcListKind.drafts).notifier)
        .deleteDraft(draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Draft deleted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(corpLcListProvider(LcListKind.drafts));
    final all = [
      for (final d in state.items)
        if (_matches(d, _query) && _typeMatches(d, _revolving)) d,
    ];
    final pages = all.isEmpty ? 1 : ((all.length - 1) ~/ _pageSize) + 1;
    final page = _page.clamp(0, pages - 1);
    final visible = all.skip(page * _pageSize).take(_pageSize).toList();

    final status = _listStatus(
      context,
      state,
      emptyTitle:
          state.items.isEmpty ? 'No saved drafts' : 'No drafts match your search',
      emptyMessage: state.items.isEmpty
          ? 'Drafts you save while initiating an LC appear here.'
          : null,
      onRetry: () =>
          ref.read(corpLcListProvider(LcListKind.drafts).notifier).refresh(),
      filteredEmpty: all.isEmpty,
    );

    return CorpCardShell(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ListToolbar(
            title: 'Drafts',
            hint: 'Search drafts…',
            onQuery: (v) => setState(() {
              _query = v.trim();
              _page = 0;
            }),
            revolving: _revolving,
            onRevolving: (v) => setState(() {
              _revolving = v;
              _page = 0;
            }),
          ),
          const SizedBox(height: 16),
          if (status != null)
            status
          else ...[
            _LcTable(
              columns: _cols,
              onRowTap: (i) =>
                  _openWizard(context, LcInitiateArgs.fromDraft(visible[i])),
              rows: [
                for (final d in visible)
                  [
                    _link(context, _name(d)),
                    _text(context, lcOrDash(d.counterPartyName)),
                    _text(context, TfDate.display(_updated(d))),
                    _text(context, lcMoney(d.amount)),
                    _text(context, _draftsAt(d)),
                    _text(context, _type(d)),
                    IconButton(
                      tooltip: 'Delete draft',
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: CorpColors.of(context).error,
                      onPressed: () => _delete(d),
                    ),
                  ],
              ],
            ),
            _Pager(
              page: page,
              pageSize: _pageSize,
              total: all.length,
              noun: 'items',
              onPage: (p) => setState(() => _page = p),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Back to Back LC ─────────────────────────────────────────────────────

class _BackToBackTab extends ConsumerStatefulWidget {
  const _BackToBackTab({required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<_BackToBackTab> createState() => _BackToBackTabState();
}

class _BackToBackTabState extends ConsumerState<_BackToBackTab> {
  bool _showOptions = true;

  /// Bumped on Clear so the text fields rebuild empty.
  int _formVersion = 0;

  CorpLcSearchNotifier get _notifier =>
      ref.read(corpLcSearchProvider(LcSearchMode.backToBack).notifier);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(corpLcSearchProvider(LcSearchMode.backToBack));
    final lookups = ref.watch(corpLcLookupsProvider).lookups;
    final entity = ref.watch(corpProfileProvider).entityName;
    final c = state.criteria;
    final results = state.results;
    final far = DateTime(2000);
    final future = DateTime(DateTime.now().year + 10);

    TradeCode? currency;
    for (final code in lookups.currencies) {
      if (code.code == c.currency) currency = code;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CorpCardShell(
          padding: const EdgeInsets.all(20),
          child: KeyedSubtree(
            key: ValueKey(_formVersion),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _CardTitle('Search LC'),
                const SizedBox(height: 4),
                const _CardSubtitle(
                  'Find the Export LC issued in your favour that will back the '
                  'new Import LC.',
                ),
                const SizedBox(height: 16),
                LcFieldRow(children: [
                  LcTextField(
                    label: 'Reference Number',
                    hint: 'Enter reference number',
                    uppercase: true,
                    initialValue: c.lcNumber,
                    suffix: const Icon(Icons.search_rounded),
                    onChanged: (v) =>
                        _notifier.update((x) => x.copyWith(lcNumber: v)),
                  ),
                  if (entity != null)
                    _FixedChip(label: 'Beneficiary Name', value: entity)
                  else
                    const SizedBox.shrink(),
                ]),
                if (_showOptions) ...[
                  LcTextField(
                    label: 'Applicant Name',
                    hint: 'All Parties',
                    initialValue: c.applicantName,
                    onChanged: (v) =>
                        _notifier.update((x) => x.copyWith(applicantName: v)),
                  ),
                  const _GroupLabel('Application Date Range'),
                  LcFieldRow(children: [
                    LcDateField(
                      label: 'From',
                      value: c.issueFrom,
                      firstDate: far,
                      lastDate: future,
                      onChanged: (v) =>
                          _notifier.update((x) => x.copyWith(issueFrom: v)),
                    ),
                    LcDateField(
                      label: 'To',
                      value: c.issueTo,
                      firstDate: far,
                      lastDate: future,
                      onChanged: (v) =>
                          _notifier.update((x) => x.copyWith(issueTo: v)),
                    ),
                  ]),
                  const _GroupLabel('Amount Range'),
                  LcFieldRow(children: [
                    LcPickerField<TradeCode>(
                      label: 'Currency',
                      options: lookups.currencies,
                      selected: currency,
                      labelOf: (x) => x.code,
                      subtitleOf: (x) => x.description ?? '',
                      helper: currency == null ? 'All' : null,
                      onSelected: (x) =>
                          _notifier.update((y) => y.copyWith(currency: x.code)),
                    ),
                    LcTextField(
                      label: 'From',
                      hint: '0.00',
                      numeric: true,
                      initialValue: c.fromAmount?.toStringAsFixed(2),
                      onChanged: (v) => _notifier.update(
                        (x) => x.copyWith(fromAmount: double.tryParse(v)),
                      ),
                    ),
                    LcTextField(
                      label: 'To',
                      hint: '0.00',
                      numeric: true,
                      initialValue: c.toAmount?.toStringAsFixed(2),
                      onChanged: (v) => _notifier.update(
                        (x) => x.copyWith(toAmount: double.tryParse(v)),
                      ),
                    ),
                  ]),
                  const _GroupLabel('Expiry Date Range'),
                  LcFieldRow(children: [
                    LcDateField(
                      label: 'From',
                      value: c.expiryFrom,
                      firstDate: far,
                      lastDate: future,
                      onChanged: (v) =>
                          _notifier.update((x) => x.copyWith(expiryFrom: v)),
                    ),
                    LcDateField(
                      label: 'To',
                      value: c.expiryTo,
                      firstDate: far,
                      lastDate: future,
                      onChanged: (v) =>
                          _notifier.update((x) => x.copyWith(expiryTo: v)),
                    ),
                  ]),
                ],
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 10,
                  spacing: 10,
                  children: [
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _showOptions = !_showOptions),
                      icon: Icon(_showOptions
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded),
                      label: Text(_showOptions
                          ? 'Hide search options'
                          : 'Show search options'),
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        LcSecondaryButton(
                          label: 'Back',
                          onPressed: widget.onBack,
                        ),
                        LcSecondaryButton(
                          label: 'Clear',
                          onPressed: () {
                            _notifier.clear();
                            setState(() => _formVersion++);
                          },
                        ),
                        LcPrimaryButton(
                          label: 'Search',
                          loading: state.isLoading,
                          onPressed: _notifier.search,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (results != null) ...[
          const SizedBox(height: 14),
          CorpCardShell(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(child: _CardTitle('Export LCs')),
                    Text(
                      '${results.length} result${results.length == 1 ? '' : 's'} found',
                      style: TextStyle(
                        fontSize: 13,
                        color: CorpColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (state.errorMessage != null)
                  LcMessageBanner(message: state.errorMessage!)
                else if (results.isEmpty)
                  const LcEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No Export LC matches these criteria',
                    message:
                        'Only active Export LCs available for back-to-back are listed.',
                  )
                else
                  _LcTable(
                    columns: const [
                      _Col('Reference No', flex: 3),
                      _Col('Applicant Name', flex: 3),
                      _Col('Amount', end: true),
                      _Col('Expiry Date'),
                      _Col('Action', end: true),
                    ],
                    rows: [
                      for (final lc in results)
                        [
                          _link(context, lc.id),
                          _text(context, lcOrDash(lc.counterPartyName)),
                          _text(context, lcMoney(lc.amount), strong: true),
                          _text(context, TfDate.display(lc.expiryDate)),
                          _TonalButton(
                            label: 'Initiate B2B',
                            onPressed: () => _openWizard(
                              context,
                              LcInitiateArgs.backToBack(lc),
                            ),
                          ),
                        ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Small pieces ────────────────────────────────────────────────────────

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: CorpColors.textPrimary(context),
        ),
      );
}

class _CardSubtitle extends StatelessWidget {
  const _CardSubtitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 13.5,
          height: 1.4,
          color: CorpColors.textSecondary(context),
        ),
      );
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: CorpColors.textPrimary(context),
          ),
        ),
      );
}

/// Light, brand-tinted row action ("Copy LC").
class _TonalButton extends StatelessWidget {
  const _TonalButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: brand.withValues(alpha: 0.08),
        foregroundColor: brand,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: brand.withValues(alpha: 0.18)),
        ),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}

/// Read-only, highlighted criterion (the beneficiary is always us).
class _FixedChip extends StatelessWidget {
  const _FixedChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: brand.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: brand.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CorpColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CorpColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}
