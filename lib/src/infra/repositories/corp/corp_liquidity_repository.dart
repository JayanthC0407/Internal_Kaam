import 'package:ubci_bank/src/core/models/common/obdx_batch.dart';
import 'package:ubci_bank/src/core/models/corp/liquidity_charges_models.dart';
import 'package:ubci_bank/src/core/models/corp/liquidity_overview_models.dart';
import 'package:ubci_bank/src/infra/network/apis/corp/obdx_corp_liquidity_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/corp/corp_repository_base.dart';

/// Liquidity Management: parses [ObdxCorpLiquidityApi] answers.
class CorpLiquidityRepository extends CorpRepositoryBase {
  CorpLiquidityRepository({required ObdxCorpLiquidityApi api}) : _api = api;

  final ObdxCorpLiquidityApi _api;

  /// Charges Inquiry's form data. Each call is best effort, as in OBDX: a
  /// failed list is empty, and the form opens whatever `maintenances`
  /// answered (hooks.js:109-136, 277-291).
  Future<LmChargeSetup> fetchChargeSetup() async {
    final (definitions, statuses, maintenances) =
        await (_api.fetchChargeDefinitions(), _api.fetchCollectionStatuses(), _api.fetchMaintenances()).wait;
    Map<String, dynamic> body(ResponseHandler<Map<String, dynamic>> r) =>
        r is Success<Map<String, dynamic>> && r.data != null ? ObdxApiUtils.asMap(r.data!['body']) : const {};
    return LmChargeSetup(
      definitions: LmOption.definitionsFrom(body(definitions)),
      statuses: LmOption.statusesFrom(body(statuses)),
      maintainedMaxDays: LmChargeSetup.maxDaysFrom(body(maintenances)),
    );
  }

  /// Search: `charges?q=…`.
  Future<ResponseHandler<List<LmCharge>>> fetchCharges(LmChargeQuery query) async =>
      parseBody(await _api.fetchCharges(query.toQ()), LmCharge.listFromPayload);

  /// Download: the same query as CSV.
  Future<ResponseHandler<List<int>>> downloadCharges(LmChargeQuery query) => _api.downloadCharges(query.toQ());

  // ---------------------------------------------------------------- Overview

  static Map<String, dynamic> _body(ResponseHandler<Map<String, dynamic>> r) =>
      r is Success<Map<String, dynamic>> && r.data != null ? ObdxApiUtils.asMap(r.data!['body']) : const {};

  /// Position By Currency (hooks.js:84-146): `me/party`, then
  /// `accounts?isNotional=false&sortBy=null&count=null` — its arguments sit
  /// one place off, so `sortBy` / `count` go as the text `null` (card §4).
  Future<ResponseHandler<LmBalances>> fetchPositionByCurrency() async {
    final party = await _api.fetchParty();
    final accounts = await _api.fetchAccounts(const {'isNotional': 'false', 'sortBy': 'null', 'count': 'null'});
    final parsed = await parseBody(accounts, LmAccount.listFromPayload);
    if (parsed is! Success<List<LmAccount>>) return mapFailure(parsed);
    return ResponseHandler.success(LmBalances(accounts: parsed.data ?? const [], partyName: lmPartyName(_body(party))),
        code: 200);
  }

  /// Position By Region (card §5): `me/party`, `currencies`,
  /// `accounts?isNotional=false`, `bankConfiguration`.
  Future<ResponseHandler<LmBalances>> fetchRegionBalances() => _balances(
        accountsQuery: const {'isNotional': 'false'},
      );

  /// Assets & Liabilities (card §6): the accounts query with OBDX's `null`s,
  /// `currencies`, `bankConfiguration`, `me/party?media=null`.
  Future<ResponseHandler<LmBalances>> fetchAssetsBalances() => _balances(
        accountsQuery: const {
          'taskCode': 'null',
          'isNotional': 'false',
          'isLinkedParties': 'null',
          'isMultiStructure': 'null',
          'q': 'null',
          'sortBy': 'null',
          'count': 'null',
        },
        partyQuery: const {'media': 'null'},
      );

