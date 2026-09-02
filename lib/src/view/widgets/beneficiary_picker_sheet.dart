import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ubci_bank/src/core/models/payment/payment_models.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// Beneficiary picker bottom sheet — shared by Internal and International
/// payments (functional flow doc §19, "Common Payment Components").
/// Follows the same native-sheet convention as
/// [SettlementAccountPickerSheet].
class BeneficiaryPickerSheet {
  BeneficiaryPickerSheet._();

  static Future<TransferBeneficiary?> show(
    BuildContext context, {
    required String title,
    required List<TransferBeneficiary> beneficiaries,
    TransferBeneficiary? selected,
  }) {
    return showModalBottomSheet<TransferBeneficiary>(
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
                if (beneficiaries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No beneficiaries found.',
                        style: TextStyle(color: textSecondary),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: beneficiaries.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: divider,
                          indent: 68,
                        ),
                        itemBuilder: (context, index) {
                          final beneficiary = beneficiaries[index];
                          final isSelected = beneficiary.id == selected?.id;
                          final subtitleParts = <String>[
                            if (beneficiary.maskedAccountNumber.isNotEmpty)
                              beneficiary.maskedAccountNumber,
                            if (beneficiary.bankName != null)
                              beneficiary.bankName!,
                            if (beneficiary.bankCountry != null)
                              beneficiary.bankCountry!,
                          ];

                          return ListTile(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.of(ctx).pop(beneficiary);
                            },
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: brand.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                beneficiary.isInternational
                                    ? Icons.public_rounded
                                    : Icons.person_outline_rounded,
                                color: brand,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              beneficiary.nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: textPrimary,
                              ),
                            ),
                            subtitle: subtitleParts.isEmpty
                                ? null
                                : Text(
                                    subtitleParts.join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondary,
                                    ),
                                  ),
                            trailing: Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.chevron_right_rounded,
                              size: isSelected ? 20 : 22,
                              color: isSelected ? brand : textSecondary,
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
