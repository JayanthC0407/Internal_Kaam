import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/theme/app_gradients.dart';

/// Phone header of every Transactions screen (designer mock): brand
/// gradient, white square back / Download / Filter buttons, account line,
/// active filter summary, optional balances and OBDX's Amount filter as
/// "Search for amount".
class TransactionsPhoneHeader extends StatelessWidget {
  const TransactionsPhoneHeader({
    super.key,
    required this.title,
    required this.accountLine,
    required this.filterSummary,
    required this.filtered,
    this.opening,
    this.closing,
    required this.amountController,
    required this.onAmountSubmitted,
    required this.onFilter,
    required this.onDownload,
    required this.downloading,
  });

  final String title;
  final String accountLine;
  final String filterSummary;
  final bool filtered;

  /// OBDX shows Opening / Closing Balance for CASA only — loans and
  /// term deposits pass null and the row is left out.
  final String? opening;
  final String? closing;
  final TextEditingController amountController;
  final ValueChanged<String> onAmountSubmitted;
  final VoidCallback onFilter;
  final VoidCallback onDownload;
  final bool downloading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.primary(context),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _HeaderSquareButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: l10n.back,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  downloading
                      ? const SizedBox(
                          width: 40,
                          height: 40,
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : _HeaderSquareButton(
                          icon: Icons.download_rounded,
                          tooltip: l10n.casaDownloadStatement,
                          onTap: onDownload,
                        ),
                  const SizedBox(width: 8),
                  _HeaderSquareButton(
                    icon: Icons.tune_rounded,
                    tooltip: l10n.filter,
                    onTap: onFilter,
                    badge: filtered,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (accountLine.isNotEmpty)
                Text(
                  accountLine,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                filterSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                ),
              ),
              if (opening != null && closing != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _HeaderBalance(
                        label: l10n.casaOpeningBalance,
                        value: opening!,
                      ),
                    ),
                    Expanded(
                      child: _HeaderBalance(
                        label: l10n.casaClosingBalance,
                        value: closing!,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: amountController,
                builder: (context, value, _) => TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  textInputAction: TextInputAction.search,
                  onSubmitted: onAmountSubmitted,
                  style: TextStyle(fontSize: 14, color: colors.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: colors.cardBg,
                    hintText: l10n.casaSearchForAmount,
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: colors.textSecondary,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l10n.casaFilterReset,
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: colors.textSecondary,
                            ),
                            onPressed: () {
                              amountController.clear();
                              onAmountSubmitted('');
                            },
                          ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White square header button from the mock (back / download / filter).
class _HeaderSquareButton extends StatelessWidget {
  const _HeaderSquareButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 22, color: colors.textPrimary),
                if (badge)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderBalance extends StatelessWidget {
  const _HeaderBalance({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}
