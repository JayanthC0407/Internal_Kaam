import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/src/core/models/common/payment/network_transfer.dart';
import 'package:ubci_bank/src/view/providers/common/network_transfer_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/common/payments/network_transfer_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// Payees — the OBDX "Payee" submenu (Manage Payees, Add Account / Draft /
/// Peer To Peer Payee) as one page:
///
///  - **Your payees**: search the saved payees and pay one straight away;
///    "See all" opens Manage Payees.
///  - **Add a payee**: the three kinds the bank supports.
///
/// Wide layouts put "Add a payee" in a column beside the list.
class PayeeHubScreen extends ConsumerStatefulWidget {
  const PayeeHubScreen({
    super.key,
    this.embedded = false,
    this.onBack,
    this.onManagePayeesTap,
    this.onAddAccountPayeeTap,
    this.onAddDraftPayeeTap,
    this.onAddPeerToPeerPayeeTap,
    this.onPayTap,
  });

  /// Shown inside the dashboard (beside the side menu) rather than pushed;
  /// [onBack] then leaves it.
  final bool embedded;
  final VoidCallback? onBack;

  /// Each opens its screen inside the dashboard; when not supplied the
  /// screen's route is pushed instead.
  final VoidCallback? onManagePayeesTap;
  final VoidCallback? onAddAccountPayeeTap;
  final VoidCallback? onAddDraftPayeeTap;
  final VoidCallback? onAddPeerToPeerPayeeTap;

  /// Starts a transfer to a payee inside the dashboard.
  final ValueChanged<TransferPayee>? onPayTap;

  @override
  ConsumerState<PayeeHubScreen> createState() => _PayeeHubScreenState();
}

class _PayeeHubScreenState extends ConsumerState<PayeeHubScreen> {
  /// How many payees show before "See all".
  static const _preview = 6;

  String _query = '';

  void _push(String route) => Navigator.of(context).pushNamed(route);

  void _pay(TransferPayee payee) {
    final tap = widget.onPayTap;
    if (tap != null) return tap(payee);
    Navigator.of(context).pushNamed(
      RoutesConst.networkTransferScreen,
      arguments: NetworkTransferArgs(NetworkTransferMode.existingPayee, payee: payee),
    );
  }

