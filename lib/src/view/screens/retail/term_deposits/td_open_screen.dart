import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/retail/term_deposit.dart';
import 'package:ubci_bank/src/core/models/retail/term_deposit_actions.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/retail/term_deposit_providers.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/widgets/td_shared_widgets.dart';

/// Open a term deposit — OBDX's `td-open` flow: product, source account,
/// amount, tenure and maturity instruction; `POST .../deposit` with
/// `X-Validate-Only: Y` answers the rate, maturity date and amount for the
/// review; the same request without it opens the deposit. Pops `true`
/// once done.
class TdOpenScreen extends ConsumerStatefulWidget {
  const TdOpenScreen({super.key});

  @override
  ConsumerState<TdOpenScreen> createState() => _TdOpenScreenState();
}

class _TdOpenScreenState extends ConsumerState<TdOpenScreen> {
  final _amount = TextEditingController();
  final _years = TextEditingController();
  final _months = TextEditingController();
  final _days = TextEditingController();
  final _rollOverAmount = TextEditingController();

  int _step = 0;
  TdProduct? _product;
  TdPayAccount? _source;
  String? _currency;
  String _rollOver = TdRollOver.closeOnMaturity;
  TdPayoutDraft _payout = const TdPayoutDraft();

  String? _productError;
  String? _sourceError;
  String? _amountError;
  String? _tenureError;
  String? _rollOverAmountError;
  String? _payoutError;

  bool _validating = false;
  TdOpenRequest? _request;
  TdOpenQuote? _quote;
  TdSubmitted? _result;

  @override
  void dispose() {
    for (final c in [_amount, _years, _months, _days, _rollOverAmount]) {
      c.dispose();
    }
    super.dispose();
  }

  TdTenure get _tenure => TdTenure(
        years: int.tryParse(_years.text) ?? 0,
        months: int.tryParse(_months.text) ?? 0,
        days: int.tryParse(_days.text) ?? 0,
      );

  /// Rough length in days, to compare a tenure with the product's limits.
  static int _span(TdTenure t) => t.years * 365 + t.months * 30 + t.days;

  void _pickProduct(TdProduct product) {
    setState(() {
      _product = product;
      _productError = null;
      final currencies = product.currencies;
      _currency = currencies.contains(_source?.currencyCode)
          ? _source!.currencyCode
          : (currencies.isEmpty ? _source?.currencyCode : currencies.first);
      // Discounted products cannot renew interest or a special amount.
      if (product.discounted &&
          (_rollOver == TdRollOver.renewPrincipalAndInterest ||
              _rollOver == TdRollOver.renewSpecialAmount)) {
        _rollOver = TdRollOver.closeOnMaturity;
      }
    });
  }

