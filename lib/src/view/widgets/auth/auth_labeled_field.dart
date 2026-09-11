import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_form_styles.dart';

Widget _fieldLabel({
  required AppColors colors,
  required String label,
  required bool required,
}) {
  if (!required) {
    return Text(label, style: AuthFormStyles.fieldLabel(colors));
  }
  return Text.rich(
    TextSpan(
      style: AuthFormStyles.fieldLabel(colors),
      children: [
        TextSpan(text: label),
        TextSpan(
          text: ' *',
          style: TextStyle(
            color: colors.error,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}

/// Label-above text field matching the login form pattern.
class AuthLabeledField extends StatelessWidget {
  const AuthLabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helperText,
    this.enabled = true,
    this.required = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
    this.validator,
    this.autovalidateMode,
    this.suffixIcon,
    this.onFieldSubmitted,
    this.onChanged,
    this.autocorrect = true,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helperText;
  final bool enabled;
  final bool required;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
  final Widget? suffixIcon;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autocorrect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fieldLabel(colors: colors, label: label, required: required),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          inputFormatters: inputFormatters,
          autocorrect: autocorrect,
          validator: validator,
          autovalidateMode: autovalidateMode,
          onFieldSubmitted: onFieldSubmitted,
          onChanged: onChanged,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          decoration: AuthFormStyles.inputDecoration(
            colors: colors,
            hintText: hint,
            suffixIcon: suffixIcon,
          ).copyWith(
            helperText: helperText,
            helperStyle: TextStyle(
              fontSize: 11,
              color: colors.textSecondary,
              height: 1.25,
            ),
            helperMaxLines: 2,
          ),
        ),
      ],
    );
  }
}

/// Label-above dropdown matching [AuthLabeledField] spacing.
class AuthLabeledDropdown<T> extends StatelessWidget {
  const AuthLabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.required = false,
    this.enabled = true,
    this.validator,
    this.hint,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool required;
  final bool enabled;
  final FormFieldValidator<T>? validator;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fieldLabel(colors: colors, label: label, required: required),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          validator: validator,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: colors.textSecondary,
          ),
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          dropdownColor: colors.cardBg,
          decoration: AuthFormStyles.inputDecoration(
            colors: colors,
            hintText: hint,
          ),
        ),
      ],
    );
  }
}

/// Date field with the same label + border treatment.
///
/// The date picker opens only from the calendar icon so tapping the value
/// area does not unexpectedly launch the picker.
class AuthLabeledDateField extends StatelessWidget {
  const AuthLabeledDateField({
    super.key,
    required this.label,
    required this.valueText,
    required this.onTap,
    this.required = false,
    this.enabled = true,
    this.placeholder,
  });

  final String label;
  final String valueText;
  final VoidCallback onTap;
  final bool required;
  final bool enabled;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final empty = valueText.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fieldLabel(colors: colors, label: label, required: required),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: AuthFormStyles.inputDecoration(
            colors: colors,
            suffixIcon: IconButton(
              onPressed: enabled ? onTap : null,
              tooltip: label,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: Icon(
                Icons.calendar_today_outlined,
                color: enabled ? colors.textSecondary : colors.inputHint,
                size: 18,
              ),
            ),
          ),
          child: Text(
            empty ? (placeholder ?? '') : valueText,
            style: TextStyle(
              color: empty ? colors.inputHint : colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
