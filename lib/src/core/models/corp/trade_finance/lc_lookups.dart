import 'package:ubci_bank/src/core/models/corp/trade_finance/lc_common.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/lc_product.dart';

/// Reference data the Initiate / Amend LC screens need, loaded together.
///
/// Every list tolerates its own endpoint failing (it stays empty) — the
/// pre-sales host returns an empty currency enumeration (H1 #42) and 500s
/// on some lookups, and the form must still open.
class LcLookups {
  const LcLookups({
    this.products = const [],
    this.currencies = const [],
    this.countries = const [],
    this.confirmationInstructions = const [],
    this.goods = const [],
    this.incoterms = const [],
    this.additionalConditions = const [],
    this.configuration = TradeFinanceConfiguration.empty,
  });

  final List<LcProduct> products;

  /// `tradeEnumerations/currencies`, falling back to the bank currency
  /// master when the trade list is empty (as on pre-sales).
  final List<TradeCode> currencies;
  final List<TradeCode> countries;
  final List<TradeCode> confirmationInstructions;
  final List<TradeCode> goods;
  final List<TradeCode> incoterms;
  final List<TradeCode> additionalConditions;
  final TradeFinanceConfiguration configuration;

  static const empty = LcLookups();

  /// Confirmation instructions with the captured default set when the
  /// enumeration is unavailable (H1 #115 values).
  List<TradeCode> get confirmationOptions => confirmationInstructions.isNotEmpty
      ? confirmationInstructions
      : const [
          TradeCode(code: 'CONFIRM', description: 'Confirm'),
          TradeCode(code: 'MAY_ADD', description: 'May Confirm'),
          TradeCode(code: 'WITHOUT', description: 'Without'),
        ];

  String countryName(String? code) {
    if (code == null) return '—';
    for (final c in countries) {
      if (c.code == code) return c.label;
    }
    return code;
  }

  LcLookups copyWith({List<TradeCode>? currencies}) => LcLookups(
        products: products,
        currencies: currencies ?? this.currencies,
        countries: countries,
        confirmationInstructions: confirmationInstructions,
        goods: goods,
        incoterms: incoterms,
        additionalConditions: additionalConditions,
        configuration: configuration,
      );
}