  @override
  Widget build(BuildContext context) {
    final addTiles = [
      PayOptionTile(
        horizontal: true,
        icon: Icons.account_balance_outlined,
        title: 'Add Account Payee',
        subtitle: 'Pay them by account number',
        onTap: widget.onAddAccountPayeeTap ?? () => _push(RoutesConst.addBankAccountPayeeScreen),
      ),
      PayOptionTile(
        horizontal: true,
        icon: Icons.description_outlined,
        title: 'Add Draft Payee',
        subtitle: 'Pay them with a bank draft',
        onTap: widget.onAddDraftPayeeTap ?? () => _push(RoutesConst.addDemandDraftPayeeScreen),
      ),
      PayOptionTile(
        horizontal: true,
        icon: Icons.alternate_email_rounded,
        title: 'Add Peer To Peer Payee',
        subtitle: 'Pay them by mobile number or email',
        onTap: widget.onAddPeerToPeerPayeeTap ?? () => _push(RoutesConst.addPeerToPeerPayeeScreen),
      ),
    ];

    return PayMenuPage(
      title: 'Payee',
      subtitle: 'The people and businesses you pay',
      onBack: widget.embedded ? widget.onBack : null,
      builder: (context, wide) {
        final list = _yourPayees(context);
        final add = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add Payee',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: HomeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            for (final (i, tile) in addTiles.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              tile,
            ],
          ],
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: list),
              const SizedBox(width: 24),
              SizedBox(width: 340, child: add),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [list, const SizedBox(height: 24), add],
        );
      },
    );
  }

  Widget _yourPayees(BuildContext context) {
    final payees = ref.watch(transferPayeesProvider);
    final all = payees.valueOrNull ?? const <TransferPayee>[];
    final q = _query.trim().toLowerCase();
    final matches = q.isEmpty
        ? all
        : all
            .where((p) =>
                p.title.toLowerCase().contains(q) ||
                p.name.toLowerCase().contains(q) ||
                (p.accountNumber ?? '').toLowerCase().contains(q) ||
                (p.bankName ?? '').toLowerCase().contains(q))
            .toList();
    // Searching shows every match; otherwise a short list and "See all".
    final shown = q.isEmpty ? matches.take(_preview).toList() : matches;

    final Widget body;
    if (payees.hasError) {
      body = PayErrorRetry(
        message: "We couldn't load your payees.",
        onRetry: () => ref.invalidate(transferPayeesProvider),
      );
    } else if (payees.isLoading) {
      body = Column(children: [for (var i = 0; i < 3; i++) const _PayeeRow.placeholder()]);
    } else if (all.isEmpty) {
      body = const _EmptyPayees();
    } else if (shown.isEmpty) {
      body = PayMuted('No payee matches "${_query.trim()}".');
    } else {
      body = Column(
        children: [
          for (final (i, p) in shown.indexed)
            _PayeeRow(
              payee: p,
              last: i == shown.length - 1,
              onPay: p.kind == null ? null : () => _pay(p),
            ),
        ],
      );
    }

    return PaySection(
      title: 'Your payees',
      icon: Icons.people_alt_outlined,
      trailing: all.isEmpty
          ? null
          : TextButton(
              onPressed: widget.onManagePayeesTap ?? () => _push(RoutesConst.payeesScreen),
              child: Text(all.length > _preview ? 'Manage Payees (${all.length})' : 'Manage Payees'),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (all.length > 3) ...[
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: payInputDecoration(
                context,
                hint: 'Search by name, account or bank',
                prefixIcon: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
                  child: Icon(Icons.search_rounded, size: 20, color: HomeColors.textSecondary(context)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          body,
        ],
      ),
    );
  }
}

/// A saved payee with a quick "Pay".
class _PayeeRow extends StatelessWidget {
  const _PayeeRow({required TransferPayee this.payee, required this.last, this.onPay});

  const _PayeeRow.placeholder()
      : payee = null,
        last = false,
        onPay = null;

  final TransferPayee? payee;
  final bool last;

  /// Null for payees the transfer screens can't pay (drafts, peer to peer).
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final p = payee;
    final grey = HomeColors.divider(context);
    final detail = p == null
        ? ''
        : [
            p.kind?.label,
            if ((p.accountNumber ?? '').isNotEmpty) payMask(p.accountNumber!),
            p.bankName,
          ].whereType<String>().join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: grey.withValues(alpha: 0.7))),
      ),
      child: Row(
        children: [
          if (p == null)
            Container(width: 42, height: 42, decoration: BoxDecoration(color: grey, shape: BoxShape.circle))
          else
            PayAvatar(name: p.title, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: p == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 120, height: 12, color: grey),
                      const SizedBox(height: 6),
                      Container(width: 180, height: 10, color: grey),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: HomeColors.textPrimary(context),
                        ),
                      ),
                      if (detail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context)),
                        ),
                      ],
                    ],
                  ),
          ),
          if (onPay != null) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Pay ${p!.title}',
              child: FilledButton.tonal(
                onPressed: onPay,
                style: FilledButton.styleFrom(
                  foregroundColor: HomeColors.brand(context),
                  backgroundColor: HomeColors.brand(context).withValues(alpha: 0.1),
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Pay', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyPayees extends StatelessWidget {
  const _EmptyPayees();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            PayAvatar(name: 'Payees', size: 56, icon: Icons.person_add_alt_1_outlined),
            const SizedBox(height: 12),
            Text(
              'No payees yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: HomeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add someone you pay often, then pay them in a tap.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: HomeColors.textSecondary(context)),
            ),
          ],
        ),
      );
}
