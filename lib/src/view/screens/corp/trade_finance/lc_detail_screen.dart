import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
import 'package:ubci_bank/src/view/routes/corp/corp_routes_const.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';

/// LC detail — `GET …/letterofcredits/{id}` (H1 #48).
///
/// Sections follow the OBDX web view: overview, parties, banks, shipment
/// & goods, documents & conditions, charges.
class LcDetailScreen extends ConsumerWidget {
  const LcDetailScreen({super.key, required this.args});

  final LcDetailArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(corpLcDetailProvider(args.lcId));
    final permissions = ref.watch(lcPermissionsProvider);
    final lc = state.lc;

    Widget body;
    if (state.isLoading && lc == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (lc == null) {
      body = LcEmptyState(
        icon: Icons.error_outline,
        title: 'Letter of credit unavailable',
        message: state.errorMessage,
        action: LcSecondaryButton(
          label: 'Try again',
          icon: Icons.refresh,
          onPressed: () =>
              ref.read(corpLcDetailProvider(args.lcId).notifier).refresh(),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () =>
            ref.read(corpLcDetailProvider(args.lcId).notifier).refresh(),
        child: _DetailBody(lc: lc, errorMessage: state.errorMessage),
      );
    }

    final isImport = (lc?.lcType ?? args.lcType) == LcType.importLc;
    final canAmend = lc != null &&
        isImport &&
        lc.isActive &&
        !lc.isExpired &&
        permissions.amend;
    final canCopy = lc != null && isImport && permissions.initiate;

    return LcScreenScaffold(
      title: lc?.id ?? args.lcId,
      body: body,
      bottomBar: (canAmend || canCopy)
          ? Row(
              children: [
                if (canCopy)
                  Expanded(
                    child: LcSecondaryButton(
                      label: 'Copy & initiate',
                      icon: Icons.copy_rounded,
                      onPressed: () => Navigator.of(context).pushNamed(
                        CorpRoutesConst.lcInitiateScreen,
                        arguments: LcInitiateArgs(seed: lc),
                      ),
                    ),
                  ),
                if (canCopy && canAmend) const SizedBox(width: 12),
                if (canAmend)
                  Expanded(
                    child: LcPrimaryButton(
                      label: 'Amend LC',
                      icon: Icons.edit_note_rounded,
                      onPressed: () => Navigator.of(context).pushNamed(
                        CorpRoutesConst.lcAmendScreen,
                        arguments: LcAmendArgs(lcId: lc!.id),
                      ),
                    ),
                  ),
              ],
            )
          : null,
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.lc, this.errorMessage});

  final CorpLetterOfCredit lc;
  final String? errorMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countries = ref.watch(corpLcLookupsProvider).lookups;
    final isImport = lc.lcType == LcType.importLc;
    final s = lc.shipment;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (errorMessage != null) LcMessageBanner(message: errorMessage!),
        _OverviewCard(lc: lc),
        LcSectionCard(
          title: 'Parties',
          children: [
            LcInfoGrid(items: [
              (isImport ? 'Applicant' : 'Beneficiary', lcOrDash(lc.partyName)),
              (
                isImport ? 'Beneficiary' : 'Applicant',
                lcOrDash(lc.counterPartyName),
              ),
              (
                isImport ? 'Beneficiary address' : 'Applicant address',
                lc.counterPartyAddress.isEmpty
                    ? '—'
                    : [
                        ...lc.counterPartyAddress.lines,
                        countries.countryName(lc.counterPartyAddress.country),
                      ].join(', '),
              ),
              ('Customer reference', lcOrDash(lc.customerReferenceNo)),
            ]),
          ],
        ),
        LcSectionCard(
          title: 'Banks & instructions',
          children: [
            LcInfoGrid(items: [
              ('Advising bank', lcOrDash(lc.advisingBankCode)),
              ('Advise through bank', lcOrDash(lc.advisingThroughBankCode)),
              ('Confirming bank', lcOrDash(lc.confirmingBankCode)),
              ('Reimbursing bank', lcOrDash(lc.reimbursingBankCode)),
              ('Available with', lcOrDash(lc.availableWith)),
              ('Available by', _availableBy(lc.transferableType)),
              ('Confirmation', _confirmation(lc.confirmationInstruction)),
              ('Charges borne by', _borneBy(lc.chargesBorneBy)),
              (
                'Presentation period',
                lc.documentPresentationDays == null
                    ? '—'
                    : '${lc.documentPresentationDays} days',
              ),
              ('Branch', lcOrDash(lc.branchId)),
            ]),
          ],
        ),
        LcSectionCard(
          title: 'Shipment',
          children: [
            LcInfoGrid(items: [
              ('Place of dispatch', lcOrDash(s.source)),
              ('Final destination', lcOrDash(s.destination)),
              ('Port of loading', lcOrDash(s.loadingPort)),
              ('Port of discharge', lcOrDash(s.dischargePort)),
              ('Latest shipment date', TfDate.display(s.latestShipmentDate)),
              ('Shipment period', s.period == null ? '—' : '${s.period} days'),
              ('Partial shipment', lcYesNo(s.partialAllowed)),
              ('Transshipment', lcYesNo(s.transshipmentAllowed)),
              ('Incoterm', lcOrDash(lc.incoterm?.label)),
            ]),
          ],
        ),
        LcSectionCard(
          title: 'Goods',
          children: [
            if (lc.goods.isEmpty)
              _muted(context, 'No goods recorded.')
            else
              for (final g in lc.goods) _GoodsRow(goods: g, currency: lc.amount?.currency),
          ],
        ),
        if (lc.additionalConditions.isNotEmpty || lc.remarks != null)
          LcSectionCard(
            title: 'Conditions & remarks',
            children: [
              for (final c in lc.additionalConditions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• ${c.label}',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: CorpColors.textPrimary(context),
                      )),
                ),
              if (lc.remarks != null) _muted(context, lc.remarks!),
            ],
          ),
        LcSectionCard(
          title: 'Charges, commissions & taxes',
          children: [LcChargesList(charges: lc.charges)],
        ),
      ],
    );
  }

  static Widget _muted(BuildContext context, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: CorpColors.textSecondary(context),
        ),
      );

  static String _availableBy(String? code) {
    for (final v in LcAvailableBy.values) {
      if (v.code == code) return v.label;
    }
    return lcOrDash(code);
  }

  static String _confirmation(String? code) => switch (code) {
        'CONFIRM' => 'Confirm',
        'MAY_ADD' => 'May confirm',
        'WITHOUT' => 'Without',
        _ => lcOrDash(code),
      };

  static String _borneBy(String? code) {
    for (final v in LcChargesBorneBy.values) {
      if (v.code == code) return v.label;
    }
    return lcOrDash(code);
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.lc});

  final CorpLetterOfCredit lc;

  @override
  Widget build(BuildContext context) {
    return LcSectionCard(
      title: lc.lcType.label,
      trailing: Wrap(
        spacing: 6,
        children: [
          LcStatusChip(label: lc.statusLabel),
          if (lc.isExpired) const LcStatusChip(label: 'EXPIRED'),
          if (lc.authStatus != null) LcStatusChip(label: lc.authStatus!),
        ],
      ),
      children: [
        Text(
          lcMoney(lc.amount),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: CorpColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          lcOrDash(lc.productName),
          style: TextStyle(
            fontSize: 13,
            color: CorpColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 14),
        LcInfoGrid(items: [
          ('LC number', lc.id),
          ('Outstanding', lcMoney(lc.outstandingAmount)),
          ('Utilised', lcMoney(lc.utilisedAmount)),
          ('Issue / application date', TfDate.display(lc.applicationDate)),
          ('Expiry date', TfDate.display(lc.expiryDate)),
          ('Expiry place', lcOrDash(lc.expiryPlace)),
          (
            'Tolerance (+/−)',
            '${(lc.toleranceAbove ?? 0).toStringAsFixed(0)}% / ${(lc.toleranceUnder ?? 0).toStringAsFixed(0)}%',
          ),
          ('Revolving', lc.revolving ? 'Yes' : 'No'),
          if (lc.userName != null) ('Initiated by', lc.userName!),
        ]),
      ],
    );
  }
}

class _GoodsRow extends StatelessWidget {
  const _GoodsRow({required this.goods, this.currency});

  final LcGoods goods;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goods.description ?? goods.code,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: CorpColors.textPrimary(context),
                  ),
                ),
                Text(
                  '${goods.code} · ${_n(goods.noOfUnits)} × ${lcAmount(goods.pricePerUnit, currency)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: CorpColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            lcAmount(goods.total, currency),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: CorpColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  static String _n(double? v) {
    if (v == null) return '—';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }
}
