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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.loanTrackerTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: HomeColors.textPrimary(context),
                  ),
                ),
              ),
              InkWell(
                onTap: onViewAll,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.viewAll,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: HomeColors.brand(context),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: HomeColors.brand(context),
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
    final currency = summary.primaryCurrency ?? '';
    final brand = HomeColors.brand(context);
    final percent = summary.outstandingPercent;

    return Row(
      children: [
        Expanded(
          child: _AmountColumn(
            label: l10n.loanTotalBorrowing,
            value: MoneyFormat.format(
              summary.totalBorrowing,
              currencyCode: currency,
              hidden: hideBalance,
            ),
          ),
        ),
        SizedBox(
          width: 96,
          height: 96,
          child: CustomPaint(
            painter: _LoanDonutPainter(
              progress: summary.outstandingRatio,
              trackColor: const Color(0xFFE8F4F1),
              progressColor: brand,
            ),
            child: Center(
              child: Text(
                hideBalance ? '**%' : '$percent%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: HomeColors.textPrimary(context),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: _AmountColumn(
            label: l10n.loanTotalOutstanding,
            value: MoneyFormat.format(
              summary.totalOutstanding,
              currencyCode: currency,
              hidden: hideBalance,
            ),
            alignEnd: true,
          ),
        ),
      ],
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

class _LoanDonutPainter extends CustomPainter {
  _LoanDonutPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = size.width * 0.12;
    final radius = (size.width - stroke) / 2;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final arc = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweep,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LoanDonutPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}
