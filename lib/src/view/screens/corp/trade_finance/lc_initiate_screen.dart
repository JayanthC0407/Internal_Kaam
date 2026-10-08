import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_lc_initiate_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_profile_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_initiate_sections.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:ubci_bank/src/view/widgets/payment_otp_sheet_view.dart';

/// Initiate Letter of Credit — the eight "Application Sections" of the
/// design (LC Details → Goods & Shipment → Documents & Conditions →
/// Linkages → Instructions → Insurance → Charges → Attachments) over
/// [corpLcInitiateProvider].
///
/// APIs: lookups H1 #42 #44 #51 #102 #104 #106 #115 #142 #143 #159;
/// section data from `LC_inititation complete flow.har` (H3 #49 #58 #63
/// #67 #70 #72 #73 #75); charges H3 #74; draft save H1 #71 / #74.
/// Submit: NOT CAPTURED — see [CorpLcInitiateNotifier.submit].
class LcInitiateScreen extends ConsumerStatefulWidget {
  const LcInitiateScreen({super.key, this.args = const LcInitiateArgs()});

  final LcInitiateArgs args;

  @override
  ConsumerState<LcInitiateScreen> createState() => _LcInitiateScreenState();
}

class _LcInitiateScreenState extends ConsumerState<LcInitiateScreen> {
  final _scroll = ScrollController();
  bool _ready = false;
  bool _otpOpen = false;
  List<String> _errors = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    await ref.read(corpLcLookupsProvider.notifier).ensureLoaded();
    if (!mounted) return;
    final args = widget.args;
    final seed = args.seed;
    final notifier = ref.read(corpLcInitiateProvider.notifier);
    if (seed != null) {
      switch (args.source) {
        case LcInitiateSource.template:
          await notifier.seedFromTemplate(seed.id, seed);
        case LcInitiateSource.copy:
          await notifier.seedFromLc(seed.id, seed);
        case LcInitiateSource.backToBack:
          await notifier.seedBackToBack(seed);
        case LcInitiateSource.draft:
          await notifier.seedFromDraft(args.draftId ?? seed.id, seed);
        case LcInitiateSource.blank:
          // Legacy callers (e.g. "Copy & initiate" on LC detail) pass a
          // seed without a source.
          notifier.seed(seed, draftId: args.draftId);
      }
      if (!mounted) return;
    }
    setState(() => _ready = true);
  }

  CorpLcInitiateNotifier get _notifier =>
      ref.read(corpLcInitiateProvider.notifier);

  void _toTop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _next() {
    final state = ref.read(corpLcInitiateProvider);
    if (state.section.isLast) {
      setState(() => _errors = const []);
      _notifier.submit();
      return;
    }
    final errors = _notifier.next();
    setState(() => _errors = errors);
    _toTop();
  }

  void _goTo(LcInitiateSection section) {
    setState(() => _errors = const []);
    _notifier.goTo(section);
    _toTop();
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this application?'),
        content: const Text(
          'Changes since your last saved draft will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel application'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _openOtpSheet() async {
    if (_otpOpen) return;
    _otpOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _InitiateOtpSheet(),
    );
    _otpOpen = false;
    if (mounted && ref.read(corpLcInitiateProvider).challenge != null) {
      _notifier.cancelOtp();
    }
  }

  Future<void> _deleteDraft() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this draft?'),
        content: const Text('The saved draft will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (await _notifier.deleteCurrentDraft() && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Draft deleted.')));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CorpLcInitiateState>(corpLcInitiateProvider, (prev, next) {
      if (prev?.challenge == null && next.challenge != null) _openOtpSheet();
      if (prev?.challenge != null && next.challenge == null && _otpOpen) {
        Navigator.of(context).pop();
      }
      final info = next.infoMessage;
      if (info != null && info != prev?.infoMessage) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(info)));
      }
      final error = next.errorMessage;
      if (error != null && error != prev?.errorMessage) _toTop();
    });

    final lookupsState = ref.watch(corpLcLookupsProvider);
    final state = ref.watch(corpLcInitiateProvider);
    // Each section loads its own data when first opened (H5 captures).
    // Watching the providers of every visited section keeps that data for
    // the life of the form, so going back does not refetch it.
    for (final s in {...state.completed, state.section}) {
      switch (s) {
        case LcInitiateSection.lcDetails:
          ref.watch(corpLcDetailsSectionProvider);
        case LcInitiateSection.documents:
          ref.watch(corpLcDocumentsSectionProvider);
        case LcInitiateSection.linkages:
          ref.watch(corpLcLinkagesSectionProvider);
        case LcInitiateSection.instructions:
          ref.watch(corpLcInstructionsSectionProvider(state.draft.product?.id));
        case LcInitiateSection.insurance:
          ref.watch(corpLcInsuranceSectionProvider);
        case LcInitiateSection.charges:
          ref.watch(corpLcChargeAccountsProvider);
        case LcInitiateSection.attachments:
          ref.watch(corpLcAttachmentCategoriesProvider);
        case LcInitiateSection.goodsShipment:
          break; // goods come with the LC lookups
      }
    }
    final title = state.draft.isBackToBack ||
            widget.args.source == LcInitiateSource.backToBack
        ? 'Initiate Back to Back LC'
        : 'Initiate Letter of Credit';

    if (!_ready) {
      return LcScreenScaffold(
        title: title,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (lookupsState.lookups.products.isEmpty) {
      return LcScreenScaffold(
        title: title,
        body: LcEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'LC products unavailable',
          message: lookupsState.errorMessage ??
              'No Letter of Credit products are set up for your entity.',
          action: LcSecondaryButton(
            label: 'Try again',
            icon: Icons.refresh,
            onPressed: () async {
              await ref.read(corpLcLookupsProvider.notifier).refresh();
            },
          ),
        ),
      );
    }

    final outcome = state.outcome;
    if (outcome != null) {
      return LcScreenScaffold(
        title: title,
        body: LcResultView(
          title: 'Letter of credit submitted',
          outcome: outcome,
          onDone: () => Navigator.of(context).pop(),
          summary: [
            ('Beneficiary', lcOrDash(state.draft.beneficiaryName)),
            ('Amount', lcAmount(state.draft.amount, state.draft.currency)),
            ('Expiry date', TfDate.display(state.draft.expiryDate)),
          ],
        ),
      );
    }

    final section = state.section;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.draft.parentLcId != null)
          LcMessageBanner(
            isError: false,
            message:
                'Back to Back LC, backed by Export LC ${state.draft.parentLcId}.',
          ),
        for (final e in _errors) LcMessageBanner(message: e),
        if (state.errorMessage != null)
          LcMessageBanner(message: state.errorMessage!),
        KeyedSubtree(
          key: ValueKey(section),
          child: LcInitiateSectionBody(section: section),
        ),
      ],
    );

    return LcScreenScaffold(
      title: title,
      actions: [
        if (state.draftId != null)
          IconButton(
            tooltip: 'Delete draft',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: state.isBusy ? null : _deleteDraft,
          ),
      ],
      body: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 900;
          return ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _ApplicationHeader(section: section),
              const SizedBox(height: 12),
              _SectionBar(state: state, onTap: _goTo),
              const SizedBox(height: 16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 270, child: _SidePanel(state: state)),
                    const SizedBox(width: 18),
                    Expanded(child: body),
                  ],
                )
              else ...[
                _SidePanel(state: state, compact: true),
                const SizedBox(height: 4),
                body,
              ],
            ],
          );
        },
      ),
      bottomBar: _Footer(
        state: state,
        onCancel: _cancel,
        onSave: () => _notifier.saveDraft(),
        onNext: _next,
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────

/// "LC TEST4 | ***401" with the step pill.
class _ApplicationHeader extends ConsumerWidget {
  const _ApplicationHeader({required this.section});

  final LcInitiateSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(corpProfileProvider);
    final party = profile.party;
    final brand = CorpColors.brand(context);
    final subtitle = [
      if (profile.entityName != null) profile.entityName!,
      if (party?.idDisplay != null) party!.idDisplay!,
    ].join('  |  ');

    return Row(
      children: [
        Expanded(
          child: Text(
            subtitle.isEmpty ? 'Import Letter of Credit' : subtitle,
            style: TextStyle(
              fontSize: 13,
              color: CorpColors.textSecondary(context),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: brand.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: brand.withValues(alpha: 0.25)),
          ),
          child: Text(
            'Step ${section.index + 1} of ${LcInitiateSection.values.length}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: brand,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Application Sections bar ────────────────────────────────────────────

class _SectionBar extends StatelessWidget {
  const _SectionBar({required this.state, required this.onTap});

  final CorpLcInitiateState state;
  final ValueChanged<LcInitiateSection> onTap;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: CorpColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CorpColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Application Sections',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: CorpColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in LcInitiateSection.values) ...[
                  if (s.index > 0) const SizedBox(width: 8),
                  _SectionChip(
                    section: s,
                    active: s == state.section,
                    done: state.completed.contains(s),
                    enabled: state.canOpen(s) && !state.isBusy,
                    brand: brand,
                    onTap: () => onTap(s),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  const _SectionChip({
    required this.section,
    required this.active,
    required this.done,
    required this.enabled,
    required this.brand,
    required this.onTap,
  });

  final LcInitiateSection section;
  final bool active;
  final bool done;
  final bool enabled;
  final Color brand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = active || done;
    final fg = highlighted
        ? CorpColors.textPrimary(context)
        : CorpColors.textSecondary(context);
    return Material(
      color: highlighted ? brand.withValues(alpha: 0.14) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: active ? BorderSide(color: brand, width: 1.2) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (highlighted) ...[
                Icon(
                  done ? Icons.check_circle_outline : Icons.radio_button_checked,
                  size: 16,
                  color: brand,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                section.number,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                section.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Left summary panel ──────────────────────────────────────────────────

class _SidePanel extends ConsumerWidget {
  const _SidePanel({required this.state, this.compact = false});

  final CorpLcInitiateState state;

  /// Phones: the panel sits above the section, so only the most useful
  /// card is shown.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookups = ref.watch(corpLcLookupsProvider).lookups;
    final d = state.draft;
    final section = state.section;
    final cards = <Widget>[
      switch (section) {
        LcInitiateSection.lcDetails => const _LimitsCard(),
        LcInitiateSection.goodsShipment => _ShipmentSummaryCard(draft: d),
        LcInitiateSection.instructions =>
          _ProgressCard(state: state, title: 'Instruction status'),
        _ => _ProgressCard(state: state, title: 'Application progress'),
      },
      if (!compact)
        switch (section) {
          LcInitiateSection.lcDetails => _PanelCard(
              title: 'Next',
              children: [
                _PanelLink(LcInitiateSection.goodsShipment.label),
                const _PanelNote(
                  'Continue when all required LC fields are complete.',
                ),
              ],
            ),
          LcInitiateSection.goodsShipment =>
            _ProgressCard(state: state, title: 'Application progress'),
          LcInitiateSection.documents => _PanelCard(
              title: 'Selection summary',
              children: [
                _PanelHighlight('${d.documents.length} documents selected'),
                _PanelNote(
                  '${d.additionalConditions.length} additional condition(s)',
                ),
                _PanelNote('Presentation • ${d.documentPresentationDays} days'),
                if (d.incoterm != null)
                  _PanelLink('Incoterms • ${d.incoterm!.code}'),
              ],
            ),
          LcInitiateSection.linkages => _PanelCard(
              title: 'Linkage summary',
              children: [
                _PanelHighlight('${d.depositLinkages.length} account(s) linked'),
                _PanelNote('Linked amount • ${d.linkedTotal.toStringAsFixed(2)}'),
              ],
            ),
          LcInitiateSection.instructions => _PanelCard(
              title: 'Instruction summary',
              children: [
                _PanelNote('Advising bank • ${d.advisingBank.summary}'),
                _PanelNote('Advise through • ${d.adviseThroughBank.summary}'),
                _PanelNote(
                  'Confirmation • ${_label(lookups.confirmationOptions, d.confirmationInstruction)}',
                ),
                if (d.standardInstructionsAccepted)
                  const _PanelLink('Standard instructions • ✓'),
              ],
            ),
          LcInitiateSection.insurance => _PanelCard(
              title: 'Selected policy',
              children: [
                _PanelHighlight(d.insurancePolicy?.policyNumber ?? 'None'),
                if (d.insurancePolicy?.companyName != null)
                  _PanelNote(d.insurancePolicy!.companyName!),
              ],
            ),
          LcInitiateSection.charges => _PanelCard(
              title: 'Charges',
              children: [
                _PanelNote(
                  'Borne by • ${_label(LcChargesBorneBy.values, d.chargesBorneBy)}',
                ),
                _PanelNote('Account • ${lcOrDash(d.chargingAccount?.label)}'),
                for (final e in LcCharge.totalsByCurrency(state.charges ?? const []).entries)
                  _PanelHighlight('${e.key} ${e.value.toStringAsFixed(2)}'),
              ],
            ),
          LcInitiateSection.attachments => _AttachmentPanel(draft: d),
        },
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final card in cards) ...[card, const SizedBox(height: 12)],
      ],
    );
  }

  static String _label(List<TradeCode> codes, String code) {
    for (final c in codes) {
      if (c.code == code) return c.label;
    }
    return code;
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: CorpColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CorpColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: CorpColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _PanelHighlight extends StatelessWidget {
  const _PanelHighlight(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: CorpColors.brand(context),
        ),
      ),
    );
  }
}

class _PanelNote extends StatelessWidget {
  const _PanelNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          height: 1.3,
          color: CorpColors.textSecondary(context),
        ),
      ),
    );
  }
}

class _PanelLink extends StatelessWidget {
  const _PanelLink(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: CorpColors.brand(context),
        ),
      ),
    );
  }
}

