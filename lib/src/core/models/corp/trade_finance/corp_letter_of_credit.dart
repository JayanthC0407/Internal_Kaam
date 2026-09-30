import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/lc_common.dart';

/// Import (we are the applicant) or Export (we are the beneficiary).
enum LcType {
  importLc('Import', 'Import LC'),
  exportLc('Export', 'Export LC');

  const LcType(this.apiValue, this.label);

  /// Value of the `lcType` query parameter / DTO field.
  final String apiValue;
  final String label;

  static LcType fromApi(String? value) =>
      value?.toLowerCase() == 'export' ? LcType.exportLc : LcType.importLc;
}

/// Shipment block of an LC (`shipmentDetails`).
class LcShipmentDetails {
  const LcShipmentDetails({
    this.period,
    this.latestShipmentDate,
    this.source,
    this.destination,
    this.loadingPort,
    this.dischargePort,
    this.partialAllowed = false,
    this.transshipmentAllowed = false,
    this.mode,
  });

  /// Shipment period in days (`"30"` in the capture).
  final String? period;
  final DateTime? latestShipmentDate;

  /// Place of taking in charge / dispatch.
  final String? source;

  /// Place of final destination / delivery.
  final String? destination;
  final String? loadingPort;
  final String? dischargePort;
  final bool partialAllowed;
  final bool transshipmentAllowed;
  final String? mode;

  static const empty = LcShipmentDetails();

  factory LcShipmentDetails.fromJson(dynamic json) {
    final map = TfJson.map(json);
    return LcShipmentDetails(
      period: TfJson.str(map['period']),
      latestShipmentDate: TfJson.date(map['date']),
      source: TfJson.str(map['source']),
      destination: TfJson.str(map['destination']),
      loadingPort: TfJson.str(map['loadingPort']),
      dischargePort: TfJson.str(map['dischargePort']),
      partialAllowed: TfJson.boolean(map['partial']),
      transshipmentAllowed: TfJson.boolean(map['transShipment']),
      mode: TfJson.str(map['mode']),
    );
  }

  LcShipmentDetails copyWith({
    String? period,
    DateTime? latestShipmentDate,
    String? source,
    String? destination,
    String? loadingPort,
    String? dischargePort,
    bool? partialAllowed,
    bool? transshipmentAllowed,
  }) {
    return LcShipmentDetails(
      period: period ?? this.period,
      latestShipmentDate: latestShipmentDate ?? this.latestShipmentDate,
      source: source ?? this.source,
      destination: destination ?? this.destination,
      loadingPort: loadingPort ?? this.loadingPort,
      dischargePort: dischargePort ?? this.dischargePort,
      partialAllowed: partialAllowed ?? this.partialAllowed,
      transshipmentAllowed: transshipmentAllowed ?? this.transshipmentAllowed,
      mode: mode,
    );
  }

  /// Full `shipmentDetails` block as the create request sends it (H1 #71).
  /// `partial` / `transShipment` are `"Y"` / `"N"` strings on the wire.
  Map<String, dynamic> toRequestJson() => {
        'id': null,
        'period': period,
        'source': source,
        'date': TfDate.toApi(latestShipmentDate),
        'destination': destination,
        'loadingPort': loadingPort,
        'dischargePort': dischargePort,
        'goodsCode': null,
        'description': null,
        'partial': partialAllowed ? 'Y' : 'N',
        'transShipment': transshipmentAllowed ? 'Y' : 'N',
        'invoiceNumber': null,
        'mode': mode,
      };

  /// The trimmed block the amendment request sends (H1 #204).
  Map<String, dynamic> toAmendmentJson() => {
        'period': period,
        'source': source,
        'date': TfDate.toApi(latestShipmentDate),
        'destination': destination,
        'loadingPort': loadingPort,
        'dischargePort': dischargePort,
        'partial': partialAllowed ? 'Y' : 'N',
        'transShipment': transshipmentAllowed ? 'Y' : 'N',
      };
}

