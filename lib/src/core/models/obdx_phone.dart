import 'package:ubci_bank/src/core/constants/app_constants.dart';

/// OBDX `com.ofss.digx.app.common.Phone` — sent as a JSON object, not a string.
class ObdxPhone {
  const ObdxPhone({
    required this.countryCode,
    required this.areaCode,
    required this.number,
  });

  final String countryCode;
  final String areaCode;
  final String number;

  Map<String, dynamic> toJson() => {
        'countryCode': countryCode,
        'areaCode': areaCode,
        'number': number,
      };

  /// Builds an OBDX phone object from free-text mobile input.
  factory ObdxPhone.fromPlainInput(String input) {
    var digits = input.replaceAll(RegExp(r'[^\d+]'), '').trim();
    var countryCode = AppConstants.defaultPhoneCountryCode;
    var number = digits;

    if (digits.startsWith('+')) {
      digits = digits.substring(1);
    } else if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }

    if (input.trim().startsWith('+') || input.trim().startsWith('00')) {
      if (countryCode.isNotEmpty &&
          digits.startsWith(countryCode) &&
          digits.length > countryCode.length + 6) {
        number = digits.substring(countryCode.length);
      } else {
        for (final len in [3, 2, 1]) {
          if (digits.length > len + 6) {
            countryCode = digits.substring(0, len);
            number = digits.substring(len);
            break;
          }
        }
      }
    } else if (countryCode.isNotEmpty &&
        digits.startsWith(countryCode) &&
        digits.length > countryCode.length + 6) {
      number = digits.substring(countryCode.length);
    } else {
      number = digits;
    }

    return ObdxPhone(
      countryCode: countryCode,
      areaCode: '',
      number: number,
    );
  }
}
