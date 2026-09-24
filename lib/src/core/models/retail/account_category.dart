/// Which account type the "Recent Transactions" dashboard widget is
/// currently showing — Current and Savings / Loans / Term Deposits /
/// Recurring Deposits / Credit Cards.
///
/// Endpoints:
/// - `currentAndSavings` → `dda/v1/demandDeposit` (already built)
/// - `loans` → `loan/v1/loan` (already built)
/// - `termDeposits` → `td/v1/deposit?module=CON&module=ISL` — no populated
///   capture to build a working list/transactions flow against yet
/// - `recurringDeposits` → `td/v1/deposit?module=RD` — same caveat
/// - `creditCards` → no card module in this app yet
enum AccountCategory {
  currentAndSavings,
  loans,
  termDeposits,
  recurringDeposits,
  creditCards;

  /// Whether this category has a real, working transactions integration
  /// yet. Everything but `currentAndSavings`/`loans` shows as a
  /// placeholder in the widget until it's built out.
  bool get isSupported => this == currentAndSavings || this == loans;
}
