import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';

void main() {
  group('CasaAccount', () {
    test('parses Offshore Postman-shaped demandDeposit payload', () {
      final accounts = CasaAccount.listFromPayload({
        'status': {'result': 'SUCCESSFUL'},
        'accounts': [
          {
            'id': {
              'displayValue': '000000041052',
              'value': '001~000000041052~TND',
            },
            'status': 'ACTIVE',
            'currencyCode': 'TND',
            'accountType': 'SAVING',
            'accountNickname': 'Main savings',
            'availableBalance': {'amount': 1250.55, 'currency': 'TND'},
            'currentBalance': {'amount': 1300.0, 'currency': 'TND'},
            'productDTO': {'description': 'Savings Account'},
          },
          {
            'id': {
              'displayValue': '000000099999',
              'value': '001~000000099999~USD',
            },
            'status': 'DORMANT',
            'currencyCode': 'USD',
            'availableBalance': 100,
          },
        ],
      });

      expect(accounts, hasLength(2));
      expect(accounts.first.id, '001~000000041052~TND');
      expect(accounts.first.displayNumber, '000000041052');
      expect(accounts.first.currencyCode, 'TND');
      expect(accounts.first.availableBalance?.amount, 1250.55);
      expect(accounts.first.title, 'Main savings');
      expect(accounts.first.maskedNumber.endsWith('1052'), isTrue);
      expect(accounts.last.isDormant, isTrue);
      expect(accounts.last.availableBalance?.amount, 100);
    });

    test('summary does not mix currencies', () {
      final summary = CasaAccountsSummary.fromAccounts([
        CasaAccount(
          id: 'a',
          displayNumber: '1111',
          status: 'ACTIVE',
          currencyCode: 'TND',
          availableBalance: const MoneyAmount(amount: 100, currency: 'TND'),
        ),
        CasaAccount(
          id: 'b',
          displayNumber: '2222',
          status: 'ACTIVE',
          currencyCode: 'USD',
          availableBalance: const MoneyAmount(amount: 50, currency: 'USD'),
        ),
        CasaAccount(
          id: 'c',
          displayNumber: '3333',
          status: 'ACTIVE',
          currencyCode: 'TND',
          availableBalance: const MoneyAmount(amount: 25, currency: 'TND'),
        ),
      ]);

      expect(summary.totalsByCurrency['TND'], 125);
      expect(summary.totalsByCurrency['USD'], 50);
      expect(summary.hasMultipleCurrencies, isTrue);
      expect(summary.primaryCurrency, 'TND');
      expect(summary.primaryTotal, 125);
    });

    test('hero total prefers summary.totalActiveAvailableBalance', () {
      final summary = CasaAccountsSummary.fromPayload({
        'status': {'result': 'SUCCESSFUL'},
        'accounts': [
          {
            'id': {
              'displayValue': 'xxxxxxxxxxxx0139',
              'value': 'acc-1',
            },
            'status': 'ACTIVE',
            'currencyCode': 'GBP',
            'availableBalance': {'currency': 'GBP', 'amount': 140000},
            'currentBalance': {'currency': 'GBP', 'amount': 1640000},
          },
          {
            'id': {
              'displayValue': 'xxxxxxxxxxxx0240',
              'value': 'acc-2',
            },
            'status': 'ACTIVE',
            'currencyCode': 'GBP',
            'availableBalance': {'currency': 'GBP', 'amount': 0},
            'currentBalance': {'currency': 'GBP', 'amount': 0},
          },
        ],
        'summary': {
          'items': [
            {
              'accountType': 'CSA',
              'totalAvailableBalance': {
                'currency': 'GBP',
                'amount': 140000,
              },
              'totalActiveAvailableBalance': {
                'currency': 'GBP',
                'amount': 1640000,
              },
            },
          ],
        },
      });

      expect(summary.accounts, hasLength(2));
      expect(summary.accounts.first.displayBalance?.amount, 140000);
      expect(summary.primaryCurrency, 'GBP');
      expect(summary.primaryTotal, 1640000);
    });

    test('parses wrapped HTTP body map from Dio layer', () {
      final accounts = CasaAccount.listFromPayload({
        'statusCode': 200,
        'body': {
          'accounts': [
            {
              'id': {'displayValue': '12345678', 'value': 'x'},
              'status': 'ACTIVE',
              'currencyCode': 'EUR',
              'currentBalance': '42.10',
            },
          ],
        },
      });

      expect(accounts, hasLength(1));
      expect(accounts.single.currentBalance?.amount, 42.10);
      expect(accounts.single.displayBalance?.amount, 42.10);
    });
  });
}
