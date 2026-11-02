import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:demo_bank/src/core/models/common/dashboard/dashboard_config.dart';
import 'package:demo_bank/src/core/models/corp/liquidity_overview_models.dart';
import 'package:demo_bank/src/view/providers/corp/corp_liquidity_providers.dart';
import 'package:demo_bank/src/view/screens/corp/liquidity/lm_balance_widgets.dart';
import 'package:demo_bank/src/view/screens/corp/liquidity/lm_sweep_widgets.dart';
import 'package:demo_bank/src/view/screens/corp/liquidity/lm_widgets.dart';

/// Liquidity Management ▸ Overview — OBDX's `liquidity-management` module
/// dashboard: the widgets the server layout lists (card §2). On wide
/// screens two `1x` widgets share a row and `2x` widgets (Position By
/// Region, Sweep Monitor) take a full row; phones stack them all.
class LmOverviewPage extends ConsumerWidget {
  const LmOverviewPage({super.key});

  /// Width from which `1x` widgets pair up.
  static const pairWidth = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(builder: (context, box) {
      final breakpoint = DashboardBreakpoint.forWidth(MediaQuery.sizeOf(context).width);
      final layout = ref.watch(lmOverviewLayoutProvider(breakpoint));
      if (layout.isLoading && !layout.hasValue) {
        return const Padding(padding: EdgeInsets.all(36), child: Center(child: CircularProgressIndicator()));
      }
      final widgets = layout.valueOrNull ?? LmOverviewWidget.values;
      if (widgets.isEmpty) return const LmEmpty(title: 'No items to display');
      Widget build(LmOverviewWidget w) => switch (w) {
            LmOverviewWidget.positionByCurrency => const LmPositionByCurrency(),
            LmOverviewWidget.positionByRegion => const LmPositionByRegion(),
            LmOverviewWidget.assetsAndLiabilities => const LmBalancesSummary(),
            LmOverviewWidget.crossBorderSweeps => const LmCrossBorderSweeps(),
            LmOverviewWidget.topFiveSweeps => const LmTopFiveSweeps(),
            LmOverviewWidget.sweepLog => const LmSweepMonitor(),
          };
      final children = <Widget>[];
      for (var i = 0; i < widgets.length; i++) {
        final w = widgets[i];
        final next = i + 1 < widgets.length ? widgets[i + 1] : null;
        if (box.maxWidth >= pairWidth && !w.wide && next != null && !next.wide) {
          children.add(Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: build(w)), const SizedBox(width: 14), Expanded(child: build(next))],
          ));
          i++;
        } else {
          children.add(build(w));
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(height: 14), c],
        ],
      );
    });
  }
}
