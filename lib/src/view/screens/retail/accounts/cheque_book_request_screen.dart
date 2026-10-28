import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/retail/cheque_book_models.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/retail/cheque_book_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/widgets/preferences_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/obdx_write_runner.dart';

/// Cheque Book Request — OBDX `flows/cheque-book-request`: the form →
/// Review → confirmation. Confirm sends `POST demandDeposit/{id}/chequeBooks`
/// with the OTP loop. Layout from UI designs 2 (193348); fields, rules and
/// labels from OBDX. Evidence: docs/obdx/features/cheque-book-request.md.
class ChequeBookRequestScreen extends ConsumerStatefulWidget {
  const ChequeBookRequestScreen({super.key, required this.onExit});

  /// Back, Cancel and Done.
  final VoidCallback onExit;

  @override
  ConsumerState<ChequeBookRequestScreen> createState() => _ChequeBookRequestScreenState();
}

/// The Delivery Location as it stands: what Submit sends, and its section.
typedef _Delivery = ({ChequeAddress address, String? addressType, String? branchCode, Widget section});

class _ChequeBookRequestScreenState extends ConsumerState<ChequeBookRequestScreen> {
  int _step = 0;
  bool _busy = false;
  bool _showErrors = false;

  ChequeAccount? _account;
  ChequeBookType? _type;
  int? _leaves;
  final _books = TextEditingController();

  ChequeDelivery _delivery = ChequeDelivery.myAddress;
  String? _addressType;
  String? _city;
  String? _branch;

  ChequeBookRequest? _request;
  ChequeBookOutcome? _outcome;