/// One line of `goods[]` — confirmed shape (H1 #71, #204).
class LcGoods {
  const LcGoods({
    required this.code,
    this.description,
    this.noOfUnits,
    this.pricePerUnit,
  });

  final String code;
  final String? description;
  final double? noOfUnits;
  final double? pricePerUnit;

  double? get total => (noOfUnits != null && pricePerUnit != null)
      ? noOfUnits! * pricePerUnit!
      : null;

  static LcGoods? fromJson(dynamic json) {
    final map = TfJson.map(json);
    final code = TfJson.str(map['code']);
    if (code == null) return null;
    return LcGoods(
      code: code,
      description: TfJson.str(map['description']),
      noOfUnits: TfJson.dbl(map['noOfUnits']),
      pricePerUnit: TfJson.dbl(map['pricePerUnit']),
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'description': description,
        'noOfUnits': _numOut(noOfUnits),
        'pricePerUnit': _numOut(pricePerUnit),
      };

  /// Whole numbers go out as ints (`2`, not `2.0`) — as in the capture.
  static num? _numOut(double? value) {
    if (value == null) return null;
    return value == value.roundToDouble() ? value.toInt() : value;
  }
}

/// One commission or tax line from `charges[].commissions[] / taxes[]`.
class LcCharge {
  const LcCharge({
    required this.label,
    required this.amount,
    this.isTax = false,
  });

  final String label;
  final MoneyAmount amount;
  final bool isTax;

  /// Parses the `charges[]` array of an LC detail (H1 #48) or of a charge
  /// preview response.
  static List<LcCharge> listFrom(dynamic chargesRaw) {
    final result = <LcCharge>[];
    for (final block in TfJson.maps(chargesRaw)) {
      for (final c in TfJson.maps(block['commissions'])) {
        result.add(LcCharge(
          label: TfJson.str(c['commitment']) ??
              TfJson.str(c['calcmth']) ??
              'Commission',
          amount: MoneyAmount.fromJson(c['amount']),
        ));
      }
      for (final t in TfJson.maps(block['taxes'])) {
        result.add(LcCharge(
          label: TfJson.str(t['ruleName']) ?? 'Tax',
          amount: MoneyAmount.fromJson(t['amount']),
          isTax: true,
        ));
      }
    }
    return result;
  }

  /// Sum per currency — charges can be booked in more than one currency.
  static Map<String, double> totalsByCurrency(List<LcCharge> charges) {
    final totals = <String, double>{};
    for (final charge in charges) {
      final ccy = charge.amount.currency ?? '';
      totals[ccy] = (totals[ccy] ?? 0) + charge.amount.amount;
    }
    return totals;
  }
}

/// A Letter of Credit as returned by the list (H1 #46) and detail (H1 #48)
/// endpoints — one class for both, since the list already carries most
/// summary fields and the detail only adds sections.
///
/// [raw] keeps the host payload untouched. The amendment request is built
/// on top of it so fields this app does not model (billing drafts,
/// insurance policies, confirmation-party details…) round-trip unchanged.
class CorpLetterOfCredit {
  const CorpLetterOfCredit({
    required this.id,
    required this.lcType,
    required this.raw,
    this.versionNo,
    this.productId,
    this.productName,
    this.status,
    this.state,
    this.authStatus,
    this.expiryStatus,
    this.applicationDate,
    this.expiryDate,
    this.expiryPlace,
    this.amount,
    this.outstandingAmount,
    this.equivalentAmount,
    this.partyId = TfId.empty,
    this.partyName,
    this.counterPartyName,
    this.counterPartyAddress = LcAddress.empty,
    this.branchId,
    this.customerReferenceNo,
    this.confirmationInstruction,
    this.transferableType,
    this.availableWith,
    this.advisingBankCode,
    this.advisingThroughBankCode,
    this.confirmingBankCode,
    this.issuingBankCode,
    this.reimbursingBankCode,
    this.documentPresentationDays,
    this.toleranceAbove,
    this.toleranceUnder,
    this.revolving = false,
    this.transferable = false,
    this.transferredLC = false,
    this.transferrableAmount,
    this.irrevocable = false,
    this.allowAmendment = false,
    this.shipment = LcShipmentDetails.empty,
    this.goods = const [],
    this.charges = const [],
    this.chargesBorneBy,
    this.incoterm,
    this.additionalConditions = const [],
    this.remarks,
    this.userName,
    this.draftName,
    this.lastUpdatedDate,
  });

