import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/own_account_transfer.dart';
import 'package:ubci_bank/src/core/models/common/payment/network_transfer.dart';
import 'package:ubci_bank/src/core/models/retail/casa_account.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/common/network_transfer_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// "Multiple Transfers" — several saved payees paid from one account.
///
/// Sent the way OBDX's own web does it (`flows/multiple-transfers`): every
/// row is an ordinary `pay/network` transfer, and all of them travel in one
/// batch request — checked together before the review, then submitted
/// together with a single OTP. The done step lists each row's outcome.
class MultipleTransfersScreen extends ConsumerStatefulWidget {
  const MultipleTransfersScreen({super.key, this.embedded = false, this.onBack});

  final bool embedded;
  final VoidCallback? onBack;

  static const maxRows = 10;

  @override
  ConsumerState<MultipleTransfersScreen> createState() =>
      _MultipleTransfersScreenState();
}

class _Row {
  TransferPayee? payee;
  TransferNetwork? network;
  final amount = TextEditingController();
  String? error;

  /// After review: the bank's reference to submit with.
  NetworkTransferRequest? request;

  /// After submit: the reference, or why it failed.
  String? reference;
  String? failure;

  /// Accepted, but waiting for an approver.
  bool pendingApproval = false;

  void dispose() => amount.dispose();
}

