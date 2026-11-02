import 'package:flutter/material.dart';

import 'package:demo_bank/src/core/models/corp/corp_loans_models.dart';
import 'package:demo_bank/src/view/screens/common/dashboard/module_hub_page.dart';
import 'package:demo_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:demo_bank/src/view/screens/corp/loans/corp_loan_application_tracker_screen.dart';
import 'package:demo_bank/src/view/screens/corp/loans/corp_loan_notices_screen.dart';
import 'package:demo_bank/src/view/screens/corp/loans/corp_loan_transactions_screen.dart';
import 'package:demo_bank/src/view/screens/corp/loans/corp_multi_loan_repayment_screen.dart';

/// Corporate Loans & Finances (OBDX corporate menu `OBCL_LOAN`), its own
/// side-menu entry beside Loan, on one page: Transactions, Messages,
/// Advices, Multiple Loan Repayment and Application Tracker. Each tile's
/// screen opens through [open], so it runs inside the dashboard with the
/// side menu and header in place.
class CorpLoansHubScreen extends StatelessWidget {
  const CorpLoansHubScreen({super.key, required this.open, this.onBack});

  /// Shows a screen in the dashboard; the builder gets its Back.
  final void Function(Widget Function(VoidCallback back) page) open;

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => ModuleHubPage(
        title: 'Corporate Loans & Finances',
        subtitle: 'Your loans’ transactions, messages and advices, repayments and applications.',
        onBack: onBack,
        tiles: [
          PayOptionTile(
            icon: Icons.receipt_long_rounded,
            title: 'Transactions',
            subtitle: 'A loan’s transactions for a period',
            onTap: () => open((back) => CorpLoanTransactionsScreen(onBack: back)),
          ),
          PayOptionTile(
            icon: Icons.mail_outline_rounded,
            title: 'Messages',
            subtitle: 'SWIFT messages sent for a loan',
            onTap: () => open((back) => CorpLoanNoticesScreen(kind: CorpLoanNoticeKind.message, onBack: back)),
          ),
          PayOptionTile(
            icon: Icons.description_outlined,
            title: 'Advices',
            subtitle: 'Advices issued for a loan',
            onTap: () => open((back) => CorpLoanNoticesScreen(kind: CorpLoanNoticeKind.advice, onBack: back)),
          ),
          PayOptionTile(
            icon: Icons.payments_outlined,
            title: 'Multiple Loan Repayment',
            subtitle: 'Repay several contracts in one go',
            onTap: () => open((back) => CorpMultiLoanRepaymentScreen(onBack: back)),
          ),
          PayOptionTile(
            icon: Icons.track_changes_rounded,
            title: 'Application Tracker',
            subtitle: 'Drafts and loan applications you have sent',
            onTap: () => open((back) => CorpLoanApplicationTrackerScreen(onBack: back)),
          ),
        ],
      );
}
