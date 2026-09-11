import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/utils/password_policy.dart';

/// Live-updating list of password rules with a check/cross per rule.
/// Rebuilds cheaply on every keystroke — keep it a `StatelessWidget` driven
/// by the parent's `setState`, same pattern as the rest of the auth forms.
class PasswordPolicyChecklist extends StatelessWidget {
  const PasswordPolicyChecklist({
    super.key,
    required this.password,
    required this.username,
    required this.title,
    required this.minLengthLabel,
    required this.uppercaseLabel,
    required this.lowercaseLabel,
    required this.numberLabel,
    required this.specialCharLabel,
    required this.noUsernameLabel,
  });

  final String password;
  final String username;
  final String title;
  final String minLengthLabel;
  final String uppercaseLabel;
  final String lowercaseLabel;
  final String numberLabel;
  final String specialCharLabel;
  final String noUsernameLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final rules = <_Rule>[
      _Rule(minLengthLabel, PasswordPolicy.hasMinLength(password)),
      _Rule(uppercaseLabel, PasswordPolicy.hasUppercase(password)),
      _Rule(lowercaseLabel, PasswordPolicy.hasLowercase(password)),
      _Rule(numberLabel, PasswordPolicy.hasDigit(password)),
      _Rule(specialCharLabel, PasswordPolicy.hasSpecialChar(password)),
      _Rule(
        noUsernameLabel,
        PasswordPolicy.doesNotContainUsername(password, username),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final rule in rules)
                _RuleChip(rule: rule, colors: colors),
            ],
          ),
        ],
      ),
    );
  }
}

class _Rule {
  const _Rule(this.label, this.met);
  final String label;
  final bool met;
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.rule, required this.colors});

  final _Rule rule;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final color = rule.met ? colors.success : colors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          rule.met ? Icons.check_circle : Icons.circle_outlined,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 5),
        Text(
          rule.label,
          style: TextStyle(fontSize: 11.5, color: color, height: 1.2),
        ),
      ],
    );
  }
}
