import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/account_type_option.dart';

void main() {
  group('AccountTypeOption', () {
    test('parses flat enumRepresentations list', () {
      final options = AccountTypeOption.listFromPayload({
        'enumRepresentations': [
          {'code': 'SAV', 'description': 'Savings'},
          {'code': 'CUR', 'description': 'Current'},
        ],
      });

      expect(options, hasLength(2));
      expect(options.first.code, 'SAV');
      expect(options.first.label, 'Savings');
    });

    test('parses nested enumRepresentations[].data from live OBDX', () {
      final options = AccountTypeOption.listFromPayload({
        'status': {'result': 'SUCCESSFUL'},
        'enumRepresentations': [
          {
            'data': [
              {
                'code': 'CSA',
                'value': 'CSA',
                'description': 'Demand Deposit',
                'ordinal': 1,
              },
              {
                'code': 'LON',
                'value': 'LON',
                'description': 'Loan',
                'ordinal': 2,
              },
              {
                'code': 'TRD',
                'value': 'TRD',
                'description': 'Term Deposit',
                'ordinal': 3,
              },
              {
                'code': 'CCA',
                'value': 'CCA',
                'description': 'Credit Card',
                'ordinal': 4,
              },
            ],
          },
        ],
      });

      expect(options, hasLength(4));
      expect(options.map((e) => e.code).toList(), ['CSA', 'LON', 'TRD', 'CCA']);
      expect(options.first.label, 'Demand Deposit');
    });
  });
}
