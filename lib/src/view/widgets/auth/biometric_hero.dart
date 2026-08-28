import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/auth/auth_colors.dart';

/// Circular fingerprint hero used on biometric setup and unlock screens.
class BiometricHero extends StatelessWidget {
  const BiometricHero({
    super.key,
    this.size = 120,
    this.inverted = false,
  });

  final double size;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final ring = inverted
        ? Colors.white24
        : AuthColors.brand(context).withValues(alpha: 0.12);
    final inner = inverted ? Colors.white.withValues(alpha: 0.12) : Colors.white;
    final iconColor = inverted ? Colors.white : AuthColors.brand(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ring,
        boxShadow: inverted
            ? null
            : [
                BoxShadow(
                  color: AuthColors.brand(context).withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Center(
        child: Container(
          width: size * 0.78,
          height: size * 0.78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: inner,
            border: Border.all(
              color: inverted
                  ? Colors.white30
                  : AuthColors.brand(context).withValues(alpha: 0.2),
            ),
          ),
          child: Icon(
            Icons.fingerprint_rounded,
            size: size * 0.42,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}
