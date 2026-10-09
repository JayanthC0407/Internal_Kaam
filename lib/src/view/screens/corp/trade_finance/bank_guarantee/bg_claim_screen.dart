import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/bank_guarantee_models.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/trade_finance_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_bank_guarantee_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_lc_export_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/bank_guarantee/bg_filter_panel.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/bank_guarantee/bg_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/bank_guarantee/bg_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:ubci_bank/src/view/widgets/payment_otp_sheet_view.dart';

/// Lodge a claim under one inward guarantee (the web's `view-lodge-claim`,
/// headed by `claim-details`, BG #74).
///
/// The header is `claim-details` as the web shows it: party, the
/// guarantee claimed under and its status, beneficiary and outstanding
/// amount, with expiry type, expiry date and demand indicator one tap
/// away. The claim itself — demand type, amount, statement — follows.
class BgClaimScreen extends ConsumerStatefulWidget {
  const BgClaimScreen({super.key, required this.args});

  final BgClaimArgs args;

  @override
  ConsumerState<BgClaimScreen> createState() => _BgClaimScreenState();
}

class _BgClaimScreenState extends ConsumerState<BgClaimScreen> {
  bool _otpOpen = false;

  CorpBankGuarantee get _seed => widget.args.guarantee;

  BgClaimNotifier get _notifier =>
      ref.read(corpBgClaimProvider(_seed).notifier);

  Future<void> _confirmAndSubmit() async {
    final error = _notifier.validate();
    if (error != null) {
      await _notifier.submit(); // surfaces the message
      return;
    }
    final draft = ref.read(corpBgClaimProvider(_seed)).data!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lodge this claim?'),
        content: Text(
          'You are claiming ${lcAmount(draft.amount, draft.currency)} under '
          '${draft.guarantee.id}'
          '${draft.demandType == BgDemandType.extendOrPay ? ', or an extension to ${TfDate.display(draft.extendTo)}' : ''}. '
          'The bank sends your claim to the issuing bank.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Lodge claim'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _notifier.submit();
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
          final s = ref.watch(corpBgClaimProvider(_seed));
          return PaymentOtpSheetView(
            title: 'Verify your claim',
            isSubmitting: s.isSubmitting,
            attemptsLeft: s.challenge?.attemptsLeft,
            errorText: s.otpError,
            onSubmit: _notifier.submitOtp,
          );
        },
      ),
    );
    _otpOpen = false;
    if (mounted && ref.read(corpBgClaimProvider(_seed)).challenge != null) {
      _notifier.cancelOtp();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LcActionState<BgClaimDraft>>(corpBgClaimProvider(_seed),
        (prev, next) {
      if (prev?.challenge == null && next.challenge != null) _openOtpSheet();
      if (prev?.challenge != null && next.challenge == null && _otpOpen) {
        Navigator.of(context).pop();
      }
    });

    final state = ref.watch(corpBgClaimProvider(_seed));
    final lookups =
        ref.watch(bgLookupsProvider(false)).valueOrNull ?? BgLookups.empty;
    final draft = state.data ?? BgClaimDraft(guarantee: _seed);
    final bg = draft.guarantee;
    final title = 'Lodge claim · ${bg.id}';

    final outcome = state.outcome;
    if (outcome != null) {
      return LcScreenScaffold(
        title: title,
        body: LcResultView(
          title: 'Claim lodged',
          outcome: outcome,
          onDone: () => Navigator.of(context).pop(),
          summary: [
            ('${bg.category.noun} number', bg.id),
            ('Claimed amount', lcAmount(draft.amount, draft.currency)),
            ('Demand', draft.demandType.label),
          ],
        ),
      );
    }

    return LcScreenScaffold(
      title: title,
      subtitle: bg.applicantName,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.isLoading) const LinearProgressIndicator(minHeight: 2),
          _ClaimDetails(bg: bg, lookups: lookups),
          const SizedBox(height: 14),
          _ClaimForm(
            key: ValueKey(_notifier.fullAmountOnly),
            draft: draft,
            fullAmountOnly: _notifier.fullAmountOnly,
            enabled: !state.isSubmitting,
            onChanged: _notifier.update,
          ),
          if (state.errorMessage != null)
            LcMessageBanner(message: state.errorMessage!),
        ],
      ),
      bottomBar: Row(
        children: [
          Expanded(
            child: LcSecondaryButton(
              label: 'Cancel',
              onPressed:
                  state.isSubmitting ? null : () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LcPrimaryButton(
              label: 'Lodge claim',
              icon: Icons.send_rounded,
              loading: state.isSubmitting,
              onPressed: state.isLoading ? null : _confirmAndSubmit,
            ),
          ),
        ],
      ),
    );
  }
}

