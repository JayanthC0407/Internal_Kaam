import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/payee/payee_models.dart';
import 'package:ubci_bank/src/core/models/common/payment/network_transfer.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/common/network_transfer_providers.dart';
import 'package:ubci_bank/src/view/providers/common/payee_providers.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/common/payments/network_transfer_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// The three "Add Payee" entry points offered from Manage Payee.
enum AddPayeeFlow { bankAccount, demandDraft, peerToPeer }

extension AddPayeeFlowX on AddPayeeFlow {
  String get label {
    switch (this) {
      case AddPayeeFlow.bankAccount:
        return 'Add Bank Account Payee';
      case AddPayeeFlow.demandDraft:
        return 'Add Demand Draft Payee';
      case AddPayeeFlow.peerToPeer:
        return 'Add Peer To Peer Payee';
    }
  }

  IconData get icon {
    switch (this) {
      case AddPayeeFlow.bankAccount:
        return Icons.account_balance_outlined;
      case AddPayeeFlow.demandDraft:
        return Icons.description_outlined;
      case AddPayeeFlow.peerToPeer:
        return Icons.alternate_email_rounded;
    }
  }

  String get routeName {
    switch (this) {
      case AddPayeeFlow.bankAccount:
        return RoutesConst.addBankAccountPayeeScreen;
      case AddPayeeFlow.demandDraft:
        return RoutesConst.addDemandDraftPayeeScreen;
      case AddPayeeFlow.peerToPeer:
        return RoutesConst.addPeerToPeerPayeeScreen;
    }
  }
}

/// The kinds of payee, one tab each — as OBDX's Manage Payees: account
/// payees from `payeesv3`, demand-draft and peer-to-peer payees from
/// `payeeGroup` (see [groupPayeesProvider]).
enum _PayeeTab { accounts, drafts, peerToPeer }

/// One row of the list, whatever the kind of payee.
class _Row {
  const _Row({
    required this.title,
    required this.kind,
    required this.detail,
    this.subtitle,
    this.payee,
    this.deleteTarget,
    this.groupName,
    this.groupSize = 1,
  });

  final String title;

  /// The name on the account, when the nickname differs.
  final String? subtitle;

  /// "Within the bank", "Domestic draft", "Email"…
  final String kind;

  /// Account, where a draft is payable, or the email / number paid.
  final String detail;

  /// Set for payees a transfer can pay.
  final TransferPayee? payee;

  /// How to delete it; null when the list lacks what the path needs.
  final PayeeDeleteTarget? deleteTarget;

  /// The payee group it belongs to, and how many payees that group holds.
  /// OBDX keeps payees in groups ("delete with group"); a group of more
  /// than one gets a warning before delete.
  final String? groupName;
  final int groupSize;

  /// Identifies the row while it is being deleted.
  String get key => deleteTarget == null ? title : '${deleteTarget!.payeeType}/${deleteTarget!.payeeId}';

  bool matches(String q) => [title, subtitle, kind, detail]
      .whereType<String>()
      .any((v) => v.toLowerCase().contains(q));
}

/// Manage Payees — every saved payee, by kind, with search, a quick "Pay"
/// for account payees, and "Add payee".
class PayeesScreen extends ConsumerStatefulWidget {
  const PayeesScreen({
    super.key,
    this.embedded = false,
    this.onAddPayee,
    this.onBack,
    this.onPayTap,
  });

  final bool embedded;
  final ValueChanged<AddPayeeFlow>? onAddPayee;
  final VoidCallback? onBack;

  /// Starts a transfer to an account payee inside the dashboard.
  final ValueChanged<TransferPayee>? onPayTap;

  @override
  ConsumerState<PayeesScreen> createState() => _PayeesScreenState();
}