  Future<void> _continue() async {
    final l10n = AppLocalizations.of(context);
    final product = _product;
    final source = _source;
    final currency = _currency ?? source?.currencyCode;
    final amount = tdParseAmount(_amount.text);
    final limit =
        product == null || currency == null ? null : product.limitFor(currency);
    final tenure = _tenure;
    final special = _rollOver == TdRollOver.renewSpecialAmount;
    final rollOverAmount = tdParseAmount(_rollOverAmount.text);

    setState(() {
      _productError = product == null ? l10n.tdSelectProductError : null;
      _sourceError = source == null ? l10n.tdSelectAccountError : null;
      _amountError = amount == null || amount <= 0
          ? l10n.tdEnterAmount
          : limit?.min != null && amount < limit!.min!
              ? l10n.tdAmountBelowMin(tdAmount(limit.min, currency!))
              : limit?.max != null && amount > limit!.max!
                  ? l10n.tdAmountAboveMax(tdAmount(limit.max, currency!))
                  : null;
      final min = product?.minTenure;
      final max = product?.maxTenure;
      _tenureError = tenure.isEmpty
          ? l10n.tdEnterTenure
          : min != null && _span(tenure) < _span(min)
              ? l10n.tdTenureBelowMin(min.label)
              : max != null && !max.isEmpty && _span(tenure) > _span(max)
                  ? l10n.tdTenureAboveMax(max.label)
                  : null;
      _rollOverAmountError = !special
          ? null
          : rollOverAmount == null || rollOverAmount <= 0
              ? l10n.tdEnterAmount
              : amount != null && rollOverAmount > amount
                  ? l10n.tdRollOverTooLarge(tdAmount(amount, currency ?? ''))
                  : null;
      _payoutError = TdRollOver.needsPayout(_rollOver) && !_payout.isComplete
          ? l10n.tdPayoutRequired
          : null;
    });
    if ([
      _productError,
      _sourceError,
      _amountError,
      _tenureError,
      _rollOverAmountError,
      _payoutError,
    ].any((e) => e != null)) {
      HapticFeedback.mediumImpact();
      return;
    }

    setState(() => _validating = true);
    final payout = TdRollOver.needsPayout(_rollOver)
        ? await tdResolvePayout(ref, _payout)
        : null;
    final request = TdOpenRequest(
      product: product!,
      source: source!,
      currency: currency!,
      amount: amount!,
      tenure: tenure,
      rollOverType: _rollOver,
      holderName: source.partyName ?? '',
      payout: payout,
      rollOverAmount: special ? rollOverAmount : null,
    );
    final result =
        await ref.read(termDepositRepositoryProvider).validateOpen(request);
    if (!mounted) return;
    setState(() => _validating = false);
    if (result is Success<TdOpenQuote> && result.data != null) {
      setState(() {
        _request = request;
        _quote = result.data;
        _step = 1;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.resolveUserMessage(l10n: l10n, fallback: l10n.tdActionFailed),
        ),
      ),
    );
  }

  void _confirm() {
    final request = _request;
    if (request == null) return;
    final repository = ref.read(termDepositRepositoryProvider);
    ref.read(tdSubmissionProvider.notifier).submit(
          (otp, challenge) => repository.open(
            request: request,
            otp: otp,
            challenge: challenge,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final products = ref.watch(tdProductsProvider);
    final rollOverOptions =
        ref.watch(tdRollOverOptionsProvider).valueOrNull ?? const [];
    final submission = ref.watch(tdSubmissionProvider);
    tdListenToSubmission(
      ref,
      context,
      onDone: (r) => setState(() {
        _result = r;
        _step = 2;
      }),
    );

    final request = _request;
    final ccy = request?.currency ?? _currency ?? '';
    final reviewRows = request == null
        ? const <(String, String)>[]
        : [
            (l10n.tdProduct, request.product.name),
            (l10n.tdPayFrom, request.source.displayNumber),
            (l10n.tdDepositAmount, tdAmount(request.amount, ccy)),
            (l10n.tdDepositTerm, request.tenure.label),
            (
              l10n.tdMaturityInstruction,
              tdRollOverLabel(request.rollOverType, rollOverOptions),
            ),
            if (request.rollOverAmount != null)
              (l10n.tdRollOverAmount, tdAmount(request.rollOverAmount, ccy)),
            if (request.payout != null) (l10n.tdPayTo, request.payout!.label),
          ];

    final Widget child;
    if (_step == 0) {
      child = products.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => TdErrorRetry(
          message: '$error',
          onRetry: () => ref.invalidate(tdProductsProvider),
        ),
        data: (list) => list.isEmpty
            ? _NoProducts(onRetry: () => ref.invalidate(tdProductsProvider))
            : _buildForm(context, l10n, list, rollOverOptions),
      );
    } else if (_step == 1) {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TdSectionLabel(l10n.tdReviewTitle),
          const SizedBox(height: 6),
          for (final (label, value) in reviewRows)
            TdReviewRow(label: label, value: value),
          TdReviewRow(
            label: l10n.tdInterestRate,
            value: tdRate(_quote?.interestRate),
          ),
          TdReviewRow(
            label: l10n.tdMaturityDate,
            value: tdDate(_quote?.maturityDate),
          ),
          TdReviewRow(
            label: l10n.tdMaturityAmount,
            value: tdMoney(_quote?.maturityAmount, currency: ccy),
            emphasize: true,
          ),
          const SizedBox(height: 24),
          TdPrimaryButton(
            label: l10n.tdConfirmOpen,
            loading: submission.isSubmitting,
            onPressed: _confirm,
          ),
        ],
      );
    } else {
      child = TdResultView(
        title: l10n.tdOpenDone,
        message: l10n.tdOpenDoneMessage,
        reference: _result?.reference,
        rows: [
          if (_result?.newDepositNumber != null)
            (l10n.tdAccountNumber, _result!.newDepositNumber!),
          ...reviewRows,
          (l10n.tdInterestRate, tdRate(_quote?.interestRate)),
          (l10n.tdMaturityDate, tdDate(_quote?.maturityDate)),
        ],
        onDone: () => Navigator.of(context).pop(true),
      );
    }

