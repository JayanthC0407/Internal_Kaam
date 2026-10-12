import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/src/core/models/common/payment/network_transfer.dart';
import 'package:ubci_bank/src/core/utils/common/responsive.dart';
import 'package:ubci_bank/src/view/providers/common/network_transfer_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/common/payments/network_transfer_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/retail/home/widgets/home_menu_button.dart';

/// Starts a payee transfer in [mode], with [payee] already chosen when the
/// person picked one on the hub.
typedef TransferStart = void Function(NetworkTransferMode mode, TransferPayee? payee);

/// The Transfer hub — where every way of moving money starts:
///
///  - **Send to**: the saved payees as a strip of avatars; one tap starts a
///    transfer to that person, "New" starts one to someone unsaved.
///  - **Ways to pay**: the OBDX Transfers menu in plain words — a saved or
///    new payee, between own accounts, repeat, abroad (low value), several
///    at once.
///  - **Manage**: payees, and the payment services still to come.
///
/// Wide layouts put Manage in a column beside the rest; phones stack it.
class TransferTabScreen extends ConsumerWidget {
  const TransferTabScreen({
    super.key,
    this.onTransferTap,
    this.onOwnAccountTransferTap,
    this.onPayeeHubTap,
    this.onMultipleTransfersTap,
  });

  /// Opens a payee transfer inside the dashboard; pushes it otherwise.
  final TransferStart? onTransferTap;

  /// Opens "Between My Accounts" inside the dashboard.
  final VoidCallback? onOwnAccountTransferTap;

  /// Opens the payee hub inside the dashboard.
  final VoidCallback? onPayeeHubTap;

  /// Opens Multiple Transfers inside the dashboard.
  final VoidCallback? onMultipleTransfersTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responsive = Responsive.of(context);

    void start(NetworkTransferMode mode, [TransferPayee? payee]) {
      final tap = onTransferTap;
      if (tap != null) return tap(mode, payee);
      Navigator.of(context).pushNamed(
        RoutesConst.networkTransferScreen,
        arguments: NetworkTransferArgs(mode, payee: payee),
      );
    }

    void push(String route) => Navigator.of(context).pushNamed(route);
    final openPayees = onPayeeHubTap ?? () => push(RoutesConst.payeeHubScreen);

    final ways = [
      PayOptionTile(
        icon: Icons.person_outline_rounded,
        title: 'Send money',
        subtitle: 'To one of your saved payees',
        onTap: () => start(NetworkTransferMode.existingPayee),
      ),
      PayOptionTile(
        icon: Icons.person_add_alt_1_outlined,
        title: 'Pay someone new',
        subtitle: 'No need to save them first',
        onTap: () => start(NetworkTransferMode.adhocPayee),
      ),
      PayOptionTile(
        icon: Icons.sync_alt_rounded,
        title: 'Between my accounts',
        subtitle: 'Move money instantly',
        onTap: onOwnAccountTransferTap ?? () => push(RoutesConst.ownAccountTransferScreen),
      ),
      PayOptionTile(
        icon: Icons.event_repeat_rounded,
        title: 'Repeat payment',
        subtitle: 'Pay on a schedule',
        onTap: () => start(NetworkTransferMode.repeatExistingPayee),
      ),
      PayOptionTile(
        icon: Icons.public_rounded,
        title: 'Pay abroad',
        subtitle: 'Low-value payment over SWIFT gpi',
        onTap: () => start(NetworkTransferMode.internationalLowValue),
      ),
      PayOptionTile(
        icon: Icons.dynamic_feed_rounded,
        title: 'Pay several at once',
        subtitle: 'Up to 10 payees in one go',
        onTap: onMultipleTransfersTap ?? () => push(RoutesConst.multipleTransfersScreen),
      ),
    ];

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final wide = width >= kPayWideFlow;
          final phone = width < 600;
          final pad = phone ? 16.0 : 32.0;

