import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/view/screens/auth/auth_colors.dart';

class AuthLogoHeader extends StatelessWidget {
  const AuthLogoHeader({
    super.key,
    this.onBack,
    this.trailing,
  });

  static const _logoAsset = 'assets/images/demobank_logo.png';

  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        if (onBack != null) ...[
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: AuthColors.textPrimary(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 4),
        ],
        Image.asset(
          _logoAsset,
          height: 32,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Text(
            l10n.brandName,
            style: TextStyle(
              color: AuthColors.brand(context),
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}
