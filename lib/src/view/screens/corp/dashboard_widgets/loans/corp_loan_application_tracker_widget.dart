import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/loans/corp_loan_sample_data.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// OBDX `loan-application-tracker` — where a loan application is in its
/// journey, from submission to disbursement.
///
/// The steps run across on web and down on a phone, where five labels
/// side by side would not fit. Shows [CorpLoanSampleData.application]
/// until live data is passed as [data].
class CorpLoanApplicationTrackerWidget extends StatelessWidget {
  const CorpLoanApplicationTrackerWidget({super.key, this.data});

  final CorpLoanApplicationData? data;

  @override
  Widget build(BuildContext context) {
    final app = data ?? CorpLoanSampleData.application;
    final isSample = data == null;
    final symbol = CorpCurrency.of(context);

    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = CorpWidgetLayout.isCompact(constraints);
          void openApplication() =>
              showCorpSampleDataNotice(context, 'The application');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CorpWidgetHeader(
                title: compact
                    ? 'Loan Application Tracker'
                    : 'Loan Finance Application Tracker',
                compact: compact,
                sample: isSample,
                subtitle: compact
                    ? CorpSubtitle('${app.applicationId} • ${app.product}')
                    : _WebSubtitle(app: app),
              ),
              const SizedBox(height: 14),
              CorpStatRow(
                minTileWidth: compact ? 84 : 130,
                gap: compact ? 8 : 10,
                tiles: [
                  CorpStatTile(
                    label: compact ? 'Amount' : 'Requested amount',
                    value: app.requestedAmount == null
                        ? '—'
                        : compact
                            ? CorpFigures.compact(app.requestedAmount!,
                                symbol: symbol)
                            : CorpFigures.full(app.requestedAmount!,
                                symbol: symbol),
                  ),
                  CorpStatTile(
                    label: compact ? 'Status' : 'Current status',
                    value: compact ? app.shortStatus : app.status,
                    tone: CorpTone.green,
                    valueSize: compact ? 14 : 16,
                  ),
                  CorpStatTile(
                    label: 'Submitted',
                    value: app.submittedOn == null
                        ? '—'
                        : compact
                            ? CorpFigures.dayMonth(app.submittedOn!)
                            : CorpFigures.date(app.submittedOn!),
                    tone: CorpTone.amber,
                    valueSize: compact ? 14 : 16,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CorpInsetPanel(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 16 : 10,
                  vertical: compact ? 16 : 18,
                ),
                child: compact
                    ? _VerticalSteps(app: app)
                    : _HorizontalSteps(app: app),
              ),
              const SizedBox(height: 10),
              _NextAction(
                app: app,
                stacked: compact,
                onView: isSample ? openApplication : null,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WebSubtitle extends StatelessWidget {
  const _WebSubtitle({required this.app});

  final CorpLoanApplicationData app;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(
      fontSize: 12,
      color: CorpColors.textSecondary(context),
    );
    return Wrap(
      spacing: 16,
      runSpacing: 2,
      children: [
        Text(
          'Application ID  ${app.applicationId}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: CorpToneColors.of(context, CorpTone.blue).label,
          ),
        ),
        Text(
          app.requestedAmount == null
              ? app.product
              : '${app.product}  •  ${CorpFigures.compact(app.requestedAmount!, symbol: CorpCurrency.of(context))}',
          style: muted,
        ),
      ],
    );
  }
}

enum _StepState { done, current, pending }

_StepState _stateOf(CorpLoanApplicationData app, int index) {
  if (index < app.currentStep) return _StepState.done;
  if (index == app.currentStep) return _StepState.current;
  return _StepState.pending;
}

/// The numbered circle for one step.
class _StepMarker extends StatelessWidget {
  const _StepMarker({required this.number, required this.state});

  final int number;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final reached = state != _StepState.pending;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            reached ? const Color(0xFF0F8A7E) : CorpChartColors.track(context),
      ),
      child: Text(
        '$number',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: reached ? Colors.white : CorpChartColors.primary,
        ),
      ),
    );
  }
}

/// The link between two steps — solid once the step before it is done.
Color _connectorColor(BuildContext context, bool reached) => reached
    ? CorpChartColors.light
    : CorpChartColors.track(context).withValues(alpha: 0.7);

class _HorizontalSteps extends StatelessWidget {
  const _HorizontalSteps({required this.app});

  final CorpLoanApplicationData app;

  @override
  Widget build(BuildContext context) {
    final steps = app.steps;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Padding(
              // Level with the circles' centres.
              padding: const EdgeInsets.only(top: 11),
              child: Container(
                width: 18,
                height: 3,
                decoration: BoxDecoration(
                  color: _connectorColor(context, i <= app.currentStep),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Expanded(
            child: Column(
              children: [
                _StepMarker(number: i + 1, state: _stateOf(app, i)),
                const SizedBox(height: 8),
                Text(
                  steps[i],
                  textAlign: TextAlign.center,
                  style: _labelStyle(context, _stateOf(app, i)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _VerticalSteps extends StatelessWidget {
  const _VerticalSteps({required this.app});

  final CorpLoanApplicationData app;

  @override
  Widget build(BuildContext context) {
    final steps = app.steps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Padding(
              // Under the circles' centres.
              padding: const EdgeInsets.only(left: 10.5),
              child: Container(
                width: 3,
                height: 22,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: _connectorColor(context, i <= app.currentStep),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Row(
            children: [
              _StepMarker(number: i + 1, state: _stateOf(app, i)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  steps[i],
                  style: _labelStyle(context, _stateOf(app, i)),
                ),
              ),
              if (_stateOf(app, i) == _StepState.current)
                const CorpStatusChip(label: 'In progress', tone: CorpTone.blue),
            ],
          ),
        ],
      ],
    );
  }
}

TextStyle _labelStyle(BuildContext context, _StepState state) => TextStyle(
      fontSize: 11.5,
      fontWeight:
          state == _StepState.pending ? FontWeight.w500 : FontWeight.w700,
      color: state == _StepState.pending
          ? CorpColors.textSecondary(context)
          : CorpColors.textPrimary(context),
    );

class _NextAction extends StatelessWidget {
  const _NextAction({
    required this.app,
    required this.stacked,
    required this.onView,
  });

  final CorpLoanApplicationData app;
  final bool stacked;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    final tone = CorpToneColors.of(context, CorpTone.blue);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Next action',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: tone.label,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${app.nextAction} • ${app.nextActionDetail}',
          style: TextStyle(
            fontSize: 12,
            color: CorpColors.textSecondary(context),
          ),
        ),
      ],
    );
    final link = CorpWidgetLink(label: 'View application', onTap: onView);

    return CorpInsetPanel(
      color: tone.fill,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [text, const SizedBox(height: 6), link],
            )
          : Row(
              children: [
                Expanded(child: text),
                const SizedBox(width: 8),
                link,
              ],
            ),
    );
  }
}
