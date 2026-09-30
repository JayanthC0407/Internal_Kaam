import 'package:ubci_bank/src/core/models/corp/trade_finance/corp_letter_of_credit.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/lc_common.dart';

/// The fields an Import LC amendment can change in this app.
///
/// Seeded from the live LC ([LcAmendmentDraft.fromLetterOfCredit]) so the
/// form opens on current values and [changes] can list only what differs.
/// [toRequestJson] produces the H1 #204 body, copying everything else from
/// the original LC's raw payload so un-modelled fields round-trip.
class LcAmendmentDraft {
  const LcAmendmentDraft({
    required this.original,
    this.newAmount,
    this.newExpiryDate,
    this.toleranceAbove = 0,
    this.toleranceUnder = 0,
    this.shipment = LcShipmentDetails.empty,
    this.expiryPlace,
    this.narrative,
  });

  final CorpLetterOfCredit original;
  final double? newAmount;
  final DateTime? newExpiryDate;
  final double toleranceAbove;
  final double toleranceUnder;
  final LcShipmentDetails shipment;
  final String? expiryPlace;

  /// Free-text description of the amendment for the bank.
  final String? narrative;

  factory LcAmendmentDraft.fromLetterOfCredit(CorpLetterOfCredit lc) {
    return LcAmendmentDraft(
      original: lc,
      newAmount: lc.amount?.amount,
      newExpiryDate: lc.expiryDate,
      toleranceAbove: lc.toleranceAbove ?? 0,
      toleranceUnder: lc.toleranceUnder ?? 0,
      shipment: lc.shipment,
      expiryPlace: lc.expiryPlace,
    );
  }

  String? get currency => original.amount?.currency;

  LcAmendmentDraft copyWith({
    double? newAmount,
    DateTime? newExpiryDate,
    double? toleranceAbove,
    double? toleranceUnder,
    LcShipmentDetails? shipment,
    String? expiryPlace,
    String? narrative,
  }) {
    return LcAmendmentDraft(
      original: original,
      newAmount: newAmount ?? this.newAmount,
      newExpiryDate: newExpiryDate ?? this.newExpiryDate,
      toleranceAbove: toleranceAbove ?? this.toleranceAbove,
      toleranceUnder: toleranceUnder ?? this.toleranceUnder,
      shipment: shipment ?? this.shipment,
      expiryPlace: expiryPlace ?? this.expiryPlace,
      narrative: narrative ?? this.narrative,
    );
  }

  /// Human-readable list of what changed, for the review step. Empty means
  /// nothing to submit.
  List<LcAmendmentChange> get changes {
    final o = original;
    final result = <LcAmendmentChange>[];
    void add(String label, String? before, String? after) {
      if ((before ?? '') != (after ?? '')) {
        result.add(LcAmendmentChange(label, before ?? '—', after ?? '—'));
      }
    }

    String? amt(double? v) => v == null ? null : v.toStringAsFixed(2);
    String? tol(double? v) => v == null ? null : '${v.toStringAsFixed(0)}%';
    String yn(bool v) => v ? 'Allowed' : 'Not allowed';

    add('LC amount', amt(o.amount?.amount), amt(newAmount));
    add('Expiry date', TfDate.display(o.expiryDate),
        TfDate.display(newExpiryDate));
    add('Expiry place', o.expiryPlace, expiryPlace);
    add('Tolerance above', tol(o.toleranceAbove ?? 0), tol(toleranceAbove));
    add('Tolerance below', tol(o.toleranceUnder ?? 0), tol(toleranceUnder));
    add('Latest shipment date', TfDate.display(o.shipment.latestShipmentDate),
        TfDate.display(shipment.latestShipmentDate));
    add('Port of loading', o.shipment.loadingPort, shipment.loadingPort);
    add('Port of discharge', o.shipment.dischargePort, shipment.dischargePort);
    add('Place of dispatch', o.shipment.source, shipment.source);
    add('Final destination', o.shipment.destination, shipment.destination);
    add('Partial shipment', yn(o.shipment.partialAllowed),
        yn(shipment.partialAllowed));
    add('Transshipment', yn(o.shipment.transshipmentAllowed),
        yn(shipment.transshipmentAllowed));
    final note = narrative?.trim();
    if (note != null && note.isNotEmpty) {
      result.add(LcAmendmentChange('Narrative', '—', note));
    }
    return result;
  }

