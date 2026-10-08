import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_lc_initiate_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_profile_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_initiate_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';

// The eight "Application Sections" of Initiate Letter of Credit. Each one
// reads and writes `corpLcInitiateProvider`; reference data comes from
// `corpLcLookupsProvider` (H1) and one provider per section (H5 — the
// per-section captures; formerly H3 =
// `LC_inititation complete flow.har`).

/// Body of [section].
class LcInitiateSectionBody extends StatelessWidget {
  const LcInitiateSectionBody({super.key, required this.section});

  final LcInitiateSection section;

  @override
  Widget build(BuildContext context) {
    return switch (section) {
      LcInitiateSection.lcDetails => const _LcDetailsSection(),
      LcInitiateSection.goodsShipment => const _GoodsShipmentSection(),
      LcInitiateSection.documents => const _DocumentsSection(),
      LcInitiateSection.linkages => const _LinkagesSection(),
      LcInitiateSection.instructions => const _InstructionsSection(),
      LcInitiateSection.insurance => const _InsuranceSection(),
      LcInitiateSection.charges => const _ChargesSection(),
      LcInitiateSection.attachments => const _AttachmentsSection(),
    };
  }
}

/// Loading strip + warnings of a section's own data (H5).
class _SectionStatus extends StatelessWidget {
  const _SectionStatus({required this.loading, this.warnings = const []});

  final bool loading;
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        for (final w in warnings) LcInfoBox(text: w),
      ],
    );
  }
}

T? _find<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

String _number(double? value) {
  if (value == null) return '';
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}

// ── 01 LC Details ───────────────────────────────────────────────────────

class _LcDetailsSection extends ConsumerWidget {
  const _LcDetailsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookups = ref.watch(corpLcLookupsProvider).lookups;
    final sectionData = ref.watch(corpLcDetailsSectionProvider);
    final support = sectionData.valueOrNull ?? const LcDetailsSectionData();
    final d = ref.watch(corpLcInitiateProvider.select((s) => s.draft));
    final notifier = ref.read(corpLcInitiateProvider.notifier);
    final profile = ref.watch(corpProfileProvider);
    final self = profile.entityName ?? 'Applicant';
    final party = profile.party;
    final applicant = d.applicant?.name ?? self;
    final applicantAddress = d.applicant != null
        ? ''
        : [
            if (party?.addressLine1 != null) party!.addressLine1!,
            if (party?.country != null) lookups.countryName(party!.country),
          ].join(' • ');
    final applicants = [
      self,
      for (final p in support.relatedParties) p.name,
    ];

    // Products follow the selected LC type (Sight / Usance); Mixed shows all.
    final type = d.paymentType;
    var products = [
      for (final p in lookups.products)
        if (type == null ||
            type == 'MIXED' ||
            p.periodIndicator == null ||
            p.periodIndicator == type)
          p,
    ];
    if (products.isEmpty) products = lookups.products;
    final product = d.product;
    final revolvingAllowed = product?.revolving ?? true;

    final currency = _find(lookups.currencies, (c) => c.code == d.currency);
    final availableBy =
        _find(LcAvailableBy.values, (c) => c.code == d.availableBy);
    final beneficiary =
        _find(support.beneficiaries, (b) => b.id == d.beneficiaryId);
    final country = _find(
      lookups.countries,
      (c) => c.code == d.beneficiaryAddress.country,
    );
    final today = DateTime.now();
    final r = d.revolvingDetails;