class _MultipleTransfersScreenState
    extends ConsumerState<MultipleTransfersScreen> {
  int _step = 0;
  CasaAccount? _debit;
  String? _debitError;
  final List<_Row> _rows = [_Row(), _Row()];
  bool _busy = false;

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  List<TransferNetwork> _networksFor(TransferPayee? payee, List<TransferNetwork> all) {
    final kind = payee?.kind;
    if (kind == null) return const [];
    final list = all
        .where((n) =>
            n.paymentType?.toUpperCase() == kind.paymentType &&
            n.code.toUpperCase() != kGpiNetworkCode)
        .toList();
    if (list.isEmpty && kind == TransferKind.internal) {
      return const [TransferNetwork(code: 'INTERNAL', paymentType: 'INTERNAL')];
    }
    return list;
  }

  bool get _formValid {
    var ok = true;
    setState(() {
      _debitError = _debit == null ? 'Choose the account to pay from.' : null;
      if (_debit == null) ok = false;
      for (final r in _rows) {
        final amount = payParseAmount(r.amount.text);
        r.error = r.payee == null
            ? 'Choose a payee.'
            : r.network == null
                ? 'Choose how to send it.'
                : amount == null || amount <= 0
                    ? 'Enter an amount.'
                    : null;
        if (r.error != null) ok = false;
      }
    });
    return ok;
  }

  Future<void> _review() async {
    if (!_formValid) {
      HapticFeedback.mediumImpact();
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final repository = ref.read(networkTransferRepositoryProvider);
    final now = DateTime.now();
    final requests = [
      for (final r in _rows)
        NetworkTransferRequest(
          kind: r.payee!.kind!,
          network: r.network!.code,
          debitAccount: _debit!,
          amount: payParseAmount(r.amount.text)!,
          currency: _debit!.currencyCode,
          paymentDate: DateTime(now.year, now.month, now.day),
          payee: r.payee,
        ),
    ];
    // One batch checks every row; each accepted row gets the reference to
    // submit it with, each refused row the bank's reason.
    final result = await repository.validateBatch(requests);
    if (!mounted) return;
    if (result is! Success<List<BatchRowResult<TransferValidationResult>>> ||
        result.data == null) {
      setState(() => _busy = false);
      _showError(result.resolveUserMessage(
        l10n: l10n,
        fallback: "The bank couldn't check these transfers. Please try again.",
      ));
      return;
    }
    final answers = result.data!;
    setState(() {
      _busy = false;
      for (var i = 0; i < _rows.length; i++) {
        final answer = answers[i];
        _rows[i].request = answer.ok
            ? requests[i].withReference(answer.value!.systemReferenceId)
            : null;
        _rows[i].error = answer.error;
      }
      if (answers.every((a) => a.ok)) _step = 1;
    });
    if (answers.any((a) => !a.ok)) HapticFeedback.mediumImpact();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Submits every transfer in one batch. The bank asks for one OTP for
  /// the whole batch; cancelling it sends nothing.
  Future<void> _submitAll() async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(networkTransferRepositoryProvider);
    final requests = [for (final r in _rows) r.request!];
    setState(() => _busy = true);
    var result = await repository.submitBatch(requests);
    while (mounted &&
        result is Success<BatchSubmitOutcome> &&
        result.data?.challenge != null) {
      final outcome = result.data!;
      if (!mounted) return;
      // Nothing is loading while they type the code.
      setState(() => _busy = false);
      final otp = await showPayOtpPrompt(
        context,
        title: 'Verify ${_rows.length} transfers',
        error: outcome.invalidOtp ? 'That code is not right. Please try again.' : null,
        attemptsLeft: outcome.challenge!.attemptsLeft,
      );
      if (!mounted) return;
      // Cancelled: nothing was sent, and the review stays so they can retry.
      if (otp == null) return;
      setState(() => _busy = true);
      result = await repository.submitBatch(
        requests,
        challenge: outcome.challenge,
        otp: otp,
      );
    }
    if (!mounted) return;
    if (result is! Success<BatchSubmitOutcome> || result.data == null) {
      setState(() => _busy = false);
      _showError(result.resolveUserMessage(
        l10n: l10n,
        fallback: "The bank couldn't complete these transfers. Please try again.",
      ));
      return;
    }
    final rows = result.data!.rows;
    setState(() {
      for (var i = 0; i < _rows.length; i++) {
        final answer = rows[i];
        _rows[i]
          ..reference = answer.value?.referenceNumber
          ..pendingApproval = answer.pendingApproval
          ..failure = answer.error;
      }
      _busy = false;
      _step = 2;
    });
  }

  double get _total => _rows.fold(0, (s, r) => s + (payParseAmount(r.amount.text) ?? 0));

  void _exit() {
    if (widget.embedded && widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop(true);
    }
  }

  void _startAgain() {
    setState(() {
      for (final r in _rows) {
        r.dispose();
      }
      _rows
        ..clear()
        ..addAll([_Row(), _Row()]);
      _step = 0;
    });
  }

  static String _accountLine(CasaAccount a) => '${payAccountName(a)} ${payMask(a.displayNumber)}';

  static String _payeeDetail(TransferPayee p) => [
        p.kind?.label,
        if ((p.accountNumber ?? '').isNotEmpty) payMask(p.accountNumber!),
      ].whereType<String>().join(' · ');

  @override
  Widget build(BuildContext context) {
    final currency = _debit?.currencyCode ?? '';
    final count = _rows.length;
    final Widget child = switch (_step) {
      0 => _form(context),
      1 => _reviewStep(currency),
      _ => _doneStep(currency),
    };
    return PayFlowScaffold(
      title: 'Multiple Transfers',
      subtitle: switch (_step) {
        0 => 'Pay up to ${MultipleTransfersScreen.maxRows} saved payees from one account',
        1 => 'Review and confirm',
        _ => null,
      },
      step: _step,
      onBackStep: () => setState(() => _step = 0),
      onExit: widget.embedded ? widget.onBack : null,
      summary: PaySummaryCard(
        icon: Icons.dynamic_feed_rounded,
        title: 'Summary',
        subtitle: 'Sent together, verified once',
        rows: [
          if (_debit != null) ('From', _accountLine(_debit!)),
          ('Payments', '$count'),
        ],
        total: _total > 0 ? ('Total', payAmount(_total, currency)) : null,
      ),
      action: switch (_step) {
        0 => PayPrimaryButton(label: 'Continue', loading: _busy, onPressed: _review),
        1 => PayPrimaryButton(
            label: 'Confirm $count transfers',
            icon: Icons.lock_outline_rounded,
            loading: _busy,
            onPressed: _submitAll,
          ),
        _ => null,
      },
      actionCaption: switch (_step) {
        0 when _total > 0 => '$count payments · Total ${payAmount(_total, currency)}',
        1 => 'Total ${payAmount(_total, currency)} plus any charges',
        _ => null,
      },
      child: child,
    );
  }

  Widget _form(BuildContext context) {
    final accounts = ref.watch(transferDebitAccountsProvider(null));
    final payees = ref.watch(transferPayeesProvider);
    final networks = ref.watch(transferNetworksProvider).valueOrNull ?? const <TransferNetwork>[];
    final payeeList = (payees.valueOrNull ?? const <TransferPayee>[])
        .where((p) => p.kind != null)
        .toList();
    final balance = _debit?.availableBalance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaySection(
          title: 'From',
          icon: Icons.account_balance_wallet_outlined,
          child: accounts.hasError
              ? PayErrorRetry(
                  message: "We couldn't load your accounts.",
                  onRetry: () => ref.invalidate(transferDebitAccountsProvider(null)),
                )
              : PayPickerField(
                  placeholder: 'Choose an account',
                  title: _debit == null ? null : payAccountName(_debit!),
                  subtitle: _debit == null
                      ? null
                      : '${payMask(_debit!.displayNumber)} · ${_debit!.currencyCode}',
                  trailingText: balance == null ? null : payAmount(balance.amount, _debit!.currencyCode),
                  loading: accounts.isLoading,
                  error: _debitError,
                  onTap: accounts.valueOrNull == null
                      ? null
                      : () async {
                          final picked = await showPayPicker<CasaAccount>(
                            context,
                            title: 'Pay from',
                            selected: _debit,
                            options: [
                              for (final a in accounts.value!)
                                PayOption(
                                  value: a,
                                  title: payAccountName(a),
                                  subtitle: '${payMask(a.displayNumber)} · ${a.currencyCode}',
                                  trailing: a.availableBalance == null
                                      ? null
                                      : payAmount(a.availableBalance!.amount, a.currencyCode),
                                  icon: Icons.account_balance_wallet_outlined,
                                ),
                            ],
                          );
                          if (picked != null) {
                            setState(() {
                              _debit = picked;
                              _debitError = null;
                            });
                          }
                        },
                ),
        ),
        const SizedBox(height: 16),
        PaySection(
          title: 'Payments',
          icon: Icons.dynamic_feed_rounded,
          trailing: Text(
            '${_rows.length} of ${MultipleTransfersScreen.maxRows}',
            style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final inline = constraints.maxWidth >= 640;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < _rows.length; i++) ...[
                    if (i > 0) SizedBox(height: inline ? 14 : 12),
                    inline
                        ? _rowLine(context, i, payeeList, networks, payees.isLoading)
                        : _rowCard(context, i, payeeList, networks, payees.isLoading),
                  ],
                  if (_rows.length < MultipleTransfersScreen.maxRows) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _rows.add(_Row())),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: const Text('Add another payment'),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _payeeField(
    BuildContext context,
    _Row row,
    List<TransferPayee> payees,
    List<TransferNetwork> networks,
    bool loading,
  ) =>
      PayPickerField(
        placeholder: 'Choose a payee',
        title: row.payee?.title,
        subtitle: row.payee == null ? null : _payeeDetail(row.payee!),
        icon: Icons.person_search_outlined,
        leading: row.payee == null ? null : PayAvatar(name: row.payee!.title, size: 38),
        loading: loading,
        onTap: () async {
          final picked = await showPayPicker<TransferPayee>(
            context,
            title: 'Choose a payee',
            selected: row.payee,
            empty: 'No payees yet. Add one under Payees.',
            options: [
              for (final p in payees)
                PayOption(value: p, title: p.title, subtitle: _payeeDetail(p), avatar: p.title),
            ],
          );
          if (picked != null) {
            setState(() {
              row.payee = picked;
              final opts = _networksFor(picked, networks);
              row.network = opts.isEmpty ? null : opts.first;
              row.error = null;
            });
          }
        },
      );

  Widget _networkField(BuildContext context, _Row row, List<TransferNetwork> options) =>
      PayPickerField(
        placeholder: 'Send by',
        title: row.network?.label,
        icon: Icons.hub_outlined,
        onTap: () async {
          final picked = await showPayPicker<TransferNetwork>(
            context,
            title: 'Send by',
            selected: row.network,
            options: [
              for (final n in options) PayOption(value: n, title: n.label, icon: Icons.hub_outlined),
            ],
          );
          if (picked != null) setState(() => row.network = picked);
        },
      );

  Widget _amountField(_Row row) => PayAmountField(
        controller: row.amount,
        currency: _debit?.currencyCode ?? '',
        compact: true,
        onChanged: (_) => setState(() => row.error = null),
      );

  Widget _removeButton(int i) => IconButton(
        tooltip: 'Remove',
        onPressed: _rows.length > 1 ? () => setState(() => _rows.removeAt(i).dispose()) : null,
        icon: const Icon(Icons.delete_outline_rounded, size: 20),
      );

  /// Wide layouts: one payment per line.
  Widget _rowLine(
    BuildContext context,
    int i,
    List<TransferPayee> payees,
    List<TransferNetwork> networks,
    bool loading,
  ) {
    final row = _rows[i];
    final options = _networksFor(row.payee, networks);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 16), child: _IndexBadge(i + 1)),
            const SizedBox(width: 12),
            Expanded(flex: 5, child: _payeeField(context, row, payees, networks, loading)),
            if (options.length > 1) ...[
              const SizedBox(width: 10),
              Expanded(flex: 3, child: _networkField(context, row, options)),
            ],
            const SizedBox(width: 10),
            SizedBox(width: 200, child: _amountField(row)),
            Padding(padding: const EdgeInsets.only(top: 8), child: _removeButton(i)),
          ],
        ),
        if (row.error != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 40),
            child: PayFieldError(row.error),
          ),
      ],
    );
  }

  /// Narrow layouts: one card per payment.
  Widget _rowCard(
    BuildContext context,
    int i,
    List<TransferPayee> payees,
    List<TransferNetwork> networks,
    bool loading,
  ) {
    final row = _rows[i];
    final options = _networksFor(row.payee, networks);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 12),
      decoration: BoxDecoration(
        color: HomeColors.bg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: row.error != null ? HomeColors.error(context) : HomeColors.divider(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IndexBadge(i + 1),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Payment ${i + 1}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: HomeColors.textPrimary(context),
                  ),
                ),
              ),
              _removeButton(i),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                _payeeField(context, row, payees, networks, loading),
                if (options.length > 1) ...[
                  const SizedBox(height: 8),
                  _networkField(context, row, options),
                ],
                const SizedBox(height: 8),
                _amountField(row),
                PayFieldError(row.error),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewStep(String currency) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaySection(
            child: PayReceiptHero(
              amount: payAmount(_total, currency),
              toName: '${_rows.length} payees',
              toDetail: 'From ${_accountLine(_debit!)}',
              avatarIcon: Icons.groups_rounded,
            ),
          ),
          const SizedBox(height: 16),
          PaySection(
            title: 'Payments',
            child: Column(
              children: [
                for (final (i, row) in _rows.indexed)
                  _PaymentLine(
                    name: row.payee!.title,
                    detail: [
                      _payeeDetail(row.payee!),
                      if (row.network != null && row.payee!.kind != TransferKind.internal)
                        row.network!.label,
                    ].join(' · '),
                    amount: payAmount(payParseAmount(row.amount.text), currency),
                    last: i == _rows.length - 1,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const PayNote(
            'All transfers are sent together. If the bank asks for a code, '
            "you'll enter it once for all of them.",
            icon: Icons.verified_user_outlined,
          ),
        ],
      );

  Widget _doneStep(String currency) {
    final sent = _rows.where((r) => r.failure == null).length;
    final approvals = _rows.any((r) => r.failure == null && r.pendingApproval);
    return PayResultView(
      title: sent == _rows.length
          ? 'All transfers submitted'
          : '$sent of ${_rows.length} transfers submitted',
      message: sent < _rows.length
          ? 'The ones that were not sent say why below.'
          : approvals
              ? 'They will go once they are approved.'
              : 'Every transfer is on its way.',
      amount: sent == _rows.length ? payAmount(_total, currency) : null,
      warning: sent < _rows.length,
      rows: [
        for (final (i, row) in _rows.indexed)
          (
            '${i + 1}. ${row.payee!.title} · ${payAmount(payParseAmount(row.amount.text), currency)}',
            row.failure ?? _outcomeLabel(row),
          ),
      ],
      onDone: _exit,
      onAnother: _startAgain,
      anotherLabel: 'Make more transfers',
    );
  }

  static String _outcomeLabel(_Row row) {
    final parts = [
      if (row.reference?.isNotEmpty == true) row.reference!,
      if (row.pendingApproval) 'Sent for approval',
    ];
    return parts.isEmpty ? 'Submitted' : parts.join(' · ');
  }
}

class _IndexBadge extends StatelessWidget {
  const _IndexBadge(this.number);

  final int number;

  @override
  Widget build(BuildContext context) => Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: HomeColors.brand(context).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Text(
          '$number',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: HomeColors.brand(context),
          ),
        ),
      );
}

/// A payee and amount on the review.
class _PaymentLine extends StatelessWidget {
  const _PaymentLine({
    required this.name,
    required this.detail,
    required this.amount,
    required this.last,
  });

  final String name;
  final String detail;
  final String amount;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(bottom: BorderSide(color: HomeColors.divider(context).withValues(alpha: 0.7))),
        ),
        child: Row(
          children: [
            PayAvatar(name: name, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: HomeColors.textPrimary(context),
                    ),
                  ),
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context)),
                    ),
                ],
              ),
            ),
            Text(
              amount,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: HomeColors.textPrimary(context),
              ),
            ),
          ],
        ),
      );
}
