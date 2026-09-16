import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/corp/corp_account.dart';
import 'package:ubci_bank/src/core/utils/corp/corp_money_format.dart';

/// Trimmed copy of the real `GET /digx-common/account/v1/accounts` response
/// from the Corporate "LOGIN to DASHBOARD" capture (entry #68) — one
/// overdrawn AED current account, one AED savings account, and the
/// `summary.items[]` roll-up for CSA / TRD / LON.
Map<String, dynamic> _capturedAccountsResponse() => {
      'status': {'result': 'SUCCESSFUL', 'apiType': 'account'},
      'accounts': [
        {
          'id': {
            'displayValue': 'xxxxxxxxxxxx1022',
            'value': 'C43E3D8ECF248543BA48E08E333443B9E02F0EE6C4104DF5F57C87C2BA139795AC',
          },
          'partyId': {
            'displayValue': '***401',
            'value': 'C43E3BFA81256601002CD05D1678F2CD4099827FA144',
          },
          'displayName': 'LC TEST4',
          'status': 'ACTIVE',
          'type': 'CSA',
          'currencyCode': 'AED',
          'branchCode': '006',
          'productDTO': {
            'description': 'Current Accounts - Regular',
            'productId': 'CACCA',
          },
          'partyName': 'LC TEST4',
          'module': 'CON',
          'defaultAccount': false,
          'ddaAccountType': 'CURRENT',
          'availableBalance': {'currency': 'AED', 'amount': -1000},
          'currentBalance': {'currency': 'AED', 'amount': -1000},
          'equivalentAvailableBalance': {'currency': 'GBP', 'amount': -272.479},
        },
        {
          'id': {
            'displayValue': 'xxxxxxxxxxxx1033',
            'value': 'C43E3D8ECF248543BA48E08E333443B8E1E08957A662000E76CCBD61B17A2DF8F1',
          },
          'partyId': {
            'displayValue': '***401',
            'value': 'C43E3BFA81256601002CD05D1678F2CD4099827FA144',
          },
          'displayName': 'LC TEST4',
          'status': 'ACTIVE',
          'type': 'CSA',
          'currencyCode': 'AED',
          'productDTO': {
            'description': 'Savings Account - Regular',
            'productId': 'SAVIN',
          },
          'partyName': 'LC TEST4',
          'module': 'CON',
          'defaultAccount': true,
          'ddaAccountType': 'SAVING',
          'availableBalance': {'currency': 'AED', 'amount': 1049601.58},
          'currentBalance': {'currency': 'AED', 'amount': 1049601.58},
        },
      ],
      'summary': {
        'items': [
          {
            'accountType': 'CSA',
            'partyName': 'LC TEST4',
            'count': 3,
            'totalAvailableBalance': {'currency': 'GBP', 'amount': 385721.909},
            'totalActiveAvailableBalance': {
              'currency': 'GBP',
              'amount': 385994.388,
            },
          },
          {
            'accountType': 'TRD',
            'count': 0,
            'totalAvailableBalance': {'currency': 'GBP', 'amount': 0},
            'totalActiveInvestmentAmount': {'currency': 'GBP', 'amount': 0},
          },
          {
            'accountType': 'LON',
            'count': 0,
            'totalActiveOutstandingBalance': {'currency': 'GBP', 'amount': 0},
          },
        ],
      },
    };