          final sendTo = _SendToCard(
            onPayee: (p) => start(NetworkTransferMode.existingPayee, p),
            onNew: () => start(NetworkTransferMode.adhocPayee),
            onAllPayees: openPayees,
          );
          final waysSection = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionTitle('Ways to pay'),
              const SizedBox(height: 12),
              PayGrid(columns: phone ? 2 : 3, children: ways),
            ],
          );
          final manage = _ManageSection(onPayees: openPayees);

          return ListView(
            padding: EdgeInsets.fromLTRB(pad, phone ? 16 : 22, pad, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          // The desktop sidebar is always there; smaller
                          // layouts reach the drawer from here.
                          if (!responsive.isDesktop) ...[
                            HomeMenuButton(onTap: () => Scaffold.of(context).openDrawer()),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Transfer',
                                  style: TextStyle(
                                    color: HomeColors.textPrimary(context),
                                    fontSize: phone ? 26 : 30,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Send money to anyone, at home or abroad.',
                                  style: TextStyle(color: HomeColors.textSecondary(context)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [sendTo, const SizedBox(height: 28), waysSection],
                              ),
                            ),
                            const SizedBox(width: 24),
                            SizedBox(width: 340, child: manage),
                          ],
                        )
                      else ...[
                        sendTo,
                        const SizedBox(height: 24),
                        waysSection,
                        const SizedBox(height: 24),
                        manage,
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: HomeColors.textPrimary(context),
        ),
      );
}

/// The saved payees as avatars — the quickest way to pay someone again.
class _SendToCard extends ConsumerWidget {
  const _SendToCard({
    required this.onPayee,
    required this.onNew,
    required this.onAllPayees,
  });

  final ValueChanged<TransferPayee> onPayee;
  final VoidCallback onNew;
  final VoidCallback onAllPayees;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payees = ref.watch(transferPayeesProvider);
    final list = (payees.valueOrNull ?? const <TransferPayee>[])
        .where((p) => p.kind != null)
        .toList();
    return PaySection(
      title: 'Send to',
      trailing: TextButton(onPressed: onAllPayees, child: const Text('All payees')),
      child: payees.hasError
          ? PayErrorRetry(
              message: "We couldn't load your payees.",
              onRetry: () => ref.invalidate(transferPayeesProvider),
            )
          : SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _PayeeBubble(
                    label: 'New',
                    tooltip: 'Pay someone new',
                    avatar: const PayAvatar(name: 'New', size: 54, icon: Icons.add_rounded),
                    onTap: onNew,
                  ),
                  if (payees.isLoading)
                    for (var i = 0; i < 4; i++) const _PayeeBubble.placeholder()
                  else if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 16),
                      child: Text(
                        'Your saved payees appear here.',
                        style: TextStyle(fontSize: 13, color: HomeColors.textSecondary(context)),
                      ),
                    )
                  else
                    for (final p in list)
                      _PayeeBubble(
                        label: p.title.split(' ').first,
                        tooltip: 'Pay ${p.title}',
                        avatar: PayAvatar(name: p.title, size: 54),
                        onTap: () => onPayee(p),
                      ),
                ],
              ),
            ),
    );
  }
}

class _PayeeBubble extends StatelessWidget {
  const _PayeeBubble({
    required this.label,
    required this.tooltip,
    required this.avatar,
    required this.onTap,
  });

  const _PayeeBubble.placeholder()
      : label = null,
        tooltip = null,
        avatar = null,
        onTap = null;

  final String? label;
  final String? tooltip;
  final Widget? avatar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = SizedBox(
      width: 76,
      child: Column(
        children: [
          avatar ??
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: HomeColors.divider(context),
                  shape: BoxShape.circle,
                ),
              ),
          const SizedBox(height: 8),
          if (label != null)
            Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: HomeColors.textPrimary(context),
              ),
            )
          else
            Container(
              width: 40,
              height: 10,
              decoration: BoxDecoration(
                color: HomeColors.divider(context),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return Padding(padding: const EdgeInsets.only(right: 4), child: body);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: tooltip!,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: body),
        ),
      ),
    );
  }
}

/// Payees, and the OBDX payment services the app does not offer yet.
class _ManageSection extends StatelessWidget {
  const _ManageSection({required this.onPayees});

  final VoidCallback onPayees;

  static const _soon = [
    (Icons.receipt_long_rounded, 'Payment status'),
    (Icons.event_note_outlined, 'Standing instructions'),
    (Icons.description_outlined, 'Demand drafts'),
    (Icons.star_border_rounded, 'Favourites & drafts'),
    (Icons.verified_outlined, 'Positive pay'),
    (Icons.groups_outlined, 'Debtors'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Manage'),
        const SizedBox(height: 12),
        PayOptionTile(
          horizontal: true,
          icon: Icons.people_alt_outlined,
          title: 'Payees',
          subtitle: 'View, add and manage the people you pay',
          onTap: onPayees,
        ),
        const SizedBox(height: 12),
        PaySection(
          title: 'Coming soon',
          icon: Icons.schedule_rounded,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (icon, label) in _soon)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: HomeColors.bg(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: HomeColors.divider(context)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: HomeColors.textSecondary(context)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
