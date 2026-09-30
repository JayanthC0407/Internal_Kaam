import 'package:ubci_bank/src/core/models/corp/trade_finance/corp_letter_of_credit.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/lc_common.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/lc_product.dart';

/// "Available by" values seen in the captures (`transferableType`).
/// Other host values (e.g. negotiation / deferred payment) exist in OBDX
/// but were not captured, so they are not offered yet.
class LcAvailableBy {
  LcAvailableBy._();

  static const List<TradeCode> values = [
    TradeCode(code: 'SIGHTPAYMENT', description: 'Sight payment'),
    TradeCode(code: 'ACCEPTANCE', description: 'Acceptance'),
  ];
}

/// Who bears the bank charges (`chargesBorneBy`). `BYAPPLICANT` is the
/// captured value; `BYBENEFICIARY` follows the same host convention.
class LcChargesBorneBy {
  LcChargesBorneBy._();

  static const List<TradeCode> values = [
    TradeCode(code: 'BYAPPLICANT', description: 'Applicant'),
    TradeCode(code: 'BYBENEFICIARY', description: 'Beneficiary'),
  ];
}

/// Everything the Initiate LC wizard collects, independent of any widget.
///
/// Immutable: every step writes through [copyWith], and the provider holds
/// the single current instance. [toRequestJson] turns it into the create
/// body — shape from H1 #71 (copy-and-initiate) and H1 #121 (fresh
/// initiation skeleton).
class LcInitiateDraft {
  const LcInitiateDraft({
    this.product,
    this.currency,
    this.amount,
    this.expiryDate,
    this.expiryPlace,
    this.toleranceAbove = 0,
    this.toleranceUnder = 0,
    this.availableBy = 'SIGHTPAYMENT',
    this.confirmationInstruction = 'WITHOUT',
    this.documentPresentationDays = 21,
    this.beneficiaryName,
    this.beneficiaryAddress = LcAddress.empty,
    this.advisingBank,
    this.advisingBankCode,
    this.chargesBorneBy = 'BYAPPLICANT',
    this.shipment = LcShipmentDetails.empty,
    this.incoterm,
    this.goods = const [],
    this.documents = const [],
    this.additionalConditions = const [],
    this.instructions,
    this.draftName,
    this.customerReferenceNo,
  });

  final LcProduct? product;
  final String? currency;
  final double? amount;
  final DateTime? expiryDate;
  final String? expiryPlace;
  final double toleranceAbove;
  final double toleranceUnder;

  /// `transferableType` on the wire.
  final String availableBy;

  /// `CONFIRM` / `MAY_ADD` / `WITHOUT` (H1 #115).
  final String confirmationInstruction;
  final int documentPresentationDays;

  final String? beneficiaryName;
  final LcAddress beneficiaryAddress;

  /// Resolved from `tradeBicCodes` when the user looked the code up.
  final TradeBank? advisingBank;
  final String? advisingBankCode;

  final String chargesBorneBy;
  final LcShipmentDetails shipment;
  final TradeCode? incoterm;
  final List<LcGoods> goods;
  final List<LcDocument> documents;
  final List<TradeCode> additionalConditions;

  /// Free-text instructions to the bank (`instructionDescription`).
  final String? instructions;

  /// Draft label (`name`) — generated when saving a draft.
  final String? draftName;
  final String? customerReferenceNo;

  static const empty = LcInitiateDraft();

  /// Seeds the wizard from an existing LC (copy-and-initiate, H1 #71) or a
  /// saved draft.
  factory LcInitiateDraft.fromLetterOfCredit(
    CorpLetterOfCredit lc, {
    LcProduct? product,
  }) {
    return LcInitiateDraft(
      product: product ??
          (lc.productId == null
              ? null
              : LcProduct(id: lc.productId!, name: lc.productName ?? lc.productId!)),
      currency: lc.amount?.currency,
      amount: lc.amount?.amount,
      expiryDate: lc.expiryDate,
      expiryPlace: lc.expiryPlace,
      toleranceAbove: lc.toleranceAbove ?? 0,
      toleranceUnder: lc.toleranceUnder ?? 0,
      availableBy: lc.transferableType ?? 'SIGHTPAYMENT',
      confirmationInstruction: lc.confirmationInstruction ?? 'WITHOUT',
      documentPresentationDays: lc.documentPresentationDays ?? 21,
      beneficiaryName: lc.counterPartyName,
      beneficiaryAddress: lc.counterPartyAddress,
      advisingBankCode: lc.advisingBankCode,
      chargesBorneBy: lc.chargesBorneBy ?? 'BYAPPLICANT',
      shipment: lc.shipment,
      incoterm: (lc.incoterm?.code.isEmpty ?? true) ? null : lc.incoterm,
      goods: lc.goods,
      additionalConditions: lc.additionalConditions,
      documents: [
        for (final doc in TfJson.maps(lc.raw['document']))
          if (LcDocument.fromJson(doc) case final d?) d,
      ],
      instructions: TfJson.str(lc.raw['instructionDescription']),
      draftName: lc.draftName,
    );
  }

