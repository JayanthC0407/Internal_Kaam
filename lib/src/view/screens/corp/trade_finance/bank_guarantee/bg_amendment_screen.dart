import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_bank_guarantee_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/bank_guarantee/bg_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/bank_guarantee/bg_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';

/// One amendment awaiting acceptance, next to the guarantee as it stands
/// (the web's `view-amend-guarantee` in ACCEPTANCE mode).
///
/// Read-only: approving and rejecting happen on the list, where several
/// can be answered together with one set of instructions.
class BgAmendmentScreen extends ConsumerWidget {
  const BgAmendmentScreen({super.key, required this.args});

  final BgAmendmentArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listed = args.amendment;
    final view = ref.watch(corpBgAmendmentViewProvider(listed));
    final data = view.valueOrNull;
    final a = data?.amendment ?? listed;
    final bg = data?.guarantee;
    final noun = a.category.noun;

    return LcScreenScaffold(
      title: '${a.kindLabel} ${a.id} · ${a.bgId}',
      subtitle: a.productLabel,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (view.isLoading) const LinearProgressIndicator(minHeight: 2),
          if (data?.warning != null)
            LcMessageBanner(message: data!.warning!, isError: false),
          if (a.isCancellation)
            LcMessageBanner(
              message: 'The issuing bank is cancelling this '
                  '${a.category.lowerNoun}. Approving ends it; rejecting keeps '
                  'it in force.',
            ),
          LcSectionCard(
            title: a.kindLabel,
            trailing: BgAmendmentKindChip(amendment: a),
            children: [
              LcInfoGrid(items: [
                ('$noun number', a.bgId),
                ('${a.kindLabel} number', a.id),
                ('Product', a.productLabel),
                ('Applicant', lcOrDash(a.applicantName)),
                ('Type', lcOrDash(a.typeLabel)),
                if (a.amendmentDate != null)
                  ('Date', TfDate.display(a.amendmentDate)),
              ]),
            ],
          ),
          LcSectionCard(
            title: 'Current and amended terms',
            children: [
              LcInfoGrid(items: [
                ('Current undertaking', lcMoney(bg?.undertakingAmount)),
                ('Amended undertaking', lcMoney(a.newAmount)),
                ('Current outstanding', lcMoney(bg?.outstandingAmount)),
                ('Equivalent (amended)', lcMoney(a.equivalentAmount)),
                ('Current expiry', TfDate.display(bg?.expiryDate)),
                (
                  'Amended expiry',
                  a.newExpiryDate == null
                      ? 'No change'
                      : TfDate.display(a.newExpiryDate),
                ),
                if (a.narrative != null) ('Narrative', a.narrative!),
              ]),
              const BgInfoNote(BgInfoNote.indicative),
            ],
          ),
          if (bg != null)
            LcSectionCard(
              title: noun,
              trailing: BgStatusChip(guarantee: bg),
              children: [
                LcInfoGrid(items: [
                  ('Issuing bank', lcOrDash(bg.issuingBank)),
                  ('Issuing bank reference no.', lcOrDash(bg.issuingBankRefNo)),
                  ('Beneficiary', lcOrDash(bg.beneficiaryName)),
                  ('Issue date', TfDate.display(bg.issueDate)),
                ]),
              ],
            ),
          const SizedBox(height: 4),
          const BgInfoNote(
            'To answer, go back, tick this amendment and choose Approve or '
            'Reject.',
          ),
        ],
      ),
    );
  }
}
