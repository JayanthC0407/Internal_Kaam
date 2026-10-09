import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/bank_guarantee_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_bank_guarantee_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/bank_guarantee/bg_route_args.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/bank_guarantee/bg_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';
import 'package:ubci_bank/src/view/widgets/payment_otp_sheet_view.dart';

/// Review → send → result for an approve / reject decision on one or more
/// guarantee amendments (the web's `review-guarantee-acceptance`).
///
/// Pops `true` when the user finishes after sending, so the acceptance
/// list clears its selection.
class BgAcceptanceReviewScreen extends ConsumerStatefulWidget {
  const BgAcceptanceReviewScreen({super.key, required this.args});

  final BgAcceptanceReviewArgs args;

  @override
  ConsumerState<BgAcceptanceReviewScreen> createState() =>
      _BgAcceptanceReviewScreenState();
}

class _BgAcceptanceReviewScreenState
    extends ConsumerState<BgAcceptanceReviewScreen> {
  bool _otpOpen = false;

  BgAcceptanceRequest get _request => widget.args.request;

  BgAcceptanceNotifier get _notifier =>
      ref.read(corpBgAcceptanceProvider(_request).notifier);

  Future<void> _openOtpSheet() async {
    if (_otpOpen) return;
    _otpOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final s = ref.watch(corpBgAcceptanceProvider(_request));
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
    if (mounted && ref.read(corpBgAcceptanceProvider(_request)).challenge != null) {
      _notifier.cancelOtp();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<BgAcceptanceState>(corpBgAcceptanceProvider(_request),
        (prev, next) {
      if (prev?.challenge == null && next.challenge != null) _openOtpSheet();
      if (prev?.challenge != null && next.challenge == null && _otpOpen) {
        Navigator.of(context).pop();
      }
    });

    final state = ref.watch(corpBgAcceptanceProvider(_request));
    final verb = _request.accept ? 'Approve' : 'Reject';
    final count = _request.amendments.length;
    final plural = count == 1 ? '' : 's';

    if (state.done) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.of(context).pop(true);
        },
        child: LcScreenScaffold(
          title: '${_request.accept ? 'Approval' : 'Rejection'} sent',
          body: _ResultView(request: _request, results: state.results),
          bottomBar: LcPrimaryButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !state.started,
      child: LcScreenScaffold(
        title: '$verb amendment$plural',
        subtitle: 'Review before sending',
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LcMessageBanner(
              isError: !_request.accept,
              message: _request.accept
                  ? 'Approving makes the amended terms binding. An approved '
                      'cancellation ends the ${_request.category.lowerNoun}.'
                  : 'Rejecting keeps the ${_request.category.lowerNoun} on its '
                      'current terms.',
            ),
            LcSectionCard(
              title: '$count amendment$plural',
              children: [
                for (final a in _request.amendments) _AmendmentRow(amendment: a),
              ],
            ),
            LcSectionCard(
              title: 'Special instructions',
              children: [
                Text(
                  _request.instructions,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: CorpColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ],
        ),
        bottomBar: Row(
          children: [
            Expanded(
              child: LcSecondaryButton(
                label: 'Back',
                onPressed: state.isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LcPrimaryButton(
                label: verb,
                icon: _request.accept ? Icons.check_rounded : Icons.close_rounded,
                loading: state.isSubmitting,
                onPressed: state.started ? null : _notifier.submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmendmentRow extends StatelessWidget {
  const _AmendmentRow({required this.amendment, this.trailing});

  final CorpBgAmendment amendment;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final a = amendment;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: CorpColors.divider(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${a.bgId} · ${a.kindLabel} ${a.id}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: CorpColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${lcOrDash(a.applicantName)} · ${lcMoney(a.newAmount)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: CorpColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          trailing ?? BgAmendmentKindChip(amendment: a),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.request, required this.results});

  final BgAcceptanceRequest request;
  final Map<String, BgResponseResult> results;

  @override
  Widget build(BuildContext context) {
    final colors = CorpColors.of(context);
    final sent = results.values.where((r) => r.isSent).length;
    final total = request.amendments.length;
    final allSent = sent == total;
    final noneSent = sent == 0;
    final pending = results.values.any((r) => r.outcome?.pendingApproval ?? false);
    final tone = allSent ? colors.success : (noneSent ? colors.error : colors.warning);

    final String headline;
    if (allSent) {
      headline = request.accept
          ? 'Approval sent to the bank'
          : 'Rejection sent to the bank';
    } else if (noneSent) {
      headline = 'Nothing was sent';
    } else {
      headline = '$sent of $total sent';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CorpCardShell(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  allSent
                      ? (pending ? Icons.hourglass_top_rounded : Icons.check_rounded)
                      : (noneSent ? Icons.error_outline_rounded : Icons.rule_rounded),
                  color: tone,
                  size: 34,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                pending
                    ? 'Your response has gone for approval under your '
                        'corporate approval rules.'
                    : noneSent
                        ? 'Check the reasons below and try again from the list.'
                        : 'The bank will update the ${request.category.lowerNoun} '
                            'once it processes your response.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LcSectionCard(
          title: 'Amendments',
          children: [
            for (final a in request.amendments)
              _ResultRow(amendment: a, result: results[a.key]),
          ],
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.amendment, required this.result});

  final CorpBgAmendment amendment;
  final BgResponseResult? result;

  @override
  Widget build(BuildContext context) {
    final colors = CorpColors.of(context);
    final r = result;
    final sent = r?.isSent ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AmendmentRow(
          amendment: amendment,
          trailing: BgChip(
            label: sent ? 'Sent' : 'Not sent',
            tone: sent ? colors.success : colors.error,
          ),
        ),
        if (r?.outcome?.referenceNo != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: LcInfoItem(
              label: 'Reference number',
              value: r!.outcome!.referenceNo!,
            ),
          ),
        if (r?.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: LcMessageBanner(message: r!.error!),
          ),
      ],
    );
  }
}