void main() {
  group('CorpAccount', () {
    test('parses the captured corporate accounts payload', () {
      final summary =
          CorpAccountsSummary.fromPayload(_capturedAccountsResponse());

      expect(summary.accounts, hasLength(2));
      expect(summary.casaAccounts, hasLength(2));
      expect(summary.depositAccounts, isEmpty);
      expect(summary.loanAccounts, isEmpty);

      final current = summary.accounts.first;
      expect(
        current.id,
        'C43E3D8ECF248543BA48E08E333443B9E02F0EE6C4104DF5F57C87C2BA139795AC',
      );
      expect(current.displayNumber, 'xxxxxxxxxxxx1022');
      expect(current.group, CorpAccountGroup.casa);
      expect(current.currencyCode, 'AED');
      expect(current.partyLabel, 'LC TEST4');
      expect(current.accountTypeLabel, 'Current Accounts - Regular');
      expect(current.availableBalance?.amount, -1000);
      expect(current.displayBalance?.isNegative, isTrue);
      expect(current.isCurrent, isTrue);
      expect(current.isDefault, isFalse);
      expect(current.equivalentAvailableBalance?.currency, 'GBP');
    });

    test('masks the account number as the summary grid displays it', () {
      final summary =
          CorpAccountsSummary.fromPayload(_capturedAccountsResponse());
      expect(summary.accounts.first.groupedMaskedNumber, 'XXXX XXXX XXXX 1022');
      expect(summary.accounts.first.lastFour, '1022');
    });

    test('reads the host summary roll-up per product group', () {
      final summary =
          CorpAccountsSummary.fromPayload(_capturedAccountsResponse());

      final casa = summary.summaryFor(CorpAccountGroup.casa);
      expect(casa, isNotNull);
      expect(casa!.count, 3);
      expect(casa.headlineTotal?.amount, closeTo(385994.388, 0.001));
      expect(casa.headlineTotal?.currency, 'GBP');

      expect(summary.summaryFor(CorpAccountGroup.deposit)?.count, 0);
      expect(summary.summaryFor(CorpAccountGroup.loan)?.count, 0);
    });

    test('unwraps the wrapHttpResponse envelope', () {
      final summary = CorpAccountsSummary.fromPayload({
        'statusCode': 200,
        'headers': <String, dynamic>{},
        'body': _capturedAccountsResponse(),
      });
      expect(summary.accounts, hasLength(2));
    });

    test('totals per currency never mix unlike currencies', () {
      final summary =
          CorpAccountsSummary.fromPayload(_capturedAccountsResponse());
      final totals = summary.totalsByCurrency(CorpAccountGroup.casa);
      expect(totals.keys, ['AED']);
      expect(totals['AED'], closeTo(1048601.58, 0.001));
    });

    test('lists distinct product names for the type filter', () {
      final summary =
          CorpAccountsSummary.fromPayload(_capturedAccountsResponse());
      expect(
        summary.productNamesIn(CorpAccountGroup.casa),
        ['Current Accounts - Regular', 'Savings Account - Regular'],
      );
    });

    test('groupOverride tags deposits fetched from td/v1/deposit', () {
      // The captured deposit response for this party is an empty list; a
      // populated one has no `type` field, which is why the group is set by
      // the caller rather than read from the payload.
      final deposits = CorpAccount.listFromPayload(
        {
          'status': {'result': 'SUCCESSFUL', 'apiType': 'td'},
          'accounts': [
            {
              'id': {'displayValue': 'xxxxxxxxxxxx2044', 'value': 'TD-1'},
              'status': 'ACTIVE',
              'currencyCode': 'AED',
              'principalAmount': {'currency': 'AED', 'amount': 50000},
              'maturityAmount': {'currency': 'AED', 'amount': 52500},
              'productDTO': {'description': 'Term Deposit - Regular'},
              'partyName': 'LC TEST4',
            },
          ],
        },
        groupOverride: CorpAccountGroup.deposit,
      );

      expect(deposits, hasLength(1));
      expect(deposits.first.group, CorpAccountGroup.deposit);
      // A deposit shows what it holds, not an available balance.
      expect(deposits.first.displayBalance?.amount, 50000);
    });

    test('mergeGroup replaces only the given group', () {
      final summary =
          CorpAccountsSummary.fromPayload(_capturedAccountsResponse());
      final loan = CorpAccount.fromJson(
        {
          'id': {'displayValue': 'xxxxxxxxxxxx3055', 'value': 'LN-1'},
          'status': 'ACTIVE',
          'currencyCode': 'GBP',
          'outstandingBalance': {'currency': 'GBP', 'amount': 12000},
          'productDTO': {'description': 'Term Loan'},
        },
        groupOverride: CorpAccountGroup.loan,
      );

      final merged = summary.mergeGroup(CorpAccountGroup.loan, [loan]);
      expect(merged.casaAccounts, hasLength(2));
      expect(merged.loanAccounts, hasLength(1));
      expect(merged.loanAccounts.first.displayBalance?.amount, 12000);

      // Merging an empty list clears that group without touching CASA.
      final cleared = merged.mergeGroup(CorpAccountGroup.loan, const []);
      expect(cleared.loanAccounts, isEmpty);
      expect(cleared.casaAccounts, hasLength(2));
    });
  });

  group('CorpMoneyFormat', () {
    test('puts the sign before the currency code', () {
      expect(
        CorpMoneyFormat.format(-1000, currencyCode: 'AED'),
        '-AED 1,000.00',
      );
      expect(
        CorpMoneyFormat.format(1049601.58, currencyCode: 'aed'),
        'AED 1,049,601.58',
      );
    });

    test('renders the amount alone when no currency is known', () {
      expect(CorpMoneyFormat.format(250.5), '250.50');
    });

    test('masks behind the eye toggle but keeps the currency', () {
      expect(CorpMoneyFormat.masked('AED'), 'AED ••••');
      expect(CorpMoneyFormat.masked(''), '••••');
    });

    test('formatAmount falls back to the account currency', () {
      final summary =
          CorpAccountsSummary.fromPayload(_capturedAccountsResponse());
      expect(
        CorpMoneyFormat.formatAmount(
          summary.accounts.last.displayBalance,
          fallbackCurrency: summary.accounts.last.currencyCode,
        ),
        'AED 1,049,601.58',
      );
      expect(CorpMoneyFormat.formatAmount(null), '—');
    });
  });
}
