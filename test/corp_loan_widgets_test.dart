import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_widget_registry.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loan_application_tracker_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loan_installments_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loan_portfolio_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loan_summary_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loans_overview_widget.dart';

/// Draws [child] [width] wide, as a dashboard column or a phone would.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required double width,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width + 40, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _web = 600.0; // half of a desktop dashboard
const _phone = 350.0; // a phone, less the dashboard margins

void main() {
  const widgets = <String, Widget>{
    'Loan Summary': CorpLoanSummaryWidget(),
    'Application Tracker': CorpLoanApplicationTrackerWidget(),
    'Installments Due': CorpLoanInstallmentsWidget(),
    'Loan Portfolio': CorpLoanPortfolioWidget(),
    'Loan and Finance Summary': CorpLoansOverviewWidget(),
  };

  group('every Loans widget lays out without overflow', () {
    for (final entry in widgets.entries) {
      for (final width in [_phone, 480.0, _web, 700.0, 1100.0]) {
        testWidgets('${entry.key} at $width', (tester) async {
          await _pump(tester, entry.value, width: width);
          expect(tester.takeException(), isNull);
          // Every one says it is showing sample figures.
          expect(find.byType(CorpSampleDataTag), findsOneWidget);
        });
      }
      testWidgets('${entry.key} in dark mode', (tester) async {
        await _pump(
          tester,
          entry.value,
          width: _phone,
          theme: AppTheme.dark(),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('Loan Summary: the gauge is the outstanding share',
      (tester) async {
    await _pump(tester, const CorpLoanSummaryWidget(), width: _web);
    // £824K of £1.20M.
    expect(find.text('69%'), findsOneWidget);
    expect(find.text('£824K outstanding'), findsOneWidget);
    expect(find.text('Interest rate'), findsOneWidget);
  });

  testWidgets('Loan Summary: shorter labels on a phone', (tester) async {
    await _pump(tester, const CorpLoanSummaryWidget(), width: _phone);
    expect(find.text('Rate'), findsOneWidget);
    expect(find.text('Interest rate'), findsNothing);
  });

  testWidgets('Application Tracker: steps run across on web, down on a phone',
      (tester) async {
    await _pump(tester, const CorpLoanApplicationTrackerWidget(), width: _web);
    expect(find.text('Loan Finance Application Tracker'), findsOneWidget);
    final webFirst = tester.getTopLeft(find.text('Application submitted'));
    final webLast = tester.getTopLeft(find.text('Disbursement'));
    expect(webLast.dy, webFirst.dy);

    await _pump(
      tester,
      const CorpLoanApplicationTrackerWidget(),
      width: _phone,
    );
    expect(find.text('Loan Application Tracker'), findsOneWidget);
    final first = tester.getTopLeft(find.text('Application submitted'));
    final last = tester.getTopLeft(find.text('Disbursement'));
    expect(last.dy, greaterThan(first.dy));
    expect(find.text('In progress'), findsOneWidget);
  });

  testWidgets('Installments Due: switches between upcoming and overdue',
      (tester) async {
    await _pump(tester, const CorpLoanInstallmentsWidget(), width: _web);
    expect(find.text('3 upcoming installments • next 10 days'), findsOneWidget);
    expect(find.text('Home Finance Loan'), findsOneWidget);
    expect(find.text('£38.4K'), findsOneWidget);

    await tester.tap(find.text('Overdue'));
    await tester.pumpAndSettle();
    expect(find.text('1 overdue installment'), findsOneWidget);
    expect(find.text('Home Finance Loan'), findsNothing);
    expect(find.text('Working Capital'), findsOneWidget);
  });

  testWidgets('Loan and Finance Summary: search narrows the rows',
      (tester) async {
    await _pump(tester, const CorpLoansOverviewWidget(), width: 1100);
    expect(find.text('5 of 5 accounts'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'acme');
    await tester.pumpAndSettle();
    expect(find.text('2 of 5 accounts'), findsOneWidget);
    expect(find.text('Northstar Co.'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nothing like this');
    await tester.pumpAndSettle();
    expect(find.text('No accounts match your search.'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('5 of 5 accounts'), findsOneWidget);
  });

  testWidgets('Loan and Finance Summary: graphical view', (tester) async {
    await _pump(tester, const CorpLoansOverviewWidget(), width: 1100);
    await tester.tap(find.text('Graphical'));
    await tester.pumpAndSettle();
    expect(find.text('£312K / £500K'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a sample link explains why it goes nowhere yet', (tester) async {
    await _pump(tester, const CorpLoanSummaryWidget(), width: _web);
    await tester.tap(find.text('View loan details'));
    await tester.pump();
    expect(
      find.text('Loan details will open here once live data is connected.'),
      findsOneWidget,
    );
  });

  test('the Loans components are on the Corporate dashboard', () {
    const corp = CorpWidgetRegistry();
    for (final name in const [
      'loan-summary',
      'loan-application-tracker',
      'loan-installments-due',
      'loan-portfolio',
      'loans-overview',
    ]) {
      expect(corp.isImplemented(name), isTrue, reason: name);
    }
  });

  group('CorpFigures', () {
    test('abbreviates like the designs', () {
      expect(CorpFigures.compact(824000), '£824K');
      expect(CorpFigures.compact(12800), '£12.8K');
      expect(CorpFigures.compact(1200000), '£1.20M');
      expect(CorpFigures.compact(8420000000), '£8.42B');
      expect(CorpFigures.compact(50000), '£50K');
      expect(CorpFigures.signedCompact(41700), '+£41.7K');
      expect(CorpFigures.full(50000), '£50,000');
      expect(CorpFigures.compact(128100), '£128K');
      expect(CorpFigures.compact(128100, precise: true), '£128.1K');
      expect(CorpFigures.compact(120000, precise: true), '£120K');
    });

    test('dates and tenure', () {
      expect(CorpFigures.date(DateTime(2026, 9, 28)), '28 Sep 2026');
      expect(CorpFigures.monthYear(DateTime(2026, 9)), 'September 2026');
      expect(CorpFigures.tenure(56), '4Y 8M');
      expect(CorpFigures.tenure(12), '1Y');
    });
  });
}
