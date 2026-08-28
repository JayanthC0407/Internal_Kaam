import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';

/// Responsive help overlay shown from the login Help link.
class LoginHelpDialog extends StatelessWidget {
  const LoginHelpDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => const LoginHelpDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final isWide = width >= 768;
    final cardWidth = (isWide ? 520.0 : width - 32).clamp(280.0, 520.0);
    final maxBodyHeight = height * (isWide ? 0.55 : 0.5);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isWide ? 40 : 16,
        vertical: isWide ? 40 : 24,
      ),
      backgroundColor: colors.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isWide ? 20 : 16),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cardWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isWide ? 28 : 20,
            isWide ? 24 : 18,
            isWide ? 28 : 20,
            isWide ? 22 : 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: isWide ? 48 : 42,
                    height: isWide ? 48 : 42,
                    decoration: BoxDecoration(
                      color: colors.otpBoxFilled,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.help_outline_rounded,
                      color: colors.brand,
                      size: isWide ? 26 : 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.loginHelpTitle,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: isWide ? 22 : 18,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.loginHelpSubtitle,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: isWide ? 14 : 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: colors.textSecondary),
                  ),
                ],
              ),
              SizedBox(height: isWide ? 20 : 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxBodyHeight),
                child: SingleChildScrollView(
                  child: Text(
                    l10n.loginHelpBody,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: isWide ? 15 : 14,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
              SizedBox(height: isWide ? 24 : 18),
              Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: isWide ? 120 : double.infinity,
                  ),
                  child: SizedBox(
                    width: isWide ? null : double.infinity,
                    height: isWide ? 48 : 46,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.brand,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        l10n.loginHelpClose,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
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
