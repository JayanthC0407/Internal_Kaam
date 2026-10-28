import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/retail/sweep_in_models.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/retail/sweep_in_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/widgets/preferences_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/obdx_write_runner.dart';

/// Sweep-In — OBDX `flows/sweep-in-instruction`: the account, its linked
/// providers (Delete delinks one) and the accounts that can be linked →
/// Review → the batch result, whose per-account status opens from
/// "Click Here", as in OBDX. Layout from UI designs 2 (193457); lists,
/// rules and labels from OBDX. Evidence: docs/obdx/features/sweep-in.md.
class SweepInScreen extends ConsumerStatefulWidget {
  const SweepInScreen({super.key, required this.onExit, this.onHome});

  /// Back and Cancel.
  final VoidCallback onExit;

  /// "Home" on the result; [onExit] when null.
  final VoidCallback? onHome;

  @override
  ConsumerState<SweepInScreen> createState() => _SweepInScreenState();
}

class _SweepInScreenState extends ConsumerState<SweepInScreen> {
  /// 0 form, 1 review, 2 link result, 3 delink result.
  int _step = 0;
  bool _busy = false;

  String? _accountId;
  SweepType _type = SweepType.casa;
  final _ticked = <String>{};

  /// What Submit took to Review: the ticked providers (New) and the linked ones.
  List<SweepAccount> _newProviders = const [];
  List<SweepAccount> _existing = const [];

  SweepLinkOutcome? _linkOutcome;
  SweepDelinkOutcome? _delinkOutcome;

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  String _loadMessage(Object? error, String fallback) =>
      error is SweepInLoadError && error.message != null ? error.message! : fallback;

  String _typeName(AppLocalizations l10n) => _type == SweepType.casa ? l10n.swpAccounts : l10n.swpDeposits;

  /// "Manage Sweep-In": the flow again from the start.
  void _restart() {
    ref.invalidate(sweepListsProvider);
    setState(() {
      _step = 0;
      _accountId = null;
      _type = SweepType.casa;
      _ticked.clear();
      _linkOutcome = null;
      _delinkOutcome = null;
    });
  }

  // ── Submit, Confirm, Delete ───────────────────────────────────────────

  void _submit(SweepLists lists) {
    final l10n = AppLocalizations.of(context);
    // saveInstructions (stage1/hooks.js:597-627).
    final picked = [for (final p in lists.providers) if (_ticked.contains(p.id)) p];
    if (picked.isEmpty) return _snack(l10n.swpSelectAtLeastOne);
    setState(() {
      _newProviders = picked;
      _existing = [for (final l in lists.linked) l.account];
      _step = 1;
    });
  }

  Future<void> _confirm(String accountId) async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(sweepInRepositoryProvider);
    setState(() => _busy = true);
    final result = await runWithOtp<SweepLinkOutcome>(
      context,
      (challenge, otp) => repository.link(accountId, _newProviders, challenge: challenge, otp: otp),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (obdxWriteDone(result)) {
      HapticFeedback.mediumImpact();
      ref.invalidate(sweepListsProvider);
      setState(() {
        _linkOutcome = (result as Success<SweepLinkOutcome>).data;
        _step = 2;
      });
    } else if (result is! Success<SweepLinkOutcome>) {
      _snack(result.resolveUserMessage(l10n: l10n, fallback: l10n.swpLinkFailed));
    }
  }

