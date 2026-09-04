import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/loan_account.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/view/providers/loan_providers.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// Dashboard "Loan Tracker" card — Total Borrowing / Outstanding + donut %.
class LoanTrackerCard extends ConsumerWidget {
  const LoanTrackerCard({
    super.key,
    this.hideBalance = false,
    this.onViewAll,
  });

  final bool hideBalance;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(loanAccountsProvider);
    final summary = state.summary;
final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
  borderRadius: BorderRadius.circular(14),
  color: isDark
      ? const Color(0xFF143847)
      : Colors.white,
  border: Border.all(
    color: isDark
        ? const Color(0x330AAADF)
        : const Color(0xFFE5E7EB),
  ),
  boxShadow: [
    BoxShadow(
      color: isDark
          ? const Color(0x2207D5FF)
          : Colors.black.withOpacity(0.06),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ],
),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    InkWell(
      onTap: onViewAll,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.viewAll,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    ),
  ],
),
          const SizedBox(height: 16),
          if (state.isLoading && summary == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.errorMessage != null && summary == null)
            _LoanMessage(
              message: state.errorMessage!,
              actionLabel: l10n.accountsRetry,
              onAction: () =>
                  ref.read(loanAccountsProvider.notifier).refresh(),
            )
          else if (summary == null || summary.isEmpty)
            _LoanMessage(message: l10n.loansEmpty)
          else
            _LoanTrackerBody(
              summary: summary,
              hideBalance: hideBalance,
            ),
        ],
      ),
    );
  }
}

class _LoanTrackerBody extends StatelessWidget {
  const _LoanTrackerBody({
    required this.summary,
    required this.hideBalance,
  });

  final LoanAccountsSummary summary;
  final bool hideBalance;

@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context);

  final completedRatio =
      (1 - summary.outstandingRatio).clamp(0.0, 1.0);

  final completedPercent =
      (completedRatio * 100).round();

  return SizedBox(
    height: 110,
    child: Row(
      children: [
Expanded(
  flex: 3,
  child: Padding(
    padding: const EdgeInsets.only(left: 32,bottom: 16),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        l10n.loanTrackerTitle,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: HomeColors.textPrimary(context),
        ),
      ),
    ),
  ),
),

        Expanded(
          flex: 4,
          child: _AnimatedLoanGauge(
            percent: completedPercent,
            progress: completedRatio,
          ),
        ),
      ],
    ),
  );
}
}

class _AmountColumn extends StatelessWidget {
  const _AmountColumn({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final align =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = alignEnd ? TextAlign.right : TextAlign.left;
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: HomeColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: HomeColors.textPrimary(context),
          ),
        ),
      ],
    );
  }
}

class _LoanMessage extends StatelessWidget {
  const _LoanMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: HomeColors.textSecondary(context),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _LoanGaugePainter extends CustomPainter {
  _LoanGaugePainter({
    required this.progress,
    required this.isDark,
  });

  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center =
        Offset(size.width / 2, size.height);

    final radius = size.width * 0.38;

    const stroke = 10.0;

    final trackPaint = Paint()
      ..color = isDark
    ? Colors.white.withOpacity(.15)
    : const Color(0xFFD7DDE3)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = const Color(0xFF0CC7C7)
      ..strokeWidth = stroke + 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter =
          const MaskFilter.blur(BlurStyle.normal, 8);

    final progressPaint = Paint()
      ..color = const Color(0xFF12CFCF)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect =
        Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      trackPaint,
    );

    final sweep = math.pi * progress;

    canvas.drawArc(
      rect,
      math.pi,
      sweep,
      false,
      glowPaint,
    );

    canvas.drawArc(
      rect,
      math.pi,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_LoanGaugePainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}

class _AnimatedLoanGauge extends StatefulWidget {
  const _AnimatedLoanGauge({
    required this.percent,
    required this.progress,
  });

  final int percent;
  final double progress;

  @override
  State<_AnimatedLoanGauge> createState() =>
      _AnimatedLoanGaugeState();
}

class _AnimatedLoanGaugeState
    extends State<_AnimatedLoanGauge>
    with SingleTickerProviderStateMixin {

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(-0.25),
          child: SizedBox(
            width: 180,
            height: 90,
            child: CustomPaint(
              painter: _LoanGaugePainter(
                progress:
                    widget.progress * _controller.value,
                    isDark: Theme.of(context).brightness == Brightness.dark,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.percent}%',
                        style:  TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                       Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}