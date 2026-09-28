import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
import 'package:ubci_bank/src/view/routes/corp/corp_routes_const.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_menu.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// A Trade Finance screen, rendered *inside* the corporate shell (the
/// sidebar, header and session handling stay live).
///
/// Shown only while an option picked in the sidebar tree is open — there is
/// no Trade Finance landing page. The back arrow at the top left calls
/// [onBack], which returns the dashboard to the screen the user came from.
///
/// List-type options render here; forms (initiate, amend, transfer,
/// acceptance) and the LC detail open as pushed routes on top.
class CorpTradeFinanceWorkspace extends StatelessWidget {
  const CorpTradeFinanceWorkspace({
    super.key,
    required this.action,
    required this.onBack,
  });

  final LcMenuAction action;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final pad = width < 600 ? 16.0 : 24.0;
    final current = action;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(pad, 12, pad, 32),
      children: [
        _PageHeader(action: current, onBack: onBack),
        const SizedBox(height: 14),
        KeyedSubtree(
          key: ValueKey(current),
          child: switch (current) {
            LcMenuAction.importInitiate => const _InitiatePage(),
            LcMenuAction.importAmend => _LcListPage(
                kind: LcListKind.amendable,
                emptyMessage:
                    'Only active, unexpired Import LCs can be amended.',
                hideExpired: true,
                onOpen: (context, lc) => Navigator.of(context).pushNamed(
                  CorpRoutesConst.lcAmendScreen,
                  arguments: LcAmendArgs(lcId: lc.id),
                ),
              ),
            LcMenuAction.importView => _LcListPage(
                kind: LcListKind.importLc,
                onOpen: _openDetail,
              ),
            LcMenuAction.exportView => _LcListPage(
                kind: LcListKind.exportLc,
                onOpen: _openDetail,
              ),
            LcMenuAction.exportAmendmentAcceptance =>
              const _AmendmentAcceptancePage(),
            LcMenuAction.exportInitiateTransfer => _LcListPage(
                kind: LcListKind.transferable,
                emptyMessage:
                    'Only active export LCs marked transferable, with an amount still available, can be transferred.',
                hideExpired: true,
                onOpen: (context, lc) => Navigator.of(context).pushNamed(
                  CorpRoutesConst.lcTransferScreen,
                  arguments: LcTransferArgs(lcId: lc.id),
                ),
              ),
            LcMenuAction.exportAmendTransfer => _LcListPage(
                kind: LcListKind.transferred,
                emptyMessage:
                    'LCs you transfer to a second beneficiary appear here for amendment.',
                hideExpired: true,
                onOpen: (context, lc) => Navigator.of(context).pushNamed(
                  CorpRoutesConst.lcAmendScreen,
                  arguments: LcAmendArgs(lcId: lc.id),
                ),
              ),
          },
        ),
      ],
    );
  }

  static void _openDetail(BuildContext context, CorpLetterOfCredit lc) {
    Navigator.of(context).pushNamed(
      CorpRoutesConst.lcDetailScreen,
      arguments: LcDetailArgs(lcId: lc.id, lcType: lc.lcType),
    );
  }
}

// ── Header: back arrow + title ──────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.action, required this.onBack});

  final LcMenuAction action;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(
      fontSize: 12.5,
      color: CorpColors.textSecondary(context),
    );
    // "Trade Finance › Letter of Credit › Import Letter of Credit"
    final trail = action.breadcrumb.sublist(0, action.breadcrumb.length - 1);

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
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trail.join('  ›  '), style: muted),
              const SizedBox(height: 2),
              Text(
                action.label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: CorpColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(action.description, style: muted),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Initiate: new LC + saved drafts ─────────────────────────────────────

class _InitiatePage extends StatelessWidget {
  const _InitiatePage();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CorpCardShell(
          child: LayoutBuilder(
            builder: (context, c) {
              final text = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Import LC',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: CorpColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'LC details → beneficiary & bank → shipment & goods → documents → review.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: CorpColors.textSecondary(context),
                    ),
                  ),
                ],
              );
              final button = LcPrimaryButton(
                label: 'Initiate LC',
                icon: Icons.add_rounded,
                onPressed: () => Navigator.of(context).pushNamed(
                  CorpRoutesConst.lcInitiateScreen,
                  arguments: const LcInitiateArgs(),
                ),
              );
              return c.maxWidth < 520
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [text, const SizedBox(height: 12), button],
                    )
                  : Row(children: [
                      Expanded(child: text),
                      const SizedBox(width: 12),
                      button,
                    ]);
            },
          ),
        ),
        const SizedBox(height: 14),
        _LcListPage(
          title: 'Saved drafts',
          kind: LcListKind.drafts,
          emptyMessage: 'Drafts you save while initiating an LC appear here.',
          showSearch: false,
          onOpen: (context, lc) => Navigator.of(context).pushNamed(
            CorpRoutesConst.lcInitiateScreen,
            arguments: LcInitiateArgs(seed: lc, draftId: lc.id),
          ),
        ),
      ],
    );
  }
}

// ── Generic LC list page ────────────────────────────────────────────────

class _LcListPage extends ConsumerStatefulWidget {
  const _LcListPage({
    required this.kind,
    required this.onOpen,
    this.title,
    this.emptyMessage,
    this.hideExpired = false,
    this.showSearch = true,
  });