  double get goodsTotal =>
      goods.fold<double>(0, (sum, g) => sum + (g.total ?? 0));

  LcInitiateDraft copyWith({
    LcProduct? product,
    String? currency,
    double? amount,
    DateTime? expiryDate,
    String? expiryPlace,
    double? toleranceAbove,
    double? toleranceUnder,
    String? availableBy,
    String? confirmationInstruction,
    int? documentPresentationDays,
    String? beneficiaryName,
    LcAddress? beneficiaryAddress,
    TradeBank? advisingBank,
    String? advisingBankCode,
    bool clearAdvisingBank = false,
    String? chargesBorneBy,
    LcShipmentDetails? shipment,
    TradeCode? incoterm,
    bool clearIncoterm = false,
    List<LcGoods>? goods,
    List<LcDocument>? documents,
    List<TradeCode>? additionalConditions,
    String? instructions,
    String? draftName,
  }) {
    return LcInitiateDraft(
      product: product ?? this.product,
      currency: currency ?? this.currency,
      amount: amount ?? this.amount,
      expiryDate: expiryDate ?? this.expiryDate,
      expiryPlace: expiryPlace ?? this.expiryPlace,
      toleranceAbove: toleranceAbove ?? this.toleranceAbove,
      toleranceUnder: toleranceUnder ?? this.toleranceUnder,
      availableBy: availableBy ?? this.availableBy,
      confirmationInstruction:
          confirmationInstruction ?? this.confirmationInstruction,
      documentPresentationDays:
          documentPresentationDays ?? this.documentPresentationDays,
      beneficiaryName: beneficiaryName ?? this.beneficiaryName,
      beneficiaryAddress: beneficiaryAddress ?? this.beneficiaryAddress,
      advisingBank:
          clearAdvisingBank ? null : (advisingBank ?? this.advisingBank),
      advisingBankCode: advisingBankCode ?? this.advisingBankCode,
      chargesBorneBy: chargesBorneBy ?? this.chargesBorneBy,
      shipment: shipment ?? this.shipment,
      incoterm: clearIncoterm ? null : (incoterm ?? this.incoterm),
      goods: goods ?? this.goods,
      documents: documents ?? this.documents,
      additionalConditions: additionalConditions ?? this.additionalConditions,
      instructions: instructions ?? this.instructions,
      draftName: draftName ?? this.draftName,
      customerReferenceNo: customerReferenceNo,
    );
  }

