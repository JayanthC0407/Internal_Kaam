import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_lc_amend_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:ubci_bank/src/view/widgets/payment_otp_sheet_view.dart';

/// Amendment form → review (with charge preview, H1 #177) → submit (H1 #204).
class LcAmendScreen extends ConsumerStatefulWidget {
  const LcAmendScreen({super.key, required this.args});

  final LcAmendArgs args;

  @override
  ConsumerState<LcAmendScreen> createState() => _LcAmendScreenState();
}

class _LcAmendScreenState extends ConsumerState<LcAmendScreen> {
  List<String> _errors = const [];
  bool _otpOpen = false;

  String get _id => widget.args.lcId;

  CorpLcAmendNotifier get _notifier =>
      ref.read(corpLcAmendProvider(_id).notifier);

  Future<void> _openOtpSheet() async {
    if (_otpOpen) return;
    _otpOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AmendOtpSheet(lcId: _id),
    );
    _otpOpen = false;
    if (mounted && ref.read(corpLcAmendProvider(_id)).challenge != null) {
      _notifier.cancelOtp();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CorpLcAmendState>(corpLcAmendProvider(_id), (prev, next) {
      if (prev?.challenge == null && next.challenge != null) _openOtpSheet();
      if (prev?.challenge != null && next.challenge == null && _otpOpen) {
        Navigator.of(context).pop();
      }
    });

    final state = ref.watch(corpLcAmendProvider(_id));
    final draft = state.draft;
    final title = 'Amend $_id';

    if (state.isLoading) {
      return LcScreenScaffold(
        title: title,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (draft == null) {
      return LcScreenScaffold(
        title: title,
        body: LcEmptyState(
          icon: Icons.error_outline,
          title: 'Letter of credit unavailable',
          message: state.errorMessage,
          action: LcSecondaryButton(
            label: 'Try again',
            icon: Icons.refresh,
            onPressed: _notifier.load,
          ),
        ),
      );
    }

    final outcome = state.outcome;
    if (outcome != null) {
      return LcScreenScaffold(
        title: title,
        body: LcResultView(
          title: 'Amendment submitted',
          outcome: outcome,
          onDone: () => Navigator.of(context).pop(),
          summary: [
            ('LC number', _id),
            ('Changes', '${draft.changes.length}'),
          ],
        ),
      );
    }

    return LcScreenScaffold(
      title: title,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final e in _errors) LcMessageBanner(message: e),
          if (state.errorMessage != null)
            LcMessageBanner(message: state.errorMessage!),
          _CurrentSummary(lc: draft.original),
          if (state.reviewing)
            _AmendReview(state: state)
          else
            _AmendForm(lcId: _id),
        ],
      ),
      bottomBar: Row(
        children: [
          if (state.reviewing)
            LcSecondaryButton(
              label: 'Back',
              icon: Icons.arrow_back_rounded,
              onPressed: state.isSubmitting ? null : _notifier.backToForm,
            )
          else
            LcSecondaryButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(context).pop(),
            ),
          const Spacer(),
          LcPrimaryButton(
            label: state.reviewing ? 'Submit amendment' : 'Review',
            icon: state.reviewing
                ? Icons.send_rounded
                : Icons.arrow_forward_rounded,
            loading: state.isSubmitting,
            onPressed: state.reviewing
                ? () => _notifier.submit()
                : () => setState(() => _errors = _notifier.review()),
          ),
        ],
      ),
    );
  }
}

class _CurrentSummary extends StatelessWidget {
  const _CurrentSummary({required this.lc});

  final CorpLetterOfCredit lc;

  @override
  Widget build(BuildContext context) {
    return LcSectionCard(
      title: 'Current LC',
      trailing: LcStatusChip(label: lc.statusLabel),
      children: [
        LcInfoGrid(items: [
          ('Beneficiary', lcOrDash(lc.counterPartyName)),
          ('Product', lcOrDash(lc.productName)),
          ('Amount', lcMoney(lc.amount)),
          ('Outstanding', lcMoney(lc.outstandingAmount)),
          ('Expiry date', TfDate.display(lc.expiryDate)),
          ('Version', lcOrDash(lc.versionNo)),
        ]),
      ],
    );
  }
}

class _AmendForm extends ConsumerWidget {
  const _AmendForm({required this.lcId});

