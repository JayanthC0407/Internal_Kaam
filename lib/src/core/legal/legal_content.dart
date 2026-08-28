import 'package:flutter/services.dart';

/// Asset paths and loaders for legal copy shown in the app.
///
/// To update Terms and Conditions, replace the contents of
/// `assets/legal/terms_and_conditions.txt` — no Dart code changes needed.
class LegalContent {
  LegalContent._();

  static const String termsAndConditionsAsset =
      'assets/legal/terms_and_conditions.txt';

  static Future<String> loadTermsAndConditions() {
    return rootBundle.loadString(termsAndConditionsAsset);
  }
}
