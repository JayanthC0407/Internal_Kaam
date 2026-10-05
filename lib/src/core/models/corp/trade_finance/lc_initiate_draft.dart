import 'package:ubci_bank/src/core/models/corp/trade_finance/corp_letter_of_credit.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/lc_common.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/lc_initiate_support.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/lc_product.dart';

/// 41A "Credit available by" (`transferableType` on the wire).
///
/// `SIGHTPAYMENT` / `ACCEPTANCE` are captured values (H1 #71); the others
/// follow the same host convention (ASSUMPTION — confirm with a capture).
class LcAvailableBy {
  LcAvailableBy._();

  static const List<TradeCode> values = [
    TradeCode(code: 'SIGHTPAYMENT', description: 'Payment'),
    TradeCode(code: 'ACCEPTANCE', description: 'Acceptance'),
    TradeCode(code: 'NEGOTIATION', description: 'Negotiation'),
    TradeCode(code: 'DEFERREDPAYMENT', description: 'Deferred Payment'),
    TradeCode(code: 'MIXEDPAYMENT', description: 'Mixed Payment'),
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

/// 40A "LC Type" — Sight / Usance / Mixed Payment (`periodIndicator`).
class LcPaymentType {
  LcPaymentType._();

  static const List<TradeCode> values = [
    TradeCode(code: 'SIGHT', description: 'Sight'),
    TradeCode(code: 'USANCE', description: 'Usance'),
    TradeCode(code: 'MIXED', description: 'Mixed Payment'),
  ];
}

/// Everything the Initiate LC sections collect, independent of any widget.
///
/// Immutable: every section writes through [copyWith], and the provider
/// holds the single current instance. [toRequestJson] turns it into the
/// draft / submit body — field names from the full DTO the web sends
/// (`LC_inititation complete flow.har` #74, and H1 #71).
class LcInitiateDraft {
  const LcInitiateDraft({
    // 01 LC Details
    this.transferable = false,
    this.paymentType,
    this.revolving = false,
    this.revolvingDetails = LcRevolvingDetails.empty,
    this.product,
    this.expiryDate,
    this.expiryPlace,
    this.newBeneficiary = false,
    this.beneficiaryId,
    this.beneficiaryName,
    this.beneficiaryAddress = LcAddress.empty,
    this.currency,
    this.amount,
    this.toleranceAbove = 0,
    this.toleranceUnder = 0,
    this.additionalAmountCovered,
    this.availableBy = 'SIGHTPAYMENT',
    this.paymentDetails,
    this.availableWith = LcBankSelection.empty,
    this.billingDrafts = const [],
    // 02 Goods & Shipment
    this.shipment = LcShipmentDetails.empty,
    this.shipmentByPeriod = false,
    this.goods = const [],
    // 03 Documents & Conditions
    this.documents = const [],
    this.additionalConditions = const [],
    this.documentPresentationDays = 21,
    this.incoterm,
    // 04 Linkages
    this.depositLinkages = const [],
    // 05 Instructions
    this.advisingBank = LcBankSelection.empty,
    this.adviseThroughBank = LcBankSelection.empty,
    this.paymentConditionsBene,
    this.paymentConditionsBank,
    this.confirmationInstruction = 'WITHOUT',
    this.requestedConfirmationParty,
    this.senderReceiverInfo,
    this.chargesDetails,
    this.instructions,
    this.standardInstructionsAccepted = false,
    // 06 Insurance
    this.insurancePolicy,
    // 07 Charges
    this.chargingAccount,
    this.chargesBorneBy = 'BYAPPLICANT',
    // Meta
    this.draftName,
    this.customerReferenceNo,
    this.parentLcId,
  });

  /// 40A — `transferable`.
  final bool transferable;

  /// 40A LC Type — `SIGHT` / `USANCE` / `MIXED` (`periodIndicator`).
  /// Null = follow the product.
  final String? paymentType;

  final bool revolving;
  final LcRevolvingDetails revolvingDetails;
  final LcProduct? product;

  /// 31D.
  final DateTime? expiryDate;
  final String? expiryPlace;

  /// 59 — `false` = maintained beneficiary ([beneficiaryId] set).
  final bool newBeneficiary;
  final String? beneficiaryId;
  final String? beneficiaryName;
  final LcAddress beneficiaryAddress;

  /// 32B.
  final String? currency;
  final double? amount;
  final double toleranceAbove;
  final double toleranceUnder;

  /// 39C — free text.
  final String? additionalAmountCovered;

  /// 41A — `transferableType`.
  final String availableBy;

  /// 42P — `paymentDetails`.
  final String? paymentDetails;

  /// "Credit available with" — `availableWith`.
  final LcBankSelection availableWith;

  /// 42C — `billingDrafts`.
  final List<LcBillingDraft> billingDrafts;

  final LcShipmentDetails shipment;

  /// 44C/44D — shipment by period instead of a latest date (UI choice; the
  /// unused one goes out null).
  final bool shipmentByPeriod;
  final List<LcGoods> goods;

  /// 46A.
  final List<LcDocument> documents;

  /// 47A.
  final List<TradeCode> additionalConditions;

  /// 48.
  final int documentPresentationDays;
  final TradeCode? incoterm;

  final List<LcDepositLinkage> depositLinkages;

  final LcBankSelection advisingBank;
  final LcBankSelection adviseThroughBank;

  /// 49G / 49H.
  final String? paymentConditionsBene;
  final String? paymentConditionsBank;

  /// 49 — `CONFIRM` / `MAY_ADD` / `WITHOUT` (H3 #68).
  final String confirmationInstruction;

  /// `ABK` / `ATB` / `COB` (H3 #70) — only when confirmation is requested.
  final String? requestedConfirmationParty;

  /// 72Z.
  final String? senderReceiverInfo;

  /// 71D — `chargesFromBeneficiary` (ASSUMPTION: the DTO's only free-text
  /// charges field).
  final String? chargesDetails;

  /// Special instructions — `instructionDescription`.
  final String? instructions;

  /// "Kindly go through all the Standard Instructions" acknowledgement.
  final bool standardInstructionsAccepted;

  /// 06 — sent as the single `policyDTOs` entry.
  final LcInsurancePolicy? insurancePolicy;

  /// 07 — `chargingAccountId`.
  final LcAccount? chargingAccount;
  final String chargesBorneBy;

  /// Draft label (`name`) — generated when saving a draft.
  final String? draftName;
  final String? customerReferenceNo;

  /// Export LC backing this one — Back to Back LC (`parentReferenceLCs`).
  final String? parentLcId;

  bool get isBackToBack => parentLcId != null;

  static const empty = LcInitiateDraft();

  /// LC amount plus the positive tolerance.
  double get totalExposure =>
      (amount ?? 0) * (1 + (toleranceAbove.isNaN ? 0 : toleranceAbove) / 100);

  double get goodsTotal =>
      goods.fold<double>(0, (sum, g) => sum + (g.total ?? 0));

  double get linkedTotal => depositLinkages.fold<double>(
        0,
        (sum, l) => sum + (l.amount ?? 0),
      );

  /// Period sent on the wire: the selected type, else the product's.
  String? get periodIndicator => paymentType ?? product?.periodIndicator;

  /// Seeds the form from an existing LC (Copy & Initiate), a template or a
  /// saved draft. Reads the extra blocks from [CorpLetterOfCredit.raw].
  factory LcInitiateDraft.fromLetterOfCredit(
    CorpLetterOfCredit lc, {
    LcProduct? product,
  }) {
    final raw = lc.raw;
    final policies = TfJson.maps(raw['policyDTOs']);
    final policy = policies.isEmpty
        ? null
        : LcInsurancePolicy.listFromPayload({'insurancePolicies': policies});
    final account = TfId.fromJson(raw['chargingAccountId']);
    final beneId = TfJson.str(raw['beneId']);
    final shipment = lc.shipment;
    return LcInitiateDraft(
      transferable: lc.transferable,
      paymentType: TfJson.str(raw['periodIndicator']),
      revolving: lc.revolving,
      revolvingDetails: LcRevolvingDetails.fromJson(raw['revolvingDetails']),
      product: product ??
          (lc.productId == null
              ? null
              : LcProduct(id: lc.productId!, name: lc.productName ?? lc.productId!)),
      expiryDate: lc.expiryDate,
      expiryPlace: lc.expiryPlace,
      newBeneficiary: beneId == null,
      beneficiaryId: beneId,
      beneficiaryName: lc.counterPartyName,
      beneficiaryAddress: lc.counterPartyAddress,
      currency: lc.amount?.currency,
      amount: lc.amount?.amount,
      toleranceAbove: lc.toleranceAbove ?? 0,
      toleranceUnder: lc.toleranceUnder ?? 0,
      additionalAmountCovered: TfJson.str(raw['additionalAmountCovered']),
      availableBy: lc.transferableType ?? 'SIGHTPAYMENT',
      paymentDetails: TfJson.str(raw['paymentDetails']),
      availableWith: LcBankSelection.fromLc(raw['availableWith'], null),
      billingDrafts: [
        for (final d in TfJson.maps(raw['billingDrafts']))
          if (LcBillingDraft.fromJson(d) case final draft
              when draft.tenor != null ||
                  draft.amount != null ||
                  draft.draweeBankCode != null)
            draft,
      ],
      shipment: shipment,
      shipmentByPeriod:
          shipment.latestShipmentDate == null && shipment.period != null,
      goods: lc.goods,
      documents: [
        for (final doc in TfJson.maps(raw['document']))
          if (LcDocument.fromJson(doc) case final d?) d,
      ],
      additionalConditions: lc.additionalConditions,
      documentPresentationDays: lc.documentPresentationDays ?? 21,
      incoterm: (lc.incoterm?.code.isEmpty ?? true) ? null : lc.incoterm,
      depositLinkages: [
        for (final l in TfJson.maps(raw['depositLinkages']))
          if (LcDepositLinkage.fromJson(l) case final link
              when !link.account.id.isEmpty)
            link,
      ],
      advisingBank: LcBankSelection.fromLc(
        raw['advisingBankCode'],
        raw['advisingBankDetails'],
      ),
      adviseThroughBank: LcBankSelection.fromLc(
        raw['advisingThroughBankCode'],
        raw['advisingThroughBankDetails'],
      ),
      paymentConditionsBene: TfJson.str(raw['paymentConditionsBene']),
      paymentConditionsBank: TfJson.str(raw['paymentConditionsBank']),
      confirmationInstruction: lc.confirmationInstruction ?? 'WITHOUT',
      requestedConfirmationParty: TfJson.str(raw['requestedConfirmationParty']),
      senderReceiverInfo: TfJson.str(raw['senderReceiverInfo']),
      chargesDetails: TfJson.str(raw['chargesFromBeneficiary']),
      instructions: TfJson.str(raw['instructionDescription']),
      insurancePolicy: (policy == null || policy.isEmpty) ? null : policy.first,
      chargingAccount: account.isEmpty ? null : LcAccount(id: account),
      chargesBorneBy: lc.chargesBorneBy ?? 'BYAPPLICANT',
      draftName: lc.draftName,
      customerReferenceNo: lc.customerReferenceNo,
    );
  }

  LcInitiateDraft copyWith({
    bool? transferable,
    String? paymentType,
    bool? revolving,
    LcRevolvingDetails? revolvingDetails,
    LcProduct? product,
    DateTime? expiryDate,
    String? expiryPlace,
    bool? newBeneficiary,
    String? beneficiaryId,
    bool clearBeneficiaryId = false,
    String? beneficiaryName,
    LcAddress? beneficiaryAddress,
    String? currency,
    double? amount,
    double? toleranceAbove,
    double? toleranceUnder,
    String? additionalAmountCovered,
    String? availableBy,
    String? paymentDetails,
    LcBankSelection? availableWith,
    List<LcBillingDraft>? billingDrafts,
    LcShipmentDetails? shipment,
    bool? shipmentByPeriod,
    List<LcGoods>? goods,
    List<LcDocument>? documents,
    List<TradeCode>? additionalConditions,
    int? documentPresentationDays,
    TradeCode? incoterm,
    bool clearIncoterm = false,
    List<LcDepositLinkage>? depositLinkages,
    LcBankSelection? advisingBank,
    LcBankSelection? adviseThroughBank,
    String? paymentConditionsBene,
    String? paymentConditionsBank,
    String? confirmationInstruction,
    String? requestedConfirmationParty,
    bool clearConfirmationParty = false,
    String? senderReceiverInfo,
    String? chargesDetails,
    String? instructions,
    bool? standardInstructionsAccepted,
    LcInsurancePolicy? insurancePolicy,
    bool clearInsurancePolicy = false,
    LcAccount? chargingAccount,
    String? chargesBorneBy,
    String? draftName,
    bool clearDraftName = false,
    String? parentLcId,
  }) {
    return LcInitiateDraft(
      transferable: transferable ?? this.transferable,
      paymentType: paymentType ?? this.paymentType,
      revolving: revolving ?? this.revolving,
      revolvingDetails: revolvingDetails ?? this.revolvingDetails,
      product: product ?? this.product,
      expiryDate: expiryDate ?? this.expiryDate,
      expiryPlace: expiryPlace ?? this.expiryPlace,
      newBeneficiary: newBeneficiary ?? this.newBeneficiary,
      beneficiaryId:
          clearBeneficiaryId ? null : (beneficiaryId ?? this.beneficiaryId),
      beneficiaryName: beneficiaryName ?? this.beneficiaryName,
      beneficiaryAddress: beneficiaryAddress ?? this.beneficiaryAddress,
      currency: currency ?? this.currency,
      amount: amount ?? this.amount,
      toleranceAbove: toleranceAbove ?? this.toleranceAbove,
      toleranceUnder: toleranceUnder ?? this.toleranceUnder,
      additionalAmountCovered:
          additionalAmountCovered ?? this.additionalAmountCovered,
      availableBy: availableBy ?? this.availableBy,
      paymentDetails: paymentDetails ?? this.paymentDetails,
      availableWith: availableWith ?? this.availableWith,
      billingDrafts: billingDrafts ?? this.billingDrafts,
      shipment: shipment ?? this.shipment,
      shipmentByPeriod: shipmentByPeriod ?? this.shipmentByPeriod,
      goods: goods ?? this.goods,
      documents: documents ?? this.documents,
      additionalConditions: additionalConditions ?? this.additionalConditions,
      documentPresentationDays:
          documentPresentationDays ?? this.documentPresentationDays,
      incoterm: clearIncoterm ? null : (incoterm ?? this.incoterm),
      depositLinkages: depositLinkages ?? this.depositLinkages,
      advisingBank: advisingBank ?? this.advisingBank,
      adviseThroughBank: adviseThroughBank ?? this.adviseThroughBank,
      paymentConditionsBene:
          paymentConditionsBene ?? this.paymentConditionsBene,
      paymentConditionsBank:
          paymentConditionsBank ?? this.paymentConditionsBank,
      confirmationInstruction:
          confirmationInstruction ?? this.confirmationInstruction,
      requestedConfirmationParty: clearConfirmationParty
          ? null
          : (requestedConfirmationParty ?? this.requestedConfirmationParty),
      senderReceiverInfo: senderReceiverInfo ?? this.senderReceiverInfo,
      chargesDetails: chargesDetails ?? this.chargesDetails,
      instructions: instructions ?? this.instructions,
      standardInstructionsAccepted:
          standardInstructionsAccepted ?? this.standardInstructionsAccepted,
      insurancePolicy: clearInsurancePolicy
          ? null
          : (insurancePolicy ?? this.insurancePolicy),
      chargingAccount: chargingAccount ?? this.chargingAccount,
      chargesBorneBy: chargesBorneBy ?? this.chargesBorneBy,
      draftName: clearDraftName ? null : (draftName ?? this.draftName),
      customerReferenceNo: customerReferenceNo,
      parentLcId: parentLcId ?? this.parentLcId,
    );
  }

  /// Create / update / submit body.
  ///
  /// [state] is `DRAFT` for a saved draft (H1 #71) and `INITIATED` for the
  /// submit (the value the web puts on every non-draft body, H3 #74).
  /// [id] is null on the first save and the host-assigned draft id after.
  Map<String, dynamic> toRequestJson({
    required TfId partyId,
    required String? partyName,
    required String? branchId,
    String state = 'INITIATED',
    String? id,
    bool autoSaved = false,
  }) {
    final money = {'currency': currency, 'amount': amount};
    final emptyBank = {
      'customerNo': null,
      'branchAddress': LcAddress.empty.toJson(),
      'name': null,
    };
    final shipmentJson = shipment.toRequestJson()
      ..['date'] =
          shipmentByPeriod ? null : TfDate.toApi(shipment.latestShipmentDate)
      ..['period'] = shipmentByPeriod ? _blankToNull(shipment.period) : null;
    final confirmed = confirmationInstruction != 'WITHOUT';

    return {
      'termsAndConditionVersion': 0,
      'termsAndConditionID': null,
      'approvalParty': TfId.empty.toJson(),
      'totalRecords': null,
      'id': id,
      // The host takes the applicant from the session, as the web portal does
      // (partyId null, H3 #74). Sending the masked party id here made the
      // host reject that id afterwards (DIGX_LC_042 "Invalid Party").
      'partyId': TfId.empty.toJson(),
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
      'partyName': null,
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
      'exposure': {'currency': currency, 'amount': totalExposure},
      'transferable': transferable,
      'allowAmendment': null,
      'irRevocable': product?.irrevocable ?? false,
      'confirmed': confirmed,
      'documentPresentationDays': documentPresentationDays,
      'instructionDescription': instructions ?? '',
      'incoterm': {
        'code': incoterm?.code ?? '',
        'description': incoterm?.description ?? '',
      },
      'revolving': revolving,
      'amount': money,
      'equivalentAmount': {'currency': null, 'amount': null},
      'equivalentOutstandingAmount': {'currency': null, 'amount': null},
      'chargingAccountId': chargingAccount?.id.toJson() ?? TfId.empty.toJson(),
      'shipmentDetails': shipmentJson,
      'revolvingDetails': revolvingDetails.toJson(revolving: revolving),
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
      'advisingBankCode': advisingBank.code,
      'confirmingBankCode': null,
      'reimbursingBankCode': null,
      'nominatedBankCode': null,
      'negotiatingBankCode': null,
      'advisingThroughBankCode': adviseThroughBank.code,
      'issuingBankCode': null,
      'draftsRequired': billingDrafts.isNotEmpty,
      'billingDrafts': [for (final d in billingDrafts) d.toJson(currency)],
      'counterPartyName': beneficiaryName,
      'counterPartyAddress': beneficiaryAddress.toJson(),
      'counterPartyId': TfId.empty.toJson(),
      'beneId': newBeneficiary ? null : beneficiaryId,
      'toleranceType': null,
      'name': draftName,
      'userId': null,
      'visibility': 'PRIVATE',
      'state': state,
      'outstandingAmount': money,
      'attachedDocuments': const <dynamic>[],
      'deletedDocuments': const <dynamic>[],
      'currentUser': null,
      'availableWith': availableWith.code ?? advisingBank.code,
      'chargesFromBeneficiary': _blankToNull(chargesDetails),
      'transactionType': 'CONVENTIONAL',
      'lcType': LcType.importLc.apiValue,
      'remarks': null,
      'charges': const <dynamic>[],
      'bankCharges': const <dynamic>[],
      'goods': [for (final g in goods) g.toJson()],
      'multiGoodsSupported': goods.length > 1 ? 'Y' : null,
      'advisingBankDetails':
          advisingBank.isEmpty ? emptyBank : advisingBank.toDetailsJson(),
      'advisingThroughBankDetails': adviseThroughBank.isEmpty
          ? emptyBank
          : adviseThroughBank.toDetailsJson(),
      'issuingBankDetails': emptyBank,
      'validBICCode': true,
      'chargesBorneBy': chargesBorneBy,
      'requestedConfirmationParty':
          confirmed ? requestedConfirmationParty : null,
      'requestedConfirmationPartyDetails': emptyBank,
      'paymentDetails': _blankToNull(paymentDetails),
      'bankInstructionDesc': null,
      'paymentConditionsBank': _blankToNull(paymentConditionsBank),
      'paymentConditionsBene': _blankToNull(paymentConditionsBene),
      'additionalAmountCovered': _blankToNull(additionalAmountCovered),
      'additionalConditions': [for (final c in additionalConditions) c.toJson()],
      'senderReceiverInfo': _blankToNull(senderReceiverInfo),
      'periodIndicator': periodIndicator,
      'localCurrency': {'currency': null, 'amount': null},
      'depositLinkages': [
        for (final l in depositLinkages)
          if ((l.amount ?? 0) > 0) l.toJson(),
      ],
      'policyDTOs': [if (insurancePolicy != null) insurancePolicy!.raw],
      'newApplicant': false,
      'letterOfCreditProductDTO': product?.toRequestJson(),
      'accounteeId': TfId.empty.toJson(),
      'accounteeName': null,
      'accounteeAddress': LcAddress.empty.toJson(),
      'primaryCustCIF': TfId.empty.toJson(),
      'autoSaved': autoSaved,
      'parentReferenceLCs': [if (parentLcId != null) parentLcId],
    };
  }

  static String? _blankToNull(String? value) {
    final text = value?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}