  @override
  void dispose() {
    _books.dispose();
    super.dispose();
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  String _loadMessage(Object? error, String fallback) =>
      error is ChequeBookLoadError && error.message != null ? error.message! : fallback;

  // ── Submit (form → Review) and Confirm ────────────────────────────────

  void _submit(ChequeBookSetup setup, ChequeAccount account, _Delivery delivery) {
    final l10n = AppLocalizations.of(context);
    final missing = (_type == null && setup.types.isNotEmpty) ||
        (setup.config.booksEnabled && !chequeBooksValid(_books.text)) ||
        _leaves == null;
    if (missing) {
      setState(() => _showErrors = true);
      return;
    }
    // OBDX checks the wallet after the field rules (stage1.js:128-136).
    if (isWalletAccount(account)) return _snack(l10n.cbrWalletNotAllowed);
    FocusScope.of(context).unfocus();
    setState(() {
      _request = ChequeBookRequest(
        account: account,
        type: _type,
        leaves: _leaves!,
        books: setup.config.booksEnabled ? _books.text.trim() : null,
        delivery: _delivery,
        address: delivery.address,
        addressType: delivery.addressType,
        branchCode: delivery.branchCode,
      );
      _step = 1;
    });
  }

  Future<void> _confirm() async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(chequeBookRepositoryProvider);
    final request = _request!;
    setState(() => _busy = true);
    final result = await runWithOtp<ChequeBookOutcome>(
      context,
      (challenge, otp) => repository.requestChequeBook(request, challenge: challenge, otp: otp),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (obdxWriteDone(result)) {
      HapticFeedback.mediumImpact();
      setState(() {
        _outcome = (result as Success<ChequeBookOutcome>).data;
        _step = 2;
      });
    } else if (result is! Success<ChequeBookOutcome>) {
      // OBDX shows the server's message and stays on Review.
      _snack(result.resolveUserMessage(l10n: l10n, fallback: l10n.cbrFailed));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(chequeBookSetupProvider);
    final setup = async.valueOrNull;

    if (setup == null || setup.accounts.isEmpty) {
      return PayFlowScaffold(
        title: l10n.cbrTitle,
        step: 0,
        onExit: widget.onExit,
        child: async.hasError
            ? PayErrorRetry(
                message: _loadMessage(async.error, l10n.cbrLoadFailed),
                onRetry: () => ref.invalidate(chequeBookSetupProvider),
              )
            : setup != null
                ? PayCard(child: PayMuted(l10n.cbrNoAccounts))
                : const PayCard(
                    child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                  ),
      );
    }

    final account = setup.accounts.any((a) => a.id == _account?.id) ? _account! : ChequeAccount.initial(setup.accounts)!;
    final delivery = _step == 0 ? _deliveryFor(l10n, setup, account) : null;

    return PayFlowScaffold(
      title: l10n.cbrTitle,
      subtitle: _step == 1 ? l10n.cbrReviewMessage : null,
      step: _step,
      onBackStep: _busy ? null : () => setState(() => _step = 0),
      onExit: _busy ? null : widget.onExit,
      action: switch (_step) {
        0 => Row(
            children: [
              Expanded(
                child: PayPrimaryButton(
                  label: l10n.addBillerSubmit,
                  onPressed: () => _submit(setup, account, delivery!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: PaySecondaryButton(label: l10n.cancel, onPressed: widget.onExit)),
            ],
          ),
        1 => PayPrimaryButton(label: l10n.addBillerConfirm, loading: _busy, onPressed: _busy ? null : _confirm),
        _ => PayPrimaryButton(label: l10n.cbrDone, onPressed: widget.onExit),
      },
      child: switch (_step) {
        0 => _form(l10n, setup, account, delivery!),
        1 => PaySummaryCard(
            icon: Icons.fact_check_outlined,
            title: l10n.addBillerReview,
            subtitle: l10n.cbrReviewMessage,
            rows: _rows(l10n, setup, _request!),
          ),
        _ => _done(l10n, setup),
      },
    );
  }

  /// Review's rows, in OBDX's order (review.html).
  List<(String, String)> _rows(AppLocalizations l10n, ChequeBookSetup setup, ChequeBookRequest r) => [
        (l10n.cbrAccountNumber, r.account.display),
        if (r.type != null) (l10n.cbrType, r.type!.stock['stockDescription']!),
        if (r.books != null) (l10n.cbrBooks, r.books!),
        (l10n.cbrLeaves, '${r.leaves}'),
        (l10n.cbrDeliveryLocation, r.address.lines.join('\n')),
      ].where((row) => row.$2.isNotEmpty).toList();

  /// OBDX's confirm screen: the message and the Reference Number, then the
  /// request (confirmationMsg AUTO_AUTH / INITIATED).
  Widget _done(AppLocalizations l10n, ChequeBookSetup setup) {
    final outcome = _outcome!;
    return PaySummaryCard(
      icon: outcome.pendingApproval ? Icons.hourglass_top_rounded : Icons.check_circle_outline_rounded,
      title: outcome.pendingApproval ? l10n.cbrInitiated : l10n.cbrAccepted,
      subtitle: outcome.pendingApproval ? l10n.cbrTitle : l10n.cbrDeliveredMessage,
      rows: [
        if (outcome.reference != null) (l10n.cbrReferenceNumber, outcome.reference!),
        ..._rows(l10n, setup, _request!),
      ],
    );
  }

  Widget _form(AppLocalizations l10n, ChequeBookSetup setup, ChequeAccount account, _Delivery delivery) {
    String required(String label) => l10n.addBillerFieldRequired(label);
    final balance = account.balance;

    final accountField = PayBoxedPicker(
      label: l10n.cbrAccountNumber,
      required: true,
      value: account.display,
      onTap: setup.accounts.length < 2
          ? null
          : () async {
              final picked = await showPayPicker<String>(
                context,
                title: l10n.cbrAccountNumber,
                selected: account.id,
                options: [
                  for (final a in setup.accounts)
                    PayOption(
                      value: a.id,
                      title: a.display,
                      subtitle: a.balance == null
                          ? null
                          : MoneyFormat.format(a.balance!.amount, currencyCode: a.balance!.currency ?? ''),
                    ),
                ],
              );
              if (picked != null && mounted) {
                setState(() => _account = setup.accounts.firstWhere((a) => a.id == picked));
              }
            },
    );
    final typeField = setup.types.isEmpty
        ? null
        : PayBoxedPicker(
            label: l10n.cbrType,
            required: true,
            value: _type?.description,
            placeholder: l10n.cbrSelect,
            error: _showErrors && _type == null ? required(l10n.cbrType) : null,
            onTap: () async {
              final picked = await showPayPicker<String>(
                context,
                title: l10n.cbrType,
                selected: _type?.code,
                options: [for (final t in setup.types) PayOption(value: t.code, title: t.description)],
              );
              if (picked != null && mounted) {
                setState(() => _type = setup.types.firstWhere((t) => t.code == picked));
              }
            },
          );
    final booksField = setup.config.booksEnabled
        ? PayBoxedTextField(
            label: l10n.cbrBooks,
            controller: _books,
            required: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            error: _showErrors && !chequeBooksValid(_books.text) ? l10n.cbrBooksError : null,
            onChanged: (_) => setState(() {}),
          )
        : null;
    final leavesField = PayBoxedPicker(
      label: l10n.cbrLeaves,
      required: true,
      value: _leaves == null ? null : l10n.cbrLeaveOption(_leaves!),
      placeholder: l10n.cbrSelect,
      error: _showErrors && _leaves == null ? required(l10n.cbrLeaves) : null,
      onTap: () async {
        final picked = await showPayPicker<int>(
          context,
          title: l10n.cbrLeaves,
          selected: _leaves,
          options: [for (final n in chequeLeaveOptions) PayOption(value: n, title: l10n.cbrLeaveOption(n))],
        );
        if (picked != null && mounted) setState(() => _leaves = picked);
      },
    );

    return PayCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 640;
          Widget pair(Widget left, Widget? right) => wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 20),
                    Expanded(child: right ?? const SizedBox.shrink()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [left, if (right != null) ...[const SizedBox(height: 12), right]],
                );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.cbrRequestDetails,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
              ),
              const SizedBox(height: 14),
              pair(
                accountField,
                balance == null
                    ? null
                    : _InfoBox(
                        label: l10n.cbrAccountBalance,
                        value: MoneyFormat.format(balance.amount, currencyCode: balance.currency ?? ''),
                        strong: true,
                      ),
              ),
              const SizedBox(height: 14),
              if (typeField != null || booksField != null) ...[
                if (typeField != null) pair(typeField, booksField) else pair(booksField!, null),
                const SizedBox(height: 14),
              ],
              pair(
                leavesField,
                _InfoBox(
                  label: l10n.cbrEstimatedIssue,
                  value: _leaves == null ? '—' : l10n.cbrLeavesPerBook(_leaves!),
                ),
              ),
              const SizedBox(height: 18),
              delivery.section,
              if (_leaves != null) ...[
                const SizedBox(height: 14),
                _SummaryBand(
                  title: l10n.cbrTitle,
                  detail: [
                    if (setup.config.booksEnabled && chequeBooksValid(_books.text))
                      l10n.cbrSummaryBooks(int.tryParse(_books.text.trim()) ?? 0),
                    l10n.cbrSummaryLeaves(_leaves!),
                  ].join('  •  '),
                  trailing: l10n.cbrSummaryDelivery(
                    _delivery == ChequeDelivery.myAddress ? l10n.cbrMyAddress : l10n.cbrBranchNearMe,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ── Delivery Location (OBDX `obdx-address`, address.js) ────────────────

  _Delivery _deliveryFor(AppLocalizations l10n, ChequeBookSetup setup, ChequeAccount account) {
    var address = ChequeAddress.empty;
    String? addressType;
    String? branchCode;
    final parts = <Widget>[];

    Widget addressBox(AsyncValue<Object?> state, VoidCallback retry) => state.hasError
        ? PayErrorRetry(message: _loadMessage(state.error, l10n.cbrAddressFailed), onRetry: retry)
        : _AddressLines(lines: address.lines, loading: state.isLoading && !state.hasValue);

    if (_delivery == ChequeDelivery.myAddress && setup.config.corpDda) {
      // The account's own address, no Address Type (stage1/hooks.js:182-198).
      final state = ref.watch(chequeAccountAddressProvider(account.id));
      address = state.valueOrNull ?? ChequeAddress.empty;
      parts.add(addressBox(state, () => ref.invalidate(chequeAccountAddressProvider(account.id))));
    } else if (_delivery == ChequeDelivery.myAddress) {
      final state = ref.watch(chequePartyAddressesProvider);
      final list = state.valueOrNull ?? const <ChequePartyAddress>[];
      final chosen =
          _addressType == null ? ChequePartyAddress.initial(list) : list.where((a) => a.type == _addressType).firstOrNull;
      address = chosen?.address ?? ChequeAddress.empty;
      addressType = chosen?.type;
      parts
        ..add(PayBoxedPicker(
          label: l10n.cbrAddressType,
          value: chosen?.description,
          placeholder: l10n.cbrSelectAddress,
          loading: state.isLoading && !state.hasValue,
          onTap: list.isEmpty
              ? null
              : () async {
                  final picked = await showPayPicker<String>(
                    context,
                    title: l10n.cbrAddressType,
                    selected: chosen?.type,
                    options: [for (final a in list) PayOption(value: a.type, title: a.description)],
                  );
                  if (picked != null && mounted) setState(() => _addressType = picked);
                },
        ))
        ..add(const SizedBox(height: 10))
        ..add(addressBox(state, () => ref.invalidate(chequePartyAddressesProvider)));
    } else {
      // Branch Near Me: first city, its first branch, that branch's address;
      // the shown branch is the one sent (card §3, user decision).
      final cities = ref.watch(chequeCitiesProvider);
      final cityList = cities.valueOrNull ?? const <String>[];
      final city = cityList.contains(_city) ? _city : cityList.firstOrNull;
      final branches = city == null ? null : ref.watch(chequeBranchesProvider(city));
      final branchList = branches?.valueOrNull ?? const [];
      final branch = branchList.where((b) => b.code == _branch).firstOrNull ?? branchList.firstOrNull;
      final branchAddress = branch == null ? null : ref.watch(chequeBranchAddressProvider(branch.code));
      address = branchAddress?.valueOrNull ?? ChequeAddress.empty;
      branchCode = branch?.code;

      final cityField = PayBoxedPicker(
        label: l10n.cbrCity,
        value: city,
        placeholder: l10n.cbrSelectCity,
        loading: cities.isLoading && !cities.hasValue,
        onTap: cityList.isEmpty
            ? null
            : () async {
                final picked = await showPayPicker<String>(
                  context,
                  title: l10n.cbrCity,
                  selected: city,
                  options: [for (final c in cityList) PayOption(value: c, title: c)],
                );
                if (picked != null && picked != city && mounted) {
                  setState(() {
                    _city = picked;
                    _branch = null;
                  });
                }
              },
      );
      final branchField = PayBoxedPicker(
        label: l10n.cbrBranchNearMe,
        value: branch?.displayName,
        placeholder: l10n.cbrSelectBranch,
        loading: branches != null && branches.isLoading && !branches.hasValue,
        onTap: branchList.isEmpty
            ? null
            : () async {
                final picked = await showPayPicker<String>(
                  context,
                  title: l10n.cbrBranchNearMe,
                  selected: branch?.code,
                  options: [for (final b in branchList) PayOption(value: b.code, title: b.displayName)],
                );
                if (picked != null && mounted) setState(() => _branch = picked);
              },
      );
      // The step that failed, else the one still loading or shown.
      final AsyncValue<Object?> state = cities.hasError
          ? cities
          : (branches?.hasError ?? false)
              ? branches!
              : branchAddress ?? branches ?? cities;
      parts
        ..add(cityField)
        ..add(const SizedBox(height: 10))
        ..add(branchField)
        ..add(const SizedBox(height: 10))
        ..add(addressBox(
          state,
          () {
            ref.invalidate(chequeCitiesProvider);
            if (city != null) ref.invalidate(chequeBranchesProvider(city));
            if (branch != null) ref.invalidate(chequeBranchAddressProvider(branch.code));
          },
        ));
    }

    final section = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.cbrDeliveryLocation,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 16,
            children: [
              for (final d in ChequeDelivery.values)
                SizedBox(
                  width: 170,
                  child: PrefRadio<ChequeDelivery>(
                    value: d,
                    group: _delivery,
                    label: d == ChequeDelivery.myAddress ? l10n.cbrMyAddress : l10n.cbrBranchNearMe,
                    onChanged: (v) => setState(() => _delivery = v),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...parts,
        ],
      ),
    );
    return (address: address, addressType: addressType, branchCode: branchCode, section: section);
  }
}

/// A tinted box with a small label and a value (design: Account Balance,
/// Estimated issue).
class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: brand.withValues(alpha: strong ? 0.10 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: brand.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context))),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: strong ? 17 : 14,
              fontWeight: FontWeight.w700,
              color: strong ? brand : HomeColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// The chosen address as lines (address.html `addressToDisplay`).
class _AddressLines extends StatelessWidget {
  const _AddressLines({required this.lines, this.loading = false});

  final List<String> lines;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomeColors.surfaceSecondary(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: loading
          ? const Align(
              alignment: AlignmentDirectional.centerStart,
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : Text(
              lines.isEmpty ? l10n.cbrNoAddress : lines.join('\n'),
              style: TextStyle(fontSize: 13, height: 1.4, color: HomeColors.textSecondary(context)),
            ),
    );
  }
}

/// The design's summary band under the form.
class _SummaryBand extends StatelessWidget {
  const _SummaryBand({required this.title, required this.detail, required this.trailing});

  final String title;
  final String detail;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final secondary = HomeColors.textSecondary(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: brand.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: brand.withValues(alpha: 0.35)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 16,
        runSpacing: 6,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: brand)),
              const SizedBox(height: 2),
              Text(detail, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: secondary)),
            ],
          ),
          Text(trailing, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: secondary)),
        ],
      ),
    );
  }
}
