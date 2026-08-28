import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/auth/auth_colors.dart';

/// Pill-shaped secondary action (e.g. "Skip for now" on biometric setup).
class AuthSecondaryButton extends StatelessWidget {
  const AuthSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AuthColors.secondaryButtonBackground(context),
        foregroundColor: AuthColors.textPrimary(context),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        elevation: 0,
      ),
      child: Text(
        label,
style: const TextStyle(
  fontFamily: 'Rubik',
  fontSize: 16,
  fontWeight: FontWeight.w500,
),
      ),
    );
  }
}
