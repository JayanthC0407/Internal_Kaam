import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_widget_registry.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/td/corp_td_accounts_overview_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/td/corp_td_sample_data.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/td/corp_td_summary_widget.dart';

/// Draws [child] [width] wide, as a dashboard column or a phone would.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required double width,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = Size(width + 40, 2000);
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

const _phone = 350.0;

void main() {
  const widgets = <String, Widget>{
    'TD Accounts Overview': CorpTdAccountsOverviewWidget(),
    'TD Summary': CorpTdSummaryWidget(),
  };

  group('every TD widget lays out without overflow', () {
    for (final entry in widgets.entries) {
      for (final width in [_phone, 480.0, 600.0, 760.0, 1000.0, 1300.0]) {
        testWidgets('${entry.key} at $width', (tester) async {
          await _pump(tester, entry.value, width: width);
          expect(tester.takeException(), isNull);
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

  test('the totals are worked out from the deposits', () {
    final totals = CorpTdTotals.of(CorpTdSampleData.deposits);
    expect(totals.balance, 680000);
    expect(totals.count, 8);
    expect(CorpFigures.percentOr(totals.averageRate), '6.85%');
    expect(totals.nextMaturity, DateTime(2026, 10, 15));
    expect(CorpFigures.compact(totals.maturityValue), '£713K');
  });

  test('the average rate is weighted by principal', () {
    final totals = CorpTdTotals.of([
      CorpTermDeposit(
        id: 'a',
        principal: 300,
        rate: 6,
        maturesOn: DateTime(2027),
        maturityValue: 318,
      ),
      CorpTermDeposit(
        id: 'b',
        principal: 100,
        rate: 10,
        maturesOn: DateTime(2027),
        maturityValue: 110,
      ),
    ]);
    expect(totals.averageRate, 7);
  });

  testWidgets('TD Accounts Overview lists the next four maturities',
      (tester) async {
    await _pump(tester, const CorpTdAccountsOverviewWidget(), width: 600);
    expect(find.text('Upcoming maturities'), findsOneWidget);
    expect(find.text('15 Oct'), findsOneWidget);
    expect(find.text('10 Dec'), findsOneWidget);
    // The fifth is not listed.
    expect(find.text('18 Jan'), findsNothing);
    expect(find.text('Total TD balance'), findsOneWidget);
  });

  testWidgets('TD Accounts Overview: a past maturity is not upcoming',
      (tester) async {
    await _pump(
      tester,
      CorpTdAccountsOverviewWidget(asOf: DateTime(2026, 10, 20)),
      width: 600,
    );
    expect(find.text('15 Oct'), findsNothing);
    expect(find.text('18 Jan'), findsOneWidget);
  });

  testWidgets('TD Summary: chart and table side by side when wide',
      (tester) async {
    await _pump(tester, const CorpTdSummaryWidget(), width: 1300);
    expect(find.text('Graphical view'), findsOneWidget);
    expect(find.text('Tabular view'), findsOneWidget);
    // No switch needed.
    expect(find.text('Graphical'), findsNothing);
  });

  testWidgets('TD Summary: one at a time on a phone', (tester) async {
    await _pump(tester, const CorpTdSummaryWidget(), width: _phone);
    expect(find.text('Graphical view'), findsOneWidget);
    expect(find.text('Tabular view'), findsNothing);

    await tester.tap(find.text('Tabular'));
    await tester.pumpAndSettle();
    expect(find.text('Tabular view'), findsOneWidget);
    expect(find.text('Graphical view'), findsNothing);
    expect(find.text('TD-1008'), findsOneWidget);
  });

  testWidgets('TD Summary: choosing a deposit updates the chart',
      (tester) async {
    await _pump(tester, const CorpTdSummaryWidget(), width: 1300);
    // The next to mature, first.
    expect(find.text('£128.1K'), findsWidgets);

    await tester.tap(find.text('TD-1003').last);
    await tester.pumpAndSettle();
    expect(find.text('£203.1K'), findsWidgets);
    expect(find.text('21 Nov 2026'), findsWidgets);
  });

  testWidgets('TD Summary: search narrows the table', (tester) async {
    await _pump(tester, const CorpTdSummaryWidget(), width: 1300);
    await tester.enterText(find.byType(TextField), '1002');
    await tester.pumpAndSettle();
    expect(find.text('TD-1001'), findsWidgets); // still in the chart picker
    expect(find.text('TD-1005'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No deposits match your search.'), findsOneWidget);
  });

  test('the TD components are on the Corporate dashboard', () {
    const corp = CorpWidgetRegistry();
    expect(corp.isImplemented('td-accounts-overview'), isTrue);
    expect(corp.isImplemented('td-summary'), isTrue);
  });
}
