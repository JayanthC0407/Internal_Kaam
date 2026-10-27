import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/retail/loan_account.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/view/providers/retail/loan_providers.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/widgets/loan_currency_tabs.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_card_surface.dart';

/// Dashboard "Loan Tracker" card — Total Borrowing / Outstanding + donut %.
class LoanTrackerCard extends ConsumerWidget {
  const LoanTrackerCard({
    super.key,
    this.hideBalance = false,
    this.onViewAll,
    this.phoneStyle = false,
  });

  final bool hideBalance;
  final VoidCallback? onViewAll;

  /// Phone Home design: "Loan Tracker" with the outstanding amount under
  /// it and a flat gradient gauge of the outstanding share ("68 %
  /// Outstanding"); no "View all" row — the whole card opens the loans
  /// list.
  final bool phoneStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(loanAccountsProvider);
    final summary = state.summary;

    // Loans in more than one currency share the same selected-currency tab
    // as the "Loans & Finances" list screen, so the two stay in sync.
    final currencies = summary?.currencies ?? const <String>[];
    final rawSelection = ref.watch(selectedLoanCurrencyProvider);
    final currency = (rawSelection != null && currencies.contains(rawSelection))
        ? rawSelection
        : (currencies.isNotEmpty ? currencies.first : summary?.primaryCurrency);
    final card = DashboardCardSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      // The active palette's card and divider, like the cards around it —
      // a fixed teal here clashed with the orange and indigo dark themes.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: HomeColors.card(context),
        border: Border.all(color: HomeColors.divider(context)),
        boxShadow: [
          BoxShadow(
            color: HomeColors.brandLight(context).withValues(alpha: 0.30),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 0),
          ),
        ],
),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
if (!phoneStyle || (summary?.isMultiCurrency ?? false))
Row(
  children: [
    if (summary != null && summary.isMultiCurrency)
      Expanded(
        child: LoanCurrencyTabs(
          currencies: currencies,
          selected: currency ?? currencies.first,
          dense: true,
          onChanged: (c) =>
              ref.read(selectedLoanCurrencyProvider.notifier).state = c,
        ),
      )
    else
      const Spacer(),
    if (!phoneStyle)
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
          if (!phoneStyle) const SizedBox(height: 16),
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
              currency: currency,
              phoneStyle: phoneStyle,
            ),
        ],
      ),
    );
    if (!phoneStyle || onViewAll == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onViewAll,
        child: card,
      ),
    );
  }
}

class _LoanTrackerBody extends StatelessWidget {
  const _LoanTrackerBody({
    required this.summary,
    required this.hideBalance,
    required this.currency,
    this.phoneStyle = false,
  });

  final bool phoneStyle;

  final LoanAccountsSummary summary;
  final bool hideBalance;