class _PayeesScreenState extends ConsumerState<PayeesScreen> {
  _PayeeTab _tab = _PayeeTab.accounts;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(payeesProvider.notifier).ensureLoaded();
    });
  }

  Future<void> _openAddPayee(AddPayeeFlow flow) async {
    if (widget.embedded && widget.onAddPayee != null) {
      widget.onAddPayee!(flow);
      return;
    }
    final created = await Navigator.of(context).pushNamed(flow.routeName);
    if (created == true && mounted) {
      await ref.read(payeesProvider.notifier).refresh();
      ref.invalidate(groupPayeesProvider);
    }
  }

  Future<void> _chooseAddPayee() async {
    final flow = await showPayPicker<AddPayeeFlow>(
      context,
      title: 'Add a payee',
      options: const [
        PayOption(
          value: AddPayeeFlow.bankAccount,
          title: 'Bank account',
          subtitle: 'Pay them by account number',
          icon: Icons.account_balance_outlined,
        ),
        PayOption(
          value: AddPayeeFlow.demandDraft,
          title: 'Demand draft',
          subtitle: 'Pay them with a bank draft',
          icon: Icons.description_outlined,
        ),
        PayOption(
          value: AddPayeeFlow.peerToPeer,
          title: 'Peer to peer',
          subtitle: 'Pay them by mobile number or email',
          icon: Icons.alternate_email_rounded,
        ),
      ],
    );
    if (flow != null) await _openAddPayee(flow);
  }

  void _pay(TransferPayee payee) {
    final tap = widget.onPayTap;
    if (tap != null) return tap(payee);
    Navigator.of(context).pushNamed(
      RoutesConst.networkTransferScreen,
      arguments: NetworkTransferArgs(NetworkTransferMode.existingPayee, payee: payee),
    );
  }

  void _goBack() {
    if (widget.onBack != null) return widget.onBack!();
    Navigator.of(context).maybePop();
  }

  static _Row _accountRow(PayeeSummary p, Map<String, int> groupSizes) {
    final payee = TransferPayee.fromJson(p.raw);
    final groupId = p.raw['groupId']?.toString();
    final target = PayeeDeleteTarget(
      payeeType: p.payeeType ?? '',
      payeeId: (p.raw['id'] ?? p.raw['payeeId'] ?? '').toString(),
      groupId: p.raw['groupId']?.toString(),
    );
    final number = p.accountNumber ?? payee?.accountNumber;
    final details = p.accountDetails;
    return _Row(
      title: p.nickname,
      subtitle: payee != null && payee.name != p.nickname ? payee.name : null,
      kind: payee?.kind?.label ?? p.accountType,
      detail: [
        if (number != null && number.isNotEmpty) payMask(number),
        if (details != '—' && details != number) details,
      ].join(' · '),
      payee: payee?.kind == null ? null : payee,
      deleteTarget: target.path == null ? null : target,
      groupName: p.raw['groupName']?.toString(),
      groupSize: groupId == null || groupId.isEmpty ? 1 : groupSizes[groupId] ?? 1,
    );
  }

  /// How many listed account payees share each group.
  static Map<String, int> _groupSizes(List<PayeeSummary> payees) {
    final sizes = <String, int>{};
    for (final p in payees) {
      final id = p.raw['groupId']?.toString();
      if (id != null && id.isNotEmpty) sizes[id] = (sizes[id] ?? 0) + 1;
    }
    return sizes;
  }

  static _Row _groupRow(GroupPayee p) {
    final target = PayeeDeleteTarget(payeeType: p.type, payeeId: p.id, groupId: p.groupId);
    return _Row(
      title: p.nickname,
      subtitle: p.name,
      kind: p.kind,
      detail: p.detail,
      deleteTarget: target.path == null ? null : target,
      groupName: p.name,
      groupSize: p.groupSize,
    );
  }

  // ── Delete ──────────────────────────────────────────────────────────────

  /// Rows being deleted, by [_Row.key].
  final _deleting = <String>{};

  /// Confirms, deletes — asking for the OTP when the bank wants one — and
  /// refreshes every list that shows payees.
  Future<void> _delete(_Row row) async {
    final target = row.deleteTarget;
    if (target == null || !await _confirmDelete(row)) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(payeeRepositoryProvider);
    setState(() => _deleting.add(row.key));
    var result = await repository.deletePayee(target);
    while (mounted &&
        result is Success<PayeeDeleteOutcome> &&
        result.data?.challenge != null) {
      final outcome = result.data!;
      if (!mounted) return;
      // Nothing is loading while they type the code.
      setState(() => _deleting.remove(row.key));
      final otp = await showPayOtpPrompt(
        context,
        title: 'Verify to delete ${row.title}',
        error: outcome.invalidOtp ? 'That code is not right. Please try again.' : null,
        attemptsLeft: outcome.challenge!.attemptsLeft,
      );
      if (!mounted) return;
      // Cancelled: nothing was deleted.
      if (otp == null) return;
      setState(() => _deleting.add(row.key));
      result = await repository.deletePayee(target, challenge: outcome.challenge, otp: otp);
    }
    if (!mounted) return;
    setState(() => _deleting.remove(row.key));

    final String message;
    if (result is Success<PayeeDeleteOutcome> && result.data != null) {
      HapticFeedback.mediumImpact();
      message = result.data!.pendingApproval
          ? 'Deleting ${row.title} is waiting for approval.'
          : '${row.title} deleted.';
      ref.read(payeesProvider.notifier).refresh();
      ref.invalidate(groupPayeesProvider);
      ref.invalidate(transferPayeesProvider);
    } else {
      message = result.resolveUserMessage(
        l10n: l10n,
        fallback: "We couldn't delete ${row.title}. Please try again.",
      );
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmDelete(_Row row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) {
        final error = HomeColors.error(dialog);
        return Dialog(
          backgroundColor: HomeColors.card(dialog),
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: PayAvatar(name: row.title, size: 56)),
                  const SizedBox(height: 14),
                  Text(
                    'Delete ${row.title}?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: HomeColors.textPrimary(dialog),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [row.kind, if (row.detail.isNotEmpty) row.detail].join(' · '),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(dialog)),
                  ),
                  if (row.groupSize > 1) ...[
                    const SizedBox(height: 14),
                    _GroupWarning(row: row),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    "They'll be removed from your saved payees. You can add them again at any time.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: HomeColors.textPrimary(dialog)),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: PaySecondaryButton(
                          label: 'Cancel',
                          onPressed: () => Navigator.of(dialog).pop(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(dialog).pop(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: error,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text(
                            'Delete',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(payeesProvider);
    final drafts = ref.watch(groupPayeesProvider(GroupPayee.demandDraft));
    final p2p = ref.watch(groupPayeesProvider(GroupPayee.peerToPeer));

    final groupSizes = _groupSizes(accounts.payees);
    final accountRows = [for (final p in accounts.payees) _accountRow(p, groupSizes)];
    final draftRows = [for (final p in drafts.valueOrNull ?? const <GroupPayee>[]) _groupRow(p)];
    final p2pRows = [for (final p in p2p.valueOrNull ?? const <GroupPayee>[]) _groupRow(p)];
    final total = accountRows.length + draftRows.length + p2pRows.length;

    String count(int n, bool loaded) => loaded ? ' ($n)' : '';
    final tabs = [
      (_PayeeTab.accounts, 'Accounts${count(accountRows.length, !accounts.isLoading)}'),
      (_PayeeTab.drafts, 'Drafts${count(draftRows.length, drafts.hasValue)}'),
      (_PayeeTab.peerToPeer, 'Peer to peer${count(p2pRows.length, p2p.hasValue)}'),
    ];

    final (rows, loading, error, retry) = switch (_tab) {
      _PayeeTab.accounts => (
          accountRows,
          accounts.isLoading && accountRows.isEmpty,
          accounts.errorMessage,
          () => ref.read(payeesProvider.notifier).refresh(),
        ),
      _PayeeTab.drafts => (
          draftRows,
          drafts.isLoading,
          drafts.hasError ? "We couldn't load your draft payees." : null,
          () => ref.invalidate(groupPayeesProvider(GroupPayee.demandDraft)),
        ),
      _PayeeTab.peerToPeer => (
          p2pRows,
          p2p.isLoading,
          p2p.hasError ? "We couldn't load your peer-to-peer payees." : null,
          () => ref.invalidate(groupPayeesProvider(GroupPayee.peerToPeer)),
        ),
    };
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty ? rows : rows.where((r) => r.matches(q)).toList();

    return PayMenuPage(
      title: 'Manage payees',
      subtitle: total == 0 ? 'The people and businesses you pay' : '$total saved payees',
      onBack: _goBack,
      builder: (context, wide) {
        final search = TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: payInputDecoration(
            context,
            hint: 'Search name, account, email…',
            prefixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
              child: Icon(Icons.search_rounded, size: 20, color: HomeColors.textSecondary(context)),
            ),
          ),
        );
        final add = PayPrimaryButton(
          label: 'Add payee',
          icon: Icons.person_add_alt_1_rounded,
          onPressed: _chooseAddPayee,
        );
        final switcher = PaySegmented<_PayeeTab>(
          options: tabs,
          selected: _tab,
          onChanged: (t) => setState(() => _tab = t),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Row(
                children: [
                  Expanded(child: switcher),
                  const SizedBox(width: 16),
                  SizedBox(width: 300, child: search),
                  const SizedBox(width: 12),
                  add,
                ],
              )
            else ...[
              switcher,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: 'Add payee',
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: FilledButton(
                        onPressed: _chooseAddPayee,
                        style: FilledButton.styleFrom(
                          backgroundColor: HomeColors.brand(context),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            PaySection(
              padding: wide ? 8 : 6,
              child: error != null
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: PayErrorRetry(message: error, onRetry: retry),
                    )
                  : loading
                      ? Column(children: [for (var i = 0; i < 4; i++) const _PayeeLine.placeholder()])
                      : rows.isEmpty
                          ? _EmptyTab(tab: _tab, onAdd: () => _openAddPayee(_tab.flow))
                          : shown.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: PayMuted('No payee matches "${_query.trim()}".'),
                                )
                              : Column(
                                  children: [
                                    if (wide) const _HeaderLine(),
                                    for (final (i, row) in shown.indexed)
                                      _PayeeLine(
                                        row: row,
                                        wide: wide,
                                        last: i == shown.length - 1,
                                        onPay: row.payee == null ? null : () => _pay(row.payee!),
                                        onDelete: row.deleteTarget == null ? null : () => _delete(row),
                                        deleting: _deleting.contains(row.key),
                                      ),
                                  ],
                                ),
            ),
          ],
        );
      },
    );
  }
}

extension on _PayeeTab {
  AddPayeeFlow get flow => switch (this) {
        _PayeeTab.accounts => AddPayeeFlow.bankAccount,
        _PayeeTab.drafts => AddPayeeFlow.demandDraft,
        _PayeeTab.peerToPeer => AddPayeeFlow.peerToPeer,
      };
}

/// Shown before deleting a payee whose group holds others too.
class _GroupWarning extends StatelessWidget {
  const _GroupWarning({required this.row});

  final _Row row;

  @override
  Widget build(BuildContext context) {
    final others = row.groupSize - 1;
    final group = row.groupName == null ? 'a payee group' : 'the group "${row.groupName}"';
    final warning = HomeColors.warning(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${row.title} is in $group with $others other '
              '${others == 1 ? 'payee' : 'payees'}. The bank may delete the whole '
              'group, including ${others == 1 ? 'that payee' : 'them'}.',
              style: TextStyle(fontSize: 13, color: HomeColors.textPrimary(context)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Column titles on wide layouts.
class _HeaderLine extends StatelessWidget {
  const _HeaderLine();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: HomeColors.textSecondary(context),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: HomeColors.divider(context))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 54),
          Expanded(flex: 4, child: Text('Payee', style: style)),
          Expanded(flex: 3, child: Text('Type', style: style)),
          Expanded(flex: 4, child: Text('Details', style: style)),
          const SizedBox(width: 116),
        ],
      ),
    );
  }
}

class _PayeeLine extends StatelessWidget {
  const _PayeeLine({
    required _Row this.row,
    required this.wide,
    required this.last,
    this.onPay,
    this.onDelete,
    this.deleting = false,
  });

  const _PayeeLine.placeholder()
      : row = null,
        wide = false,
        last = false,
        onPay = null,
        onDelete = null,
        deleting = false;

  final _Row? row;
  final bool wide;
  final bool last;
  final VoidCallback? onPay;
  final VoidCallback? onDelete;

  /// A delete is in flight: a spinner instead of the menu.
  final bool deleting;

  @override
  Widget build(BuildContext context) {
    final r = row;
    final grey = HomeColors.divider(context);
    final secondary = HomeColors.textSecondary(context);
    final border = BoxDecoration(
      border: last ? null : Border(bottom: BorderSide(color: grey.withValues(alpha: 0.7))),
    );
    if (r == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: border,
        child: Row(
          children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: grey, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 140, height: 12, color: grey),
                const SizedBox(height: 6),
                Container(width: 200, height: 10, color: grey),
              ],
            ),
          ],
        ),
      );
    }

    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          r.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: HomeColors.textPrimary(context),
          ),
        ),
        if (!wide || r.subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            wide ? r.subtitle! : [r.kind, if (r.detail.isNotEmpty) r.detail].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: secondary),
          ),
        ],
      ],
    );
    final pay = onPay == null
        ? const SizedBox(width: 64)
        : Tooltip(
            message: 'Pay ${r.title}',
            child: FilledButton.tonal(
              onPressed: onPay,
              style: FilledButton.styleFrom(
                foregroundColor: HomeColors.brand(context),
                backgroundColor: HomeColors.brand(context).withValues(alpha: 0.1),
                minimumSize: const Size(64, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Pay', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: border,
      child: Row(
        children: [
          PayAvatar(name: r.title, size: 42),
          const SizedBox(width: 12),
          if (wide) ...[
            Expanded(flex: 4, child: name),
            Expanded(
              flex: 3,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _KindChip(r.kind),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                r.detail.isEmpty ? '—' : r.detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: HomeColors.textPrimary(context)),
              ),
            ),
          ] else
            Expanded(child: name),
          const SizedBox(width: 8),
          pay,
          SizedBox(
            width: 44,
            child: deleting
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : onDelete == null
                    ? null
                    : PopupMenuButton<String>(
                        tooltip: 'More for ${r.title}',
                        icon: Icon(Icons.more_vert_rounded, color: secondary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (_) => onDelete!(),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 20, color: HomeColors.error(context)),
                                const SizedBox(width: 10),
                                Text('Delete payee', style: TextStyle(color: HomeColors.error(context))),
                              ],
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

class _KindChip extends StatelessWidget {
  const _KindChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: HomeColors.brand(context).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: HomeColors.brand(context),
          ),
        ),
      );
}

/// A tab with no payees — say so, and offer to add one of that kind.
class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.tab, required this.onAdd});

  final _PayeeTab tab;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final (title, text, action) = switch (tab) {
      _PayeeTab.accounts => (
          'No account payees yet',
          'Save someone you pay by account number, then pay them in a tap.',
          'Add a bank account payee',
        ),
      _PayeeTab.drafts => (
          'No draft payees yet',
          'Save who your demand drafts are made out to.',
          'Add a draft payee',
        ),
      _PayeeTab.peerToPeer => (
          'No peer-to-peer payees yet',
          'Save someone you pay by mobile number or email.',
          'Add a peer-to-peer payee',
        ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          PayAvatar(name: title, size: 56, icon: tab.flow.icon),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: HomeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: HomeColors.textSecondary(context)),
          ),
          const SizedBox(height: 16),
          PaySecondaryButton(label: action, icon: Icons.add_rounded, onPressed: onAdd),
        ],
      ),
    );
  }
}
