import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/screens/auth/auth_colors.dart';

/// 6-digit PIN display + numeric keypad for passcode setup/unlock.
class AuthPinPad extends StatelessWidget {
  const AuthPinPad({
    super.key,
    required this.length,
    required this.maxLength,
    required this.onDigit,
    required this.onBackspace,
    this.obscure = true,
  });

  final int length;
  final int maxLength;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 32;
        final keySize = Responsive.pinKeySize(available);
        final gap = math.max(8.0, keySize * 0.12);
        final dotSize = math.max(10.0, keySize * 0.2);
        final compact = Responsive.of(context).isCompactHeight;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(maxLength, (index) {
                final filled = index < length;
                return Container(
                  width: dotSize,
                  height: dotSize,
                  margin: EdgeInsets.symmetric(horizontal: gap * 0.65),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        filled ? AuthColors.brand(context) : Colors.transparent,
                    border: Border.all(
                      color: filled
                          ? AuthColors.brand(context)
                          : AuthColors.inputBorder(context),
                      width: 1.5,
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: compact ? 20 : 36),
            _Keypad(
              onDigit: onDigit,
              onBackspace: onBackspace,
              keySize: keySize,
              gap: gap,
            ),
          ],
        );
      },
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.keySize,
    required this.gap,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final double keySize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'back'],
    ];
    final fontSize = (keySize * 0.39).clamp(18.0, 28.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows.map((row) {
        return Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key.isEmpty) {
                return SizedBox(width: keySize, height: keySize);
              }
              if (key == 'back') {
                return _Key(
                  size: keySize,
                  onTap: onBackspace,
                  child: Icon(
                    Icons.backspace_outlined,
                    size: fontSize,
                    color: AuthColors.textPrimary(context),
                  ),
                );
              }
              return _Key(
                size: keySize,
                onTap: () => onDigit(key),
                child: Text(
                  key,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: AuthColors.textPrimary(context),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.onTap,
    required this.child,
    required this.size,
  });

  final VoidCallback onTap;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AuthColors.surfaceLevel0(context),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: child),
        ),
      ),
    );
  }
}