    void revolving(LcRevolvingDetails Function(LcRevolvingDetails) change) =>
        notifier.update((x) => x.copyWith(
              revolvingDetails: change(x.revolvingDetails),
            ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LcSectionHeading('LC Details'),
        _SectionStatus(
          loading: sectionData.isLoading,
          warnings: support.warnings,
        ),
        LcTagCard(
          tag: '50',
          title: 'Applicant Name',
          children: [
            LcFieldRow(children: [
              LcPickerField<String>(
                label: 'Applicant Name *',
                options: applicants,
                selected: applicant,
                labelOf: (s) => s,
                onSelected: (name) {
                  final related = _find(
                    support.relatedParties,
                    (p) => p.name == name,
                  );
                  notifier.update((x) => related == null
                      ? x.copyWith(clearApplicant: true)
                      : x.copyWith(applicant: related));
                },
              ),
              LcInfoBox(
                title: 'Address',
                text: applicantAddress.isEmpty ? '—' : applicantAddress,
              ),
            ]),
          ],
        ),
        LcTagCard(
          tag: '40A',
          title: 'Type of Documentary Credit',
          children: [
            LcFieldRow(children: [
              LcRadioGroup<bool>(
                label: 'Documentary Credit',
                options: const [
                  (true, 'Transferable'),
                  (false, 'Non Transferable'),
                ],
                value: d.transferable,
                onChanged: (v) =>
                    notifier.update((x) => x.copyWith(transferable: v)),
              ),
              LcRadioGroup<String>(
                label: 'LC Type',
                options: [
                  for (final t in LcPaymentType.values) (t.code, t.label),
                ],
                value: d.periodIndicator,
                onChanged: (v) =>
                    notifier.update((x) => x.copyWith(paymentType: v)),
              ),
            ]),
          ],
        ),
        LcTagCard(
          tag: '40A',
          title: 'Trade Structure',
          children: [
            LcFieldRow(children: [
              LcRadioGroup<bool>(
                label: 'Revolving',
                options: lcYesNoOptions,
                value: d.revolving,
                enabled: revolvingAllowed,
                onChanged: (v) =>
                    notifier.update((x) => x.copyWith(revolving: v)),
              ),
              LcPickerField<LcProduct>(
                label: 'Select Product *',
                options: products,
                selected: product,
                labelOf: (p) => '${p.id} – ${p.name}',
                subtitleOf: (p) =>
                    '${p.periodIndicator ?? ''}${p.revolving ? ' · Revolving' : ''}',
                onSelected: notifier.selectProduct,
              ),
            ]),
            if (d.revolving) ...[
              LcFieldRow(children: [
                LcRadioGroup<bool>(
                  label: 'Auto-Reinstatement',
                  options: lcYesNoOptions,
                  value: r.autoReinstatement,
                  onChanged: (v) =>
                      revolving((x) => x.copyWith(autoReinstatement: v)),
                ),
                LcRadioGroup<String>(
                  label: 'Revolving Type',
                  options: const [('VALUE', 'Value'), ('TIME', 'Time')],
                  value: r.type,
                  onChanged: (v) => revolving((x) => x.copyWith(type: v)),
                ),
              ]),
              LcFieldRow(children: [
                LcRadioGroup<bool>(
                  label: 'Cumulative',
                  options: lcYesNoOptions,
                  value: r.cumulative,
                  onChanged: (v) =>
                      revolving((x) => x.copyWith(cumulative: v)),
                ),
                LcFieldRow(children: [
                  LcTextField(
                    label: 'Repeat Frequency *',
                    numeric: true,
                    initialValue: r.frequency?.toString(),
                    onChanged: (v) => revolving((x) => x.copyWith(
                          frequency: int.tryParse(v.split('.').first) ?? 0,
                        )),
                  ),
                  LcPickerField<String>(
                    label: 'Unit',
                    options: const ['DAYS', 'MONTHS'],
                    selected: r.frequencyUnit,
                    labelOf: (u) => u == 'DAYS' ? 'Days' : 'Months',
                    onSelected: (u) =>
                        revolving((x) => x.copyWith(frequencyUnit: u)),
                  ),
                ]),
              ]),
            ],
            LcInfoBox(
              title: 'Product rules',
              text: product == null
                  ? 'Selected product controls the available revolving options.'
                  : '${product.name} · ${product.periodIndicator ?? '—'} · '
                      '${product.revolving ? 'Revolving allowed' : 'Revolving not allowed'}'
                      ' · Tolerance +${_number(product.positiveTolerance)}% / '
                      '−${_number(product.negativeTolerance)}%',
            ),
          ],
        ),
        LcTagCard(
          tag: '31D',
          title: 'Expiry Details',
          children: [
            LcFieldRow(children: [
              LcDateField(
                label: 'Date of Expiry',
                value: d.expiryDate,
                // The bank's business date (branchdate, H5) when known.
                firstDate: (support.branchDate ?? today)
                    .add(const Duration(days: 1)),
                onChanged: (v) =>
                    notifier.update((x) => x.copyWith(expiryDate: v)),
              ),
              LcTextField(
                label: 'Place of Expiry',
                initialValue: d.expiryPlace,
                onChanged: (v) =>
                    notifier.update((x) => x.copyWith(expiryPlace: v)),
              ),
            ]),
          ],
        ),
        LcTagCard(
          tag: '59',
          title: 'Beneficiary Details',
          children: [
            LcFieldRow(children: [
              LcRadioGroup<bool>(
                label: 'Beneficiary',
                options: const [(false, 'Existing'), (true, 'New')],
                value: d.newBeneficiary,
                onChanged: notifier.setNewBeneficiary,
              ),
              if (d.newBeneficiary)
                LcTextField(
                  key: const ValueKey('bene-new-name'),
                  label: 'Beneficiary Name *',
                  initialValue: d.beneficiaryName,
                  onChanged: (v) =>
                      notifier.update((x) => x.copyWith(beneficiaryName: v)),
                )
              else
                LcPickerField<LcBeneficiary>(
                  label: 'Beneficiary Name *',
                  options: support.beneficiaries,
                  selected: beneficiary,
                  labelOf: (b) => b.name,
                  subtitleOf: (b) => b.address.singleLine,
                  onSelected: notifier.selectBeneficiary,
                ),
            ]),
            if (!d.newBeneficiary && support.beneficiaries.isEmpty)
              const LcInfoBox(
                text: 'No maintained beneficiaries were found. Select New to '
                    'enter the beneficiary details.',
              ),
            if (!d.newBeneficiary && d.beneficiaryId != null)
              LcInfoBox(
                title: 'Address',
                text: [
                  ...d.beneficiaryAddress.lines,
                  if (d.beneficiaryAddress.country != null)
                    'Country: ${lookups.countryName(d.beneficiaryAddress.country)}',
                ].join(' • '),
              ),
            if (d.newBeneficiary) ...[
              LcTextField(
                key: const ValueKey('bene-new-a1'),
                label: 'Address line 1 *',
                initialValue: d.beneficiaryAddress.line1,
                onChanged: (v) => notifier.update((x) => x.copyWith(
                      beneficiaryAddress:
                          x.beneficiaryAddress.copyWith(line1: v),
                    )),
              ),
              LcFieldRow(children: [
                LcTextField(
                  key: const ValueKey('bene-new-a2'),
                  label: 'Address line 2',
                  initialValue: d.beneficiaryAddress.line2,
                  onChanged: (v) => notifier.update((x) => x.copyWith(
                        beneficiaryAddress:
                            x.beneficiaryAddress.copyWith(line2: v),
                      )),
                ),
                LcTextField(
                  key: const ValueKey('bene-new-a3'),
                  label: 'Address line 3',
                  initialValue: d.beneficiaryAddress.line3,
                  onChanged: (v) => notifier.update((x) => x.copyWith(
                        beneficiaryAddress:
                            x.beneficiaryAddress.copyWith(line3: v),
                      )),
                ),
              ]),
              LcPickerField<TradeCode>(
                label: 'Country *',
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
          ],
        ),
        LcTagCard(
          tag: '32B',
          title: 'LC Amount',
          children: [
            LcFieldRow(children: [
              LcPickerField<TradeCode>(
                label: 'Currency *',
                options: lookups.currencies,
                selected: currency,
                labelOf: (c) => c.code,
                subtitleOf: (c) => c.description ?? '',
                onSelected: (c) =>
                    notifier.update((x) => x.copyWith(currency: c.code)),
              ),
              LcTextField(
                label: 'LC Amount *',
                numeric: true,
                initialValue: d.amount?.toStringAsFixed(2),
                onChanged: (v) => notifier.update(
                  (x) => x.copyWith(amount: double.tryParse(v) ?? 0),
                ),
              ),
            ]),
            LcFieldRow(children: [
              LcTextField(
                key: ValueKey('tolU-${d.product?.id}'),
                label: 'LC Amount Tolerance Under (%)',
                numeric: true,
                initialValue: _number(d.toleranceUnder),
                onChanged: (v) => notifier.update(
                  (x) => x.copyWith(toleranceUnder: double.tryParse(v) ?? 0),
                ),
              ),
              LcTextField(
                key: ValueKey('tolA-${d.product?.id}'),
                label: 'Above (%)',
                numeric: true,
                initialValue: _number(d.toleranceAbove),
                onChanged: (v) => notifier.update(
                  (x) => x.copyWith(toleranceAbove: double.tryParse(v) ?? 0),
                ),
              ),
            ]),
            LcInfoBox(
              title: 'Total Exposure',
              text: lcAmount(d.totalExposure, d.currency),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const LcSectionHeading('Additional & Draft Details'),
        LcTagCard(
          tag: '39C',
          title: 'Additional Amount Covered',
          children: [
            LcTextField(
              label: 'Additional Amount',
              maxLines: 2,
              initialValue: d.additionalAmountCovered,
              onChanged: (v) => notifier
                  .update((x) => x.copyWith(additionalAmountCovered: v)),
            ),
          ],
        ),
        LcTagCard(
          tag: '41A',
          title: 'Credit Available By',
          children: [
            LcPickerField<TradeCode>(
              label: 'Credit Available By',
              options: LcAvailableBy.values,
              selected: availableBy,
              labelOf: (c) => c.label,
              onSelected: (c) =>
                  notifier.update((x) => x.copyWith(availableBy: c.code)),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '42P • Negotiation / Deferred Payment Details',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: CorpColors.brand(context),
                ),
              ),
            ),
            LcTextField(
              label: 'Payment details',
              maxLines: 3,
              initialValue: d.paymentDetails,
              onChanged: (v) =>
                  notifier.update((x) => x.copyWith(paymentDetails: v)),
            ),
            const LcBankBlock(
              role: LcBankRole.availableWith,
              label: 'Credit Available With',
              allowByName: false,
            ),
          ],
        ),
        LcTagCard(
          tag: '42C',
          title: 'Drafts',
          trailing: LcAddButton(
            label: 'Add Another Draft',
            onPressed: () async {
              final draft = await _showAddDraftDialog(context, d.currency);
              if (draft != null) notifier.addBillingDraft(draft);
            },
          ),
          children: [
            LcGridTable(
              columns: const [
                LcGridColumn('Serial Number', flex: 2),
                LcGridColumn('Tenor', flex: 2),
                LcGridColumn('Credit Days From', flex: 3),
                LcGridColumn('Drawee Bank', flex: 3),
                LcGridColumn('Draft Amount', flex: 3),
                LcGridColumn('Actions', flex: 2),
              ],
              emptyText: 'No drafts added.',
              rows: [
                for (var i = 0; i < d.billingDrafts.length; i++)
                  [
                    LcCell('${i + 1}'),
                    LcCell(d.billingDrafts[i].tenor?.toString() ?? '—'),
                    LcCell([
                      if (d.billingDrafts[i].creditDays != null)
                        '${d.billingDrafts[i].creditDays}',
                      if (d.billingDrafts[i].creditDaysType != null)
                        d.billingDrafts[i].creditDaysType!,
                    ].join(' · ').ifEmpty('—')),
                    LcCell(d.billingDrafts[i].draweeLabel),
                    LcCell(lcAmount(d.billingDrafts[i].amount, d.currency)),
                    LcRemoveIcon(
                      onPressed: () => notifier.removeBillingDraftAt(i),
                    ),
                  ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

Future<LcBillingDraft?> _showAddDraftDialog(
  BuildContext context,
  String? currency,
) {
  var tenor = '';
  var creditDays = '';
  var creditFrom = '';
  var drawee = '';
  var amount = '';
  return showDialog<LcBillingDraft>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: CorpColors.card(ctx),
        title: const Text('Add draft'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LcFieldRow(children: [
                  LcTextField(
                    label: 'Tenor (days)',
                    numeric: true,
                    onChanged: (v) => setState(() => tenor = v),
                  ),
                  LcTextField(
                    label: 'Credit days',
                    numeric: true,
                    onChanged: (v) => setState(() => creditDays = v),
                  ),
                ]),
                LcTextField(
                  label: 'Credit days from (e.g. Bill of Lading date)',
                  onChanged: (v) => setState(() => creditFrom = v),
                ),
                LcTextField(
                  label: 'Drawee bank SWIFT code',
                  uppercase: true,
                  maxLength: 11,
                  onChanged: (v) => setState(() => drawee = v),
                ),
                LcTextField(
                  label: 'Draft amount${currency == null ? '' : ' ($currency)'}',
                  numeric: true,
                  onChanged: (v) => setState(() => amount = v),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: tenor.isEmpty && drawee.trim().isEmpty
                ? null
                : () => Navigator.of(ctx).pop(LcBillingDraft(
                      tenor: int.tryParse(tenor.split('.').first),
                      creditDays: int.tryParse(creditDays.split('.').first),
                      creditDaysType:
                          creditFrom.trim().isEmpty ? null : creditFrom.trim(),
                      draweeBankCode: drawee.trim().isEmpty
                          ? null
                          : drawee.trim().toUpperCase(),
                      amount: double.tryParse(amount),
                    )),
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
}

// ── 02 Goods & Shipment Details ─────────────────────────────────────────

class _GoodsShipmentSection extends ConsumerWidget {
  const _GoodsShipmentSection();

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
        const LcSectionHeading('Goods & Shipment Details'),
        LcTagCard(
          tag: '43P',
          title: 'Partial Shipment',
          children: [
            LcFieldRow(children: [
              LcRadioGroup<bool>(
                label: 'Partial Shipment',
                options: lcAllowedOptions,
                value: s.partialAllowed,
                onChanged: (v) => ship((x) => x.copyWith(partialAllowed: v)),
              ),
              LcRadioGroup<String>(
                label: 'LC Type',
                options: [
                  for (final t in LcPaymentType.values) (t.code, t.label),
                ],
                value: d.periodIndicator,
                onChanged: (v) =>
                    notifier.update((x) => x.copyWith(paymentType: v)),
              ),
            ]),
            LcInfoBox(
              text: s.partialAllowed
                  ? 'Goods can be delivered in more than one shipment.'
                  : 'Goods must be delivered in a single shipment.',
            ),
          ],
        ),
        LcTagCard(
          tag: '43T',
          title: 'Trans-shipment',
          children: [
            LcRadioGroup<bool>(
              label: 'Trans-shipment',
              options: lcAllowedOptions,
              value: s.transshipmentAllowed,
              onChanged: (v) =>
                  ship((x) => x.copyWith(transshipmentAllowed: v)),
            ),
          ],
        ),
        LcTagCard(
          tag: '44A',
          title: 'Place of Taking in Charge / Dispatch',
          children: [
            LcFieldRow(children: [
              LcTextField(
                label: 'Place of Taking in Charge / Dispatch',
                initialValue: s.source,
                onChanged: (v) => ship((x) => x.copyWith(source: v)),
              ),
              LcTextField(
                label: 'Port of Loading / Airport of Departure *',
                initialValue: s.loadingPort,
                onChanged: (v) => ship((x) => x.copyWith(loadingPort: v)),
              ),
            ]),
          ],
        ),
        LcTagCard(
          tag: '44F',
          title: 'Port of Discharge / Airport of Destination',
          children: [
            LcFieldRow(children: [
              LcTextField(
                label: 'Port of Discharge / Airport of Destination *',
                initialValue: s.dischargePort,
                onChanged: (v) => ship((x) => x.copyWith(dischargePort: v)),
              ),
              LcTextField(
                label: 'Place of Final Destination / Delivery',
                initialValue: s.destination,
                onChanged: (v) => ship((x) => x.copyWith(destination: v)),
              ),
            ]),
          ],
        ),
        LcTagCard(
          tag: '44C/44D',
          title: 'Shipment',
          children: [
            LcFieldRow(children: [
              LcRadioGroup<bool>(
                label: 'Shipment date or period',
                options: const [(false, 'Date'), (true, 'Period')],
                value: d.shipmentByPeriod,
                onChanged: (v) =>
                    notifier.update((x) => x.copyWith(shipmentByPeriod: v)),
              ),
              if (d.shipmentByPeriod)
                LcTextField(
                  label: 'Shipment Period',
                  hint: 'e.g. 30 days after LC issuance',
                  initialValue: s.period,
                  onChanged: (v) => ship((x) => x.copyWith(period: v)),
                )
              else
                LcDateField(
                  label: 'Shipment Date',
                  value: s.latestShipmentDate,
                  firstDate: DateTime.now(),
                  lastDate: d.expiryDate,
                  onChanged: (v) =>
                      ship((x) => x.copyWith(latestShipmentDate: v)),
                ),
            ]),
            const LcInfoBox(
              text: 'Use Date for a single shipment date. Select Period when '
                  'a shipment window is required.',
            ),
          ],
        ),
        LcTagCard(
          title: 'Goods List',
          trailing: LcAddButton(
            label: 'Add Goods',
            onPressed: () async {
              final goods =
                  await _showAddGoodsDialog(context, lookups.goods, d.currency);
              if (goods != null) notifier.addGoods(goods);
            },
          ),
          children: [
            LcGridTable(
              columns: const [
                LcGridColumn('Sr.No', flex: 1),
                LcGridColumn('Goods', flex: 3),
                LcGridColumn('Description', flex: 3),
                LcGridColumn('Quantity', flex: 2),
                LcGridColumn('Cost/Unit', flex: 2),
                LcGridColumn('Gross amount', flex: 3),
                LcGridColumn('Action', flex: 2),
              ],
              emptyText: 'No goods added. Add the goods covered by this LC.',
              rows: [
                for (var i = 0; i < d.goods.length; i++)
                  [
                    LcCell('${i + 1}'),
                    LcCell(d.goods[i].code),
                    LcCell(d.goods[i].description ?? '—', bold: true),
                    LcCell(_number(d.goods[i].noOfUnits)),
                    LcCell(_number(d.goods[i].pricePerUnit)),
                    LcCell(lcAmount(d.goods[i].total, d.currency)),
                    LcRemoveIcon(onPressed: () => notifier.removeGoodsAt(i)),
                  ],
              ],
            ),
            if (d.goods.isNotEmpty &&
                d.amount != null &&
                d.goodsTotal > d.totalExposure)
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
  var description = '';
  return showDialog<LcGoods>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: CorpColors.card(ctx),
        title: const Text('Add goods'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
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
                  label: 'Description (optional)',
                  onChanged: (v) => setState(() => description = v),
                ),
                LcTextField(
                  label: 'Quantity',
                  numeric: true,
                  onChanged: (v) => setState(() => units = v),
                ),
                LcTextField(
                  label: 'Cost per unit${currency == null ? '' : ' ($currency)'}',
                  numeric: true,
                  onChanged: (v) => setState(() => price = v),
                ),
              ],
            ),
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
                      description: description.trim().isEmpty
                          ? selected!.description
                          : description.trim(),
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

// ── 03 Documents & Conditions ───────────────────────────────────────────

class _DocumentsSection extends ConsumerStatefulWidget {
  const _DocumentsSection();

  @override
  ConsumerState<_DocumentsSection> createState() => _DocumentsSectionState();
}

class _DocumentsSectionState extends ConsumerState<_DocumentsSection> {
  static const _pageSize = 5;

  String _typed = '';
  String _query = '';
  int _page = 0;

  CorpLcInitiateNotifier get _notifier =>
      ref.read(corpLcInitiateProvider.notifier);

  Future<void> _addDocument(List<LcDocument> master) async {
    final available = ref.read(corpLcInitiateProvider).availableDocuments;
    final options = [
      for (final doc in master)
        if (!available.any((a) => a.id == doc.id)) doc,
    ];
    final picked = await showModalBottomSheet<LcDocument>(
      context: context,
      backgroundColor: CorpColors.card(context),
      builder: (ctx) => options.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Every document is already in the list.'),
            )
          : ListView(
              children: [
                for (final doc in options)
                  ListTile(
                    title: Text(doc.name.isEmpty ? doc.id : doc.name),
                    subtitle: Text(doc.id),
                    onTap: () => Navigator.of(ctx).pop(doc),
                  ),
              ],
            ),
    );
    if (picked != null) _notifier.addMasterDocument(picked);
  }

  Future<void> _editClauses(LcDocument doc, LcDocument? selected) async {
    if (doc.clauses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No clauses are defined for this document.')),
      );
      return;
    }
    final chosen = <String>{
      for (final c in (selected ?? doc).clauses) c.code,
    };
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: CorpColors.card(ctx),
          title: Text('Clauses · ${doc.name}'),
          content: SizedBox(
            width: 460,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final clause in doc.clauses)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: chosen.contains(clause.code),
                    activeColor: CorpColors.brand(ctx),
                    title: Text(clause.label, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(clause.code),
                    onChanged: (v) => setState(() {
                      if (v ?? false) {
                        chosen.add(clause.code);
                      } else {
                        chosen.remove(clause.code);
                      }
                    }),
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
              onPressed: () => Navigator.of(ctx).pop(chosen),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final clauses = [
      for (final c in doc.clauses)
        if (result.contains(c.code)) c,
    ];
    final base = selected ?? doc;
    if (selected == null) _notifier.toggleDocument(doc, true);
    _notifier.updateDocument(base.copyWith(clauses: clauses));
  }

  Future<void> _editCopies(LcDocument selected) async {
    var originals = selected.originals;
    var copies = selected.copies;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: CorpColors.card(ctx),
          title: Text(selected.name),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LcCounter(
                  label: 'Originals',
                  value: originals,
                  onChanged: (v) => setState(() => originals = v),
                ),
                LcCounter(
                  label: 'Number of copies',
                  value: copies,
                  onChanged: (v) => setState(() => copies = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      _notifier.updateDocument(
        selected.copyWith(originals: originals, copies: copies),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookups = ref.watch(corpLcLookupsProvider).lookups;
    final sectionData = ref.watch(corpLcDocumentsSectionProvider);
    final support = sectionData.valueOrNull ?? const LcDocumentsSectionData();
    final state = ref.watch(corpLcInitiateProvider);
    final d = state.draft;
    final brand = CorpColors.brand(context);

    final q = _query.trim().toLowerCase();
    final all = state.availableDocuments;
    final filtered = [
      for (final doc in all)
        if (q.isEmpty ||
            doc.name.toLowerCase().contains(q) ||
            doc.id.toLowerCase().contains(q))
          doc,
    ];
    final pages = filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
    final page = _page.clamp(0, pages - 1);
    final visible = filtered.skip(page * _pageSize).take(_pageSize).toList();

    LcDocument? selectedOf(LcDocument doc) =>
        _find(d.documents, (s) => s.id == doc.id);

    final conditionMaster = [
      ...lookups.additionalConditions,
      for (final c in support.maintainedConditions)
        if (!lookups.additionalConditions.contains(c)) c,
    ];
    final remaining = [
      for (final c in conditionMaster)
        if (!d.additionalConditions.contains(c)) c,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LcSectionHeading('Documents & Conditions'),
        _SectionStatus(
          loading: sectionData.isLoading,
          warnings: support.warnings,
        ),
        LcTagCard(
          tag: '46A',
          title: 'Select Documents',
          trailing: LcAddButton(
            label: 'Add Document',
            onPressed: support.tradeDocuments.isEmpty
                ? null
                : () => _addDocument(support.tradeDocuments),
          ),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LcTextField(
                    label: 'Search documents',
                    initialValue: _typed,
                    onChanged: (v) {
                      _typed = v;
                      if (v.isEmpty) {
                        setState(() {
                          _query = '';
                          _page = 0;
                        });
                      }
                    },
                    suffix: const Icon(Icons.search, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: LcPrimaryButton(
                    label: 'Search',
                    onPressed: () => setState(() {
                      _query = _typed;
                      _page = 0;
                    }),
                  ),
                ),
              ],
            ),
            if (state.documentsLoading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              LcGridTable(
                columns: const [
                  LcGridColumn('', flex: 1),
                  LcGridColumn('Name of Document', flex: 4),
                  LcGridColumn('Original', flex: 2),
                  LcGridColumn('Number of Copies', flex: 2),
                  LcGridColumn('Clause', flex: 3),
                  LcGridColumn('Actions', flex: 1),
                ],
                emptyText: d.product == null
                    ? 'Select a product in LC Details to see its documents.'
                    : (q.isEmpty
                        ? 'The selected product lists no documents. Use Add Document.'
                        : 'No documents match "$_query".'),
                rows: [
                  for (final doc in visible)
                    () {
                      final selected = selectedOf(doc);
                      final shown = selected ?? doc;
                      return <Widget>[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Checkbox(
                            value: selected != null,
                            activeColor: brand,
                            onChanged: (v) =>
                                _notifier.toggleDocument(doc, v ?? false),
                          ),
                        ),
                        LcCell(doc.name.isEmpty ? doc.id : doc.name, bold: true),
                        LcCell(
                          '${shown.originals} / ${shown.originals + shown.copies}',
                        ),
                        LcCell('${shown.copies}'),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              textStyle: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () => _editClauses(doc, selected),
                            child: Text(
                              shown.clauses.isEmpty
                                  ? 'View / Edit Clauses'
                                  : 'View / Edit Clauses (${shown.clauses.length})',
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18),
                            tooltip: 'Actions',
                            onSelected: (action) {
                              final current = selectedOf(doc);
                              switch (action) {
                                case 'copies':
                                  if (current != null) _editCopies(current);
                                case 'remove':
                                  _notifier.toggleDocument(doc, false);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'copies',
                                enabled: selected != null,
                                child: const Text('Edit originals / copies'),
                              ),
                              PopupMenuItem(
                                value: 'remove',
                                enabled: selected != null,
                                child: const Text('Deselect'),
                              ),
                            ],
                          ),
                        ),
                      ];
                    }(),
                ],
              ),
            if (filtered.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Page ${page + 1} of $pages  •  '
                      '${page * _pageSize + 1}–${page * _pageSize + visible.length} '
                      'of ${filtered.length} items',
                      style: TextStyle(
                        fontSize: 12,
                        color: CorpColors.textSecondary(context),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.chevron_left),
                      onPressed:
                          page > 0 ? () => setState(() => _page = page - 1) : null,
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.chevron_right),
                      onPressed: page < pages - 1
                          ? () => setState(() => _page = page + 1)
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        ),
        LcTagCard(
          tag: '47A',
          title: 'Additional Conditions',
          trailing: LcAddButton(
            label: 'Add Condition',
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
                    if (picked != null) {
                      _notifier.toggleCondition(picked, true);
                    }
                  },
          ),
          children: [
            LcGridTable(
              minWidth: 520,
              columns: const [
                LcGridColumn('Condition Code', flex: 3),
                LcGridColumn('Description', flex: 5),
                LcGridColumn('Action', flex: 1),
              ],
              emptyText: 'No additional conditions.',
              rows: [
                for (final c in d.additionalConditions)
                  [
                    LcCell(c.code),
                    LcCell(c.description ?? '—', bold: true),
                    LcRemoveIcon(
                      onPressed: () => _notifier.toggleCondition(c, false),
                    ),
                  ],
              ],
            ),
          ],
        ),
        LcTagCard(
          tag: '48',
          title: 'Presentation & Incoterms',
          children: [
            LcFieldRow(children: [
              LcTextField(
                label: 'Documents to be Presented (days)',
                numeric: true,
                initialValue: '${d.documentPresentationDays}',
                onChanged: (v) => _notifier.update((x) => x.copyWith(
                      documentPresentationDays:
                          int.tryParse(v.split('.').first) ?? 0,
                    )),
              ),
              LcPickerField<TradeCode>(
                label: 'Incoterms',
                options: lookups.incoterms,
                selected: d.incoterm,
                labelOf: (c) => c.description ?? c.code,
                subtitleOf: (c) => c.code,
                onSelected: (c) =>
                    _notifier.update((x) => x.copyWith(incoterm: c)),
              ),
            ]),
          ],
        ),
      ],
    );
  }
}

// ── 04 Linkages ─────────────────────────────────────────────────────────

class _LinkagesSection extends ConsumerWidget {
  const _LinkagesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final support = ref.watch(corpLcLinkagesSectionProvider);
    final accounts = support.valueOrNull?.accounts ?? const <LcAccount>[];
    final warnings = support.valueOrNull?.warnings ?? const <String>[];
    final d = ref.watch(corpLcInitiateProvider.select((s) => s.draft));
    final notifier = ref.read(corpLcInitiateProvider.notifier);
    final brand = CorpColors.brand(context);

    LcDepositLinkage? linkOf(LcAccount account) =>
        _find(d.depositLinkages, (l) => l.account == account);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LcSectionHeading('Linkages', trailing: 'Optional'),
        LcTagCard(
          title: 'Deposit Linkages',
          children: [
            const LcInfoBox(
              text: 'Link your deposit accounts as collateral for this LC. '
                  'Select an account and enter the amount to link.',
            ),
            for (final w in warnings) LcMessageBanner(message: w),
            if (support.isLoading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              LcGridTable(
                columns: const [
                  LcGridColumn('', flex: 1),
                  LcGridColumn('Account', flex: 4),
                  LcGridColumn('Currency', flex: 2),
                  LcGridColumn('Available Balance', flex: 3),
                  LcGridColumn('Linkage Amount', flex: 3),
                ],
                emptyText: 'No deposit accounts are available for linkage.',
                rows: [
                  for (final account in accounts)
                    () {
                      final link = linkOf(account);
                      return <Widget>[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Checkbox(
                            value: link != null,
                            activeColor: brand,
                            onChanged: (v) => notifier.setLinkage(
                              account,
                              (v ?? false) ? 0 : null,
                            ),
                          ),
                        ),
                        LcCell(
                          [
                            account.id.displayValue ?? account.id.value ?? '',
                            if (account.productName != null) account.productName!,
                            if (account.isTermDeposit) 'Term deposit',
                          ].join('\n'),
                          bold: true,
                        ),
                        LcCell(account.currency ?? '—'),
                        LcCell(lcMoney(account.availableBalance)),
                        if (link == null)
                          const LcCell('—')
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 12, right: 8),
                            child: LcTextField(
                              key: ValueKey('link-${account.id.value}'),
                              label: 'Amount',
                              numeric: true,
                              initialValue: (link.amount ?? 0) > 0
                                  ? _number(link.amount)
                                  : null,
                              onChanged: (v) => notifier.setLinkage(
                                account,
                                double.tryParse(v) ?? 0,
                              ),
                            ),
                          ),
                      ];
                    }(),
                ],
              ),
            if (d.depositLinkages.isNotEmpty)
              LcInfoBox(
                title: 'Total linked',
                text: '${_number(d.linkedTotal)} across '
                    '${d.depositLinkages.length} account(s)'
                    '${d.amount == null ? '' : ' · LC amount ${lcAmount(d.amount, d.currency)}'}',
              ),
          ],
        ),
      ],
    );
  }
}

// ── 05 Instructions ─────────────────────────────────────────────────────

class _InstructionsSection extends ConsumerWidget {
  const _InstructionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookups = ref.watch(corpLcLookupsProvider).lookups;
    final d = ref.watch(corpLcInitiateProvider.select((s) => s.draft));
    final sectionData =
        ref.watch(corpLcInstructionsSectionProvider(d.product?.id));
    final support =
        sectionData.valueOrNull ?? const LcInstructionsSectionData();
    final notifier = ref.read(corpLcInitiateProvider.notifier);
    final confirmationOptions = support.confirmationInstructions.isNotEmpty
        ? support.confirmationInstructions
        : lookups.confirmationOptions;
    final parties = support.confirmationParties.isNotEmpty
        ? support.confirmationParties
        : const [
            TradeCode(code: 'ABK', description: 'Advising Bank'),
            TradeCode(code: 'ATB', description: 'Advise Through Bank'),
            TradeCode(code: 'COB', description: 'Confirming Bank'),
          ];
    final party =
        _find(parties, (p) => p.code == d.requestedConfirmationParty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LcSectionHeading('Instructions'),
        _SectionStatus(
          loading: sectionData.isLoading,
          warnings: support.warnings,
        ),
        const LcTagCard(
          tag: '57A',
          title: 'Advising Bank',
          children: [
            LcBankBlock(role: LcBankRole.advising, label: 'Advising Bank'),
          ],
        ),
        const LcTagCard(
          title: 'Advise Through',
          children: [
            LcBankBlock(
              role: LcBankRole.adviseThrough,
              label: 'Advise Through Bank',
            ),
          ],
        ),
        LcTagCard(
          tag: '49G',
          title: 'Special Payment Conditions for Beneficiary',
          children: [
            LcTextField(
              label: 'Special Payment Conditions for Beneficiary',
              hint: 'Enter payment conditions…',
              maxLines: 3,
              initialValue: d.paymentConditionsBene,
              onChanged: (v) => notifier
                  .update((x) => x.copyWith(paymentConditionsBene: v)),
            ),
          ],
        ),
        LcTagCard(
          tag: '49H',
          title: 'Special Payment Conditions for Bank Only',
          children: [
            LcTextField(
              label: 'Special Payment Conditions for Bank Only',
              hint: 'Enter bank-only conditions…',
              maxLines: 3,
              initialValue: d.paymentConditionsBank,
              onChanged: (v) => notifier
                  .update((x) => x.copyWith(paymentConditionsBank: v)),
            ),
          ],
        ),
        LcTagCard(
          tag: '49',
          title: 'Confirmation Instructions',
          children: [
            LcRadioGroup<String>(
              label: 'Confirmation',
              options: [
                for (final c in confirmationOptions) (c.code, c.label),
              ],
              value: d.confirmationInstruction,
              onChanged: (v) => notifier.update((x) => x.copyWith(
                    confirmationInstruction: v,
                    clearConfirmationParty: v == 'WITHOUT',
                  )),
            ),
            if (d.confirmationInstruction != 'WITHOUT')
              LcPickerField<TradeCode>(
                label: 'Requested Confirmation Party',
                options: parties,
                selected: party,
                labelOf: (p) => p.label,
                onSelected: (p) => notifier.update(
                  (x) => x.copyWith(requestedConfirmationParty: p.code),
                ),
              ),
          ],
        ),
        LcTagCard(
          tag: '72Z',
          title: 'Sender to Receiver Information',
          children: [
            LcTextField(
              label: 'Sender to Receiver Information',
              hint: 'Enter message information…',
              maxLines: 3,
              initialValue: d.senderReceiverInfo,
              onChanged: (v) =>
                  notifier.update((x) => x.copyWith(senderReceiverInfo: v)),
            ),
          ],
        ),
        LcTagCard(
          tag: '71D',
          title: 'Charges',
          children: [
            LcTextField(
              label: 'Charges',
              hint: 'Specify applicable charges…',
              maxLines: 2,
              initialValue: d.chargesDetails,
              onChanged: (v) =>
                  notifier.update((x) => x.copyWith(chargesDetails: v)),
            ),
          ],
        ),
        LcTagCard(
          title: 'Special Instructions',
          children: [
            LcTextField(
              label: 'Special Instructions',
              hint: 'Enter special instructions…',
              maxLines: 3,
              initialValue: d.instructions,
              onChanged: (v) =>
                  notifier.update((x) => x.copyWith(instructions: v)),
            ),
          ],
        ),
        LcTagCard(
          title: 'Standard Instructions',
          children: [
            // `customerInstructions` for the product (H5 Instructions).
            for (final text in support.standardInstructions)
              LcInfoBox(text: text),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: d.standardInstructionsAccepted,
              activeColor: CorpColors.brand(context),
              title: Text(
                'Kindly go through all the Standard Instructions',
                style: TextStyle(
                  fontSize: 13,
                  color: CorpColors.textPrimary(context),
                ),
              ),
              subtitle: Text(
                'I have read and accept the standard instructions for this '
                'Letter of Credit (UCP 600).',
                style: TextStyle(
                  fontSize: 12,
                  color: CorpColors.textSecondary(context),
                ),
              ),
              onChanged: (v) => notifier.update(
                (x) => x.copyWith(standardInstructionsAccepted: v ?? false),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ],
    );
  }
}

// ── 06 Insurance ────────────────────────────────────────────────────────

class _InsuranceSection extends ConsumerStatefulWidget {
  const _InsuranceSection();

  @override
  ConsumerState<_InsuranceSection> createState() => _InsuranceSectionState();
}

class _InsuranceSectionState extends ConsumerState<_InsuranceSection> {
  String _query = '';
  bool _lcCurrencyOnly = false;
  bool _hideExpired = false;

  Future<void> _openFilter() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: CorpColors.card(context),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Only policies in the LC currency'),
                value: _lcCurrencyOnly,
                onChanged: (v) {
                  setSheet(() {});
                  setState(() => _lcCurrencyOnly = v);
                },
              ),
              SwitchListTile(
                title: const Text('Hide expired policies'),
                value: _hideExpired,
                onChanged: (v) {
                  setSheet(() {});
                  setState(() => _hideExpired = v);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final support = ref.watch(corpLcInsuranceSectionProvider);
    final policies = support.valueOrNull ?? const <LcInsurancePolicy>[];
    final d = ref.watch(corpLcInitiateProvider.select((s) => s.draft));
    final notifier = ref.read(corpLcInitiateProvider.notifier);
    final brand = CorpColors.brand(context);
    final now = DateTime.now();

    final visible = [
      for (final p in policies)
        if (p.matches(_query) &&
            (!_lcCurrencyOnly ||
                d.currency == null ||
                p.amount?.currency == d.currency) &&
            (!_hideExpired ||
                p.expiryDate == null ||
                p.expiryDate!.isAfter(now)))
          p,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LcSectionHeading('Insurance', trailing: 'Optional'),
        LcTagCard(
          title: 'Insurance Policies',
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LcTextField(
                    label: 'Search insurance policies',
                    onChanged: (v) => setState(() => _query = v),
                    suffix: const Icon(Icons.search, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: LcSecondaryButton(
                    label: 'Filter',
                    icon: (_lcCurrencyOnly || _hideExpired)
                        ? Icons.filter_alt
                        : Icons.filter_alt_outlined,
                    onPressed: _openFilter,
                  ),
                ),
              ],
            ),
            if (support.hasError)
              LcMessageBanner(message: support.error.toString().replaceFirst('Exception: ', '')),
            if (support.isLoading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              LcGridTable(
                minWidth: 700,
                columns: const [
                  LcGridColumn('', flex: 1),
                  LcGridColumn('Policy Number', flex: 3),
                  LcGridColumn('Company Name', flex: 3),
                  LcGridColumn('Country', flex: 2),
                  LcGridColumn('Cover Date', flex: 2),
                  LcGridColumn('Expiry Date', flex: 2),
                  LcGridColumn('Amount', flex: 3),
                ],
                emptyText: policies.isEmpty
                    ? 'No insurance policies are maintained for your entity.'
                    : 'No policies match the search or filter.',
                rows: [
                  for (final p in visible)
                    [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            d.insurancePolicy == p
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 20,
                            color: d.insurancePolicy == p
                                ? brand
                                : CorpColors.textSecondary(context),
                          ),
                          onPressed: () => notifier
                              .update((x) => x.copyWith(insurancePolicy: p)),
                        ),
                      ),
                      LcCell(p.policyNumber),
                      LcCell(p.companyName ?? '—', bold: true),
                      LcCell(p.country ?? '—'),
                      LcCell(TfDate.display(p.startDate)),
                      LcCell(TfDate.display(p.expiryDate)),
                      LcCell(lcMoney(p.amount), color: brand),
                    ],
                ],
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LcSecondaryButton(
                  label: 'Clear Selection',
                  onPressed: d.insurancePolicy == null
                      ? null
                      : () => notifier.update(
                            (x) => x.copyWith(clearInsurancePolicy: true),
                          ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── 07 Charges ──────────────────────────────────────────────────────────

class _ChargesSection extends ConsumerWidget {
  const _ChargesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsValue = ref.watch(corpLcChargeAccountsProvider);
    final chargeAccounts = accountsValue.valueOrNull ?? const <LcAccount>[];
    final state = ref.watch(corpLcInitiateProvider);
    final d = state.draft;
    final notifier = ref.read(corpLcInitiateProvider.notifier);
    final account = d.chargingAccount == null
        ? null
        : (_find(chargeAccounts, (a) => a == d.chargingAccount) ??
            d.chargingAccount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LcSectionHeading('Charges'),
        LcTagCard(
          title: 'Charge Details',
          children: [
            LcFieldRow(children: [
              LcPickerField<LcAccount>(
                label: 'Charges Account',
                options: chargeAccounts,
                selected: account,
                labelOf: (a) => a.label,
                subtitleOf: (a) => lcMoney(a.availableBalance),
                helper: accountsValue.isLoading
                    ? 'Loading accounts…'
                    : (accountsValue.hasError
                        ? accountsValue.error.toString().replaceFirst('Exception: ', '')
                        : (chargeAccounts.isEmpty
                            ? 'No accounts are enabled for LC charges.'
                            : null)),
                onSelected: (a) =>
                    notifier.update((x) => x.copyWith(chargingAccount: a)),
              ),
              LcRadioGroup<String>(
                label: 'Charges Borne By',
                options: [
                  for (final c in LcChargesBorneBy.values) (c.code, c.label),
                ],
                value: d.chargesBorneBy,
                onChanged: (v) =>
                    notifier.update((x) => x.copyWith(chargesBorneBy: v)),
              ),
            ]),
          ],
        ),
        LcTagCard(
          title: 'Charges, Commissions & Taxes',
          trailing: TextButton.icon(
            onPressed: state.chargesLoading ? null : notifier.loadCharges,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
          ),
          children: [
            LcChargesList(
              charges: state.charges,
              loading: state.chargesLoading,
              message: state.chargesMessage,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ],
    );
  }
}

// ── 08 Attachments ──────────────────────────────────────────────────────

/// LC Attachments (design `Attachments.pdf`): pick files, choose their
/// category, Upload, then template & consent and the draft preview.
///
/// API: categories `documentcontent/documentcategories` (H5 Attachments).
///
/// Save Template: `template save api.har` (see
/// [CorpLcInitiateNotifier.saveTemplate]).
///
/// Upload: picked files join the list; the Upload button posts each one to
/// `content/v1/contents` with its category — `upload api.har` (see
/// [CorpLcInitiateNotifier.uploadAttachments]).
///
/// Left for later, until a capture shows them: Preview Draft Copy (button
/// disabled) and how uploaded files are referenced in the LC request
/// (`attachedDocuments` goes out empty).
class _AttachmentsSection extends ConsumerStatefulWidget {
  const _AttachmentsSection();

  @override
  ConsumerState<_AttachmentsSection> createState() =>
      _AttachmentsSectionState();
}

class _AttachmentsSectionState extends ConsumerState<_AttachmentsSection> {
  List<String> _rejected = const [];

  /// Category · type the next picked files are uploaded under.
  (String, String?, bool)? _kind;

  CorpLcInitiateNotifier get _notifier =>
      ref.read(corpLcInitiateProvider.notifier);

  bool _picking = false;

  /// Opens the device file library (as "Browse files" does on the web).
  ///
  /// Tries the type filter first (JPEG, PNG, DOC, PDF, TXT); some pickers
  /// reject custom filters, so it falls back to any file and the upload
  /// rules then check the type. A failure is shown instead of being lost.
  Future<void> _browse((String, String?, bool)? kind) async {
    if (_picking) return;
    _picking = true;
    try {
      FilePickerResult? result;
      try {
        result = await FilePicker.pickFiles(
          allowMultiple: true,
          type: FileType.custom,
          allowedExtensions: LcAttachment.allowedExtensions,
          withData: true,
        );
      } on PlatformException {
        result = await FilePicker.pickFiles(
          allowMultiple: true,
          withData: true,
        );
      }
      if (result == null || !mounted) return; // user closed the picker
      final unreadable = <String>[];
      final files = <(String, List<int>)>[];
      for (final f in result.files) {
        final bytes = f.bytes;
        if (bytes == null) {
          unreadable.add('${f.name} could not be read.');
        } else {
          files.add((f.name, bytes));
        }
      }
      setState(() => _rejected = [
            ...unreadable,
            ..._notifier.addAttachments(
              files,
              category: kind?.$1,
              documentType: kind?.$2,
            ),
          ]);
    } on MissingPluginException {
      _pickFailed(
        'The file picker is not set up in this build. Stop the app and run '
        'it again (a full restart is needed after adding file_picker).',
      );
    } catch (error) {
      _pickFailed('Could not open the file library: $error');
    } finally {
      _picking = false;
    }
  }

  void _pickFailed(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }


  Future<void> _showTerms() {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CorpColors.card(ctx),
        title: const Text('Terms & Conditions'),
        content: const SingleChildScrollView(
          child: Text(
            'This Letter of Credit is subject to the Uniform Customs and '
            'Practice for Documentary Credits (UCP 600). By submitting, you '
            'confirm that the details and documents provided are true and '
            'complete, authorise the bank to issue the credit on your '
            'behalf, and agree to reimburse the bank for all payments, '
            'charges, commissions and taxes arising under it, in line with '
            'your facility agreement with the bank.',
            style: TextStyle(fontSize: 13, height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static String _size(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).ceil()} KB';
  }

  @override
  Widget build(BuildContext context) {
    final categoriesValue = ref.watch(corpLcAttachmentCategoriesProvider);
    final categories =
        categoriesValue.valueOrNull ?? const <LcDocumentCategory>[];
    final state = ref.watch(corpLcInitiateProvider);
    final d = state.draft;
    final brand = CorpColors.brand(context);
    final secondary = CorpColors.textSecondary(context);

    // Category · type pairs for the picker (H5 Attachments).
    final kinds = <(String, String?, bool)>[
      for (final c in categories)
        if (c.types.isEmpty)
          (c.category, null, false)
        else
          for (final t in c.types) (c.category, t.$1, t.$2),
    ];
    String kindLabel((String, String?, bool) k) =>
        [k.$1, if (k.$2 != null) k.$2!].join(' · ') + (k.$3 ? ' *' : '');
    final kind = _kind ?? (kinds.isEmpty ? null : kinds.first);
    final waiting = d.attachments.where((a) => !a.isUploaded).length;
    final missingMandatory = [
      for (final k in kinds)
        if (k.$3 &&
            !d.attachments.any(
              (a) => a.category == k.$1 && a.documentType == k.$2,
            ))
          kindLabel(k),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LcSectionHeading('LC Attachments'),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 14),
          child: Text(
            'Attach supporting documents to this Letter of Credit',
            style: TextStyle(fontSize: 12.5, color: secondary),
          ),
        ),
        LcTagCard(
          title: 'Upload documents',
          children: [
            // `upload api.har` sends documentCategoryId / documentTypeId
            // with each file, so the category is chosen before picking.
            if (kinds.isNotEmpty)
              LcPickerField<(String, String?, bool)>(
                label: 'Document Category *',
                options: kinds,
                selected: kind,
                labelOf: kindLabel,
                onSelected: (k) => setState(() => _kind = k),
              ),
            // Phones have no drag and drop — the whole zone opens the picker.
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: state.isBusy ? null : () => _browse(kind),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: brand.withValues(alpha: 0.7)),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: brand.withValues(alpha: 0.10),
                      child: Icon(Icons.upload_rounded, color: brand),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Drag and Drop',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: CorpColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select or drop files here.',
                      style: TextStyle(fontSize: 12.5, color: secondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Browse files',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const LcInfoBox(
              title: 'Upload requirements',
              text: 'Maximum file size: 5 MB per file\n'
                  'Supported files: JPEG, PNG, DOC, PDF, TXT\n'
                  'Multiple files can be uploaded at a time\n'
                  'Filename: alphanumeric, dot, underscore and space only',
            ),
            for (final r in _rejected) LcMessageBanner(message: r),
            if (d.attachments.isNotEmpty) ...[
              LcGridTable(
                columns: const [
                  LcGridColumn('File Name', flex: 4),
                  LcGridColumn('Size', flex: 2),
                  LcGridColumn('Document Category', flex: 4),
                  LcGridColumn('Status', flex: 3),
                  LcGridColumn('Action', flex: 1),
                ],
                rows: [
                  for (final a in d.attachments)
                    [
                      LcCell(a.fileName, bold: true),
                      LcCell(_size(a.size)),
                      LcCell(
                        a.category == null
                            ? '—'
                            : [a.category!, if (a.documentType != null) a.documentType!]
                                .join(' · '),
                      ),
                      a.uploading
                          ? const Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : LcCell(
                              a.isUploaded
                                  ? 'Uploaded'
                                  : (a.error ?? 'Ready to upload'),
                              color: a.isUploaded
                                  ? CorpColors.of(context).success
                                  : (a.error != null
                                      ? CorpColors.of(context).error
                                      : null),
                            ),
                      LcRemoveIcon(
                        onPressed: () => _notifier.removeAttachment(a.key),
                      ),
                    ],
                ],
              ),
              // Picked files only join the list; Upload posts them
              // (`upload api.har`), as on the web.
              if (waiting > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: LcPrimaryButton(
                      label: 'Upload ($waiting)',
                      icon: Icons.cloud_upload_outlined,
                      loading: state.isUploading,
                      onPressed: state.isBusy
                          ? null
                          : _notifier.uploadAttachments,
                    ),
                  ),
                ),
            ],
            if (categoriesValue.hasError)
              LcMessageBanner(
                message: categoriesValue.error
                    .toString()
                    .replaceFirst('Exception: ', ''),
              ),
          ],
        ),
        LcInfoBox(
          text: missingMandatory.isEmpty
              ? 'Please click on Upload to attach the documents.'
              : 'Please click on Upload to attach the documents. The bank '
                  'requires: ${missingMandatory.join(', ')}.',
        ),
        LcTagCard(
          title: 'Template & consent',
          children: [
            LcRadioGroup<bool>(
              label: 'Save As Template',
              options: lcYesNoOptions,
              value: d.saveAsTemplate,
              onChanged: (v) =>
                  _notifier.update((x) => x.copyWith(saveAsTemplate: v)),
            ),
            if (d.saveAsTemplate) ...[
              LcFieldRow(children: [
                LcTextField(
                  label: 'Template Name *',
                  maxLength: 35,
                  initialValue: d.templateName,
                  onChanged: (v) =>
                      _notifier.update((x) => x.copyWith(templateName: v)),
                ),
                LcRadioGroup<String>(
                  label: 'Visibility',
                  options: const [('PRIVATE', 'Private'), ('PUBLIC', 'Public')],
                  value: d.templateVisibility,
                  onChanged: (v) => _notifier
                      .update((x) => x.copyWith(templateVisibility: v)),
                ),
              ]),
              // `template save api.har`: POST letterofcredits, state TEMPLATE.
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LcSecondaryButton(
                    label: 'Save Template',
                    icon: Icons.bookmark_add_outlined,
                    loading: state.isSaving,
                    onPressed: state.isBusy ||
                            (d.templateName ?? '').trim().isEmpty
                        ? null
                        : () => _notifier.saveTemplate(),
                  ),
                ),
              ),
            ],
            Row(
              children: [
                Checkbox(
                  value: d.termsAccepted,
                  activeColor: brand,
                  onChanged: (v) => _notifier
                      .update((x) => x.copyWith(termsAccepted: v ?? false)),
                ),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'I accept the ',
                        style: TextStyle(
                          fontSize: 13,
                          color: CorpColors.textPrimary(context),
                        ),
                      ),
                      InkWell(
                        onTap: _showTerms,
                        child: Text(
                          'Terms & Conditions',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: brand,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
        LcTagCard(
          title: 'Draft preview',
          children: [
            Text(
              'Preview Draft Copy becomes available after required consent '
              'and attachment validation.',
              style: TextStyle(fontSize: 12.5, color: secondary),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                // Not wired yet — no capture of the preview call.
                child: LcSecondaryButton(
                  label: 'Preview Draft Copy',
                  icon: Icons.visibility_outlined,
                  onPressed: null,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
