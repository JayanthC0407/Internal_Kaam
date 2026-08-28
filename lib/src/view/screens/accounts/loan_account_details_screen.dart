import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/loan_account.dart';
import 'package:ubci_bank/src/core/models/loan_account_details.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/view/providers/loan_detail_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/accounts/loan_repayment_screen.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// Route arguments for [LoanAccountDetailsScreen].
class LoanAccountDetailsArgs {
  const LoanAccountDetailsArgs({required this.loan});

  final LoanAccount loan;
}

/// Loan overview + repayment schedule + disbursement history for a single
/// loan, backed by `GET /digx-common/loan/v1/loan/{id}` and its
/// `/schedule` and `/disbursements` sub-resources.
class LoanAccountDetailsScreen extends ConsumerStatefulWidget {
  const LoanAccountDetailsScreen({super.key, required this.args});

  final LoanAccountDetailsArgs args;

  @override
  ConsumerState<LoanAccountDetailsScreen> createState() =>
      _LoanAccountDetailsScreenState();
}

class _LoanAccountDetailsScreenState
    extends ConsumerState<LoanAccountDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final LoanDetailKey _detailKey;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _detailKey = LoanDetailKey(
      loanId: widget.args.loan.id,
      module: widget.args.loan.module,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(loanAccountDetailProvider(_detailKey).notifier).ensureLoaded();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openRepayment() async {
    HapticFeedback.selectionClick();
    final result = await Navigator.of(context).pushNamed(
      RoutesConst.loanRepaymentScreen,
      arguments: LoanRepaymentArgs(loan: widget.args.loan),
    );
    if (result == true && mounted) {
      ref.read(loanAccountDetailProvider(_detailKey).notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(loanAccountDetailProvider(_detailKey));
    final brand = HomeColors.brand(context);
    final textSecondary = HomeColors.textSecondary(context);

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      appBar: AppBar(
        title: Text(
          widget.args.loan.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: HomeColors.bg(context),
        foregroundColor: HomeColors.textPrimary(context),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: brand,
          unselectedLabelColor: textSecondary,
          indicatorColor: brand,
          tabs: [
            Tab(text: l10n.loanDetailsTabOverview),
            Tab(text: l10n.loanDetailsTabSchedule),
            Tab(text: l10n.loanDetailsTabDisbursements),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(loanAccountDetailProvider(_detailKey).notifier).refresh(),
        child: _buildBody(context, l10n, state),
      ),
      floatingActionButton: state.details == null
          ? null
          : FloatingActionButton.extended(
        onPressed: _openRepayment,
        backgroundColor: brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.payments_outlined),
        label: Text(l10n.repayNow),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context,
      AppLocalizations l10n,
      LoanDetailState state,
      ) {
    if (state.isLoading && state.details == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    final details = state.details;

    if (details == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: HomeColors.textSecondary(context),
          ),
          const SizedBox(height: 12),
          Text(
            state.errorMessage ?? l10n.errorLoanDetailsLoadFailed,
            textAlign: TextAlign.center,
            style: TextStyle(color: HomeColors.textSecondary(context)),
          ),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(
              onPressed: () => ref
                  .read(loanAccountDetailProvider(_detailKey).notifier)
                  .refresh(),
              child: Text(l10n.accountsRetry),
            ),
          ),
        ],
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _OverviewTab(loan: widget.args.loan, details: details),
        _ScheduleTab(
          schedule: state.schedule,
          errorMessage: state.scheduleError,
        ),
        _DisbursementsTab(
          disbursements: state.disbursements,
          errorMessage: state.disbursementsError,
        ),
      ],
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.loan, required this.details});

  final LoanAccount loan;
  final LoanAccountDetails details;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currency = details.approvedAmount?.currency ??
        details.outstandingAmount?.currency ??
        loan.currencyCode;

    String money(double? amount) {
      if (amount == null) return '—';
      return MoneyFormat.format(amount, currencyCode: currency);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HomeColors.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HomeColors.divider(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _AmountBlock(
                      label: l10n.loanApprovedAmount,
                      value: money(details.approvedAmount?.amount),
                    ),
                  ),
                  Expanded(
                    child: _AmountBlock(
                      label: l10n.loanOutstandingAmountLabel,
                      value: money(details.outstandingAmount?.amount),
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: HomeColors.divider(context), height: 1),
              const SizedBox(height: 16),
              _InfoRow(
                label: l10n.loanNextDueDate,
                value: _formatDate(details.nextDueDate),
              ),
              _InfoRow(
                label: l10n.loanNextInstallmentAmount,
                value: money(details.nextInstallmentAmount?.amount),
              ),
              _InfoRow(
                label: l10n.loanInstallmentsPaid,
                value: details.installmentPaidCount?.toString() ?? '—',
              ),
              _InfoRow(
                label: l10n.loanInstallmentsDue,
                value: details.installmentDueCount?.toString() ?? '—',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HomeColors.card(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HomeColors.divider(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoRow(
                label: l10n.loanDisbursedAmount,
                value: money(details.disbursedAmount?.amount),
              ),
              _InfoRow(
                label: l10n.loanInterestRateLabel,
                value: details.interestRate != null
                    ? '${details.interestRate}%'
                    : '—',
              ),
              _InfoRow(
                label: l10n.loanRepaymentModeLabel,
                value: details.repaymentMode ?? '—',
              ),
              _InfoRow(
                label: l10n.loanOpeningDate,
                value: _formatDate(details.openingDate),
              ),
              _InfoRow(
                label: l10n.loanMaturityDate,
                value: _formatDate(details.maturityDate),
              ),
              _InfoRow(
                label: l10n.loanTenure,
                value: _formatTenure(details.tenureMonths, details.tenureDays),
              ),
              _InfoRow(
                label: l10n.loanNumberOfInstallments,
                value: details.numberOfInstallment?.toString() ?? '—',
              ),
              if (details.branchName != null)
                _InfoRow(
                  label: l10n.loanBranchLabel,
                  value: details.branchName!,
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTenure(int? months, int? days) {
    if (months == null && days == null) return '—';
    final parts = <String>[];
    if (months != null && months > 0) parts.add('$months mo');
    if (days != null && days > 0) parts.add('$days d');
    return parts.isEmpty ? '—' : parts.join(' ');
  }
}

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab({required this.schedule, this.errorMessage});

  final LoanSchedule? schedule;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (schedule == null || schedule!.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          Icon(
            Icons.event_note_outlined,
            size: 40,
            color: HomeColors.textSecondary(context),
          ),
          const SizedBox(height: 12),
          Text(
            errorMessage ?? l10n.loanScheduleEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(color: HomeColors.textSecondary(context)),
          ),
        ],
      );
    }

    final items = schedule!.items;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: HomeColors.divider(context)),
      itemBuilder: (context, index) {
        final item = items[index];
        final paid = item.isPaid;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(item.dueDate),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: HomeColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.loanScheduleColumnPrincipal}: '
                          '${MoneyFormat.format(item.principal.amount, currencyCode: item.principal.currency ?? '')}'
                          '  ·  '
                          '${l10n.loanScheduleColumnInterest}: '
                          '${MoneyFormat.format(item.interest.amount, currencyCode: item.interest.currency ?? '')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: HomeColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    MoneyFormat.format(
                      item.installmentAmount.amount,
                      currencyCode: item.installmentAmount.currency ?? '',
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: HomeColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    paid
                        ? l10n.loanScheduleStatusPaid
                        : l10n.loanScheduleStatusUnpaid,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: paid
                          ? AppColors.successColor
                          : AppColors.warningColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DisbursementsTab extends StatelessWidget {
  const _DisbursementsTab({required this.disbursements, this.errorMessage});

  final List<LoanDisbursement>? disbursements;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (disbursements == null || disbursements!.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          Icon(
            Icons.payments_outlined,
            size: 40,
            color: HomeColors.textSecondary(context),
          ),
          const SizedBox(height: 12),
          Text(
            errorMessage ?? l10n.loanDisbursementsEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(color: HomeColors.textSecondary(context)),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: disbursements!.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: HomeColors.divider(context)),
      itemBuilder: (context, index) {
        final item = disbursements![index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${l10n.loanDisbursementDateLabel}: ${_formatDate(item.date)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: HomeColors.textPrimary(context),
                  ),
                ),
              ),
              Text(
                MoneyFormat.format(
                  item.amount.amount,
                  currencyCode: item.amount.currency ?? '',
                ),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: HomeColors.textPrimary(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AmountBlock extends StatelessWidget {
  const _AmountBlock({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = alignEnd ? TextAlign.right : TextAlign.left;
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: 12,
            color: HomeColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: HomeColors.textPrimary(context),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: HomeColors.textSecondary(context),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: HomeColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const List<String> _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  final month = _monthNames[(date.month - 1).clamp(0, 11)];
  return '${date.day.toString().padLeft(2, '0')} $month ${date.year}';
}