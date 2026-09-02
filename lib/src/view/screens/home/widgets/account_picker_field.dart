import 'package:flutter/material.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/view/providers/recent_transactions_widget_providers.dart';
import '../home_colors.dart';

/// Compact "which account" control. Renders as a single tappable field
/// showing the current selection; tapping opens a scrollable bottom sheet
/// to pick another account. Deliberately not a row of chips — that layout
/// stops scaling once a user has more than a handful of accounts, whereas
/// this stays a single line regardless of count.
///
/// Works off [SelectableAccount] rather than [CasaAccount] so the same
/// control can back the "View All" transactions screen for CASA, Loans,
/// and Credit Cards alike.
class AccountPickerField extends StatelessWidget {
  const AccountPickerField({
    super.key,
    required this.accounts,
    required this.selectedAccountId,
    required this.onSelected,
  });

  final List<SelectableAccount> accounts;
  final String? selectedAccountId;
  final ValueChanged<String> onSelected;

  SelectableAccount? get _selected {
    if (selectedAccountId == null) return null;
    for (final a in accounts) {
      if (a.id == selectedAccountId) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final l10n = AppLocalizations.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: accounts.length <= 1
          ? null
          : () => _openPicker(context, l10n),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: HomeColors.bg(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: HomeColors.divider(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                selected == null
                    ? '—'
                    : '${selected.title} · ${selected.subtitle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HomeColors.textPrimary(context),
                ),
              ),
            ),
            if (accounts.length > 1) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: HomeColors.textSecondary(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context, AppLocalizations l10n) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: HomeColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.selectAccountTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: HomeColors.textPrimary(sheetContext),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: accounts.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: HomeColors.divider(sheetContext)),
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      final selected = account.id == selectedAccountId;
                      final balance = account.balance;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          account.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: HomeColors.textPrimary(context),
                          ),
                        ),
                        subtitle: Text(
                          account.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: HomeColors.textSecondary(context),
                          ),
                        ),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (balance != null)
                              Text(
                                MoneyFormat.format(
                                  balance.amount,
                                  currencyCode: balance.currency ?? '',
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: HomeColors.textPrimary(context),
                                ),
                              ),
                            if (selected) ...[
                              const SizedBox(height: 2),
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: HomeColors.brand(context),
                              ),
                            ],
                          ],
                        ),
                        onTap: () {
                          onSelected(account.id);
                          Navigator.of(sheetContext).pop();
                        },
                      );
                    },
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