  Future<void> _delink(String accountId, SweepLinked linked) async {
    final l10n = AppLocalizations.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.swpTitle),
        content: Text(l10n.swpDelinkConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.of(dialog).pop(true), child: Text(l10n.addBillerConfirm)),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final repository = ref.read(sweepInRepositoryProvider);
    setState(() => _busy = true);
    final result = await runWithOtp<SweepDelinkOutcome>(
      context,
      (challenge, otp) => repository.delink(accountId, linked.instructionNumber, challenge: challenge, otp: otp),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (obdxWriteDone(result)) {
      HapticFeedback.mediumImpact();
      ref.invalidate(sweepListsProvider);
      setState(() {
        _delinkOutcome = (result as Success<SweepDelinkOutcome>).data;
        _step = 3;
      });
    } else if (result is! Success<SweepDelinkOutcome>) {
      _snack(result.resolveUserMessage(l10n: l10n, fallback: l10n.swpDelinkFailed));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(sweepPickerAccountsProvider);
    final accounts = async.valueOrNull;

    if (accounts == null || accounts.isEmpty) {
      return PayFlowScaffold(
        title: l10n.swpTitle,
        step: 0,
        onExit: widget.onExit,
        child: async.hasError
            ? PayErrorRetry(
                message: _loadMessage(async.error, l10n.swpLoadFailed),
                onRetry: () => ref.invalidate(sweepPickerAccountsProvider),
              )
            : accounts != null
                ? PayCard(child: PayMuted(l10n.swpNoAccounts))
                : const PayCard(
                    child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                  ),
      );
    }

    final account = accounts.where((a) => a.id == _accountId).firstOrNull ?? SweepAccount.initial(accounts)!;
    final listsAsync = _step == 0 ? ref.watch(sweepListsProvider((account.id, _type))) : null;
    final lists = listsAsync?.valueOrNull;

    return PayFlowScaffold(
      title: l10n.swpTitle,
      subtitle: _step == 1 ? _reviewText(l10n) : null,
      step: _step.clamp(0, 2),
      onBackStep: _busy || _step != 1 ? null : () => setState(() => _step = 0),
      onExit: _busy ? null : widget.onExit,
      action: switch (_step) {
        0 => Row(
            children: [
              Expanded(
                child: PayPrimaryButton(
                  label: l10n.addBillerSubmit,
                  onPressed: lists == null || _busy ? null : () => _submit(lists),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: PaySecondaryButton(label: l10n.cancel, onPressed: _busy ? null : widget.onExit)),
            ],
          ),
        1 => PayPrimaryButton(
            label: l10n.addBillerConfirm,
            loading: _busy,
            onPressed: _busy ? null : () => _confirm(account.id),
          ),
        _ => null,
      },
      child: switch (_step) {
        0 => _form(l10n, accounts, account, listsAsync!),
        1 => _review(l10n, account),
        2 => _linkResult(l10n),
        _ => _delinkResult(l10n),
      },
    );
  }

  String _reviewText(AppLocalizations l10n) =>
      _type == SweepType.casa ? l10n.swpReviewAccounts : l10n.swpReviewDeposits;

  Widget _form(
    AppLocalizations l10n,
    List<SweepAccount> accounts,
    SweepAccount account,
    AsyncValue<SweepLists> listsAsync,
  ) {
    final showBalance = _type == SweepType.casa;
    final accountField = PayBoxedPicker(
      label: l10n.swpAccountNumber,
      required: true,
      value: account.display,
      onTap: accounts.length < 2 || _busy
          ? null
          : () async {
              final picked = await showPayPicker<String>(
                context,
                title: l10n.swpAccountNumber,
                selected: account.id,
                options: [
                  for (final a in accounts)
                    PayOption(value: a.id, title: a.display, subtitle: a.balance == null ? null : _money(a.balance!)),
                ],
              );
              if (picked != null && picked != account.id && mounted) {
                setState(() {
                  _accountId = picked;
                  _ticked.clear();
                });
              }
            },
    );

    final Widget lists = listsAsync.when(
      loading: () => const PayCard(
        child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      ),
      error: (e, _) => PayErrorRetry(
        message: _loadMessage(e, l10n.swpLoadFailed),
        onRetry: () => ref.invalidate(sweepListsProvider((account.id, _type))),
      ),
      data: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final notice in data.notices) ...[
            PayInfoBanner(
              message: switch (notice) {
                SweepNotice.noCasaAccounts => l10n.swpNoCasaAvailable,
                SweepNotice.noDeposits => l10n.swpNoTdAvailable,
                SweepNotice.allLinked => l10n.swpAllLinked,
              },
            ),
            const SizedBox(height: 12),
          ],
          _Section(
            title: l10n.swpLinkedHeading(_typeName(l10n)),
            children: data.linked.isEmpty
                ? [PayMuted(_type == SweepType.casa ? l10n.swpNoLinkedAccounts : l10n.swpNoLinkedDeposits)]
                : [
                    for (final linked in data.linked)
                      _AccountRow(
                        account: linked.account,
                        showBalance: showBalance,
                        trailing: IconButton(
                          tooltip: l10n.swpDelete,
                          icon: Icon(Icons.delete_outline_rounded, color: HomeColors.error(context)),
                          onPressed: _busy ? null : () => _delink(account.id, linked),
                        ),
                      ),
                  ],
          ),
          // OBDX shows the provider list only when it has accounts.
          if (data.providers.isNotEmpty) ...[
            const SizedBox(height: 14),
            _Section(
              title: l10n.swpLinkHeading(_typeName(l10n)),
              header: _HeaderRow(
                select: l10n.swpSelectColumn,
                account: l10n.swpAccountNumber,
                holder: l10n.swpPrimaryHolderName,
                balance: showBalance ? l10n.swpBalance : null,
              ),
              children: [
                for (final p in data.providers)
                  _AccountRow(
                    account: p,
                    showBalance: showBalance,
                    leading: Checkbox(
                      value: _ticked.contains(p.id),
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => v == true ? _ticked.add(p.id) : _ticked.remove(p.id)),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PayCard(
          child: LayoutBuilder(
            builder: (context, c) {
              final balance = account.balance == null
                  ? null
                  : _BalanceBox(label: l10n.swpAccountBalance, value: _money(account.balance!));
              return c.maxWidth >= 640
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: accountField),
                        const SizedBox(width: 20),
                        Expanded(child: balance ?? const SizedBox.shrink()),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [accountField, if (balance != null) ...[const SizedBox(height: 12), balance]],
                    );
            },
          ),
        ),
        const SizedBox(height: 14),
        _Section(
          title: l10n.swpLinkedAccountType,
          children: [
            Wrap(
              spacing: 16,
              children: [
                for (final t in SweepType.values)
                  SizedBox(
                    width: 200,
                    child: PrefRadio<SweepType>(
                      value: t,
                      group: _type,
                      label: t == SweepType.casa ? l10n.swpCasa : l10n.swpTd,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() {
                                _type = v;
                                _ticked.clear();
                              }),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        lists,
      ],
    );
  }

  /// Review: Account Number, Linked Account Type, then the new accounts
  /// (New) and the linked ones (review.html).
  Widget _review(AppLocalizations l10n, SweepAccount account) {
    final showBalance = _type == SweepType.casa;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaySummaryCard(
          icon: Icons.fact_check_outlined,
          title: l10n.addBillerReview,
          subtitle: _reviewText(l10n),
          rows: [
            (l10n.swpAccountNumber, account.display),
            (l10n.swpLinkedAccountType, _type == SweepType.casa ? l10n.swpCasa : l10n.swpTd),
          ],
        ),
        const SizedBox(height: 14),
        _Section(
          title: l10n.swpLinkedHeading(_typeName(l10n)),
          children: [
            for (final p in _newProviders) _AccountRow(account: p, showBalance: showBalance, badge: l10n.swpNew),
            for (final p in _existing) _AccountRow(account: p, showBalance: showBalance),
          ],
        ),
      ],
    );
  }

  /// OBDX's confirm screen for the batch: the message, the status link,
  /// then "What would you like to do next?" (confirm-screen/sweep-in.html).
  Widget _linkResult(AppLocalizations l10n) {
    final outcome = _linkOutcome!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaySummaryCard(
          icon: outcome.anyFailed
              ? Icons.error_outline_rounded
              : outcome.pendingApproval
                  ? Icons.hourglass_top_rounded
                  : Icons.check_circle_outline_rounded,
          title: outcome.pendingApproval
              ? l10n.swpInitiated
              : outcome.anyFailed
                  ? l10n.swpPartFailed
                  : l10n.swpSuccess,
          subtitle: l10n.swpTitle,
          note: l10n.swpStatusLinkText,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(onPressed: () => _showStatus(outcome), child: Text(l10n.swpClickHere)),
        ),
        _NextActions(onHome: widget.onHome ?? widget.onExit, onManage: _restart),
      ],
    );
  }

  /// Delink's confirm screen (confirmationMsg AUTO_AUTH / INITIATED).
  Widget _delinkResult(AppLocalizations l10n) {
    final outcome = _delinkOutcome!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaySummaryCard(
          icon: outcome.pendingApproval ? Icons.hourglass_top_rounded : Icons.check_circle_outline_rounded,
          title: outcome.pendingApproval ? l10n.swpInitiated : l10n.swpAccepted,
          subtitle: l10n.swpTitle,
          rows: [if (outcome.reference != null) (l10n.swpReferenceNumber, outcome.reference!)],
          note: l10n.swpTitle,
        ),
        _NextActions(onHome: widget.onHome ?? widget.onExit, onManage: _restart),
      ],
    );
  }

  /// "Click Here": Multiple Sweep-In Instruction Status
  /// (multiple-sweep-in-instruction-status.html).
  Future<void> _showStatus(SweepLinkOutcome outcome) {
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final showReason = outcome.rows.any((r) => r.failureReason != null);
    return showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(wide ? l10n.swpStatusHeader : l10n.swpStatus),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in outcome.rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PaySummaryCard(
                      icon: r.completed ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                      title: r.account.display,
                      subtitle: r.account.partyName ?? '',
                      rows: [
                        (l10n.swpReferenceNumber, r.reference),
                        (l10n.swpStatus, r.completed ? l10n.swpCompleted : l10n.swpFailed),
                        if (showReason && r.failureReason != null) (l10n.swpFailureReason, r.failureReason!),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(dialog).pop(), child: Text(l10n.payBillOk))],
      ),
    );
  }
}

