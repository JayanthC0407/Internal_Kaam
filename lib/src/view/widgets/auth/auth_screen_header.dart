import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/auth/auth_colors.dart';

/// Top bar with secondary back button and optional trailing text link.
class AuthScreenHeader extends StatelessWidget {
  const AuthScreenHeader({
    super.key,
    this.onBack,
    this.trailingLabel,
    this.onTrailingTap,
    this.trailingFontSize = 12,
  });

  final VoidCallback? onBack;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;
  final double trailingFontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null)
          SizedBox(
            width: 32,
            height: 32,
            child: Material(
              color: AuthColors.secondaryButtonBackground(context),
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(6),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 22,
                  color: AuthColors.textPrimary(context),
                ),
              ),
            ),
          )
        else
          const SizedBox(width: 32),
        const Spacer(),
        if (trailingLabel != null && onTrailingTap != null)
          TextButton(
            onPressed: onTrailingTap,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(40, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              trailingLabel!,
              style: TextStyle(
                fontSize: trailingFontSize,
                color: AuthColors.brand(context),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
      ],
    );
  }
}