  final String id;
  final LcType lcType;
  final Map<String, dynamic> raw;

  final String? versionNo;
  final String? productId;
  final String? productName;

  /// Host LC status, e.g. `ACTIVE`.
  final String? status;

  /// Workflow state, e.g. `INITIATED` / `DRAFT`.
  final String? state;

  /// e.g. `UNAUTHORIZED`.
  final String? authStatus;

  /// `EXPIRED` / `NON-EXPIRED`.
  final String? expiryStatus;

  final DateTime? applicationDate;
  final DateTime? expiryDate;
  final String? expiryPlace;
  final MoneyAmount? amount;
  final MoneyAmount? outstandingAmount;
  final MoneyAmount? equivalentAmount;

  /// Applicant (our party for an Import LC).
  final TfId partyId;
  final String? partyName;

  /// Beneficiary for an Import LC, applicant for an Export LC.
  final String? counterPartyName;
  final LcAddress counterPartyAddress;

  final String? branchId;
  final String? customerReferenceNo;
  final String? confirmationInstruction;
  final String? transferableType;
  final String? availableWith;
  final String? advisingBankCode;
  final String? advisingThroughBankCode;
  final String? confirmingBankCode;
  final String? issuingBankCode;
  final String? reimbursingBankCode;
  final int? documentPresentationDays;
  final double? toleranceAbove;
  final double? toleranceUnder;
  final bool revolving;
  final bool transferable;

  /// True for an LC created by transferring an Export LC to a second
  /// beneficiary (`transferredLC`, present on every H2 #138 row).
  final bool transferredLC;

  /// Amount still available for transfer, when the host reports it.
  final MoneyAmount? transferrableAmount;
  final bool irrevocable;
  final bool allowAmendment;
  final LcShipmentDetails shipment;
  final List<LcGoods> goods;
  final List<LcCharge> charges;
  final String? chargesBorneBy;
  final TradeCode? incoterm;
  final List<TradeCode> additionalConditions;
  final String? remarks;

  /// Maker who initiated it, e.g. `Pooja Jha`.
  final String? userName;

  /// Draft label (`name`, e.g. `LC_CREATE_18BA_2189`) — drafts only.
  final String? draftName;
  final DateTime? lastUpdatedDate;

  /// Utilised = amount − outstanding, when both are in the same currency.
  MoneyAmount? get utilisedAmount {
    final a = amount;
    final o = outstandingAmount;
    if (a == null || o == null) return null;
    if (a.currency != null && o.currency != null && a.currency != o.currency) {
      return null;
    }
    return MoneyAmount(amount: a.amount - o.amount, currency: a.currency);
  }

  bool get isActive => status?.toUpperCase() == 'ACTIVE';

  bool get isExpired => expiryStatus?.toUpperCase() == 'EXPIRED';

  /// Label for the status chip: workflow state wins while not yet active.
  String get statusLabel {
    final s = status ?? state;
    if (s == null) return 'Unknown';
    return s.replaceAll('_', ' ');
  }

