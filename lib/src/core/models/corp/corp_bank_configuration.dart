import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// `GET /digx-common/common/v1/bankConfiguration` (Corporate capture,
/// entry #7).
///
/// The corporate dashboard reads [calculationCurrency] so cross-currency
/// roll-ups are labelled with the currency the host actually converted to
/// (`summary.items[].total*` amounts are all in this currency), and
/// [moduleList] to decide which product modules to query at all.
class CorpBankConfiguration {
  const CorpBankConfiguration({
    this.bankCode,
    this.region,
    this.homeBranch,
    this.localCurrency,
    this.calculationCurrency,
    this.moduleList = const <String>[],
    this.accountUniqueness,
  });

  static const empty = CorpBankConfiguration();

  final String? bankCode;
  final String? region;
  final String? homeBranch;

  /// `localCurrency` — the bank's own reporting currency.
  final String? localCurrency;

  /// `calCurrency` — the currency `summary.items[]` totals are expressed in.
  final String? calculationCurrency;

  /// `moduleList`, e.g. `['CON', 'RD']`.
  final List<String> moduleList;

  final String? accountUniqueness;

  /// Preferred currency code for aggregate labels.
  String? get totalsCurrency => calculationCurrency ?? localCurrency;

  bool supportsModule(String module) => moduleList.any(
        (value) => value.trim().toUpperCase() == module.trim().toUpperCase(),
      );

  static CorpBankConfiguration fromPayload(dynamic data) {
    final root = _unwrap(data);
    if (root == null) return empty;

    final dto = ObdxApiUtils.asMap(
      root['bankConfigurationDTO'] ?? root['bankConfiguration'],
    );
    if (dto.isEmpty) return empty;

    final modulesRaw = dto['moduleList'];
    final modules = modulesRaw is List
        ? modulesRaw
            .map((module) => module?.toString().trim() ?? '')
            .where((module) => module.isNotEmpty)
            .toList()
        : const <String>[];

    return CorpBankConfiguration(
      bankCode: _trimmed(dto['bankCode']),
      region: _trimmed(dto['region']),
      homeBranch: _trimmed(dto['homeBranch']),
      localCurrency: _trimmed(dto['localCurrency']),
      calculationCurrency: _trimmed(dto['calCurrency']),
      moduleList: modules,
      accountUniqueness: _trimmed(dto['accountUniqueness']),
    );
  }

  static Map<String, dynamic>? _unwrap(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map.containsKey('bankConfigurationDTO') ||
        map.containsKey('bankConfiguration')) {
      return map;
    }
    final body = map['body'];
    if (body is Map) return _unwrap(body);
    return map;
  }

  static String? _trimmed(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }
}
