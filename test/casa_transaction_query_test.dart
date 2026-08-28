import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/casa_transaction.dart';

void main() {
  group('CasaTransactionQuery', () {
    test('default matches existing Postman params', () {
      const query = CasaTransactionQuery();
      expect(query.searchBy, 'CPR');
      expect(query.transactionType, 'A');
      expect(query.isDefault, isTrue);
      expect(query.toQueryParameters(), {
        'searchBy': 'CPR',
        'transactionType': 'A',
      });
    });

    test('omits empty amount and reference', () {
      const query = CasaTransactionQuery(
        period: CasaTransactionPeriod.previousMonth,
        creditDebit: CasaCreditDebitFilter.debits,
        amount: '  ',
        referenceNumber: '',
      );
      expect(query.toQueryParameters(), {
        'searchBy': 'PM',
        'transactionType': 'D',
      });
    });

    test('includes amount and reference when set', () {
      const query = CasaTransactionQuery(
        period: CasaTransactionPeriod.currentDay,
        creditDebit: CasaCreditDebitFilter.credits,
        amount: '10.00',
        referenceNumber: '000ZTRF2235609QM',
      );
      expect(query.toQueryParameters(), {
        'searchBy': 'C',
        'transactionType': 'C',
        'amount': '10.00',
        'referenceNumber': '000ZTRF2235609QM',
      });
    });
  });
}
