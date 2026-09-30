import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_lc_initiate_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_profile_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:ubci_bank/src/view/widgets/payment_otp_sheet_view.dart';

/// Initiate Import LC — five-step wizard over [corpLcInitiateProvider].
///
/// Lookups: H1 #42 #44 #51 #102 #104 #106 #115 #142 #143 #159.
/// Draft save: H1 #71 (POST) / #74 (PUT). Charges: H1 #121.
/// Submit: see `CorpTradeFinanceRepository.submitInitiation` (NOT CAPTURED).
class LcInitiateScreen extends ConsumerStatefulWidget {
  const LcInitiateScreen({super.key, this.args = const LcInitiateArgs()});

  final LcInitiateArgs args;

  @override
  ConsumerState<LcInitiateScreen> createState() => _LcInitiateScreenState();
}

class _LcInitiateScreenState extends ConsumerState<LcInitiateScreen> {
  bool _ready = false;
  bool _otpOpen = false;
  List<String> _errors = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
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

  void _next() {
    final errors = _notifier.next();
    setState(() => _errors = errors);
  }

  void _back() {
    setState(() => _errors = const []);
    _notifier.back();
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
    });

    final lookupsState = ref.watch(corpLcLookupsProvider);
    final state = ref.watch(corpLcInitiateProvider);
    final title = state.draft.isBackToBack ||
            widget.args.source == LcInitiateSource.backToBack
        ? 'Initiate Back to Back LC'
        : 'Initiate Import LC';

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

    final isReview = state.step == LcInitiateStep.review;
    // Icons are dropped on narrow phones so Back / Save / Next fit one row.
    final narrow = MediaQuery.sizeOf(context).width < 420;
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
      body: Column(
        children: [
          _StepIndicator(current: state.step),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
                  key: ValueKey(state.step),
                  child: switch (state.step) {
                    LcInitiateStep.details => const _DetailsStep(),
                    LcInitiateStep.parties => const _PartiesStep(),
                    LcInitiateStep.shipment => const _ShipmentStep(),
                    LcInitiateStep.documents => const _DocumentsStep(),
                    LcInitiateStep.review => const _ReviewStep(),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      bottomBar: Row(
        children: [
          if (state.step.index > 0) ...[
            LcSecondaryButton(
              label: 'Back',
              icon: narrow ? null : Icons.arrow_back_rounded,
              onPressed: state.isBusy ? null : _back,
            ),
            const SizedBox(width: 10),
          ],
          LcSecondaryButton(
            label: narrow ? 'Save' : 'Save draft',
            icon: narrow ? null : Icons.save_outlined,
            loading: state.isSaving,
            onPressed: state.isBusy ? null : () => _notifier.saveDraft(),
          ),
          const Spacer(),
          LcPrimaryButton(
            label: isReview ? 'Submit' : 'Next',
            icon: narrow
                ? null
                : (isReview ? Icons.send_rounded : Icons.arrow_forward_rounded),
            loading: state.isSubmitting,
            onPressed: state.isBusy
                ? null
                : (isReview ? () => _notifier.submit() : _next),
          ),
        ],
      ),
    );
  }
}

