import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cash_flow_forecast_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cash_flow_sample_data.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cash_flow_snapshot_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cash_withdrawal_summary_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/cash_flow/corp_cashflow_summary_widget.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_bar_chart.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_widget_registry.dart';

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
    'Cash Flow Forecast': CorpCashFlowForecastWidget(),
    'Today Cashflow Snapshot': CorpCashFlowSnapshotWidget(),
    'Cashflow Summary': CorpCashflowSummaryWidget(),
    'Cash Withdrawal Summary': CorpCashWithdrawalSummaryWidget(),
  };

  group('every Cash Flow widget lays out without overflow', () {
    for (final entry in widgets.entries) {
      for (final width in [_phone, 480.0, 600.0, 800.0, 1000.0, 1300.0]) {
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

  group('the forecast series', () {
    final series = CorpCashFlowSampleData.forecast;

    test('covers the design period, with its totals', () {
      expect(series.start, DateTime(2026, 3));
      expect(series.end, DateTime(2027, 2, 28));
      final t = series.totals(series.start, series.end);
      expect(CorpFigures.compact(t.inflow), '£8.42B');
      expect(CorpFigures.compact(t.outflow), '£6.73B');
      expect(CorpFigures.compact(t.net), '£1.69B');
    });

    test('compares with the previous period as the design does', () {
      final t = series.totals(series.start, series.end);
      expect(
        CorpCashFlowTotals.change(t.inflow, t.previousInflow)!
            .toStringAsFixed(1),
        '8.4',
      );
      expect(
        CorpCashFlowTotals.change(t.net, t.previousNet)!.toStringAsFixed(1),
        '12.1',
      );
    });

    test('every grouping adds up to the same totals', () {
      final t = series.totals(series.start, series.end);
      for (final g in CorpCashFlowGrouping.values) {
        final buckets = series.buckets(series.start, series.end, g);
        final inflow = buckets.fold<double>(0, (s, b) => s + b.inflow);
        expect(inflow, closeTo(t.inflow, 1), reason: g.name);
      }
      expect(
        series
            .buckets(series.start, series.end, CorpCashFlowGrouping.monthly)
            .length,
        12,
      );
      expect(
        series
            .buckets(series.start, series.end, CorpCashFlowGrouping.quarterly)
            .length,
        4,
      );
      expect(
        series
            .buckets(series.start, series.end, CorpCashFlowGrouping.daily)
            .length,
        365,
      );
    });

    test('a month keeps its total when spread over its days', () {
      final march = series.totals(DateTime(2026, 3), DateTime(2026, 3, 31));
      expect(march.inflow, closeTo(0.62e9, 1));
    });

    test('the lowest balance falls within the range', () {
      final (amount, on) = series.lowestBalance(series.start, series.end);
      expect(amount, lessThan(series.openingBalance));
      expect(on.isBefore(series.start), isFalse);
      expect(on.isAfter(series.end), isFalse);
    });
  });

  testWidgets('Forecast: the range changes the figures', (tester) async {
    await _pump(tester, const CorpCashFlowForecastWidget(), width: 1300);
    expect(find.text('£8.42B'), findsOneWidget);

    await tester.tap(find.text('3M'));
    await tester.pumpAndSettle();
    expect(find.text('£8.42B'), findsNothing);
    // March to May.
    expect(find.text('£1.73B'), findsOneWidget);
  });

  testWidgets('Forecast: daily over a year scrolls rather than squashes',
      (tester) async {
    await _pump(tester, const CorpCashFlowForecastWidget(), width: _phone);
    await tester.tap(find.text('Daily'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(CorpBarChart),
        matching: find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Forecast: tapping a bar shows its figures', (tester) async {
    await _pump(tester, const CorpCashFlowForecastWidget(), width: 1300);
    expect(find.text('Tap a bar to see its figures'), findsOneWidget);

    final chart = find.byType(CustomPaint).last;
    await tester.tapAt(tester.getTopLeft(chart) + const Offset(20, 60));
    await tester.pumpAndSettle();
    expect(find.text('March 2026'), findsOneWidget);
  });

  testWidgets('Snapshot: net is inflow less outflow', (tester) async {
    await _pump(tester, const CorpCashFlowSnapshotWidget(), width: 600);
    expect(find.text('+£41.7K'), findsOneWidget);
    expect(find.text('28 inflows • 19 outflows • 3 pending'), findsOneWidget);
  });

  testWidgets('Cashflow Summary: closing is opening plus net', (tester) async {
    await _pump(tester, const CorpCashflowSummaryWidget(), width: 600);
    expect(find.text('£640K'), findsOneWidget);
    expect(find.text('+£260K'), findsOneWidget);
    expect(find.text('Positive movement vs opening balance'), findsOneWidget);
  });

  testWidgets('Withdrawals: the total is the channels summed', (tester) async {
    await _pump(tester, const CorpCashWithdrawalSummaryWidget(), width: 600);
    expect(find.text('£245.8K'), findsOneWidget);
    expect(find.text('£149.6K'), findsOneWidget);
  });

  test('the Cash Flow components are on the Corporate dashboard', () {
    const corp = CorpWidgetRegistry();
    for (final name in const [
      'cash-flow-forecast',
      'cash-flow-snapshot',
      'cashflow-summary',
      'cash-withdrawal-summary',
    ]) {
      expect(corp.isImplemented(name), isTrue, reason: name);
    }
  });
}