/// `claim-details`: four headline facts, three more on request.
class _ClaimDetails extends StatefulWidget {
  const _ClaimDetails({required this.bg, required this.lookups});

  final CorpBankGuarantee bg;
  final BgLookups lookups;

  @override
  State<_ClaimDetails> createState() => _ClaimDetailsState();
}

class _ClaimDetailsState extends State<_ClaimDetails> {
  bool _more = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.bg;
    return LcSectionCard(
      title: 'Claimed to ${bg.category.lowerNoun}',
      trailing: BgStatusChip(guarantee: bg),
      children: [
        LcInfoGrid(items: [
          ('Party name', lcOrDash(bg.applicantName)),
          ('${bg.category.noun} reference no.', bg.id),
          ('Beneficiary name', lcOrDash(bg.beneficiaryName)),
          ('Outstanding amount', lcMoney(bg.outstandingAmount)),
          if (_more) ...[
            ('Issue date', TfDate.display(bg.issueDate)),
            ('Expiry type', lcOrDash(bg.expiryTypeLabel)),
            ('Expiry date', TfDate.display(bg.expiryDate)),
            (
              'Demand indicator',
              lcOrDash(widget.lookups.demandIndicatorLabel(bg.demandIndicator)),
            ),
            if (bg.claimedAmount != null)
              ('Claimed so far', lcMoney(bg.claimedAmount)),
          ],
        ]),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _more = !_more),
            icon: Icon(
              _more ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            ),
            label: Text(_more ? 'Less information' : 'More information'),
          ),
        ),
      ],
    );
  }
}

class _ClaimForm extends StatelessWidget {
  const _ClaimForm({
    super.key,
    required this.draft,
    required this.fullAmountOnly,
    required this.enabled,
    required this.onChanged,
  });

  final BgClaimDraft draft;
  final bool fullAmountOnly;
  final bool enabled;
  final void Function(BgClaimDraft Function(BgClaimDraft)) onChanged;

  @override
  Widget build(BuildContext context) {
    final bg = draft.guarantee;
    final outstanding = bg.outstandingAmount;
    final currency = draft.currency;
    final expiry = bg.expiryDate;
    final now = DateTime.now();
    final firstExtension = (expiry ?? now).add(const Duration(days: 1));

    // Full-amount guarantees start filled in, and stay so.
    if (fullAmountOnly && outstanding != null && draft.amount == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => onChanged((d) => d.copyWith(amount: outstanding.amount)),
      );
    }

    return LcSectionCard(
      title: 'Your claim',
      children: [
        _Label('What are you asking for?'),
        for (final type in BgDemandType.values)
          _DemandOption(
            type: type,
            selected: draft.demandType == type,
            onTap: enabled
                ? () => onChanged((d) => d.copyWith(
                      demandType: type,
                      clearExtendTo: type == BgDemandType.pay,
                    ))
                : null,
          ),
        const SizedBox(height: 12),
        LcTextField(
          label: 'Claim amount${currency == null ? '' : ' ($currency)'}',
          initialValue: fullAmountOnly && outstanding != null
              ? bgAmountText(outstanding.amount)
              : bgAmountText(draft.amount),
          numeric: true,
          enabled: enabled && !fullAmountOnly,
          helper: fullAmountOnly
              ? 'Partial claims are not allowed under this '
                  '${bg.category.lowerNoun}: the full outstanding amount is '
                  'claimed.'
              : 'Up to ${lcMoney(outstanding)} outstanding.',
          onChanged: (v) {
            final amount = double.tryParse(v.trim());
            onChanged((d) => amount == null
                ? d.copyWith(clearAmount: true)
                : d.copyWith(amount: amount));
          },
        ),
        if (draft.demandType == BgDemandType.extendOrPay)
          LcDateField(
            label: 'Extend expiry to',
            value: draft.extendTo,
            firstDate: firstExtension,
            lastDate: DateTime(firstExtension.year + 10),
            helper: 'Currently expires ${TfDate.display(expiry)}.',
            onChanged: (d) => onChanged((x) => x.copyWith(extendTo: d)),
          ),
        LcTextField(
          label: 'Claim statement',
          hint: 'State the default under the underlying contract',
          initialValue: draft.description,
          maxLines: 4,
          maxLength: 1000,
          enabled: enabled,
          onChanged: (v) => onChanged((d) => d.copyWith(description: v)),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: CorpColors.textSecondary(context),
        ),
      ),
    );
  }
}

class _DemandOption extends StatelessWidget {
  const _DemandOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final BgDemandType type;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? brand.withValues(alpha: 0.08) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? brand : CorpColors.divider(context),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: selected ? brand : CorpColors.textSecondary(context),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CorpColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        type.description,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: CorpColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