    return TdFlowScaffold(
      title: l10n.tdOpenTitle,
      step: _step,
      onBackStep: () => setState(() => _step = 0),
      summary: _OpenSummary(product: _product, currency: _currency),
      child: child,
    );
  }

  Widget _buildForm(
    BuildContext context,
    AppLocalizations l10n,
    List<TdProduct> products,
    List<TdEnumOption> rollOverOptions,
  ) {
    final product = _product;
    final currency = _currency ?? _source?.currencyCode ?? '';
    final limit = product?.limitFor(currency);
    final allowed = rollOverOptions
        .where(
          (o) =>
              !(product?.discounted ?? false) ||
              (o.code != TdRollOver.renewPrincipalAndInterest &&
                  o.code != TdRollOver.renewSpecialAmount),
        )
        .toList();

    String? limitHint() {
      if (limit == null) return null;
      final parts = [
        if (limit.min != null) l10n.tdMin(tdAmount(limit.min, currency)),
        if (limit.max != null) l10n.tdMax(tdAmount(limit.max, currency)),
      ];
      return parts.isEmpty ? null : parts.join(' · ');
    }

    String? tenureHint() {
      final min = product?.minTenure;
      final max = product?.maxTenure;
      if (min == null && max == null) return null;
      return l10n.tdTenureRange(min?.label ?? '—', max?.label ?? '—');
    }

    Widget tenureBox(TextEditingController c, String label) => Expanded(
          child: TextField(
            controller: c,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            onChanged: (_) {
              if (_tenureError != null) setState(() => _tenureError = null);
            },
            decoration: tdInputDecoration(context, hint: '0').copyWith(
              labelText: label,
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TdSectionLabel(l10n.tdOpenTitle),
        const SizedBox(height: 16),
        TdFieldLabel(l10n.tdProduct),
        TdPickerField(
          placeholder: l10n.tdSelectProduct,
          title: product?.name,
          subtitle: product == null ? null : tenureHint(),
          icon: Icons.savings_outlined,
          hasError: _productError != null,
          onTap: () async {
            final picked = await _showProductPicker(context, products, product);
            if (picked != null) _pickProduct(picked);
          },
        ),
        TdFieldError(_productError),
        const SizedBox(height: 18),
        TdFieldLabel(l10n.tdPayFrom),
        TdPayAccountField(
          taskCode: TdTask.open,
          selected: _source,
          error: _sourceError,
          onSelected: (a) => setState(() {
            _source = a;
            _sourceError = null;
            final currencies = product?.currencies ?? const [];
            if (_currency == null ||
                (currencies.isEmpty) ||
                currencies.contains(a.currencyCode)) {
              _currency = a.currencyCode;
            }
          }),
        ),
        const SizedBox(height: 18),
        TdFieldLabel(l10n.tdDepositAmount),
        if ((product?.currencies.length ?? 0) > 1) ...[
          Wrap(
            spacing: 8,
            children: [
              for (final c in product!.currencies)
                ChoiceChip(
                  label: Text(c),
                  selected: c == currency,
                  onSelected: (_) => setState(() => _currency = c),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        TdAmountField(
          controller: _amount,
          currency: currency,
          error: _amountError,
          helper: limitHint(),
          onChanged: (_) {
            if (_amountError != null) setState(() => _amountError = null);
          },
        ),
        const SizedBox(height: 18),
        TdFieldLabel(l10n.tdDepositTerm),
        Row(
          children: [
            tenureBox(_years, l10n.tdYears),
            const SizedBox(width: 8),
            tenureBox(_months, l10n.tdMonths),
            const SizedBox(width: 8),
            tenureBox(_days, l10n.tdDays),
          ],
        ),
        if (_tenureError != null)
          TdFieldError(_tenureError)
        else if (tenureHint() != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              tenureHint()!,
              style: TextStyle(
                fontSize: 12,
                color: HomeColors.textSecondary(context),
              ),
            ),
          ),
        const SizedBox(height: 18),
        TdFieldLabel(l10n.tdMaturityInstruction),
        DropdownButtonFormField<String>(
          // Keyed by the choice so a reset (a discounted product) shows.
          key: ValueKey(_rollOver),
          initialValue:
              allowed.any((o) => o.code == _rollOver) ? _rollOver : null,
          isExpanded: true,
          decoration: tdInputDecoration(context),
          items: [
            for (final o in allowed)
              DropdownMenuItem(
                value: o.code,
                child: Text(o.description, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) => setState(() {
            if (v != null) _rollOver = v;
            _payoutError = null;
          }),
        ),
        if (_rollOver == TdRollOver.renewSpecialAmount) ...[
          const SizedBox(height: 14),
          TdFieldLabel(l10n.tdRollOverAmount),
          TdAmountField(
            controller: _rollOverAmount,
            currency: currency,
            error: _rollOverAmountError,
          ),
        ],
        if (TdRollOver.needsPayout(_rollOver)) ...[
          const SizedBox(height: 16),
          TdFieldLabel(l10n.tdPayAtMaturityTo),
          TdPayoutEditor(
            taskCode: TdTask.open,
            value: _payout,
            error: _payoutError,
            onChanged: (v) => setState(() {
              _payout = v;
              _payoutError = null;
            }),
          ),
        ],
        const SizedBox(height: 24),
        TdPrimaryButton(
          label: l10n.tdContinue,
          loading: _validating,
          onPressed: _continue,
        ),
      ],
    );
  }

  Future<TdProduct?> _showProductPicker(
    BuildContext context,
    List<TdProduct> products,
    TdProduct? selected,
  ) {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<TdProduct>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (sheet) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.75,
        ),
        decoration: BoxDecoration(
          color: HomeColors.card(sheet),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: HomeColors.divider(sheet),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TdSectionLabel(l10n.tdSelectProduct),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in products)
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      selected: p.id == selected?.id,
                      selectedTileColor:
                          HomeColors.brand(sheet).withValues(alpha: 0.08),
                      leading: Icon(
                        Icons.savings_outlined,
                        color: HomeColors.brand(sheet),
                      ),
                      title: Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        [
                          if (p.currencies.isNotEmpty) p.currencies.join(', '),
                          if (p.minTenure != null || p.maxTenure != null)
                            l10n.tdTenureRange(
                              p.minTenure?.label ?? '—',
                              p.maxTenure?.label ?? '—',
                            ),
                        ].join(' · '),
                      ),
                      onTap: () => Navigator.of(sheet).pop(p),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The left panel / top card while opening: the chosen product.
class _OpenSummary extends StatelessWidget {
  const _OpenSummary({required this.product, required this.currency});

  final TdProduct? product;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [HomeColors.brand(context), HomeColors.brandDark(context)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.savings_outlined, color: Colors.white, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product?.name ?? l10n.tdOpenTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  product == null
                      ? l10n.tdOpenIntro
                      : [
                          if (currency != null) currency!,
                          if (product!.minTenure != null ||
                              product!.maxTenure != null)
                            l10n.tdTenureRange(
                              product!.minTenure?.label ?? '—',
                              product!.maxTenure?.label ?? '—',
                            ),
                        ].join(' · '),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoProducts extends StatelessWidget {
  const _NoProducts({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 40,
            color: HomeColors.textSecondary(context),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.tdNoProducts,
            textAlign: TextAlign.center,
            style: TextStyle(color: HomeColors.textSecondary(context)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: Text(l10n.accountsRetry)),
        ],
      ),
    );
  }
}