  Future<ResponseHandler<LmBalances>> _balances({
    required Map<String, String> accountsQuery,
    Map<String, String>? partyQuery,
  }) async {
    final (accounts, currencies, bank, party) = await (
      _api.fetchAccounts(accountsQuery),
      _api.fetchCurrencies(),
      _api.fetchBankConfiguration(),
      _api.fetchParty(partyQuery),
    ).wait;
    final parsed = await parseBody(accounts, LmAccount.listFromPayload);
    if (parsed is! Success<List<LmAccount>>) return mapFailure(parsed);
    return ResponseHandler.success(
      LmBalances(
        accounts: parsed.data ?? const [],
        currencies: lmCurrencies(_body(currencies)),
        localCurrency: lmLocalCurrency(_body(bank)),
        partyName: lmPartyName(_body(party)),
      ),
      code: 200,
    );
  }

  /// FX rates for [accounts] into [target]; no call when none is needed.
  /// A failed batch gives no rates, so the widget says "Exchange rate not
  /// found", as OBDX's missing-rate case.
  Future<LmRates> fetchRates(List<LmAccount> accounts, String target) async {
    final requests = LmRates.requests(accounts, target);
    if (requests.isEmpty) return LmRates.none;
    final result = await _api.fetchRates(requests);
    final body = _body(result);
    return LmRates.fromResults(ObdxBatchItemResult.listFromPayload(body));
  }

  /// Top 5 Sweeps and Top 5 Cross Currency Sweeps' currency list:
  /// `currencies?limit=null&offset=null&q=null` and `bankConfiguration`.
  Future<LmBalances> fetchSweepCurrencies() async {
    final (currencies, bank) = await (
      _api.fetchCurrencies(const {'limit': 'null', 'offset': 'null', 'q': 'null'}),
      _api.fetchBankConfiguration(),
    ).wait;
    return LmBalances(currencies: lmCurrencies(_body(currencies)), localCurrency: lmLocalCurrency(_body(bank)));
  }

  /// The five largest executed sweeps into [currency] over the last month:
  /// cross-currency (`crossCcy=true`, with `structureId=null`) or not
  /// (`crossCcy=false`, no `structureId`) (card §7, §8.1).
  Future<ResponseHandler<List<LmSweepLog>>> fetchTopSweeps(String currency,
      {required bool cross, required DateTime today}) async {
    final result = await _api.fetchSweepLogs({
      if (cross) 'structureId': 'null',
      'fromDate': lmIsoDate(lmMonthFrom(today, -1)),
      'toDate': lmIsoDate(today),
      'sweepStatus': 'S',
      'structureType': 'Sweep',
      'toAccCcy': currency,
      'crossCcy': '$cross',
    });
    return parseBody(result, (b) => LmSweepLog.topFive(LmSweepLog.listFromPayload(b)));
  }

  /// Sweep Monitor's Structure Details (best effort).
  Future<Map<String, String>> fetchStructures() async => lmStructures(_body(await _api.fetchStructures(const {
        'limit': 'null',
        'offset': 'null',
        'structureType': 'null',
        'structureStatus': 'null',
        'latestDetailsRequired': 'null',
      })));

  static Map<String, String> _monitorQuery(LmSweepStatus status, DateTime today) {
    final w = status.window(today);
    return {
      'structureId': 'null',
      'fromDate': lmIsoDate(w.from),
      'toDate': lmIsoDate(w.to),
      'sweepStatus': status.code,
      'structureType': 'Sweep',
      'toAccCcy': 'null',
      'crossCcy': 'null',
    };
  }

  /// Sweep Monitor: the first 5 rows of [status], in server order.
  Future<ResponseHandler<List<LmSweepLog>>> fetchSweepMonitor(LmSweepStatus status, {required DateTime today}) async =>
      parseBody(await _api.fetchSweepLogs(_monitorQuery(status, today)),
          (b) => LmSweepLog.listFromPayload(b).take(5).toList());

  /// Sweep Monitor's Download (PDF or CSV) for the tab shown. OBDX sends
  /// `fromDate=null&toDate=null` for Pending (card §9); the app sends the
  /// tab's dates, so the file matches the list.
  Future<ResponseHandler<List<int>>> downloadSweepMonitor(LmSweepStatus status,
          {required DateTime today, required bool pdf}) =>
      _api.downloadSweepLogs(_monitorQuery(status, today),
          media: pdf ? 'application/pdf' : 'text/csv', mediaFormat: pdf ? 'pdf' : 'csv');
}
