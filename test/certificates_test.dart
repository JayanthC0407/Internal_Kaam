import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/retail/certificate_models.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/apis/retail/obdx_certificates_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/statement_download.dart';
import 'package:ubci_bank/src/infra/repositories/retail/certificates_repository.dart';
import 'package:ubci_bank/src/view/providers/retail/certificates_providers.dart';
import 'package:ubci_bank/src/view/screens/retail/certificates/certificates_screens.dart';

// Shapes follow OBDX interest-certificate-all, balance-certificate and
// tax-deduction-at-source (docs/obdx/features/certificates.md). Values are
// made up.

Map<String, dynamic> _interest(String acc, num amount) => {
      'accountId': {'value': acc, 'displayValue': 'xxxx$acc'},
      'productName': 'Savings Account - Regular',
      'date': '2026-05-08T00:00:00',
      'interestAmount': {'amount': amount, 'currency': 'GBP'},
    };

void main() {
  group('model', () {
    test('categories from roles: CASA, Deposits (TD or RD), Loans', () {
      expect(CertificateCategory.fromRoles(['CASARole', 'RDRole', 'LoanRole']), [
        CertificateCategory.casa,
        CertificateCategory.deposits,
        CertificateCategory.loans,
      ]);
      expect(CertificateCategory.fromRoles(['CorporateUser']), isEmpty);
    });

    test('financial years: last 3 by branch month; current FY ends today, padded', () {
      expect(FinancialYear.list(DateTime(2026, 10, 28)).map((y) => y.label), ['2024-2025', '2025-2026', '2026-2027']);
      expect(FinancialYear.list(DateTime(2026, 2, 5)).map((y) => y.label), ['2023-2024', '2024-2025', '2025-2026']);
      expect(const FinancialYear(2025).range(DateTime(2026, 1, 5)), ('2025-04-01', '2026-01-05'));
      expect(const FinancialYear(2024).range(DateTime(2026, 1, 5)), ('2024-04-01', '2025-03-31'));
      expect(certificateEarliestDate(DateTime(2026, 10, 28)), DateTime(2024, 4, 1));
    });

    test('balance months: six, even on the 31st (OBDX skips some)', () {
      final months = balanceCertificateMonths(DateTime(2026, 3, 31));
      expect(months.map((m) => '${m.year}-${m.month}'), ['2026-3', '2026-2', '2026-1', '2025-12', '2025-11', '2025-10']);
    });

    test('interest: single and All shapes', () {
      final single = InterestRow.listFromPayload({
        'demandDepositInterestListResponseDTO': {
          'demandDepositInterestList': [_interest('0047', 10000)],
        },
      });
      expect(single.single.account, 'xxxx0047');
      final all = InterestRow.listFromPayload({
        'termDepositInterestResponseDTOs': [
          {
            'termDepositInterestListResponseDTO': {
              'accountInterests': [_interest('1', 5), _interest('2', 6)],
            },
          },
        ],
      });
      expect(all.map((r) => r.amount!.amount), [5, 6]);
    });

    test('balance and TDS parsing', () {
      final b = BalanceCertificate.fromPayload({
        'demandDeposits': [
          {'account': {'value': 'A', 'displayValue': 'xxA'}, 'balance': {'amount': 10, 'currency': 'GBP'}},
        ],
        'termDeposits': [
          {'account': {'value': 'T', 'displayValue': 'xxT'}, 'depostiNumber': '3', 'balance': {'amount': 5, 'currency': 'GBP'}},
        ],
      });
      expect(b.casa.single.account, 'xxA');
      expect(b.deposits.single.depositNumber, '3');

      final tds = TdsRow.listFromPayload({
        'depositTaxPaidListResponseDTO': [
          {
            'totalInterest': {'amount': 100, 'currency': 'GBP'},
            'totalTaxPaid': {'amount': 10, 'currency': 'GBP'},
            'depositTaxPaidDTOs': [
              {'accountId': {'value': 'D', 'displayValue': 'xxD'}, 'waiverApplied': false},
            ],
          },
          {'totalInterest': {'amount': 1, 'currency': 'GBP'}},
        ],
      });
      expect(tds.single.account, 'xxD');
      expect(tds.single.waiverLabel, '-');
      expect(TdsRow.taxByCurrency(tds), {'GBP': 10});
    });

    test('interest requests: OBDX path per category and mode', () {
      (String, Map<String, dynamic>) r(CertificateCategory c, String? id, {String? module}) =>
          ObdxCertificatesApi.interestRequest(category: c, accountId: id, module: module, fromDate: 'f', toDate: 't');
      expect(r(CertificateCategory.casa, 'A').$1, '/digx-common/dda/v1/demandDeposit/A/interest');
      expect(r(CertificateCategory.casa, null).$2['taskCode'], 'CH_I_IC');
      expect(r(CertificateCategory.loans, null).$1, '/digx-common/loan/v1/loan/paidInterest');
      expect(r(CertificateCategory.loans, 'L').$1, '/digx-common/loan/v1/loan/L/paidInterest');
      expect(r(CertificateCategory.deposits, 'T', module: 'CON').$2['module'], 'CON');
      expect(r(CertificateCategory.deposits, null).$1, '/digx-common/td/v1/deposit/paidInterest');
    });
  });

  group('screens', () {
    Future<_FakeRepo> pump(WidgetTester tester, Widget screen, {double width = 390}) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _FakeRepo();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [certificatesRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: LocaleConfig.supportedLocales,
            home: screen,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('Interest: FY required, Apply loads; Loans says Interest Debited; Reset', (tester) async {
      final repo = await pump(tester, const InterestCertificatesScreen(roles: ['CASARole', 'LoanRole']));
      expect(find.text('Current & Savings'), findsOneWidget, reason: 'sorted: Current & Savings first');
      expect(find.text('xxxx0139'), findsOneWidget, reason: 'the first account');

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('FY is required.'), findsOneWidget);

      await tester.tap(find.text('Please Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2025-2026').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(repo.interest.last.fromDate, '2025-04-01');
      expect(repo.interest.last.toDate, '2026-03-31');
      expect(find.text('Interest Credited'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);

      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(repo.downloads, 1);

      // The category picker (the band repeats the label).
      await tester.tap(find.text('Current & Savings').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Loans & Finances').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(repo.interest.last.category, CertificateCategory.loans);
      expect(find.text('Interest Debited'), findsOneWidget);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(find.text('Download'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Interest: All Accounts hides the account; Duration needs both dates', (tester) async {
      final repo = await pump(tester, const InterestCertificatesScreen(roles: ['CASARole']));
      await tester.tap(find.text('All Accounts'));
      await tester.pumpAndSettle();
      expect(find.text('Account Number'), findsNothing);
      await tester.tap(find.text('Duration'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Select both dates.'), findsNWidgets(2));
      expect(repo.interest, isEmpty);
    });

    testWidgets('no certificate roles: OBDX text', (tester) async {
      await pump(tester, const InterestCertificatesScreen(roles: []));
      expect(find.text('No Certificates Available.'), findsOneWidget);
    });

    testWidgets('Balance (web): month, Apply, two sections, Deposit No', (tester) async {
      final repo = await pump(tester, const BalanceCertificatesScreen(), width: 1280);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(repo.balanceMonths.single, DateTime(2026, 10));
      expect(find.text('Current and Savings Accounts'), findsOneWidget);
      expect(find.text('Term Deposits'), findsOneWidget);
      expect(find.text('Deposit No'), findsOneWidget);
      expect(find.text('xxA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TDS: FY required; heading with the total', (tester) async {
      await pump(tester, const TdsCertificatesScreen());
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Select Financial Year is required.'), findsOneWidget);
      await tester.tap(find.text('Please Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2024-2025').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.textContaining('TDS For Financial Year 2024-2025 was'), findsOneWidget);
      expect(find.text('TDS Waiver'), findsWidgets);
    });
  });
}

class _FakeRepo implements CertificatesRepository {
  final interest = <InterestQuery>[];
  final balanceMonths = <DateTime>[];
  int downloads = 0;

  @override
  Future<ResponseHandler<DateTime>> fetchBranchDate() async => ResponseHandler.success(DateTime(2026, 10, 28), code: 200);

  @override
  Future<ResponseHandler<List<CertificateAccount>>> fetchAccounts(CertificateCategory category) async =>
      ResponseHandler.success(const [CertificateAccount(id: '0139', display: 'xxxx0139')], code: 200);

  @override
  Future<ResponseHandler<List<InterestRow>>> fetchInterest(InterestQuery q) async {
    interest.add(q);
    return ResponseHandler.success([InterestRow.fromJson(_interest('0047', 10000))!], code: 200);
  }

  @override
  Future<ResponseHandler<StatementFile>> downloadInterest(InterestQuery q) async {
    downloads++;
    return ResponseHandler.error(500, 'nope');
  }

  @override
  Future<ResponseHandler<BalanceCertificate>> fetchBalance(DateTime month) async {
    balanceMonths.add(month);
    return ResponseHandler.success(
      BalanceCertificate.fromPayload({
        'demandDeposits': [
          {'account': {'value': 'A', 'displayValue': 'xxA'}, 'balance': {'amount': 10, 'currency': 'GBP'}},
        ],
        'termDeposits': [
          {'account': {'value': 'T', 'displayValue': 'xxT'}, 'depostiNumber': '3', 'balance': {'amount': 5, 'currency': 'GBP'}},
        ],
      }),
      code: 200,
    );
  }

  @override
  Future<ResponseHandler<List<TdsRow>>> fetchTds(FinancialYear year, DateTime branchDate) async =>
      ResponseHandler.success(
        TdsRow.listFromPayload({
          'depositTaxPaidListResponseDTO': [
            {
              'totalInterest': {'amount': 100, 'currency': 'GBP'},
              'totalTaxPaid': {'amount': 10, 'currency': 'GBP'},
              'depositTaxPaidDTOs': [
                {'accountId': {'value': 'D', 'displayValue': 'xxD'}, 'waiverApplied': true},
              ],
            },
          ],
        }),
        code: 200,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
