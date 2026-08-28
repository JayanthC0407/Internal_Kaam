import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/loan_account.dart';

void main() {
  group('LoanAccountsSummary', () {
    test('sums sanctioned and outstanding and computes percent', () {
      final summary = LoanAccountsSummary.fromPayload({
        'status': {'result': 'SUCCESSFUL'},
        'loans': [
          {
            'id': {'value': 'L1', 'displayValue': 'xxxx1111'},
            'currencyCode': 'GBP',
            'sanctionedAmount': {'amount': 100000, 'currency': 'GBP'},
            'outstandingAmount': {'amount': 90000, 'currency': 'GBP'},
            'productDTO': {'description': 'Home Loan'},
          },
        ],
      });

      expect(summary.loans, hasLength(1));
      expect(summary.totalBorrowing, 100000);
      expect(summary.totalOutstanding, 90000);
      expect(summary.outstandingPercent, 90);
      expect(summary.primaryCurrency, 'GBP');
      expect(summary.loans.first.title, 'Home Loan');
    });

    test('prefers summary totals when present', () {
      final summary = LoanAccountsSummary.fromPayload({
        'summary': {
          'totalBorrowing': {'amount': 200000, 'currency': 'GBP'},
          'totalOutstanding': {'amount': 50000, 'currency': 'GBP'},
        },
        'loans': [],
      });

      expect(summary.totalBorrowing, 200000);
      expect(summary.totalOutstanding, 50000);
      expect(summary.outstandingPercent, 25);
    });

    test('handles empty payload', () {
      final summary = LoanAccountsSummary.fromPayload({
        'status': {'result': 'SUCCESSFUL'},
      });
      expect(summary.isEmpty, isTrue);
      expect(summary.outstandingPercent, 0);
    });
  });
}
