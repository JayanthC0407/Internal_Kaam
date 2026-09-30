import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_lc_export_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:ubci_bank/src/view/widgets/payment_otp_sheet_view.dart';

/// Export LC → LC Amendment Acceptance.
///
/// Shows the amendment (H2 #157) next to the current LC (H1 #48 detail of
/// `lcId`) and lets the beneficiary accept or reject it. The response call
/// is NOT CAPTURED — see `CorpLcAmendment.toResponseJson`.
class LcAcceptanceScreen extends ConsumerStatefulWidget {
  const LcAcceptanceScreen({super.key, required this.args});

  final LcAcceptanceArgs args;

  @override
  ConsumerState<LcAcceptanceScreen> createState() =>
      _LcAcceptanceScreenState();
}

class _LcAcceptanceScreenState extends ConsumerState<LcAcceptanceScreen> {
  String _remarks = '';
  bool _otpOpen = false;

  CorpLcAmendment get _amendment => widget.args.amendment;

  CorpLcAcceptanceNotifier get _notifier =>
      ref.read(corpLcAcceptanceProvider(_amendment).notifier);

  Future<void> _respond(bool accept) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(accept ? 'Accept amendment?' : 'Reject amendment?'),
        content: Text(
          accept
              ? 'The amended terms will become binding on this LC.'
              : 'The LC will continue on its current terms.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(accept ? 'Accept' : 'Reject'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _notifier.respond(accept: accept, remarks: _remarks);
  }

  Future<void> _openOtpSheet() async {
    if (_otpOpen) return;
    _otpOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final s = ref.watch(corpLcAcceptanceProvider(_amendment));
          return PaymentOtpSheetView(
            title: 'Verify your response',
            isSubmitting: s.isSubmitting,
            attemptsLeft: s.challenge?.attemptsLeft,
            errorText: s.otpError,
            onSubmit: _notifier.submitOtp,
          );
        },
      ),
    );
    _otpOpen = false;
    if (mounted &&
        ref.read(corpLcAcceptanceProvider(_amendment)).challenge != null) {
      _notifier.cancelOtp();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LcActionState<Object>>(corpLcAcceptanceProvider(_amendment),
        (prev, next) {
      if (prev?.challenge == null && next.challenge != null) _openOtpSheet();
      if (prev?.challenge != null && next.challenge == null && _otpOpen) {
        Navigator.of(context).pop();
      }
    });

    final state = ref.watch(corpLcAcceptanceProvider(_amendment));
    final detail = ref.watch(corpLcDetailProvider(_amendment.lcId));
    final a = _amendment;
    final title = 'Amendment ${a.id} · ${a.lcId}';

    final outcome = state.outcome;
    if (outcome != null) {
      return LcScreenScaffold(
        title: title,
        body: LcResultView(
          title: _notifier.lastDecisionAccepted
              ? 'Amendment accepted'
              : 'Amendment rejected',
          outcome: outcome,
          onDone: () => Navigator.of(context).pop(),
          summary: [('LC number', a.lcId), ('Amendment', a.id)],
        ),
      );
    }

    final lc = detail.lc;
    return LcScreenScaffold(
      title: title,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.errorMessage != null)
            LcMessageBanner(message: state.errorMessage!),
          LcSectionCard(
            title: 'Amendment',
            trailing: LcStatusChip(
              label: a.isPending ? 'PENDING' : a.acceptanceStatus!.toUpperCase(),
            ),
            children: [
              LcInfoGrid(items: [
                ('LC number', a.lcId),
                ('Amendment number', a.id),
                ('Applicant', lcOrDash(a.applicantName)),
                ('Product type', lcOrDash(a.productType)),
                if (a.amendmentDate != null)
                  ('Amendment date', TfDate.display(a.amendmentDate)),
              ]),
            ],
          ),
          LcSectionCard(
            title: 'Current vs amended terms',
            children: [
              if (detail.isLoading && lc == null)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else
                LcInfoGrid(items: [
                  ('Current amount', lcMoney(lc?.amount)),
                  ('Amended amount', lcMoney(a.newAmount)),
                  ('Current expiry', TfDate.display(lc?.expiryDate)),
                  (
                    'Amended expiry',
                    a.newExpiryDate == null
                        ? 'No change'
                        : TfDate.display(a.newExpiryDate),
                  ),
                  if (a.shipment.latestShipmentDate != null)
                    (
                      'Amended latest shipment',
                      TfDate.display(a.shipment.latestShipmentDate),
                    ),
                  if (a.narrative != null) ('Narrative', a.narrative!),
                ]),
            ],
          ),
          if (a.isPending)
            LcSectionCard(
              title: 'Your response',
              children: [
                LcTextField(
                  label: 'Remarks (optional)',
                  maxLines: 3,
                  onChanged: (v) => _remarks = v,
                ),
              ],
            ),
        ],
      ),
      bottomBar: a.isPending
          ? Row(
              children: [
                Expanded(
                  child: LcSecondaryButton(
                    label: 'Reject',
                    icon: Icons.close_rounded,
                    onPressed: state.isSubmitting ? null : () => _respond(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LcPrimaryButton(
                    label: 'Accept',
                    icon: Icons.check_rounded,
                    loading: state.isSubmitting,
                    onPressed: () => _respond(true),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}
