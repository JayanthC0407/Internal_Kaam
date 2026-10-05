import 'package:ubci_bank/src/core/models/corp/trade_finance/lc_common.dart';

/// An LC product from `GET …/tradeproducts/letterofcredits` (H1 #51).
///
/// The product drives the tolerance defaults, revolving flag and the
/// sight/usance period shown on the initiate screen.
class LcProduct {
  const LcProduct({
    required this.id,
    required this.name,
    this.irrevocable = false,
    this.revolving = false,
    this.periodIndicator,
    this.positiveTolerance = 0,
    this.negativeTolerance = 0,
  });

  final String id;
  final String name;
  final bool irrevocable;
  final bool revolving;

  /// `SIGHT` / `USANCE`.
  final String? periodIndicator;
  final double positiveTolerance;
  final double negativeTolerance;

  String get label => '$name ($id)';

  static LcProduct? fromJson(dynamic json) {
    final map = TfJson.map(json);
    final id = TfJson.str(map['id']);
    if (id == null) return null;
    return LcProduct(
      id: id,
      name: TfJson.str(map['name']) ?? id,
      irrevocable: TfJson.boolean(map['irrevocable']),
      revolving: TfJson.boolean(map['revolving']),
      periodIndicator: TfJson.str(map['periodIndicator']),
      positiveTolerance: TfJson.dbl(map['positiveTolerance']) ?? 0,
      negativeTolerance: TfJson.dbl(map['negativeTolerance']) ?? 0,
    );
  }

  static List<LcProduct> listFromPayload(dynamic data) {
    final root = TfJson.root(data);
    return [
      for (final item in TfJson.maps(root['lcProductDTOList']))
        if (LcProduct.fromJson(item) case final product?) product,
    ];
  }

  /// The `letterOfCreditProductDTO` block of the LC request (H1 #121).
  Map<String, dynamic> toRequestJson() => {
        'id': id,
        'name': name,
        'irrevocable': irrevocable,
        'revolving': revolving,
        'periodIndicator': periodIndicator,
        'currencies': const <dynamic>[],
        'documents': const <dynamic>[],
        'positiveTolerance': positiveTolerance,
        'negativeTolerance': negativeTolerance,
      };

  @override
  bool operator ==(Object other) => other is LcProduct && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A document the product requires/allows — H1 #159
/// (`tradeproducts/letterofcredits/{id}/documents`).
class LcDocument {
  const LcDocument({
    required this.id,
    required this.name,
    this.docType,
    this.clauses = const [],
    this.originals = 1,
    this.copies = 0,
  });

  final String id;
  final String name;

  /// `T` transport, `O` other, `C` commercial (as returned by the host).
  final String? docType;
  final List<TradeCode> clauses;

  /// Number of originals / copies the user asks the beneficiary to present.
  final int originals;
  final int copies;

  LcDocument copyWith({
    int? originals,
    int? copies,
    List<TradeCode>? clauses,
  }) =>
      LcDocument(
        id: id,
        name: name,
        docType: docType,
        clauses: clauses ?? this.clauses,
        originals: originals ?? this.originals,
        copies: copies ?? this.copies,
      );

  static LcDocument? fromJson(dynamic json) {
    final map = TfJson.map(json);
    final id = TfJson.str(map['id']);
    if (id == null) return null;
    return LcDocument(
      id: id,
      name: TfJson.str(map['name']) ?? id,
      docType: TfJson.str(map['docType']),
      clauses: [
        for (final clause in TfJson.maps(map['clause']))
          if (TfJson.str(clause['id']) case final clauseId?)
            TradeCode(
              code: clauseId,
              description: TfJson.str(clause['description']),
            ),
      ],
      originals: TfJson.integer(map['copies']) ?? 1,
      copies: TfJson.integer(map['secondCopies']) ?? 0,
    );
  }

  /// Product documents (H1 #159) or the document master (H1 #105).
  static List<LcDocument> listFromPayload(dynamic data) {
    final root = TfJson.root(data);
    final product = TfJson.map(root['letterOfCreditProductDTO']);
    final raw = product.isNotEmpty ? product['documents'] : root['documents'];
    return [
      for (final item in TfJson.maps(raw))
        if (LcDocument.fromJson(item) case final doc?) doc,
    ];
  }

  /// Entry of the LC request's `document[]`.
  ///
  /// ASSUMPTION: no captured request had a non-empty `document[]` (the
  /// copied LC had none). This mirrors the document-master shape the host
  /// returns (H1 #105/#159); confirm against a capture with documents.
  Map<String, dynamic> toRequestJson() => {
        'id': id,
        'name': name,
        'docType': docType,
        'copies': originals,
        'secondCopies': copies,
        'clause': [
          for (final clause in clauses)
            {'id': clause.code, 'description': clause.description, 'docId': id},
        ],
      };
}

/// `GET …/configurations` (H1 #44) — trade-finance host configuration.
class TradeFinanceConfiguration {
  const TradeFinanceConfiguration({
    this.branchCode,
    this.islamicBranchCode,
    this.walkinCustomerId = TfId.empty,
    this.values = const {},
  });

  /// `TRADE_BRANCH_CODE` — the `branchId` the web sends on a new LC.
  final String? branchCode;
  final String? islamicBranchCode;
  final TfId walkinCustomerId;
  final Map<String, String> values;

  static const empty = TradeFinanceConfiguration();

  factory TradeFinanceConfiguration.fromPayload(dynamic data) {
    final root = TfJson.root(data);
    final list = TfJson.map(root['configResponseList']);
    final values = <String, String>{
      for (final entry in list.entries)
        if (TfJson.str(entry.value) case final v?) entry.key: v,
    };
    return TradeFinanceConfiguration(
      branchCode: values['TRADE_BRANCH_CODE'],
      islamicBranchCode: values['ISLAMIC_TRADE_BRANCH_CODE'],
      walkinCustomerId: TfId.fromJson(root['walkinCustomerId']),
      values: values,
    );
  }
}