  /// Currency the gauge below is scoped to (from the currency tabs when the
  /// customer holds loans in more than one) — never blends currencies.
  final String? currency;

@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context);

  // "Remaining", stated the way a bank statement would: the outstanding
  // (still-owed) balance and what fraction of the total borrowing that
  // represents — rather than an "% completed" framing.
  final outstandingRatio = summary.outstandingRatioFor(currency);
  final outstandingPercent = summary.outstandingPercentFor(currency);
  final outstandingAmount = summary.totalOutstandingFor(currency);

  return SizedBox(
    height: 110,
    child: Row(
      children: [
Expanded(
  flex: 3,
  child: Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // One line, as in the mock — shrinks rather than wrapping.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            l10n.loanTrackerTitle,
            maxLines: 1,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: HomeColors.textPrimary(context),
            ),
          ),
        ),
        if (phoneStyle) ...[
          const SizedBox(height: 8),
          Text(
            l10n.loanOutstandingAmountLabel,
            style: TextStyle(
              fontSize: 12,
              color: HomeColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              MoneyFormat.format(
                outstandingAmount,
                currencyCode: currency ?? '',
                hidden: hideBalance,
              ),
              maxLines: 1,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: HomeColors.textPrimary(context),
              ),
            ),
          ),
        ],
        if (!phoneStyle) ...[
        const SizedBox(height: 6),
        Text(
          '${MoneyFormat.format(
            outstandingAmount,
            currencyCode: currency ?? '',
            hidden: hideBalance,
          )} outstanding',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: HomeColors.textSecondary(context),
          ),
        ),
        ],
      ],
    ),
  ),
),

        Expanded(
          flex: 4,
          // Outstanding share on both; phones use the flat gradient look.
          child: phoneStyle
              ? _AnimatedLoanGauge(
                  percent: outstandingPercent,
                  progress: outstandingRatio,
                  label: l10n.loanTrackerOutstanding,
                  brandColor: true,
                )
              : _AnimatedLoanGauge(
                  percent: outstandingPercent,
                  progress: outstandingRatio,
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

/// Maps loan progress to a traffic-light color: red when most of the loan
/// is still outstanding, through amber, to green as it nears payoff —
/// mirrors how risk/health indicators read in banking UX (red = attention
/// needed, green = healthy/nearly settled). Colors are read from the active
/// theme's semantic error/warning/success tokens rather than hardcoded, so
/// this follows the app's light/dark theme automatically.
Color _loanRiskColor(BuildContext context, double completedRatio) {
  final red = HomeColors.error(context);
  final amber = HomeColors.warning(context);
  final green = HomeColors.success(context);
  final clamped = completedRatio.clamp(0.0, 1.0);
  if (clamped <= 0.5) {
    return Color.lerp(red, amber, clamped / 0.5)!;
  }
  return Color.lerp(amber, green, (clamped - 0.5) / 0.5)!;
}

class _LoanGaugePainter extends CustomPainter {
  _LoanGaugePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    this.glow = true,
    this.gradient,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  /// Left-to-right arc gradient (phone design); [color] when null.
  final List<Color>? gradient;

  /// Blurred halo under the arc; off on the phone Home (flat design).
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final center =
        Offset(size.width / 2, size.height);

    final radius = size.width * 0.38;

    const stroke = 10.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color
      ..strokeWidth = stroke + 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter =
          const MaskFilter.blur(BlurStyle.normal, 8);

    final rect =
        Rect.fromCircle(center: center, radius: radius);

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (gradient != null) {
      progressPaint.shader = LinearGradient(colors: gradient!).createShader(rect);
    }

    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      trackPaint,
    );

    final sweep = math.pi * progress;

    if (glow) {
      canvas.drawArc(
        rect,
        math.pi,
        sweep,
        false,
        glowPaint,
      );
    }

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
    return progress != oldDelegate.progress ||
        glow != oldDelegate.glow ||
        color != oldDelegate.color ||
        trackColor != oldDelegate.trackColor;
  }
}

class _AnimatedLoanGauge extends StatefulWidget {
  const _AnimatedLoanGauge({
    required this.percent,
    required this.progress,
    this.label,
    this.brandColor = false,
  });

  final int percent;
  final double progress;

  /// Under the percentage; "Outstanding" when null.
  final String? label;

  /// Brand teal instead of the red-amber-green health colour.
  final bool brandColor;

  @override
  State<_AnimatedLoanGauge> createState() =>
      _AnimatedLoanGaugeState();
}

class _AnimatedLoanGaugeState
    extends State<_AnimatedLoanGauge>
    with SingleTickerProviderStateMixin {

  late final AnimationController _controller;

  /// The draw-in animation plays once per app run. Home is rebuilt every
  /// time the user comes back to it, and replaying 1.8 s of animation
  /// each time made the cards look like they were still loading.
  static bool _playedOnce = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (_playedOnce) {
      _controller.value = 1;
    } else {
      _playedOnce = true;
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    // widget.progress is the *outstanding* fraction (what's still owed),
    // but the risk color should track health — i.e. how much has been
    // repaid — so it's inverted here rather than changing what the color
    // helper itself means.
    final color = widget.brandColor
        ? HomeColors.brand(context)
        : _loanRiskColor(context, 1 - widget.progress);
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Transform(
          alignment: Alignment.center,
          transform: widget.brandColor
              ? Matrix4.identity()
              : (Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateX(-0.25)),
          child: SizedBox(
            width: 180,
            height: 90,
            child: CustomPaint(
              painter: _LoanGaugePainter(
                progress:
                    widget.progress * _controller.value,
                    color: color,
                    // Design: pale cyan track behind the brand arc.
                    trackColor: widget.brandColor
                        ? HomeColors.brandLight(context).withValues(alpha: 0.25)
                        : HomeColors.divider(context),
                    glow: !widget.brandColor,
                    gradient: widget.brandColor
                        ? [
                            HomeColors.brand(context),
                            HomeColors.brandLight(context),
                          ]
                        : null,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.brandColor
                            ? '${widget.percent} %'
                            : '${widget.percent}%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: widget.brandColor
                              ? HomeColors.textPrimary(context)
                              : color,
                        ),
                      ),
                       Text(
                        widget.label ?? 'Outstanding',
                        style: widget.brandColor
                            ? TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: HomeColors.textPrimary(context),
                              )
                            : TextStyle(
                                fontSize: 13,
                                color: HomeColors.textSecondary(context),
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