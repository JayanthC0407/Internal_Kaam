import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_lc_export_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_trade_finance_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/lc_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:ubci_bank/src/view/widgets/payment_otp_sheet_view.dart';

/// Export LC → Initiate Transfer LC.
///
/// Opened from the transferable-LC list (H2 #202). Loads the LC detail,
/// collects the second beneficiary and transfer terms, and submits the
/// transfer — the submit call is NOT CAPTURED (see
/// `LcTransferDraft.toRequestJson` / `CorpTradeFinanceApiConst.transfersApi`).
class LcTransferScreen extends ConsumerStatefulWidget {
  const LcTransferScreen({super.key, required this.args});

  final LcTransferArgs args;

  @override
  ConsumerState<LcTransferScreen> createState() => _LcTransferScreenState();
}

class _LcTransferScreenState extends ConsumerState<LcTransferScreen> {
  List<String> _errors = const [];
  bool _otpOpen = false;

  String get _id => widget.args.lcId;

  CorpLcTransferNotifier get _notifier =>
      ref.read(corpLcTransferProvider(_id).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(corpLcLookupsProvider.notifier).ensureLoaded();
    });
  }

  Future<void> _submit() async {
    final errors = _notifier.validate();
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;
    final d = ref.read(corpLcTransferProvider(_id)).data!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer this LC?'),
        content: Text(
          '${lcAmount(d.amount, d.currency)} will be transferred to '
          '${d.beneficiaryName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final more = await _notifier.submit();
    if (mounted && more.isNotEmpty) setState(() => _errors = more);
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
          final s = ref.watch(corpLcTransferProvider(_id));
          return PaymentOtpSheetView(
            title: 'Verify LC transfer',
            isSubmitting: s.isSubmitting,
            attemptsLeft: s.challenge?.attemptsLeft,
            errorText: s.otpError,
            onSubmit: (otp) => _notifier.submit(otp: otp),
          );
        },
      ),
    );
    _otpOpen = false;
    if (mounted && ref.read(corpLcTransferProvider(_id)).challenge != null) {
      _notifier.cancelOtp();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LcActionState<LcTransferDraft>>(corpLcTransferProvider(_id),
        (prev, next) {
      if (prev?.challenge == null && next.challenge != null) _openOtpSheet();
      if (prev?.challenge != null && next.challenge == null && _otpOpen) {
        Navigator.of(context).pop();
      }
    });

    final state = ref.watch(corpLcTransferProvider(_id));
    final lookups = ref.watch(corpLcLookupsProvider).lookups;
    final title = 'Transfer $_id';
    final d = state.data;

    if (state.isLoading) {
      return LcScreenScaffold(
        title: title,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (d == null) {
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
          title: 'Transfer submitted',
          outcome: outcome,
          onDone: () => Navigator.of(context).pop(),
          summary: [
            ('LC number', _id),
            ('Second beneficiary', lcOrDash(d.beneficiaryName)),
            ('Amount', lcAmount(d.amount, d.currency)),
          ],
        ),
      );
    }

    final lc = d.original;
    TradeCode? country;
    for (final c in lookups.countries) {
      if (c.code == d.beneficiaryAddress.country) country = c;
    }

    return LcScreenScaffold(
      title: title,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final e in _errors) LcMessageBanner(message: e),
          if (state.errorMessage != null)
            LcMessageBanner(message: state.errorMessage!),
          LcSectionCard(
            title: 'Export LC',
            trailing: LcStatusChip(label: lc.statusLabel),
            children: [
              LcInfoGrid(items: [
                ('Applicant', lcOrDash(lc.counterPartyName)),
                ('Product', lcOrDash(lc.productName)),
                ('LC amount', lcMoney(lc.amount)),
                ('Available to transfer', lcAmount(d.maxAmount, d.currency)),
                ('Expiry date', TfDate.display(lc.expiryDate)),
                (
                  'Latest shipment',
                  TfDate.display(lc.shipment.latestShipmentDate),
                ),
              ]),
            ],
          ),
          LcSectionCard(
            title: 'Second beneficiary',
            children: [
              LcTextField(
                label: 'Name',
                initialValue: d.beneficiaryName,
                onChanged: (v) =>
                    _notifier.update((x) => x.copyWith(beneficiaryName: v)),
              ),
              LcTextField(
                label: 'Address line 1',
                initialValue: d.beneficiaryAddress.line1,
                onChanged: (v) => _notifier.update((x) => x.copyWith(
                      beneficiaryAddress: x.beneficiaryAddress.copyWith(line1: v),
                    )),
              ),
              LcFieldRow(children: [
                LcTextField(
                  label: 'Address line 2',
                  initialValue: d.beneficiaryAddress.line2,
                  onChanged: (v) => _notifier.update((x) => x.copyWith(
                        beneficiaryAddress:
                            x.beneficiaryAddress.copyWith(line2: v),
                      )),
                ),
                LcPickerField<TradeCode>(
                  label: 'Country',
                  options: lookups.countries,
                  selected: country,
                  labelOf: (c) => c.label,
                  subtitleOf: (c) => c.code,
                  onSelected: (c) => _notifier.update((x) => x.copyWith(
                        beneficiaryAddress:
                            x.beneficiaryAddress.copyWith(country: c.code),
                      )),
                ),
              ]),
            ],
          ),
          LcSectionCard(
            title: 'Transfer terms',
            children: [
              LcTextField(
                label: 'Transfer amount${d.currency == null ? '' : ' (${d.currency})'}',
                numeric: true,
                initialValue: d.amount?.toStringAsFixed(2),
                helper: d.maxAmount == null
                    ? null
                    : 'Up to ${lcAmount(d.maxAmount, d.currency)}',
                onChanged: (v) => _notifier
                    .update((x) => x.copyWith(amount: double.tryParse(v) ?? 0)),
              ),
              LcFieldRow(children: [
                LcDateField(
                  label: 'Expiry date',
                  value: d.expiryDate,
                  firstDate: DateTime.now(),
                  lastDate: lc.expiryDate,
                  helper: 'Cannot be later than the original LC',
                  onChanged: (v) =>
                      _notifier.update((x) => x.copyWith(expiryDate: v)),
                ),
                LcDateField(
                  label: 'Latest shipment date',
                  value: d.latestShipmentDate,
                  firstDate: DateTime.now(),
                  lastDate: lc.shipment.latestShipmentDate ?? lc.expiryDate,
                  onChanged: (v) => _notifier
                      .update((x) => x.copyWith(latestShipmentDate: v)),
                ),
              ]),
              LcTextField(
                label: 'Remarks (optional)',
                maxLines: 3,
                initialValue: d.remarks,
                onChanged: (v) =>
                    _notifier.update((x) => x.copyWith(remarks: v)),
              ),
            ],
          ),
        ],
      ),
      bottomBar: Row(
        children: [
          LcSecondaryButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          LcPrimaryButton(
            label: 'Submit transfer',
            icon: Icons.send_rounded,
            loading: state.isSubmitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