  final String lcId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(corpLcAmendProvider(lcId).select((s) => s.draft))!;
    final notifier = ref.read(corpLcAmendProvider(lcId).notifier);
    final s = d.shipment;

    void ship(LcShipmentDetails Function(LcShipmentDetails) change) =>
        notifier.update((x) => x.copyWith(shipment: change(x.shipment)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LcSectionCard(
          title: 'Amount & validity',
          children: [
            LcFieldRow(children: [
              LcTextField(
                label: 'New LC amount${d.currency == null ? '' : ' (${d.currency})'}',
                numeric: true,
                initialValue: d.newAmount?.toStringAsFixed(2),
                onChanged: (v) => notifier.update(
                  (x) => x.copyWith(newAmount: double.tryParse(v) ?? 0),
                ),
              ),
              LcDateField(
                label: 'New expiry date',
                value: d.newExpiryDate,
                firstDate: DateTime.now(),
                onChanged: (v) =>
                    notifier.update((x) => x.copyWith(newExpiryDate: v)),
              ),
            ]),
            LcTextField(
              label: 'Place of expiry',
              initialValue: d.expiryPlace,
              onChanged: (v) =>
                  notifier.update((x) => x.copyWith(expiryPlace: v)),
            ),
            LcFieldRow(children: [
              LcTextField(
                label: 'Tolerance above (%)',
                numeric: true,
                initialValue: d.toleranceAbove.toStringAsFixed(0),
                onChanged: (v) => notifier.update(
                  (x) => x.copyWith(toleranceAbove: double.tryParse(v) ?? 0),
                ),
              ),
              LcTextField(
                label: 'Tolerance below (%)',
                numeric: true,
                initialValue: d.toleranceUnder.toStringAsFixed(0),
                onChanged: (v) => notifier.update(
                  (x) => x.copyWith(toleranceUnder: double.tryParse(v) ?? 0),
                ),
              ),
            ]),
          ],
        ),
        LcSectionCard(
          title: 'Shipment',
          children: [
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
            LcDateField(
              label: 'Latest shipment date',
              value: s.latestShipmentDate,
              firstDate: DateTime.now(),
              lastDate: d.newExpiryDate,
              onChanged: (v) => ship((x) => x.copyWith(latestShipmentDate: v)),
            ),
            LcSwitchField(
              label: 'Partial shipment',
              value: s.partialAllowed,
              onChanged: (v) => ship((x) => x.copyWith(partialAllowed: v)),
            ),
            LcSwitchField(
              label: 'Transshipment',
              value: s.transshipmentAllowed,
              onChanged: (v) =>
                  ship((x) => x.copyWith(transshipmentAllowed: v)),
            ),
          ],
        ),
        LcSectionCard(
          title: 'Amendment narrative',
          children: [
            LcTextField(
              label: 'Describe the amendment (optional)',
              maxLines: 3,
              initialValue: d.narrative,
              onChanged: (v) =>
                  notifier.update((x) => x.copyWith(narrative: v)),
            ),
          ],
        ),
      ],
    );
  }
}

class _AmendReview extends StatelessWidget {
  const _AmendReview({required this.state});

  final CorpLcAmendState state;

  @override
  Widget build(BuildContext context) {
    final changes = state.draft?.changes ?? const <LcAmendmentChange>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LcSectionCard(
          title: 'Changes requested',
          children: [
            for (final c in changes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        c.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: CorpColors.textSecondary(context),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        c.before,
                        style: TextStyle(
                          fontSize: 13,
                          decoration: TextDecoration.lineThrough,
                          color: CorpColors.textSecondary(context),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        c.after,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: CorpColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        LcSectionCard(
          title: 'Amendment charges',
          children: [
            LcChargesList(
              charges: state.charges,
              loading: state.chargesLoading,
              message: state.chargesMessage,
            ),
          ],
        ),
      ],
    );
  }
}

class _AmendOtpSheet extends ConsumerWidget {
  const _AmendOtpSheet({required this.lcId});

  final String lcId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(corpLcAmendProvider(lcId));
    return PaymentOtpSheetView(
      title: 'Verify amendment',
      isSubmitting: state.isSubmitting,
      attemptsLeft: state.challenge?.attemptsLeft,
      errorText: state.otpError,
      onSubmit: (otp) =>
          ref.read(corpLcAmendProvider(lcId).notifier).submit(otp: otp),
    );
  }
}
