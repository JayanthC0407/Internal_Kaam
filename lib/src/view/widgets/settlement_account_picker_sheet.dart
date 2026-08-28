import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// Native-feeling account picker — a swipe-to-dismiss bottom sheet that
/// shows each account's balance and masked number (not just a name), with
/// haptic feedback on selection. Used by the loan repayment "Pay From"
/// step; written generically enough to reuse anywhere a CASA account
/// needs picking.
class SettlementAccountPickerSheet {
  SettlementAccountPickerSheet._();

  static Future<CasaAccount?> show(
    BuildContext context, {
    required String title,
    required List<CasaAccount> accounts,
    CasaAccount? selected,
  }) {
    return showModalBottomSheet<CasaAccount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.viewPaddingOf(ctx).bottom;
        final card = HomeColors.card(ctx);
        final divider = HomeColors.divider(ctx);
        final textPrimary = HomeColors.textPrimary(ctx);
        final textSecondary = HomeColors.textSecondary(ctx);
        final brand = HomeColors.brand(ctx);

        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: divider,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ),
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: accounts.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: divider,
                        indent: 68,
                      ),
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        final isSelected = account.id == selected?.id;
                        final balance = account.displayBalance;
                        final balanceText = balance == null
                            ? '—'
                            : MoneyFormat.format(
                                balance.amount,
                                currencyCode:
                                    balance.currency ?? account.currencyCode,
                              );

                        return ListTile(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(ctx).pop(account);
                          },
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: brand.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.account_balance_outlined,
                              color: brand,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            account.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            account.maskedNumber,
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                balanceText,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                size: 16,
                                color: isSelected ? brand : textSecondary,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
