import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/casa_account_detail.dart';
import 'package:ubci_bank/src/core/models/casa_transaction.dart';

void main() {
  group('CasaAccountDetail', () {
    test('parses live OBDX demandDepositAccountDTO payload', () {
      final detail = CasaAccountDetail.fromPayload({
        'status': {
          'result': 'SUCCESSFUL',
          'apiType': 'dda',
        },
        'demandDepositAccountDTO': {
          'id': {
            'displayValue': 'xxxxxxxxxxxx0240',
            'value':
                'A35C603EB68145E44FA11DAE0A7032A254D0FF61B63BC9390E62DF4FD89E2FFFF84F',
          },
          'status': 'ACTIVE',
          'type': 'CSA',
          'currencyCode': 'GBP',
          'productDTO': {
            'description': 'Savings Account - Regular',
          },
          'partyName': 'SAHAM BISWA',
          'branchAddressDTO': {
            'branchName': 'CITY HEAD OFFICE',
            'branchAddress': {
              'postalAddress': {
                'line1': 'Unit 1',
                'line2': 'Block A',
                'city': 'California',
                'country': 'GREAT BRITAIN',
              },
            },
          },
          'holdingPattern': 'SINGLE',
          'unclearFund': {'currency': 'GBP', 'amount': 0},
          'holdAmount': {'currency': 'GBP', 'amount': 0},
          'ddaAccountType': 'SAVING',
          'sweepInLienAmount': {'currency': 'GBP', 'amount': 0},
          'fundsAdvanceLimit': {'currency': 'GBP', 'amount': 0},
          'availableBalance': {'currency': 'GBP', 'amount': 0},
          'currentBalance': {'currency': 'GBP', 'amount': 0},
          'bookBalance': {'currency': 'GBP', 'amount': 0},
          'overDraftLimit': {
            'sanctionedLimitAmount': {'currency': 'GBP', 'amount': 0},
          },
          'nomineeRegistered': false,
        },
      });

      expect(detail, isNotNull);
      expect(
        detail!.id,
        'A35C603EB68145E44FA11DAE0A7032A254D0FF61B63BC9390E62DF4FD89E2FFFF84F',
      );
      expect(detail.displayNumber, 'xxxxxxxxxxxx0240');
      expect(detail.currencyCode, 'GBP');
      expect(detail.productName, 'Savings Account - Regular');
      expect(detail.primaryAccountHolder, 'SAHAM BISWA');
      expect(detail.holdingPattern, 'SINGLE');
      expect(detail.nomineeRegistered, isFalse);
      expect(detail.amountOnHold?.amount, 0);
      expect(detail.underClearingFunds?.amount, 0);
      expect(detail.advanceAgainstUnclearFunds?.amount, 0);
      expect(detail.sweepInAmount?.amount, 0);
      expect(detail.overdraftLimit?.amount, 0);
      expect(detail.todaysOpeningBalance?.amount, 0); // bookBalance fallback
      expect(detail.branch, contains('CITY HEAD OFFICE'));
      expect(detail.branch, contains('Unit 1'));
      expect(detail.branch, contains('GREAT BRITAIN'));
      expect(detail.account.accountType, 'SAVING');
    });

    test('parses detail payload with balances and general fields', () {
      final detail = CasaAccountDetail.fromPayload({
        'id': {
          'displayValue': '000000041052',
          'value': '001~000000041052~TND',
        },
        'status': 'ACTIVE',
        'currencyCode': 'TND',
        'accountNickname': 'Main',
        'availableBalance': {'amount': 1000, 'currency': 'TND'},
        'currentBalance': {'amount': 1100, 'currency': 'TND'},
        'todaysOpeningBalance': {'amount': 900, 'currency': 'TND'},
        'amountOnHold': {'amount': 10, 'currency': 'TND'},
        'holdingPattern': 'Single',
        'primaryAccountHolder': 'Saham Biswa',
        'branchDTO': {
          'branchName': 'CITY HEAD OFFICE',
          'address': 'Unit 1, Block A',
        },
        'productDTO': {'description': 'Saving Account - Regular'},
      });

      expect(detail, isNotNull);
      expect(detail!.id, '001~000000041052~TND');
      expect(detail.todaysOpeningBalance?.amount, 900);
      expect(detail.amountOnHold?.amount, 10);
      expect(detail.holdingPattern, 'Single');
      expect(detail.primaryAccountHolder, 'Saham Biswa');
      expect(detail.branch, contains('CITY HEAD OFFICE'));
      expect(detail.productName, 'Saving Account - Regular');
    });
  });

  group('CasaTransactionsResult', () {
    test('parses transactions and opening/closing balances', () {
      final result = CasaTransactionsResult.fromPayload({
        'currencyCode': 'TND',
        'openingBalance': {'amount': 100000, 'currency': 'TND'},
        'closingBalance': {'amount': 98000, 'currency': 'TND'},
        'transactions': [
          {
            'narrative': 'Kenyon Inc.',
            'transactionAmount': {'amount': 2000, 'currency': 'TND'},
            'creditDebitIndicator': 'D',
            'transactionDate': '2026-03-04T10:00:00',
            'valueDate': '2026-03-04T17:31:00',
            'referenceNumber': '984528347865287688273462',
            'runningBalance': {'amount': 98000, 'currency': 'TND'},
            'status': 'SUCCESS',
          },
          {
            'description': 'Salary',
            'amount': 500,
            'creditDebitIndicator': 'C',
            'valueDate': '2026-03-05T09:00:00',
          },
          {
            'narrative': 'PRINCIPAL Liquidation',
            'transactionAmount': {'amount': 100, 'currency': 'TND'},
            'creditDebitIndicator': 'C',
            'valueDate': '2026-03-06T10:00:00',
          },
          {
            'narrative': 'ATM WITHDRAWAL',
            'transactionAmount': {'amount': 50, 'currency': 'TND'},
            'creditDebitIndicator': 'D',
            'valueDate': '2026-03-06T11:00:00',
          },
        ],
      });

      expect(result.transactions, hasLength(4));
      expect(result.openingBalance?.amount, 100000);
      expect(result.closingBalance?.amount, 98000);
      expect(result.transactions.first.title, 'Kenyon Inc.');
      expect(result.transactions.first.isCredit, isFalse);
      expect(result.transactions.first.reference, '984528347865287688273462');
      expect(result.transactions.first.transactionDate, isNotNull);
      expect(result.transactions.first.valueDate, isNotNull);
      expect(result.transactions.first.runningBalance?.amount, 98000);
      expect(result.transactions[1].isCredit, isTrue);
      expect(result.transactions[2].title, 'Principal Liquidation');
      expect(result.transactions[3].title, 'ATM Withdrawal');
    });
  });
}