  final LcListKind kind;
  final void Function(BuildContext context, CorpLetterOfCredit lc) onOpen;
  final String? title;
  final String? emptyMessage;
  final bool hideExpired;
  final bool showSearch;

  @override
  ConsumerState<_LcListPage> createState() => _LcListPageState();
}

class _LcListPageState extends ConsumerState<_LcListPage> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(corpLcListProvider(widget.kind).notifier);
      // Action lists (amendable / transferable) change as the user acts on
      // them, so they are always refetched; browse lists load once.
      if (widget.kind == LcListKind.amendable ||
          widget.kind == LcListKind.transferable ||
          widget.kind == LcListKind.drafts) {
        notifier.refresh();
      } else {
        notifier.ensureLoaded();
      }
      ref.read(corpLcLookupsProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(corpLcListProvider(widget.kind));
    final isDraft = widget.kind == LcListKind.drafts;
    final q = _query.toLowerCase();
    final items = [
      for (final lc in state.items)
        if (!(widget.hideExpired && lc.isExpired) &&
            (q.isEmpty ||
                [
                  lc.id,
                  lc.counterPartyName,
                  lc.partyName,
                  lc.productName,
                  lc.draftName,
                ].any((v) => v?.toLowerCase().contains(q) ?? false)))
          lc,
    ];

    return CorpCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CorpCardHeader(
            title: widget.title ?? '${state.items.length} ${widget.kind.label}',
            trailing: IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              color: CorpColors.textSecondary(context),
              onPressed: () =>
                  ref.read(corpLcListProvider(widget.kind).notifier).refresh(),
            ),
          ),
          const SizedBox(height: 8),
          if (widget.showSearch) ...[
            TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: lcInputDecoration(
                context,
                label: 'Search by LC number, party or product',
                suffix: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (state.errorMessage != null)
            LcMessageBanner(message: state.errorMessage!),
          if (state.isLoading && state.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (items.isEmpty && state.errorMessage == null)
            LcEmptyState(
              icon: Icons.description_outlined,
              title: _query.isEmpty
                  ? 'Nothing to show yet'
                  : 'No results for "$_query"',
              message: _query.isEmpty ? widget.emptyMessage : null,
            )
          else
            for (final lc in items)
              _LcTile(
                lc: lc,
                isDraft: isDraft,
                onTap: () => widget.onOpen(context, lc),
              ),
        ],
      ),
    );
  }
}

// ── LC amendment acceptance (H2 #157) ───────────────────────────────────

class _AmendmentAcceptancePage extends ConsumerStatefulWidget {
  const _AmendmentAcceptancePage();

  @override
  ConsumerState<_AmendmentAcceptancePage> createState() =>
      _AmendmentAcceptancePageState();
}

class _AmendmentAcceptancePageState
    extends ConsumerState<_AmendmentAcceptancePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(corpLcExportAmendmentsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(corpLcExportAmendmentsProvider);
    return CorpCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CorpCardHeader(
            title: '${state.items.length} amendment(s) received',
            trailing: IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              color: CorpColors.textSecondary(context),
              onPressed: () =>
                  ref.read(corpLcExportAmendmentsProvider.notifier).refresh(),
            ),
          ),
          const SizedBox(height: 8),
          if (state.errorMessage != null)
            LcMessageBanner(message: state.errorMessage!),
          if (state.isLoading && state.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.items.isEmpty && state.errorMessage == null)
            const LcEmptyState(
              icon: Icons.fact_check_outlined,
              title: 'No amendments awaiting your response',
            )
          else
            for (final a in state.items)
              InkWell(
                onTap: () => Navigator.of(context).pushNamed(
                  CorpRoutesConst.lcAcceptanceScreen,
                  arguments: LcAcceptanceArgs(amendment: a),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: CorpColors.divider(context)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${a.lcId} · Amendment ${a.id}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: CorpColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Applicant: ${lcOrDash(a.applicantName)}',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: CorpColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            lcMoney(a.newAmount),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: CorpColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          LcStatusChip(
                            label: a.isPending
                                ? 'PENDING'
                                : a.acceptanceStatus!.toUpperCase(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

// ── LC row ──────────────────────────────────────────────────────────────

class _LcTile extends StatelessWidget {
  const _LcTile({required this.lc, required this.isDraft, required this.onTap});

  final CorpLetterOfCredit lc;
  final bool isDraft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final counterparty = lc.lcType == LcType.importLc
        ? 'Beneficiary: ${lcOrDash(lc.counterPartyName)}'
        : 'Applicant: ${lcOrDash(lc.counterPartyName ?? lc.partyName)}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: CorpColors.divider(context)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: CorpColors.brand(context).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isDraft
                    ? Icons.edit_document
                    : (lc.lcType == LcType.importLc
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded),
                size: 20,
                color: CorpColors.brand(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDraft ? (lc.draftName ?? 'Draft ${lc.id}') : lc.id,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: CorpColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    counterparty,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: CorpColors.textSecondary(context),
                    ),
                  ),
                  Text(
                    '${lcOrDash(lc.productName)} · Expires ${TfDate.display(lc.expiryDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: CorpColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  lcMoney(lc.amount),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: CorpColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                LcStatusChip(
                  label: isDraft
                      ? 'DRAFT'
                      : (lc.isExpired ? 'EXPIRED' : lc.statusLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
