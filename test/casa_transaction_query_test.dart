import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/retail/casa_transaction.dart';

// OBDX account-transactions (docs/obdx/features/accounts.md §6-7):
// View Options and how each is sent, dates from the bank's business date,
// and when Opening / Closing Balance are shown.

void main() {
  group('View Options (OBDX hooks.js:627-660)', () {
    test('the eight OBDX options, in OBDX order; Specific Day is not offered', () {
      expect(CasaTransactionPeriod.obdxOptions, [
        CasaTransactionPeriod.currentMonth,
        CasaTransactionPeriod.currentDay,
        CasaTransactionPeriod.previousDay,
        CasaTransactionPeriod.previousMonth,
        CasaTransactionPeriod.currentAndPreviousMonth,
        CasaTransactionPeriod.previousQuarter,
        CasaTransactionPeriod.dateRange,
        CasaTransactionPeriod.last10,
      ]);
      expect(CasaTransactionPeriod.obdxOptions, isNot(contains(CasaTransactionPeriod.specificDay)));
    });

    test('default is Current Month, all transactions', () {
      expect(const CasaTransactionQuery().toQueryParameters(), {'searchBy': 'CPR', 'transactionType': 'A'});
    });

    test('Previous Month / Previous Quarter / Last 10 send no dates', () {
      expect(const CasaTransactionQuery(period: CasaTransactionPeriod.previousMonth).toQueryParameters(),
          {'searchBy': 'PMT', 'transactionType': 'A'});
      expect(const CasaTransactionQuery(period: CasaTransactionPeriod.previousQuarter).toQueryParameters(),
          {'searchBy': 'PQT', 'transactionType': 'A'});
      expect(const CasaTransactionQuery(period: CasaTransactionPeriod.last10).toQueryParameters(),
          {'searchBy': 'LNT', 'transactionType': 'A', 'noOfTransactions': 10});
    });
  });

  group('day periods go out as SPD, counted from the bank date (hooks.js:856-881)', () {
    Map<String, dynamic> params(CasaTransactionPeriod p, DateTime bank) =>
        CasaTransactionQuery(period: p, businessDate: bank).toQueryParameters();

    test('Current Day', () {
      expect(params(CasaTransactionPeriod.currentDay, DateTime(2026, 10, 22)),
          {'searchBy': 'SPD', 'transactionType': 'A', 'fromDate': '2026-10-22', 'toDate': '2026-10-22'});
    });

    test('Previous Day, across a month boundary', () {
      expect(params(CasaTransactionPeriod.previousDay, DateTime(2026, 11, 1)),
          {'searchBy': 'SPD', 'transactionType': 'A', 'fromDate': '2026-10-31', 'toDate': '2026-10-31'});
    });

    test('Current & Previous Month: 1st of the previous month → today, also in January', () {
      expect(params(CasaTransactionPeriod.currentAndPreviousMonth, DateTime(2026, 10, 22)),
          {'searchBy': 'SPD', 'transactionType': 'A', 'fromDate': '2026-09-01', 'toDate': '2026-10-22'});
      expect(params(CasaTransactionPeriod.currentAndPreviousMonth, DateTime(2027, 1, 5)),
          {'searchBy': 'SPD', 'transactionType': 'A', 'fromDate': '2026-12-01', 'toDate': '2027-01-05'});
    });

    test('Date Range sends the chosen dates', () {
      final q = CasaTransactionQuery(
        period: CasaTransactionPeriod.dateRange,
        rangeStart: DateTime(2026, 9, 3),
        rangeEnd: DateTime(2026, 9, 30),
      );
      expect(q.toQueryParameters(),
          {'searchBy': 'SPD', 'transactionType': 'A', 'fromDate': '2026-09-03', 'toDate': '2026-09-30'});
    });
  });

  group('other filters', () {
    test('single Amount goes as fromAmount = toAmount; reference as referenceNo; blanks dropped', () {
      const q = CasaTransactionQuery(
        creditDebit: CasaCreditDebitFilter.credits,
        fromAmount: '10.00',
        toAmount: '10.00',
        referenceNumber: ' REF1 ',
      );
      expect(q.toQueryParameters(), {
        'searchBy': 'CPR',
        'transactionType': 'C',
        'fromAmount': '10.00',
        'toAmount': '10.00',
        'referenceNo': 'REF1',
      });
      expect(const CasaTransactionQuery(fromAmount: '  ', referenceNumber: '').toQueryParameters(),
          {'searchBy': 'CPR', 'transactionType': 'A'});
    });
  });

  group('Opening / Closing Balance shown only unfiltered (hooks.js:890-892)', () {
    test('shown for a plain period', () {
      expect(const CasaTransactionQuery().showsBalances, isTrue);
      expect(const CasaTransactionQuery(period: CasaTransactionPeriod.previousQuarter).showsBalances, isTrue);
    });

    test('hidden for Credits/Debits only, an amount, a reference, or Last 10', () {
      expect(const CasaTransactionQuery(creditDebit: CasaCreditDebitFilter.debits).showsBalances, isFalse);
      expect(const CasaTransactionQuery(fromAmount: '5', toAmount: '5').showsBalances, isFalse);
      expect(const CasaTransactionQuery(referenceNumber: 'R').showsBalances, isFalse);
      expect(const CasaTransactionQuery(period: CasaTransactionPeriod.last10).showsBalances, isFalse);
    });
  });
}
