import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/loan_account.dart';
import 'package:ubci_bank/src/core/models/loan_account_details.dart';
import 'package:ubci_bank/src/core/utils/money_format.dart';
import 'package:ubci_bank/src/core/utils/responsive.dart';
import 'package:ubci_bank/src/view/providers/loan_detail_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/accounts/loan_repayment_screen.dart';
import 'package:ubci_bank/src/view/screens/accounts/widgets/casa_shared_widgets.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// Route arguments for [LoanAccountDetailsScreen].
class LoanAccountDetailsArgs {
  const LoanAccountDetailsArgs({required this.loan});

  final LoanAccount loan;
}

/// Loan overview + repayment schedule + disbursement history for a single
/// loan, backed by `GET /digx-common/loan/v1/loan/{id}` and its
/// `/schedule` and `/disbursements` sub-resources.
///
/// Redesigned to match the "Loan & Finance" detail UX/UI spec: a brand
/// summary banner (Total Outstanding Balance, maskable, with an inline
/// Repay Now action), a loan-identity info grid, an EMI/repayment info
/// grid, and a Schedule / Disbursements segmented list — all in a single
/// scroll, matching the provided design.
class LoanAccountDetailsScreen extends ConsumerStatefulWidget {
  const LoanAccountDetailsScreen({
    super.key,
    required this.args,
    this.embedded = false,
    this.onBack,
  });

  final LoanAccountDetailsArgs args;

  /// When `true`, this screen is rendered inline inside the desktop/wide
  /// dashboard shell (next to the persistent [WebNavigationSidebar]) rather
  /// than pushed as its own route.
  final bool embedded;

  /// Back handler used by the embedded header; ignored when not embedded.
  final VoidCallback? onBack;

  @override
  ConsumerState<LoanAccountDetailsScreen> createState() =>
      _LoanAccountDetailsScreenState();
}