  /// `POST …/letterofcredits/{lcId}/amendments` body (H1 #204); the same
  /// body goes to `…/amendments/charges` for the preview (H1 #177).
  Map<String, dynamic> toRequestJson({required TfId partyId}) {
    final raw = original.raw;
    dynamic keep(String key) => raw[key];
    final emptyBank = {
      'customerNo': null,
      'branchAddress': LcAddress.empty.toJson(),
      'name': null,
    };

    return {
      'termsAndConditionVersion': null,
      'termsAndConditionID': null,
      'approvalParty': TfId.empty.toJson(),
      'totalRecords': null,
      'id': null,
      'lcId': original.id,
      'cancellationAllowed': null,
      'applicationNumber': null,
      'customerReferenceNo': original.customerReferenceNo ?? original.id,
      'partyId': (original.partyId.isEmpty ? partyId : original.partyId)
          .toJson(),
      'counterPartyId': keep('counterPartyId') ?? TfId.empty.toJson(),
      'newExpiryDate': TfDate.toApi(newExpiryDate),
      'newAmount': {'currency': currency, 'amount': newAmount},
      'eventDate': null,
      'eventDescription': null,
      'amendmentDate': null,
      'percCreditAmount': null,
      'toleranceUnder': toleranceUnder,
      'collateralDTO': {
        'account': TfId.empty.toJson(),
        'linkedPartyId': TfId.empty.toJson(),
        'accountBranch': null,
        'amount': {'currency': currency, 'amount': 0},
        'collateralType': 'cashCollateral',
        'percentage': 0,
        'exchangeRate': 1,
        'description': null,
        'collateralDTOs': const <dynamic>[],
        'outstandingAmount': {'currency': null, 'amount': null},
        'accountCurrency': null,
      },
      'toleranceAbove': toleranceAbove,
      'additionalAmountCovered': keep('additionalAmountCovered') ?? '',
      'narrative': (narrative?.trim().isEmpty ?? true) ? null : narrative!.trim(),
      'shipmentDetails': shipment.toAmendmentJson(),
      'versionNo': original.versionNo,
      'counterPartyName': original.counterPartyName,
      'status': null,
      'transactionStatus': null,
      'customerAcceptanceStatus': null,
      'amendStatus': null,
      'authStatus': null,
      'noOfAmendment': null,
      'productType': null,
      'goods': [for (final g in original.goods) g.toJson()],
      'branchId': original.branchId,
      'expiryPlace': expiryPlace,
      'availableWith': original.availableWith,
      'paymentDetails': null,
      'documentPresentationDays': original.documentPresentationDays,
      'document': keep('document') ?? const <dynamic>[],
      'documentMaster': const <dynamic>[],
      'counterPartyAddress': original.counterPartyAddress.toJson(),
      'applicantAddress': LcAddress.fromJson(keep('accounteeAddress')).toJson(),
      'validBICCode': TfJson.boolean(keep('validBICCode')),
      'type': null,
      'billingDrafts': keep('billingDrafts') ?? const <dynamic>[],
      'confirmationInstruction': original.confirmationInstruction,
      'transferableType': original.transferableType,
      'chargesFromBeneficiary': keep('chargesFromBeneficiary') ?? '',
      'chargesBorneBy': original.chargesBorneBy,
      'requestedConfirmationParty': keep('requestedConfirmationParty'),
      'requestedConfirmationPartyDetails':
          keep('requestedConfirmationPartyDetails') ?? emptyBank,
      'issuingBankDetails': keep('issuingBankDetails') ?? emptyBank,
      'issuingBankCode': null,
      'bankRefNo': null,
      'confirmingBankCode': original.confirmingBankCode,
      'advisingThroughBankCode': original.advisingThroughBankCode,
      'advisingBankCode': original.advisingBankCode,
      'advisingBankDetails': keep('advisingBankDetails') ?? emptyBank,
      'advisingThroughBankDetails':
          keep('advisingThroughBankDetails') ?? emptyBank,
      'walkinCustomerId': null,
      'paymentConditionsBank': keep('paymentConditionsBank') ?? '',
      'paymentConditionsBene': keep('paymentConditionsBene') ?? '',
      'additionalConditions': keep('additionalConditions') ?? const <dynamic>[],
      'transferable': original.transferable,
      'instructionDescription': null,
      'incoterm': {'description': original.incoterm?.description},
      'policyDTOs': keep('policyDTOs') ?? const <dynamic>[],
      'b2BLCAvailable': null,
      'charges': const <dynamic>[],
      'bankCharges': const <dynamic>[],
      'parties': const <dynamic>[],
      'transactionType': 'CONVENTIONAL',
      'instructionsToIntermediaryBank': null,
      'depositLinkages': const <dynamic>[],
      'attachedDocuments': const <dynamic>[],
      'deletedDocuments': const <dynamic>[],
      'primaryCustCIF': TfId.empty.toJson(),
      'periodIndicator': null,
    };
  }
}

class LcAmendmentChange {
  const LcAmendmentChange(this.label, this.before, this.after);

  final String label;
  final String before;
  final String after;
}
