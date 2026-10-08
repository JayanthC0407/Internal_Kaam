import 'package:ubci_bank/src/core/models/retail/term_deposit.dart';

/// Route arguments for the term deposit details screen.
class TermDepositDetailsArgs {
  const TermDepositDetailsArgs({required this.deposit});

  final TermDeposit deposit;
}

/// Route arguments for a deposit's top-up, redeem and maturity-edit
/// screens. Each pops `true` once the action is done, so the caller can
/// refresh.
class TdActionArgs {
  const TdActionArgs({required this.deposit});

  final TermDeposit deposit;
}
