import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/widgets/brand_logo.dart';
import 'package:ubci_bank/src/view/screens/common/auth/auth_colors.dart';

class AuthLogoHeader extends StatelessWidget {
  const AuthLogoHeader({
    super.key,
    this.onBack,
    this.trailing,
  });

  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
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
        // White in dark mode.
        BrandLogo(height: 32, fallbackColor: AuthColors.brand(context)),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}