  static CorpLetterOfCredit? fromJson(dynamic json, {LcType? fallbackType}) {
    final map = TfJson.map(json);
    final id = TfJson.str(map['id']);
    if (id == null) return null;
    final lcTypeRaw = TfJson.str(map['lcType']);
    return CorpLetterOfCredit(
      id: id,
      lcType: lcTypeRaw == null
          ? (fallbackType ?? LcType.importLc)
          : LcType.fromApi(lcTypeRaw),
      raw: map,
      versionNo: TfJson.str(map['versionNo']),
      productId: TfJson.str(map['productId']),
      productName: TfJson.str(map['productName']),
      status: TfJson.str(map['status']),
      state: TfJson.str(map['state']),
      authStatus: TfJson.str(map['authStatus']),
      expiryStatus: TfJson.str(map['expiryStatus']),
      applicationDate: TfJson.date(map['applicationDate']),
      expiryDate: TfJson.date(map['expiryDate']),
      expiryPlace: TfJson.str(map['expiryPlace']),
      amount: _money(map['amount']),
      outstandingAmount: _money(map['outstandingAmount']),
      equivalentAmount: _money(map['equivalentAmount']),
      partyId: TfId.fromJson(map['partyId']),
      partyName: TfJson.str(map['partyName']) ?? TfJson.str(map['accounteeName']),
      counterPartyName: TfJson.str(map['counterPartyName']),
      counterPartyAddress: LcAddress.fromJson(map['counterPartyAddress']),
      branchId: TfJson.str(map['branchId']),
      customerReferenceNo: TfJson.str(map['customerReferenceNo']),
      confirmationInstruction: TfJson.str(map['confirmationInstruction']),
      transferableType: TfJson.str(map['transferableType']),
      availableWith: TfJson.str(map['availableWith']),
      advisingBankCode: TfJson.str(map['advisingBankCode']),
      advisingThroughBankCode: TfJson.str(map['advisingThroughBankCode']),
      confirmingBankCode: TfJson.str(map['confirmingBankCode']),
      issuingBankCode: TfJson.str(map['issuingBankCode']),
      reimbursingBankCode: TfJson.str(map['reimbursingBankCode']),
      documentPresentationDays: TfJson.integer(map['documentPresentationDays']),
      toleranceAbove: TfJson.dbl(map['toleranceAbove']),
      toleranceUnder: TfJson.dbl(map['toleranceUnder']),
      revolving: TfJson.boolean(map['revolving']),
      transferable: TfJson.boolean(map['transferable']),
      transferredLC: TfJson.boolean(map['transferredLC']),
      transferrableAmount: _money(map['transferrableAmount']),
      irrevocable: TfJson.boolean(map['irRevocable']),
      allowAmendment: TfJson.boolean(map['allowAmendment']),
      shipment: LcShipmentDetails.fromJson(map['shipmentDetails']),
      goods: [
        for (final g in TfJson.maps(map['goods']))
          if (LcGoods.fromJson(g) case final goods?) goods,
      ],
      charges: LcCharge.listFrom(map['charges']),
      chargesBorneBy: TfJson.str(map['chargesBorneBy']),
      incoterm: TradeCode.fromJson(map['incoterm']),
      additionalConditions: TradeCode.listFrom(map['additionalConditions']),
      remarks: TfJson.str(map['remarks']),
      userName: TfJson.str(map['userName']),
      draftName: TfJson.str(map['name']),
      lastUpdatedDate: TfJson.date(map['lastUpdatedDate']),
    );
  }

  /// `letterOfCreditDTOs[]` — list, drafts and amendable-list responses.
  static List<CorpLetterOfCredit> listFromPayload(
    dynamic data, {
    LcType? fallbackType,
  }) {
    final root = TfJson.root(data);
    return [
      for (final item in TfJson.maps(root['letterOfCreditDTOs']))
        if (CorpLetterOfCredit.fromJson(item, fallbackType: fallbackType)
            case final lc?)
          lc,
    ];
  }

  /// `letterOfCredit` — detail and create responses.
  static CorpLetterOfCredit? fromDetailPayload(dynamic data) {
    final root = TfJson.root(data);
    return CorpLetterOfCredit.fromJson(root['letterOfCredit']);
  }

  static MoneyAmount? _money(dynamic json) {
    final map = TfJson.map(json);
    if (map.isEmpty || map['amount'] == null) return null;
    return MoneyAmount.fromJson(map);
  }
}