  /// Create / update / submit body.
  ///
  /// [state] is `DRAFT` for a saved draft (H1 #71) and `INITIATED` for the
  /// submit (the value the web puts on every non-draft body, H1 #121).
  /// [id] is null on the first save and the host-assigned draft id after.
  Map<String, dynamic> toRequestJson({
    required TfId partyId,
    required String? partyName,
    required String? branchId,
    String state = 'INITIATED',
    String? id,
    bool autoSaved = false,
  }) {
    final bankCode = advisingBank?.code ?? _nullIfBlank(advisingBankCode);
    final money = {'currency': currency, 'amount': amount};
    final emptyBank = {
      'customerNo': null,
      'branchAddress': LcAddress.empty.toJson(),
      'name': null,
    };

    return {
      'termsAndConditionVersion': 0,
      'termsAndConditionID': null,
      'approvalParty': TfId.empty.toJson(),
      'totalRecords': null,
      'id': id,
      'partyId': partyId.toJson(),
      'collateralDTO': {
        'account': TfId.empty.toJson(),
        'linkedPartyId': TfId.empty.toJson(),
        'accountBranch': null,
        'amount': {'currency': currency, 'amount': null},
        'collateralType': 'cashCollateral',
        'percentage': 0,
        'exchangeRate': null,
        'description': null,
        'collateralDTOs': const <dynamic>[],
        'outstandingAmount': {'currency': null, 'amount': null},
        'accountCurrency': null,
      },
      'partyName': partyName,
      'partyAddress': LcAddress.empty.toJson(),
      'branchId': branchId,
      'applicationDate': null,
      'customerReferenceNo': customerReferenceNo,
      'applicationNumber': null,
      'productId': product?.id,
      'productName': product?.name,
      'expiryDate': TfDate.toApi(expiryDate),
      'swiftId': null,
      'expiryPlace': expiryPlace,
      'exposure': money,
      'transferable': false,
      'allowAmendment': null,
      'irRevocable': product?.irrevocable ?? false,
      'confirmed': confirmationInstruction != 'WITHOUT',
      'documentPresentationDays': documentPresentationDays,
      'instructionDescription': instructions ?? '',
      'incoterm': {
        'code': incoterm?.code ?? '',
        'description': incoterm?.description ?? '',
      },
      'revolving': product?.revolving ?? false,
      'amount': money,
      'equivalentAmount': {'currency': null, 'amount': null},
      'equivalentOutstandingAmount': {'currency': null, 'amount': null},
      'chargingAccountId': TfId.empty.toJson(),
      'shipmentDetails': shipment.toRequestJson(),
      'revolvingDetails': {
        'frequency': 0,
        'autoReinstatement': 'false',
        'cumulativeFrequency': 'false',
        'reinstatementDate': null,
        'type': null,
        'frequencyUnit': 'MONTHS',
      },
      'document': [for (final doc in documents) doc.toRequestJson()],
      'documentMaster': const <dynamic>[],
      'toleranceUnder': toleranceUnder,
      'toleranceAbove': toleranceAbove,
      'status': null,
      'drawingStatus': null,
      'transferableType': availableBy,
      'confirmationInstruction': confirmationInstruction,
      'paymentType': null,
      'paymentClause': null,
      // The captured LC used one BIC for every bank role; with only the
      // advising bank collected here we do the same for advising and
      // "available with", and leave the rest for the bank to set.
      'advisingBankCode': bankCode,
      'confirmingBankCode': null,
      'reimbursingBankCode': null,
      'nominatedBankCode': null,
      'negotiatingBankCode': null,
      'advisingThroughBankCode': null,
      'issuingBankCode': null,
      'draftsRequired': false,
      'counterPartyName': beneficiaryName,
      'counterPartyAddress': beneficiaryAddress.toJson(),
      'counterPartyId': TfId.empty.toJson(),
      'beneId': null,
      'toleranceType': null,
      'name': draftName,
      'userId': null,
      'visibility': 'PRIVATE',
      'state': state,
      'outstandingAmount': money,
      'attachedDocuments': const <dynamic>[],
      'deletedDocuments': const <dynamic>[],
      'currentUser': null,
      'availableWith': bankCode,
      'chargesFromBeneficiary': null,
      'transactionType': 'CONVENTIONAL',
      'lcType': LcType.importLc.apiValue,
      'remarks': null,
      'charges': const <dynamic>[],
      'bankCharges': const <dynamic>[],
      'goods': [for (final g in goods) g.toJson()],
      'multiGoodsSupported': goods.length > 1 ? 'Y' : null,
      'advisingBankDetails': advisingBank?.toDetailsJson() ?? emptyBank,
      'advisingThroughBankDetails': emptyBank,
      'issuingBankDetails': emptyBank,
      'requestedConfirmationParty': null,
      'requestedConfirmationPartyDetails': emptyBank,
      'validBICCode': advisingBank != null,
      'chargesBorneBy': chargesBorneBy,
      'paymentDetails': null,
      'paymentConditionsBank': null,
      'paymentConditionsBene': null,
      'additionalAmountCovered': null,
      'additionalConditions': [for (final c in additionalConditions) c.toJson()],
      'periodIndicator': product?.periodIndicator,
      'localCurrency': {'currency': null, 'amount': null},
      'policyDTOs': const <dynamic>[],
      'newApplicant': false,
      'letterOfCreditProductDTO': product?.toRequestJson(),
      'accounteeId': partyId.toJson(),
      'accounteeName': partyName,
      'accounteeAddress': LcAddress.empty.toJson(),
      'primaryCustCIF': TfId.empty.toJson(),
      'autoSaved': autoSaved,
    };
  }

  static String? _nullIfBlank(String? value) {
    final text = value?.trim();
    return (text == null || text.isEmpty) ? null : text.toUpperCase();
  }
}
