import 'package:flutter/services.dart';
import 'package:ubci_bank/src/core/utils/common/date_of_birth_format.dart';

/// Accepts digits only; auto-inserts `/` as `dd/MM/yyyy` while typing.
class DateOfBirthInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > DateOfBirthFormat.maxDigitCount) {
      return oldValue;
    }

    final formatted = DateOfBirthFormat.formatDigits(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
