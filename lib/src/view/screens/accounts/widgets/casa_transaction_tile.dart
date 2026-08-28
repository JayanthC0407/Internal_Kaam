import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/casa_transaction.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

class CasaTransactionTile extends StatelessWidget {
  const CasaTransactionTile({
    super.key,
    required this.transaction,
    this.compact = false,
    this.hideBalance = false,
  });

  final CasaTransaction transaction;
  final bool compact;
  final bool hideBalance;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const _success = Color(0xFF079455);
  static const _creditBg = Color(0xFFECFDF3);
  static const _creditBorder = Color(0xFF75E0A7);
  static const _creditIcon = Color(0xFF079455);
  static const _debitBg = Color(0xFFFEF3F2);
  static const _debitBorder = Color(0xFFFDA29B);
  static const _debitIcon = Color(0xFFD92D20);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currency = (transaction.amount.currency ?? '').trim();
    final formatted = hideBalance
        ? '******'
        : MoneyFormat.format(
            transaction.amount.amount,
            currencyCode: currency,
          );
    final amountText = hideBalance
        ? '******'
        : compact
            ? (transaction.isCredit ? '+ $formatted' : '- $formatted')
            : formatted;

    final dateLabel = _formatDate(transaction.dateTime, compact: compact);
    final isCredit = transaction.isCredit;
    final iconBg = isCredit ? _creditBg : _debitBg;
    final iconBorder = isCredit ? _creditBorder : _debitBorder;
    final iconColor = isCredit ? _creditIcon : _debitIcon;
    final icon =
        isCredit ? Icons.north_east_rounded : Icons.south_west_rounded;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
              border: Border.all(color: iconBorder, width: 1),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    height: 1.35,
                    color: HomeColors.textPrimary(context),
                  ),
                ),
                if (!compact && dateLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: HomeColors.textSecondary(context),
                    ),
                  ),
                ],
                if (!compact &&
                    transaction.reference != null &&
                    transaction.reference!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    l10n.casaTransactionRef(transaction.reference!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: HomeColors.textSecondary(context),
                    ),
                  ),
                ],
                if (compact && transaction.subtitle?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    transaction.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: HomeColors.textSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountText,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  height: 1.35,
                  color: compact && transaction.isCredit
                      ? _success
                      : HomeColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 2),
              if (compact && dateLabel != null)
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: HomeColors.textSecondary(context),
                  ),
                )
              else if (!compact)
                Text(
                  transaction.isSuccess
                      ? l10n.transactionSuccess
                      : (transaction.status ?? l10n.transactionPending),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: transaction.isSuccess
                        ? _success
                        : const Color(0xFFB45309),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String? _formatDate(DateTime? date, {required bool compact}) {
    if (date == null) return null;
    final local = date.toLocal();
    final hour24 = local.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = hour24 >= 12 ? 'PM' : 'AM';
    final time = '$hour12:$minute$ampm';
    if (compact) return time;
    final month = _months[local.month - 1];
    final day = local.day.toString().padLeft(2, '0');
    return '$month $day at $time';
  }
}