class _LoanAccountDetailsScreenState
    extends ConsumerState<LoanAccountDetailsScreen> {
  late final LoanDetailKey _detailKey;
  bool _balanceHidden = false;
  int _subTab = 0; // 0 = Schedule, 1 = Disbursements

  @override
  void initState() {
    super.initState();
    _detailKey = LoanDetailKey(
      loanId: widget.args.loan.id,
      module: widget.args.loan.module,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(loanAccountDetailProvider(_detailKey).notifier).ensureLoaded();
    });
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
    final wide = Responsive.of(context).useWideLayout;
    final state = ref.watch(loanAccountDetailProvider(_detailKey));

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                wide ? 28 : 16,
                wide ? 12 : 12,
                wide ? 28 : 16,
                8,
              ),
              child: CasaScreenHeader(
                title: widget.args.loan.title,
                wide: wide,
                onBack: widget.onBack,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref
                    .read(loanAccountDetailProvider(_detailKey).notifier)
                    .refresh(),
                child: _buildBody(context, l10n, state, wide),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    LoanDetailState state,
    bool wide,
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

    final currency = details.approvedAmount?.currency ??
        details.outstandingAmount?.currency ??
        widget.args.loan.currencyCode;

    String money(double? amount, {bool hidden = false}) {
      if (amount == null) return '—';
      return MoneyFormat.format(amount, currencyCode: currency, hidden: hidden);
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 8, wide ? 28 : 16, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _Banner(
          loan: widget.args.loan,
          details: details,
          wide: wide,
          hidden: _balanceHidden,
          onToggleHidden: () =>
              setState(() => _balanceHidden = !_balanceHidden),
          money: money,
          onRepay: _openRepayment,
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          decoration: BoxDecoration(
            color: HomeColors.card(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HomeColors.divider(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoGrid(
                wide: wide,
                columns: wide ? 5 : 2,
                fields: [
                  CasaDetailField(
                    label: 'Account Number',
                    value: details.displayNumber.isEmpty
                        ? widget.args.loan.displayNumber
                        : details.displayNumber,
                  ),
                  CasaDetailField(
                    label: 'Loan Holder',
                    value: details.holderName?.trim().isNotEmpty == true
                        ? details.holderName!
                        : '—',
                  ),
                  CasaDetailField(
                    label: 'Status',
                    value: (details.status?.trim().isNotEmpty ?? false)
                        ? details.status!
                        : 'Active',
                  ),
                  CasaDetailField(
                    label: l10n.loanOpeningDate,
                    value: _formatDate(details.openingDate),
                  ),
                  CasaDetailField(
                    label: l10n.loanMaturityDate,
                    value: _formatDate(details.maturityDate),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Divider(color: HomeColors.divider(context), height: 1),
              const SizedBox(height: 12),
              _InfoGrid(
                wide: wide,
                columns: wide ? 6 : 2,
                fields: [
                  CasaDetailField(
                    label: l10n.loanInterestRateLabel,
                    value: details.interestRate != null
                        ? '${details.interestRate}%'
                        : '—',
                  ),
                  CasaDetailField(
                    label: l10n.loanNextInstallmentAmount,
                    value: money(details.nextInstallmentAmount?.amount),
                  ),
                  CasaDetailField(
                    label: l10n.loanNextDueDate,
                    value: _formatDate(details.nextDueDate),
                  ),
                  CasaDetailField(
                    label: l10n.loanOutstandingAmountLabel,
                    value: money(details.outstandingAmount?.amount),
                  ),
                  CasaDetailField(
                    label: l10n.loanRepaymentModeLabel,
                    value: details.repaymentMode ?? '—',
                  ),
                  CasaDetailField(
                    label: l10n.loanBranchLabel,
                    value: details.branchName ?? '—',
                  ),
                  CasaDetailField(
                    label: l10n.loanTenure,
                    value:
                        _formatTenure(details.tenureMonths, details.tenureDays),
                  ),
                  CasaDetailField(
                    label: l10n.loanNumberOfInstallments,
                    value: details.numberOfInstallment?.toString() ?? '—',
                  ),
                  CasaDetailField(
                    label: l10n.loanInstallmentsPaid,
                    value: details.installmentPaidCount?.toString() ?? '—',
                  ),
                  CasaDetailField(
                    label: l10n.loanInstallmentsDue,
                    value: details.installmentDueCount?.toString() ?? '—',
                  ),
                  CasaDetailField(
                    label: l10n.loanDisbursedAmount,
                    value: money(details.disbursedAmount?.amount),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SubTabBar(
          selected: _subTab,
          onChanged: (i) => setState(() => _subTab = i),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: HomeColors.card(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HomeColors.divider(context)),
          ),
          child: _subTab == 0
              ? _ScheduleList(
                  schedule: state.schedule,
                  errorMessage: state.scheduleError,
                )
              : _DisbursementsList(
                  disbursements: state.disbursements,
                  errorMessage: state.disbursementsError,
                ),
        ),
      ],
    );
  }
}

String _formatTenure(int? months, int? days) {
  if (months == null && days == null) return '—';
  final parts = <String>[];
  if (months != null && months > 0) parts.add('$months mo');
  if (days != null && days > 0) parts.add('$days d');
  return parts.isEmpty ? '—' : parts.join(' ');
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.loan,
    required this.details,
    required this.wide,
    required this.hidden,
    required this.onToggleHidden,
    required this.money,
    required this.onRepay,
  });

  final LoanAccount loan;
  final LoanAccountDetails details;
  final bool wide;
  final bool hidden;
  final VoidCallback onToggleHidden;
  final String Function(double?, {bool hidden}) money;
  final VoidCallback onRepay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repayButton = _RepayButton(onPressed: onRepay);
    final secondary = HomeColors.textSecondary(context);
    final primary = HomeColors.textPrimary(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: HomeColors.brand(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.request_quote_outlined,
                color: HomeColors.brand(context),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loan.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        l10n.loanOutstandingAmountLabel,
                        style: TextStyle(color: secondary, fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: onToggleHidden,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Icon(
                            hidden
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 14,
                            color: secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (wide) repayButton,
          ],
        ),
        const SizedBox(height: 8),
        Text(
          money(details.outstandingAmount?.amount, hidden: hidden),
          style: TextStyle(
            color: primary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${l10n.loanApprovedAmount}: '
          '${money(details.approvedAmount?.amount ?? loan.sanctionedAmount?.amount)}',
          style: TextStyle(
            color: secondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (!wide) ...[
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: repayButton),
        ],
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: content,
    );
  }
}

class _RepayButton extends StatelessWidget {
  const _RepayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: HomeColors.brand(context),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      icon: const Icon(Icons.payments_outlined, size: 16),
      label: Text(
        l10n.repayNow,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Responsive N-per-row label/value grid used for the loan info sections.
class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.wide, required this.columns, required this.fields});

  final bool wide;
  final int columns;
  final List<CasaDetailField> fields;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < fields.length; i += columns) {
      final rowFields = fields.skip(i).take(columns).toList();
      final cells = <Widget>[];
      for (var c = 0; c < columns; c++) {
        if (c > 0) cells.add(const SizedBox(width: 12));
        cells.add(
          Expanded(
            child: c < rowFields.length ? rowFields[c] : const SizedBox.shrink(),
          ),
        );
      }
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells));
    }
    return Column(children: rows);
  }
}

class _SubTabBar extends StatelessWidget {
  const _SubTabBar({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        _SubTabItem(
          label: l10n.loanDetailsTabSchedule,
          selected: selected == 0,
          onTap: () => onChanged(0),
        ),
        const SizedBox(width: 24),
        _SubTabItem(
          label: l10n.loanDetailsTabDisbursements,
          selected: selected == 1,
          onTap: () => onChanged(1),
        ),
      ],
    );
  }
}

class _SubTabItem extends StatelessWidget {
  const _SubTabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final inactive = HomeColors.textSecondary(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? brand : inactive,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 2,
              width: 28,
              color: selected ? brand : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleList extends StatelessWidget {
  const _ScheduleList({required this.schedule, this.errorMessage});

  final LoanSchedule? schedule;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (schedule == null || schedule!.isEmpty) {
      return _EmptyTab(
        icon: Icons.event_note_outlined,
        message: errorMessage ?? l10n.loanScheduleEmpty,
      );
    }

    final items = schedule!.items;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: HomeColors.divider(context)),
      itemBuilder: (context, index) {
        final item = items[index];
        final paid = item.isPaid;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: (paid ? HomeColors.success(context) : HomeColors.warning(context))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  paid ? Icons.check_rounded : Icons.north_east_rounded,
                  size: 15,
                  color: paid ? HomeColors.success(context) : HomeColors.warning(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(item.dueDate),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
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
                    (paid ? '-' : '') +
                        MoneyFormat.format(
                          item.installmentAmount.amount,
                          currencyCode: item.installmentAmount.currency ?? '',
                        ),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: paid ? HomeColors.error(context) : HomeColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    paid ? l10n.loanScheduleStatusPaid : l10n.loanScheduleStatusUnpaid,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: paid ? HomeColors.success(context) : HomeColors.warning(context),
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

class _DisbursementsList extends StatelessWidget {
  const _DisbursementsList({required this.disbursements, this.errorMessage});

  final List<LoanDisbursement>? disbursements;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (disbursements == null || disbursements!.isEmpty) {
      return _EmptyTab(
        icon: Icons.payments_outlined,
        message: errorMessage ?? l10n.loanDisbursementsEmpty,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: disbursements!.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: HomeColors.divider(context)),
      itemBuilder: (context, index) {
        final item = disbursements![index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: HomeColors.brand(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.north_east_rounded,
                  size: 15,
                  color: HomeColors.brand(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${l10n.loanDisbursementDateLabel}: ${_formatDate(item.date)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: HomeColors.textPrimary(context),
                  ),
                ),
              ),
              Text(
                MoneyFormat.format(item.amount.amount, currencyCode: item.amount.currency ?? ''),
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

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 36, color: HomeColors.textSecondary(context)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: HomeColors.textSecondary(context)),
          ),
        ],
      ),
    );
  }
}

const List<String> _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  final month = _monthNames[(date.month - 1).clamp(0, 11)];
  return '${date.day.toString().padLeft(2, '0')} $month ${date.year}';
}