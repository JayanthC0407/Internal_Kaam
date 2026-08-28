import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/auth/auth_colors.dart';

class AuthQuickAccessOption extends StatelessWidget {
  const AuthQuickAccessOption({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(icon, size: 24, color: AuthColors.textPrimary(context)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          color: AuthColors.textPrimary(context),
                          height: 1.45,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AuthColors.textSecondary(context),
                            height: 1.35,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AuthColors.textSecondary(context),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: AuthColors.inputBorder(context),
          ),
      ],
    );
  }
}
