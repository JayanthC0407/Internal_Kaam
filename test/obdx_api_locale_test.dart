import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/config/app_locale_holder.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

void main() {
  tearDown(() {
    AppLocaleHolder.instance.update(const Locale('en'));
  });

  group('ObdxApiUtils.appendLocaleQuery', () {
    test('uses ? for paths without query string', () {
      AppLocaleHolder.instance.update(const Locale('ar'));
      expect(
        ObdxApiUtils.appendLocaleQuery('/digx-infra/login/v1/login'),
        '/digx-infra/login/v1/login?locale=ar',
      );
    });

    test('uses & when path already has query params', () {
      AppLocaleHolder.instance.update(const Locale('fr'));
      expect(
        ObdxApiUtils.appendLocaleQuery(
          '/digx-common/account/cz/v1/czaccounts?accountCode=ALL',
        ),
        '/digx-common/account/cz/v1/czaccounts?accountCode=ALL&locale=fr',
      );
    });

    test('allows explicit locale override', () {
      expect(
        ObdxApiUtils.appendLocaleQuery('/digx-common/user/v1/me', locale: 'it'),
        '/digx-common/user/v1/me?locale=it',
      );
    });
  });

  group('LocaleConfig.acceptLanguageHeader', () {
    test('prioritizes Arabic when selected', () {
      expect(LocaleConfig.acceptLanguageHeader('ar'), 'ar,en;q=0.8');
    });

    test('includes Arabic fallback for English', () {
      expect(LocaleConfig.acceptLanguageHeader('en'), 'en,ar;q=0.9');
    });
  });
}
