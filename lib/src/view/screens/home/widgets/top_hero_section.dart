import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/theme/app_gradients.dart';
import 'package:ubci_bank/src/view/screens/home/widgets/dashboard_header_bar.dart';

class TopHeroSection extends StatelessWidget {
  const TopHeroSection({
    super.key,
    required this.displayName,
    required this.hideBalance,
    required this.currentActionSlide,
    required this.actionPageController,
    required this.onToggleBalance,
    required this.onActionSlideChanged,
    this.onTransferTap,
    this.onProfileTap,
    this.onMenuTap,
    this.onNotificationsTap,
    this.balanceText,
    this.balanceSubtitle,
    this.isBalanceLoading = false,
  });

  /// Kept for future use — the header row no longer renders a greeting,
  /// but callers still pass the resolved display name.
  final String displayName;
  final bool hideBalance;
  final int currentActionSlide;
  final PageController actionPageController;
  final VoidCallback onToggleBalance;
  final ValueChanged<int> onActionSlideChanged;
  final VoidCallback? onTransferTap;
  final VoidCallback? onProfileTap;

  /// Opens the hamburger drawer. Only passed on mobile/tablet — desktop has
  /// the persistent `WebNavigationSidebar` instead, so this is `null` there
  /// and the menu button is not shown.
  final VoidCallback? onMenuTap;
  final VoidCallback? onNotificationsTap;
  final String? balanceText;
  final String? balanceSubtitle;
  final bool isBalanceLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actionSlides = [
      [
        _HeroActionItem(
            icon: Icons.currency_exchange_rounded, label: l10n.transfer),
        _HeroActionItem(icon: Icons.qr_code_scanner_rounded, label: l10n.scan),
        _HeroActionItem(icon: Icons.receipt_long_rounded, label: l10n.payBill),
      ],
      [
        _HeroActionItem(
            icon: Icons.phone_android_rounded, label: l10n.recharge),
        _HeroActionItem(
            icon: Icons.account_balance_wallet_rounded, label: l10n.wallet),
        _HeroActionItem(icon: Icons.savings_rounded, label: l10n.savings),
      ],
      [
        _HeroActionItem(icon: Icons.send_rounded, label: l10n.send),
        _HeroActionItem(icon: Icons.request_page_rounded, label: l10n.request),
        _HeroActionItem(icon: Icons.credit_score_rounded, label: l10n.credit),
      ],
    ];

    return Container(
decoration: BoxDecoration(
  // gradient: AppGradients.primary(context),
),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
//             Positioned(
//               right: -45,
//               top: -70,
//               child: Container(
//                 width: 240,
//                 height: 240,
// decoration: BoxDecoration(
//   shape: BoxShape.circle,
//   color: AppColors.cyan400.withValues(alpha: 0.13),
// ),
//               ),
//             ),
//             Positioned(
//               right: -55,
//               bottom: -40,
//               child: Container(
//                 width: 190,
//                 height: 190,
// decoration: BoxDecoration(
//   shape: BoxShape.circle,
//   color: AppColors.cyan300.withValues(alpha: 0.10),
// ),
//               ),
//             ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MobileDashboardHeaderRow(
                    onMenuTap: onMenuTap,
                    onNotificationsTap: onNotificationsTap,
                    onProfileTap: onProfileTap,
                  ),
                 // const SizedBox(height: 20),
                  // Text(
                  //   l10n.totalBalance.toUpperCase(),
                  //   style: const TextStyle(
                  //     color: Color(0xB3FFFFFF),
                  //     fontSize: 11,
                  //     letterSpacing: 1.1,
                  //     fontWeight: FontWeight.w600,
                  //   ),
                  // ),
                  //const SizedBox(height: 6),
                  // Row(
                  //   crossAxisAlignment: CrossAxisAlignment.center,
                  //   children: [
                  //     Flexible(
                  //       child: isBalanceLoading && balanceText == null
                  //           ? const SizedBox(
                  //               height: 34,
                  //               width: 34,
                  //               child: CircularProgressIndicator(
                  //                 strokeWidth: 2.5,
                  //                 color: Colors.white,
                  //               ),
                  //             )
                  //           : Text(
                  //               hideBalance ? '******' : (balanceText ?? '—'),
                  //               style: const TextStyle(
                  //                 color: Colors.white,
                  //                 fontSize: 32,
                  //                 fontWeight: FontWeight.w700,
                  //                 height: 1.1,
                  //                 letterSpacing: -0.5,
                  //               ),
                  //             ),
                  //     ),
                  //     const SizedBox(width: 10),
                  //     InkWell(
                  //       onTap: onToggleBalance,
                  //       borderRadius: BorderRadius.circular(16),
                  //       child: CircleAvatar(
                  //         radius: 15,
                  //         backgroundColor: const Color(0x33FFFFFF),
                  //         child: Icon(
                  //           hideBalance
                  //               ? Icons.visibility_off_outlined
                  //               : Icons.visibility_outlined,
                  //           color: Colors.white,
                  //           size: 16,
                  //         ),
                  //       ),
                  //     ),
                  //   ],
                  // ),
                //  const SizedBox(height: 4),
                  // Text(
                  //   balanceSubtitle ?? l10n.availableBalanceLabel,
                  //   style: const TextStyle(
                  //     color: Color(0xB3FFFFFF),
                  //     fontSize: 13,
                  //     letterSpacing: 0.6,
                  //   ),
                  // ),
                 // const SizedBox(height: 18),
                  // SizedBox(
                  //   height: 84,
                  //   child: PageView.builder(
                  //     controller: actionPageController,
                  //     onPageChanged: onActionSlideChanged,
                  //     itemCount: actionSlides.length,
                  //     itemBuilder: (_, index) {
                  //       final items = actionSlides[index];
                  //       return Row(
                  //         children: [
                  //           Expanded(
                  //             child: _HeroActionTile(
                  //               item: items[0],
                  //               onTap: index == 0 ? onTransferTap : null,
                  //             ),
                  //           ),
                  //           const SizedBox(width: 10),
                  //           Expanded(child: _HeroActionTile(item: items[1])),
                  //           const SizedBox(width: 10),
                  //           Expanded(child: _HeroActionTile(item: items[2])),
                  //         ],
                  //       );
                  //     },
                  //   ),
                  // ),
                //  const SizedBox(height: 14),
                  // _HeroDots(active: currentActionSlide),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroActionItem {
  const _HeroActionItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _HeroActionTile extends StatelessWidget {
  const _HeroActionTile({required this.item, this.onTap});

  final _HeroActionItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 84,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
            color: Colors.white.withValues(alpha: 0.08),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: Colors.white, size: 24),
              const SizedBox(height: 6),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroDots extends StatelessWidget {
  const _HeroDots({required this.active});

  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 20 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white38,
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}