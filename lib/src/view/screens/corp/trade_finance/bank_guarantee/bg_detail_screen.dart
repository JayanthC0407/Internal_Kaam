import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/bank_guarantee_models.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_bank_guarantee_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/bank_guarantee/bg_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/bank_guarantee/bg_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';

/// One inward guarantee in full (`bankguarantees/{id}`, FROM COMPONENT —
/// the web opens `view-bank-guarantee-details`).
///
/// The list row is shown straight away and replaced by the detail once it
/// loads; if the detail fails, the row stays with the reason above it. The
/// detail response has not been captured, so whatever else the bank sends
/// is listed under "More from the bank" rather than dropped.
class BgDetailScreen extends ConsumerWidget {
  const BgDetailScreen({super.key, required this.args});

  final BgDetailArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seed = args.seed;
    final key = (id: seed.id, category: seed.category);
    final detail = ref.watch(corpBgDetailProvider(key));
    final lookups =
        ref.watch(bgLookupsProvider(false)).valueOrNull ?? BgLookups.empty;
    final bg = detail.valueOrNull ?? seed;
    final noun = bg.category.noun;

    return LcScreenScaffold(
      title: '$noun ${bg.id}',
      subtitle: '${bg.formLabel} · Inward',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(corpBgDetailProvider(key)),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await ref.refresh(corpBgDetailProvider(key).future);
          } catch (_) {
            // Shown by the banner from the provider's error state.
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (detail.isLoading) const LinearProgressIndicator(minHeight: 2),
            if (detail.hasError)
              LcMessageBanner(message: '${detail.error}'),
            _Summary(bg: bg),
            const SizedBox(height: 14),
            LcSectionCard(
              title: 'Parties',
              children: [
                LcInfoGrid(items: [
                  ('Applicant', lcOrDash(bg.applicantName)),
                  ('Beneficiary', lcOrDash(bg.beneficiaryName)),
                  ('Issuing bank', lcOrDash(bg.issuingBank)),
                  ('Issuing bank reference no.', lcOrDash(bg.issuingBankRefNo)),
                  if (bg.customerReferenceNo != null)
                    ('Customer reference no.', bg.customerReferenceNo!),
                ]),
              ],
            ),
            LcSectionCard(
              title: 'Dates and validity',
              children: [
                LcInfoGrid(items: [
                  ('Issue date', TfDate.display(bg.issueDate)),
                  ('Date of expiry', TfDate.display(bg.expiryDate)),
                  ('Expiry type', lcOrDash(bg.expiryTypeLabel)),
                  (
                    'Demand indicator',
                    lcOrDash(lookups.demandIndicatorLabel(bg.demandIndicator)),
                  ),
                ]),
              ],
            ),
            LcSectionCard(
              title: 'Amounts',
              children: [
                LcInfoGrid(items: [
                  ('Undertaking amount', lcMoney(bg.undertakingAmount)),
                  (
                    'Equivalent undertaking amount',
                    lcMoney(bg.equivalentUndertakingAmount),
                  ),
                  ('Outstanding amount', lcMoney(bg.outstandingAmount)),
                  (
                    'Equivalent outstanding amount',
                    lcMoney(bg.equivalentOutstandingAmount),
                  ),
                  if (bg.claimedAmount != null)
                    ('Claimed so far', lcMoney(bg.claimedAmount)),
                ]),
                const BgInfoNote(BgInfoNote.indicative),
              ],
            ),
            _MoreFromBank(bg: bg),
          ],
        ),
      ),
    );
  }
}

/// Number, status and the outstanding amount — the three things a user
/// opens a guarantee to check.
class _Summary extends StatelessWidget {
  const _Summary({required this.bg});

  final CorpBankGuarantee bg;

  @override
  Widget build(BuildContext context) {
    final colors = CorpColors.of(context);
    return LcSectionCard(
      title: '${bg.category.noun} number',
      trailing: BgStatusChip(guarantee: bg),
      children: [
        Text(
          bg.id,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Outstanding',
          style: TextStyle(fontSize: 12, color: colors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          lcMoney(bg.outstandingAmount),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: CorpColors.brand(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'of ${lcMoney(bg.undertakingAmount)} undertaken · '
          'expires ${TfDate.display(bg.expiryDate)}',
          style: TextStyle(fontSize: 12.5, color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// Every other plain field in the bank's response, so nothing it sends is
/// hidden while the detail shape is uncaptured.
class _MoreFromBank extends StatelessWidget {
  const _MoreFromBank({required this.bg});

  final CorpBankGuarantee bg;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[];
    for (final entry in bg.raw.entries) {
      if (CorpBankGuarantee.knownKeys.contains(entry.key)) continue;
      final value = entry.value;
      String? text;
      if (value is String || value is num || value is bool) {
        text = TfJson.str(value);
        final date = value is String && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value)
            ? TfJson.date(value)
            : null;
        if (date != null) text = TfDate.display(date);
        if (value is bool) text = value ? 'Yes' : 'No';
      } else if (value is Map && value['amount'] != null) {
        text = lcMoney(MoneyAmount.fromJson(value));
      } else if (value is Map && value['displayValue'] != null) {
        text = TfJson.str(value['displayValue']);
      }
      if (text == null) continue;
      items.add((bgHumanize(entry.key), text));
    }
    if (items.isEmpty) return const SizedBox.shrink();
    items.sort((a, b) => a.$1.compareTo(b.$1));

    return LcSectionCard(
      title: 'More from the bank',
      children: [
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 4),
            title: Text(
              '${items.length} further details',
              style: TextStyle(
                fontSize: 13.5,
                color: CorpColors.textSecondary(context),
              ),
            ),
            children: [LcInfoGrid(items: items)],
          ),
        ),
      ],
    );
  }
}
