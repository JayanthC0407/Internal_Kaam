import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/utils/email_validator.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';

void main() {
  group('EmailValidator', () {
    test('rejects incomplete and invalid addresses', () {
      expect(EmailValidator.isValid(null), isFalse);
      expect(EmailValidator.isValid(''), isFalse);
      expect(EmailValidator.isValid('ytdg@'), isFalse);
      expect(EmailValidator.isValid('ytdg@domain'), isFalse);
      expect(EmailValidator.isValid('plainaddress'), isFalse);
      expect(EmailValidator.isValid('@example.com'), isFalse);
    });

    test('accepts valid addresses', () {
      expect(EmailValidator.isValid('user@example.com'), isTrue);
      expect(EmailValidator.isValid('  user.name+tag@bank.co.uk  '), isTrue);
    });
  });

  group('MoneyFormat', () {
    test('uses currency codes not symbols', () {
      expect(
        MoneyFormat.format(4210.9, currencyCode: 'GBP'),
        'GBP 4,210.90',
      );
      expect(
        MoneyFormat.format(1000, currencyCode: 'USD'),
        'USD 1,000.00',
      );
      expect(
        MoneyFormat.format(1000, currencyCode: 'EUR'),
        'EUR 1,000.00',
      );
    });

    test('defaults to GBP when currency code is empty', () {
      expect(
        MoneyFormat.format(1000, currencyCode: ''),
        'GBP 1,000.00',
      );
    });

    test('keeps other currency codes', () {
      expect(
        MoneyFormat.format(1000, currencyCode: 'TND'),
        'TND 1,000.00',
      );
    });
  });
}