/// Attachments side cards (design): attachment status, the upload rules
/// reminder and the consent state.
class _AttachmentPanel extends StatelessWidget {
  const _AttachmentPanel({required this.draft});

  final LcInitiateDraft draft;

  @override
  Widget build(BuildContext context) {
    final files = draft.attachments;
    final uploaded = files.where((a) => a.isUploaded).length;
    final brand = CorpColors.brand(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelCard(
          title: 'Attachment status',
          children: [
            _PanelHighlight('$uploaded files attached'),
            _PanelNote(
              files.isEmpty
                  ? 'No attachment uploaded yet'
                  : '${files.length - uploaded} of ${files.length} not uploaded yet',
            ),
            const _PanelNote('Max 5 MB / file'),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: brand.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: brand.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelLink('Before upload'),
              Text(
                'Check file type and filename rules before attaching documents.',
                style: TextStyle(fontSize: 12.5, color: brand),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _PanelCard(
          title: 'Submit',
          children: [
            _PanelLink(draft.termsAccepted ? 'Consent given' : 'Pending consent'),
            const _PanelNote('Accept Terms & Conditions'),
          ],
        ),
      ],
    );
  }
}

/// "N of 8 sections reviewed" with a progress bar.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.state, required this.title});

  final CorpLcInitiateState state;
  final String title;

  @override
  Widget build(BuildContext context) {
    final total = LcInitiateSection.values.length;
    final done = state.completed.length;
    final next = state.section.next;
    return _PanelCard(
      title: title,
      children: [
        _PanelHighlight('$done of $total sections reviewed'),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: done / total,
            minHeight: 6,
            color: CorpColors.brand(context),
            backgroundColor: CorpColors.divider(context),
          ),
        ),
        const SizedBox(height: 8),
        _PanelLink(state.section.label),
        _PanelNote(next == null ? 'Next • Submit' : 'Next • ${next.label}'),
      ],
    );
  }
}