String _money(MoneyAmount m) => MoneyFormat.format(m.amount, currencyCode: m.currency ?? '');

/// A titled, bordered block (design: Linked Account Type, Link Accounts).
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.header});

  final String title;
  final Widget? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PayCard(
      padding: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
          ),
          const SizedBox(height: 10),
          if (header != null) header!,
          ...children,
        ],
      ),
    );
  }
}

/// The provider table's header on web (design 193457).
class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.select, required this.account, required this.holder, this.balance});

  final String select;
  final String account;
  final String holder;
  final String? balance;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 640) return const SizedBox.shrink();
        final style = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HomeColors.textSecondary(context));
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          color: HomeColors.surfaceSecondary(context),
          child: Row(
            children: [
              SizedBox(width: 56, child: Text(select, style: style)),
              Expanded(flex: 3, child: Text(account, style: style)),
              Expanded(flex: 3, child: Text(holder, style: style)),
              Expanded(flex: 2, child: Text(balance ?? '', style: style)),
            ],
          ),
        );
      },
    );
  }
}

/// One account: a table row on web, a compact card row on phone.
class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.showBalance, this.leading, this.trailing, this.badge});

  final SweepAccount account;
  final bool showBalance;
  final Widget? leading;
  final Widget? trailing;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final primary = HomeColors.textPrimary(context);
    final secondary = HomeColors.textSecondary(context);
    final balance = showBalance && account.balance != null ? _money(account.balance!) : null;
    final badgeChip = badge == null
        ? null
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: HomeColors.success(context).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge!,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: HomeColors.success(context)),
            ),
          );
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: HomeColors.divider(context)))),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: LayoutBuilder(
        builder: (context, c) {
          final number = Text(
            account.display,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: primary),
          );
          if (c.maxWidth >= 640) {
            return Row(
              children: [
                if (leading != null) SizedBox(width: 56, child: Align(alignment: Alignment.centerLeft, child: leading)),
                Expanded(
                  flex: 3,
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [number, if (badgeChip != null) badgeChip],
                  ),
                ),
                Expanded(flex: 3, child: Text(account.partyName ?? '', style: TextStyle(fontSize: 13, color: primary))),
                Expanded(flex: 2, child: Text(balance ?? '', style: TextStyle(fontSize: 13, color: primary))),
                if (trailing != null) trailing!,
              ],
            );
          }
          return Row(
            children: [
              if (leading != null) leading!,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [number, if (badgeChip != null) badgeChip],
                    ),
                    if (account.partyName != null)
                      Text(account.partyName!, style: TextStyle(fontSize: 12.5, color: secondary)),
                    if (balance != null) Text(balance, style: TextStyle(fontSize: 12.5, color: secondary)),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          );
        },
      ),
    );
  }
}

/// The design's Account Balance box.
class _BalanceBox extends StatelessWidget {
  const _BalanceBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: brand.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: brand.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context))),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: brand)),
        ],
      ),
    );
  }
}

/// "What would you like to do next?": Home and Manage Sweep-In
/// (confirm-screen/sweep-in.html).
class _NextActions extends StatelessWidget {
  const _NextActions({required this.onHome, required this.onManage});

  final VoidCallback onHome;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.swpNextAction,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 200,
                child: PaySecondaryButton(label: l10n.home, icon: Icons.home_outlined, onPressed: onHome),
              ),
              SizedBox(
                width: 200,
                child: PaySecondaryButton(label: l10n.swpManageSweepIn, icon: Icons.sync_alt_rounded, onPressed: onManage),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
