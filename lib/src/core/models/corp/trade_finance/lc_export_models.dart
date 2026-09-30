import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/corp_letter_of_credit.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/lc_common.dart';

/// An amendment the applicant's bank made to one of our Export LCs, waiting
/// for us (the beneficiary) to accept or reject it.
///
/// From `GET …/letterofcredits/amendments?type=EXPORT` (H2 #157):
/// `letterOfCreditAmendmentDTOs[]`.
class CorpLcAmendment {
  const CorpLcAmendment({
    required this.id,
    required this.lcId,
    required this.raw,
    this.newAmount,
    this.newExpiryDate,
    this.applicantName,
    this.productType,
    this.amendmentDate,
    this.acceptanceStatus,
    this.narrative,
    this.shipment = LcShipmentDetails.empty,
  });

  /// Amendment sequence within the LC (`"1"`, `"2"` in the capture).
  final String id;
  final String lcId;
  final Map<String, dynamic> raw;
  final MoneyAmount? newAmount;
  final DateTime? newExpiryDate;
  final String? applicantName;

  /// e.g. `EXPORTLC`.
  final String? productType;
  final DateTime? amendmentDate;

  /// `customerAcceptanceStatus` — null / PENDING until we respond.
  final String? acceptanceStatus;
  final String? narrative;
  final LcShipmentDetails shipment;

  /// Stable key for providers: the id alone repeats across LCs.
  String get key => '$lcId#$id';

  bool get isPending {
    final s = acceptanceStatus?.toUpperCase();
    return s == null || s == 'PENDING' || s == 'INITIATED';
  }

  static CorpLcAmendment? fromJson(dynamic json) {
    final map = TfJson.map(json);
    final id = TfJson.str(map['id']);
    final lcId = TfJson.str(map['lcId']);
    if (id == null || lcId == null) return null;
    final amount = TfJson.map(map['newAmount']);
    return CorpLcAmendment(
      id: id,
      lcId: lcId,
      raw: map,
      newAmount: amount['amount'] == null ? null : MoneyAmount.fromJson(amount),
      newExpiryDate: TfJson.date(map['newExpiryDate']),
      applicantName: TfJson.str(map['applicantName']),
      productType: TfJson.str(map['productType']),
      amendmentDate: TfJson.date(map['amendmentDate']),
      acceptanceStatus: TfJson.str(map['customerAcceptanceStatus']),
      narrative: TfJson.str(map['narrative']),
      shipment: LcShipmentDetails.fromJson(map['shipmentDetails']),
    );
  }

  static List<CorpLcAmendment> listFromPayload(dynamic data) {
    final root = TfJson.root(data);
    return [
      for (final item in TfJson.maps(root['letterOfCreditAmendmentDTOs']))
        if (CorpLcAmendment.fromJson(item) case final a?) a,
    ];
  }

  /// Accept / reject body.
  ///
  /// NOT CAPTURED: the captures only list the amendments (H2 #157); the
  /// response call was never made. This sends the amendment back with
  /// `customerAcceptanceStatus` set — the field the amendment DTO carries
  /// (see H1 #204). Confirm against a capture of Accept / Reject.
  Map<String, dynamic> toResponseJson({
    required bool accept,
    String? remarks,
  }) {
    return {
      ...raw,
      'customerAcceptanceStatus': accept ? 'ACCEPTED' : 'REJECTED',
      'remarks': (remarks?.trim().isEmpty ?? true) ? null : remarks!.trim(),
      'transactionType': 'CONVENTIONAL',
    };
  }
}

/// Transfer of (part of) a transferable Export LC to a second beneficiary.
class LcTransferDraft {
  const LcTransferDraft({
    required this.original,
    this.amount,
    this.beneficiaryName,
    this.beneficiaryAddress = LcAddress.empty,
    this.expiryDate,
    this.latestShipmentDate,
    this.remarks,
  });

  final CorpLetterOfCredit original;

  /// Amount transferred to the second beneficiary (LC currency).
  final double? amount;
  final String? beneficiaryName;
  final LcAddress beneficiaryAddress;

  /// Transferred LCs may shorten, never extend, these dates.
  final DateTime? expiryDate;
  final DateTime? latestShipmentDate;
  final String? remarks;

  factory LcTransferDraft.fromLetterOfCredit(CorpLetterOfCredit lc) {
    return LcTransferDraft(
      original: lc,
      amount: lc.transferrableAmount?.amount ?? lc.outstandingAmount?.amount,
      expiryDate: lc.expiryDate,
      latestShipmentDate: lc.shipment.latestShipmentDate,
    );
  }

  String? get currency => original.amount?.currency;

  /// Upper limit for [amount].
  double? get maxAmount =>
      original.transferrableAmount?.amount ?? original.outstandingAmount?.amount;

  LcTransferDraft copyWith({
    double? amount,
    String? beneficiaryName,
    LcAddress? beneficiaryAddress,
    DateTime? expiryDate,
    DateTime? latestShipmentDate,
    String? remarks,
  }) {
    return LcTransferDraft(
      original: original,
      amount: amount ?? this.amount,
      beneficiaryName: beneficiaryName ?? this.beneficiaryName,
      beneficiaryAddress: beneficiaryAddress ?? this.beneficiaryAddress,
      expiryDate: expiryDate ?? this.expiryDate,
      latestShipmentDate: latestShipmentDate ?? this.latestShipmentDate,
      remarks: remarks ?? this.remarks,
    );
  }

  /// Transfer body.
  ///
  /// NOT CAPTURED: the captures stop at the transferable-LC list (H2 #202).
  /// The LC DTO carries `transferredLCs[]` / `transferrableAmount`
  /// (H1 #121), so this sends the original LC with one entry in
  /// `transferredLCs`. Confirm against a capture of a completed transfer.
  Map<String, dynamic> toRequestJson({required TfId partyId}) {
    final money = {'currency': currency, 'amount': amount};
    return {
      ...original.raw,
      'partyId': (original.partyId.isEmpty ? partyId : original.partyId)
          .toJson(),
      'transactionType': 'CONVENTIONAL',
      'transferrableAmount': money,
      'transferredLCs': [
        {
          'counterPartyName': beneficiaryName,
          'counterPartyAddress': beneficiaryAddress.toJson(),
          'amount': money,
          'expiryDate': TfDate.toApi(expiryDate),
          'shipmentDetails': original.shipment
              .copyWith(latestShipmentDate: latestShipmentDate)
              .toAmendmentJson(),
          'remarks': (remarks?.trim().isEmpty ?? true) ? null : remarks!.trim(),
        },
      ],
    };
  }
}
