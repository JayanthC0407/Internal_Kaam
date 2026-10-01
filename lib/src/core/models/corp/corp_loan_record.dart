import 'package:ubci_bank/src/core/models/retail/loan_account.dart';
import 'package:ubci_bank/src/core/models/retail/loan_account_details.dart';

/// One loan as the Loans widgets need it: the list entry from
/// `loan/v1/loan`, and its detail call (`loan/v1/loan/{id}`) when that
/// loaded — the rate, EMI, next due date and maturity live only there.
class CorpLoanRecord {
  const CorpLoanRecord({required this.account, this.details});

  final LoanAccount account;
  final LoanAccountDetails? details;

  double get outstanding =>
      account.outstandingAmount?.amount ??
      details?.outstandingAmount?.amount ??
      0;

  /// What was lent: the sanctioned amount, else the approved one, else — a
  /// host that reports neither — the outstanding balance, so a repaid share
  /// is never invented.
  double get financed =>
      account.sanctionedAmount?.amount ??
      details?.approvedAmount?.amount ??
      outstanding;
}
