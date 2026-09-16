/// Corporate (`corporateuser`) endpoint paths.
///
/// Every path here was taken from the Corporate "LOGIN to DASHBOARD" HAR
/// capture; the entry number of the capture is noted against each one so the
/// exact request/response shape stays traceable. Retail paths remain in
/// `ApiConst` — this class only adds what the corporate flow needs, it does
/// not shadow or replace it (host, headers, auth and locale handling are all
/// still shared through `ObdxDioClient` / `ApiConst`).
class CorpApiConst {
  CorpApiConst._();

  /// Aggregated account list + per-product-group summary.
  /// `GET /digx-common/account/v1/accounts` — capture entry #68.
  ///
  /// Unlike Retail's `dda/v1/demandDeposit`, this returns every product
  /// group the corporate user can see in one call, plus a `summary.items[]`
  /// roll-up already converted to the bank's calculation currency.
  static const String accountsApi = '/digx-common/account/v1/accounts';

  /// Demand-deposit (CASA) list — capture entry #38. Same payload shape as
  /// [accountsApi] but CASA-only; kept as a fallback for hosts where the
  /// aggregated endpoint is not enabled for corporate users.
  static const String demandDepositApi = '/digx-common/dda/v1/demandDeposit';

  /// Term / recurring deposits — capture entry #61.
  /// `GET /digx-common/td/v1/deposit?module=CON&module=ISL`
  static const String depositsApi = '/digx-common/td/v1/deposit';

  /// Loans & finances. Not exercised by the capture (the captured corporate
  /// party holds no loans — `summary.items[]` reports `accountType: LON,
  /// count: 0`), but it is the same `digx-common` list endpoint the Retail
  /// flow already uses successfully, so the Loans tab calls it directly.
  static const String loansApi = '/digx-common/loan/v1/loan';

  /// Corporate party behind the logged-in user — capture entry #12.
  static const String partyApi = '/digx-common/user/v1/me/party';

  /// Bank-wide configuration (calculation currency, enabled modules) —
  /// capture entry #7.
  static const String bankConfigurationApi =
      '/digx-common/common/v1/bankConfiguration';

  /// Unread-message badge count for the header bell — capture entry #10.
  /// `GET /digx-common/collaboration/v1/mailbox/count?msgFlag=T`
  static const String mailboxCountApi =
      '/digx-common/collaboration/v1/mailbox/count';

  /// Deposit modules requested by digx-ui on the corporate dashboard
  /// (conventional + Islamic) — capture entry #61 sends both.
  static const List<String> depositModules = ['CON', 'ISL'];
}