/// Shipment summary — loading → discharge, destination, date, terms.
class _ShipmentSummaryCard extends StatelessWidget {
  const _ShipmentSummaryCard({required this.draft});

  final LcInitiateDraft draft;

  @override
  Widget build(BuildContext context) {
    final s = draft.shipment;
    final terms = [
      draft.shipmentByPeriod ? 'Period' : 'Date',
      if (s.partialAllowed) 'Partial',
      if (s.transshipmentAllowed) 'Trans-shipment',
    ];
    return _PanelCard(
      title: 'Shipment summary',
      children: [
        _PanelHighlight(
          '${lcOrDash(s.loadingPort)}  →  ${lcOrDash(s.dischargePort)}',
        ),
        const _PanelNote('Port of loading → Port of discharge'),
        const Divider(height: 16),
        _SummaryTile(label: 'Final destination', value: lcOrDash(s.destination)),
        _SummaryTile(
          label: draft.shipmentByPeriod ? 'Shipment period' : 'Shipment date',
          value: draft.shipmentByPeriod
              ? lcOrDash(s.period)
              : TfDate.display(s.latestShipmentDate),
        ),
        _SummaryTile(
          label: 'Shipment terms',
          value: '${terms.first} • ${terms.length > 1 ? terms.skip(1).join(' + ') : 'No partial / trans-shipment'}',
          tinted: true,
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    this.tinted = false,
  });

  final String label;
  final String value;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tinted
            ? brand.withValues(alpha: 0.08)
            : CorpColors.tableHeaderBg(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: tinted ? brand : CorpColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: tinted ? brand : CorpColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Limits card of the LC Details section.
///
/// NOT CAPTURED: the initiation capture has no limits call, so no figures
/// are shown — wire the facility/limits API here once it is captured.
class _LimitsCard extends StatelessWidget {
  const _LimitsCard();

  @override
  Widget build(BuildContext context) {
    return const _PanelCard(
      title: 'Limits',
      children: [
        _PanelHighlight('—'),
        _PanelNote(
          'Limit details are not available for this application. The bank '
          'checks your available limit when the LC is processed.',
        ),
      ],
    );
  }
}

// ── Footer ──────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({
    required this.state,
    required this.onCancel,
    required this.onSave,
    required this.onNext,
  });

  final CorpLcInitiateState state;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final error = CorpColors.of(context).error;
    final narrow = MediaQuery.sizeOf(context).width < 520;
    final isLast = state.section.isLast;

    final cancel = OutlinedButton(
      onPressed: state.isBusy ? null : onCancel,
      style: OutlinedButton.styleFrom(
        foregroundColor: error,
        side: BorderSide(color: CorpColors.textSecondary(context)),
        minimumSize: const Size(0, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      child: const Text('Cancel'),
    );
    final save = LcSecondaryButton(
      label: narrow ? 'Save' : 'Save As draft',
      loading: state.isSaving,
      onPressed: state.isBusy ? null : onSave,
    );
    final next = LcPrimaryButton(
      label: isLast ? 'Submit' : 'Next',
      loading: state.isSubmitting,
      onPressed: state.isBusy ? null : onNext,
    );

    if (narrow) {
      return Row(
        children: [
          Expanded(child: cancel),
          const SizedBox(width: 8),
          Expanded(child: save),
          const SizedBox(width: 8),
          Expanded(child: next),
        ],
      );
    }
    return Row(
      children: [
        const Spacer(),
        SizedBox(width: 140, child: cancel),
        const SizedBox(width: 12),
        SizedBox(width: 160, child: save),
        const SizedBox(width: 12),
        SizedBox(width: 140, child: next),
      ],
    );
  }
}

// ── OTP ─────────────────────────────────────────────────────────────────

class _InitiateOtpSheet extends ConsumerWidget {
  const _InitiateOtpSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(corpLcInitiateProvider);
    return PaymentOtpSheetView(
      title: 'Verify LC submission',
      isSubmitting: state.isSubmitting,
      attemptsLeft: state.challenge?.attemptsLeft,
      errorText: state.otpError,
      onSubmit: (otp) =>
          ref.read(corpLcInitiateProvider.notifier).submit(otp: otp),
    );
  }
}