// ── Step indicator ──────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});

  final LcInitiateStep current;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          for (final step in LcInitiateStep.values) ...[
            if (step.index > 0)
              Container(
                width: 18,
                height: 1.5,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: CorpColors.divider(context),
              ),
            CircleAvatar(
              radius: 12,
              backgroundColor: step.index <= current.index
                  ? brand
                  : CorpColors.divider(context),
              child: step.index < current.index
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      '${step.index + 1}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: step.index <= current.index
                            ? Colors.white
                            : CorpColors.textSecondary(context),
                      ),
                    ),
            ),
            const SizedBox(width: 6),
            Text(
              step.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight:
                    step == current ? FontWeight.w700 : FontWeight.w500,
                color: step == current
                    ? CorpColors.textPrimary(context)
                    : CorpColors.textSecondary(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Step 1: LC details ──────────────────────────────────────────────────

class _DetailsStep extends ConsumerWidget {
  const _DetailsStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookups = ref.watch(corpLcLookupsProvider).lookups;
    final d = ref.watch(corpLcInitiateProvider.select((s) => s.draft));
    final notifier = ref.read(corpLcInitiateProvider.notifier);
    final applicant = ref.watch(corpProfileProvider).entityName;

    TradeCode? currency;
    for (final c in lookups.currencies) {
      if (c.code == d.currency) currency = c;
    }
    TradeCode? confirmation;
    for (final c in lookups.confirmationOptions) {
      if (c.code == d.confirmationInstruction) confirmation = c;
    }
    TradeCode? availableBy;
    for (final c in LcAvailableBy.values) {
      if (c.code == d.availableBy) availableBy = c;
    }
    final today = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LcSectionCard(
          title: 'Applicant',
          children: [
            LcInfoGrid(items: [
              ('Applicant', lcOrDash(applicant)),
              ('LC type', 'Import LC'),
            ]),
          ],
        ),
        LcSectionCard(
          title: 'LC details',
          children: [
            LcPickerField<LcProduct>(
              label: 'LC product',
              options: lookups.products,
              selected: d.product,
              labelOf: (p) => p.label,
              subtitleOf: (p) =>
                  '${p.periodIndicator ?? ''}${p.revolving ? ' · Revolving' : ''}',
              onSelected: notifier.selectProduct,
            ),
            LcFieldRow(children: [
              LcPickerField<TradeCode>(
                label: 'Currency',
                options: lookups.currencies,
                selected: currency,
                labelOf: (c) => c.code,
                subtitleOf: (c) => c.description ?? '',
                onSelected: (c) =>
                    notifier.update((x) => x.copyWith(currency: c.code)),
              ),
              LcTextField(
                label: 'LC amount',
                numeric: true,
                initialValue: d.amount?.toStringAsFixed(2),
                onChanged: (v) => notifier.update(
                  (x) => x.copyWith(amount: double.tryParse(v) ?? 0),
                ),
              ),
            ]),
            LcFieldRow(children: [
              LcDateField(
                label: 'Expiry date',
                value: d.expiryDate,
                firstDate: today.add(const Duration(days: 1)),
                onChanged: (v) =>
                    notifier.update((x) => x.copyWith(expiryDate: v)),
              ),
              LcTextField(
                label: 'Place of expiry',
                initialValue: d.expiryPlace,
                onChanged: (v) =>
                    notifier.update((x) => x.copyWith(expiryPlace: v)),
              ),
            ]),
            LcFieldRow(children: [
              LcTextField(
                key: ValueKey('tolA-${d.product?.id}'),
                label: 'Tolerance above (%)',
                numeric: true,
                initialValue: d.toleranceAbove.toStringAsFixed(0),
                onChanged: (v) => notifier.update(
                  (x) => x.copyWith(toleranceAbove: double.tryParse(v) ?? 0),
                ),
              ),
              LcTextField(
                key: ValueKey('tolU-${d.product?.id}'),
                label: 'Tolerance below (%)',
                numeric: true,
                initialValue: d.toleranceUnder.toStringAsFixed(0),
                onChanged: (v) => notifier.update(
                  (x) => x.copyWith(toleranceUnder: double.tryParse(v) ?? 0),
                ),
              ),
            ]),
            LcFieldRow(children: [
              LcPickerField<TradeCode>(
                label: 'Available by',
                options: LcAvailableBy.values,
                selected: availableBy,
                labelOf: (c) => c.label,
                onSelected: (c) =>
                    notifier.update((x) => x.copyWith(availableBy: c.code)),
              ),
              LcPickerField<TradeCode>(
                label: 'Confirmation instruction',
                options: lookups.confirmationOptions,
                selected: confirmation,
                labelOf: (c) => c.label,
                onSelected: (c) => notifier.update(
                  (x) => x.copyWith(confirmationInstruction: c.code),
                ),
              ),
            ]),
            LcTextField(
              label: 'Documents to be presented within (days)',
              numeric: true,
              initialValue: '${d.documentPresentationDays}',
              onChanged: (v) => notifier.update((x) => x.copyWith(
                    documentPresentationDays: int.tryParse(v.split('.').first),
                  )),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Step 2: beneficiary & bank ──────────────────────────────────────────

class _PartiesStep extends ConsumerStatefulWidget {
  const _PartiesStep();

  @override
  ConsumerState<_PartiesStep> createState() => _PartiesStepState();
}

class _PartiesStepState extends ConsumerState<_PartiesStep> {
  late String _swift =
      ref.read(corpLcInitiateProvider).draft.advisingBankCode ?? '';

  @override
  Widget build(BuildContext context) {
    final lookups = ref.watch(corpLcLookupsProvider).lookups;
    final state = ref.watch(corpLcInitiateProvider);
    final d = state.draft;
    final notifier = ref.read(corpLcInitiateProvider.notifier);

    TradeCode? country;
    for (final c in lookups.countries) {
      if (c.code == d.beneficiaryAddress.country) country = c;
    }
    TradeCode? borneBy;
    for (final c in LcChargesBorneBy.values) {
      if (c.code == d.chargesBorneBy) borneBy = c;
    }
    final bank = d.advisingBank;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LcSectionCard(
          title: 'Beneficiary',
          children: [
            LcTextField(
              label: 'Beneficiary name',
              initialValue: d.beneficiaryName,
              onChanged: (v) =>
                  notifier.update((x) => x.copyWith(beneficiaryName: v)),
            ),
            LcTextField(
              label: 'Address line 1',
              initialValue: d.beneficiaryAddress.line1,
              onChanged: (v) => notifier.update((x) => x.copyWith(
                    beneficiaryAddress: x.beneficiaryAddress.copyWith(line1: v),
                  )),
            ),
            LcFieldRow(children: [
              LcTextField(
                label: 'Address line 2',
                initialValue: d.beneficiaryAddress.line2,
                onChanged: (v) => notifier.update((x) => x.copyWith(
                      beneficiaryAddress:
                          x.beneficiaryAddress.copyWith(line2: v),
                    )),
              ),
              LcTextField(
                label: 'Address line 3',
                initialValue: d.beneficiaryAddress.line3,
                onChanged: (v) => notifier.update((x) => x.copyWith(
                      beneficiaryAddress:
                          x.beneficiaryAddress.copyWith(line3: v),
                    )),
              ),
            ]),
            LcPickerField<TradeCode>(
              label: 'Country',
              options: lookups.countries,
              selected: country,
              labelOf: (c) => c.label,
              subtitleOf: (c) => c.code,
              onSelected: (c) => notifier.update((x) => x.copyWith(
                    beneficiaryAddress:
                        x.beneficiaryAddress.copyWith(country: c.code),
                  )),
            ),
          ],
        ),
        LcSectionCard(
          title: 'Advising bank',
          children: [
            LcTextField(
              label: 'SWIFT / BIC code',
              uppercase: true,
              maxLength: 11,
              initialValue: _swift,
              helper: 'Also used as "available with".',
              onChanged: (v) {
                _swift = v;
                notifier.update((x) => x.copyWith(
                      advisingBankCode: v,
                      clearAdvisingBank: true,
                    ));
              },
              suffix: state.isLookingUpBic
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton(
                      onPressed: () => notifier.lookupAdvisingBank(_swift),
                      child: const Text('Verify'),
                    ),
            ),
            if (bank != null)
              LcMessageBanner(
                isError: false,
                message:
                    '${bank.name ?? bank.code}\n${bank.address.singleLine}',
              )
            else if (state.bicMessage != null)
              LcMessageBanner(message: state.bicMessage!),
            LcPickerField<TradeCode>(
              label: 'Charges borne by',
              options: LcChargesBorneBy.values,
              selected: borneBy,
              labelOf: (c) => c.label,
              onSelected: (c) =>
                  notifier.update((x) => x.copyWith(chargesBorneBy: c.code)),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Step 3: shipment & goods ────────────────────────────────────────────

class _ShipmentStep extends ConsumerWidget {
  const _ShipmentStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookups = ref.watch(corpLcLookupsProvider).lookups;
    final d = ref.watch(corpLcInitiateProvider.select((s) => s.draft));
    final notifier = ref.read(corpLcInitiateProvider.notifier);
    final s = d.shipment;

    void ship(LcShipmentDetails Function(LcShipmentDetails) change) =>
        notifier.update((x) => x.copyWith(shipment: change(x.shipment)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LcSectionCard(
          title: 'Shipment',
          children: [
            LcFieldRow(children: [
              LcTextField(
                label: 'Place of dispatch',
                initialValue: s.source,
                onChanged: (v) => ship((x) => x.copyWith(source: v)),
              ),
              LcTextField(
                label: 'Final destination',
                initialValue: s.destination,
                onChanged: (v) => ship((x) => x.copyWith(destination: v)),
              ),
            ]),
            LcFieldRow(children: [
              LcTextField(
                label: 'Port of loading',
                initialValue: s.loadingPort,
                onChanged: (v) => ship((x) => x.copyWith(loadingPort: v)),
              ),
              LcTextField(
                label: 'Port of discharge',
                initialValue: s.dischargePort,
                onChanged: (v) => ship((x) => x.copyWith(dischargePort: v)),
              ),
            ]),
            LcFieldRow(children: [
              LcDateField(
                label: 'Latest shipment date',
                value: s.latestShipmentDate,
                firstDate: DateTime.now(),
                lastDate: d.expiryDate,
                onChanged: (v) =>
                    ship((x) => x.copyWith(latestShipmentDate: v)),
              ),
              LcTextField(
                label: 'Shipment period (days)',
                numeric: true,
                initialValue: s.period,
                onChanged: (v) => ship((x) => x.copyWith(period: v)),
              ),
            ]),
            LcSwitchField(
              label: 'Partial shipment',
              subtitle: 'Goods may be shipped in more than one lot',
              value: s.partialAllowed,
              onChanged: (v) => ship((x) => x.copyWith(partialAllowed: v)),
            ),
            LcSwitchField(
              label: 'Transshipment',
              subtitle: 'Goods may be moved between vessels / carriers',
              value: s.transshipmentAllowed,
              onChanged: (v) =>
                  ship((x) => x.copyWith(transshipmentAllowed: v)),
            ),
            LcPickerField<TradeCode>(
              label: 'Incoterm (optional)',
              options: lookups.incoterms,
              selected: d.incoterm,
              labelOf: (c) => '${c.code} — ${c.description ?? ''}',
              onSelected: (c) =>
                  notifier.update((x) => x.copyWith(incoterm: c)),
            ),
          ],
        ),
        LcSectionCard(
          title: 'Goods',
          trailing: TextButton.icon(
            onPressed: () async {
              final goods = await _showAddGoodsDialog(
                context,
                lookups.goods,
                d.currency,
              );
              if (goods != null) notifier.addGoods(goods);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add goods'),
          ),
          children: [
            if (d.goods.isEmpty)
              Text(
                'No goods added. Add the goods covered by this LC.',
                style: TextStyle(
                  fontSize: 13,
                  color: CorpColors.textSecondary(context),
                ),
              ),
            for (var i = 0; i < d.goods.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  d.goods[i].description ?? d.goods[i].code,
                  style: TextStyle(color: CorpColors.textPrimary(context)),
                ),
                subtitle: Text(
                  '${d.goods[i].noOfUnits ?? 0} × ${lcAmount(d.goods[i].pricePerUnit, d.currency)}'
                  ' = ${lcAmount(d.goods[i].total, d.currency)}',
                  style: TextStyle(color: CorpColors.textSecondary(context)),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: CorpColors.of(context).error,
                  onPressed: () => notifier.removeGoodsAt(i),
                ),
              ),
            if (d.goods.isNotEmpty && d.amount != null && d.goodsTotal > d.amount!)
              const LcMessageBanner(
                message: 'Goods value exceeds the LC amount.',
              ),
          ],
        ),
      ],
    );
  }
}

Future<LcGoods?> _showAddGoodsDialog(
  BuildContext context,
  List<TradeCode> master,
  String? currency,
) {
  TradeCode? selected;
  var units = '';
  var price = '';
  return showDialog<LcGoods>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: CorpColors.card(ctx),
        title: const Text('Add goods'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LcPickerField<TradeCode>(
                label: 'Goods',
                options: master,
                selected: selected,
                labelOf: (c) => c.label,
                subtitleOf: (c) => c.code,
                onSelected: (c) => setState(() => selected = c),
              ),
              LcTextField(
                label: 'Number of units',
                numeric: true,
                onChanged: (v) => setState(() => units = v),
              ),
              LcTextField(
                label: 'Price per unit${currency == null ? '' : ' ($currency)'}',
                numeric: true,
                onChanged: (v) => setState(() => price = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: selected == null ||
                    (double.tryParse(units) ?? 0) <= 0 ||
                    (double.tryParse(price) ?? 0) <= 0
                ? null
                : () => Navigator.of(ctx).pop(LcGoods(
                      code: selected!.code,
                      description: selected!.description,
                      noOfUnits: double.tryParse(units),
                      pricePerUnit: double.tryParse(price),
                    )),
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
}

// ── Step 4: documents & conditions ──────────────────────────────────────

class _DocumentsStep extends ConsumerWidget {
  const _DocumentsStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookups = ref.watch(corpLcLookupsProvider).lookups;
    final state = ref.watch(corpLcInitiateProvider);
    final d = state.draft;
    final notifier = ref.read(corpLcInitiateProvider.notifier);

    LcDocument? selectedOf(LcDocument doc) {
      for (final s in d.documents) {
        if (s.id == doc.id) return s;
      }
      return null;
    }

    final remaining = [
      for (final c in lookups.additionalConditions)
        if (!d.additionalConditions.contains(c)) c,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LcSectionCard(
          title: 'Documents required',
          children: [
            if (state.documentsLoading)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else if (state.productDocuments.isEmpty)
              Text(
                'The selected product lists no documents.',
                style: TextStyle(
                  fontSize: 13,
                  color: CorpColors.textSecondary(context),
                ),
              ),
            for (final doc in state.productDocuments)
              _DocumentTile(
                document: doc,
                selected: selectedOf(doc),
                onToggle: (v) => notifier.toggleDocument(doc, v),
                onChanged: notifier.updateDocument,
              ),
          ],
        ),
        LcSectionCard(
          title: 'Additional conditions',
          trailing: TextButton.icon(
            onPressed: remaining.isEmpty
                ? null
                : () async {
                    final picked = await showModalBottomSheet<TradeCode>(
                      context: context,
                      backgroundColor: CorpColors.card(context),
                      builder: (ctx) => ListView(
                        children: [
                          for (final c in remaining)
                            ListTile(
                              title: Text(c.label),
                              subtitle: Text(c.code),
                              onTap: () => Navigator.of(ctx).pop(c),
                            ),
                        ],
                      ),
                    );
                    if (picked != null) notifier.toggleCondition(picked, true);
                  },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
          ),
          children: [
            if (d.additionalConditions.isEmpty)
              Text(
                'No additional conditions.',
                style: TextStyle(
                  fontSize: 13,
                  color: CorpColors.textSecondary(context),
                ),
              ),
            for (final c in d.additionalConditions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  c.label,
                  style: TextStyle(color: CorpColors.textPrimary(context)),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => notifier.toggleCondition(c, false),
                ),
              ),
          ],
        ),
        LcSectionCard(
          title: 'Instructions to bank',
          children: [
            LcTextField(
              label: 'Instructions (optional)',
              maxLines: 3,
              initialValue: d.instructions,
              onChanged: (v) =>
                  notifier.update((x) => x.copyWith(instructions: v)),
            ),
          ],
        ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.document,
    required this.selected,
    required this.onToggle,
    required this.onChanged,
  });

  final LcDocument document;
  final LcDocument? selected;
  final ValueChanged<bool> onToggle;
  final ValueChanged<LcDocument> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: current != null,
          activeColor: CorpColors.brand(context),
          onChanged: (v) => onToggle(v ?? false),
          title: Text(
            document.name,
            style: TextStyle(color: CorpColors.textPrimary(context)),
          ),
          subtitle: document.clauses.isEmpty
              ? null
              : Text(
                  document.clauses.map((c) => c.label).join('; '),
                  style: TextStyle(color: CorpColors.textSecondary(context)),
                ),
        ),
        if (current != null)
          Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 8),
            child: Row(
              children: [
                _Counter(
                  label: 'Originals',
                  value: current.originals,
                  onChanged: (v) => onChanged(current.copyWith(originals: v)),
                ),
                const SizedBox(width: 16),
                _Counter(
                  label: 'Copies',
                  value: current.copies,
                  onChanged: (v) => onChanged(current.copyWith(copies: v)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: CorpColors.textSecondary(context),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        Text(
          '$value',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: CorpColors.textPrimary(context),
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

// ── Step 5: review ──────────────────────────────────────────────────────

class _ReviewStep extends ConsumerWidget {
  const _ReviewStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookups = ref.watch(corpLcLookupsProvider).lookups;
    final state = ref.watch(corpLcInitiateProvider);
    final notifier = ref.read(corpLcInitiateProvider.notifier);
    final d = state.draft;
    final s = d.shipment;

    Widget edit(LcInitiateStep step) => TextButton(
          onPressed: () => notifier.goTo(step),
          child: const Text('Edit'),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LcSectionCard(
          title: 'LC details',
          trailing: edit(LcInitiateStep.details),
          children: [
            LcInfoGrid(items: [
              ('Product', lcOrDash(d.product?.label)),
              ('Amount', lcAmount(d.amount, d.currency)),
              ('Expiry date', TfDate.display(d.expiryDate)),
              ('Place of expiry', lcOrDash(d.expiryPlace)),
              (
                'Tolerance (+/−)',
                '${d.toleranceAbove.toStringAsFixed(0)}% / ${d.toleranceUnder.toStringAsFixed(0)}%',
              ),
              ('Confirmation', d.confirmationInstruction),
              ('Presentation period', '${d.documentPresentationDays} days'),
            ]),
          ],
        ),
        LcSectionCard(
          title: 'Beneficiary & bank',
          trailing: edit(LcInitiateStep.parties),
          children: [
            LcInfoGrid(items: [
              ('Beneficiary', lcOrDash(d.beneficiaryName)),
              (
                'Address',
                [
                  ...d.beneficiaryAddress.lines,
                  lookups.countryName(d.beneficiaryAddress.country),
                ].join(', '),
              ),
              (
                'Advising bank',
                d.advisingBank == null
                    ? lcOrDash(d.advisingBankCode)
                    : '${d.advisingBank!.code} · ${d.advisingBank!.name ?? ''}',
              ),
              ('Charges borne by', d.chargesBorneBy),
            ]),
          ],
        ),
        LcSectionCard(
          title: 'Shipment & goods',
          trailing: edit(LcInitiateStep.shipment),
          children: [
            LcInfoGrid(items: [
              ('Port of loading', lcOrDash(s.loadingPort)),
              ('Port of discharge', lcOrDash(s.dischargePort)),
              ('Latest shipment date', TfDate.display(s.latestShipmentDate)),
              ('Partial shipment', lcYesNo(s.partialAllowed)),
              ('Transshipment', lcYesNo(s.transshipmentAllowed)),
              ('Goods', '${d.goods.length} item(s)'),
            ]),
          ],
        ),
        LcSectionCard(
          title: 'Documents & conditions',
          trailing: edit(LcInitiateStep.documents),
          children: [
            LcInfoGrid(items: [
              (
                'Documents',
                d.documents.isEmpty
                    ? 'None'
                    : d.documents
                        .map((x) => '${x.name} (${x.originals}+${x.copies})')
                        .join(', '),
              ),
              ('Additional conditions', '${d.additionalConditions.length}'),
            ]),
          ],
        ),
        LcSectionCard(
          title: 'Charges, commissions & taxes',
          children: [
            LcChargesList(
              charges: state.charges,
              loading: state.chargesLoading,
              message: state.chargesMessage,
            ),
          ],
        ),
        Text(
          'By submitting, you confirm the details above. The request follows '
          'your corporate approval rules and is then processed by the bank '
          'under UCP 600.',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: CorpColors.textSecondary(context),
          ),
        ),
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
