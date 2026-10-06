import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/lc_common.dart';

// Models used only by the View LC screen tabs.
// Captures: `view_LC_details.har` (**H4 #n**).

/// A bill drawn under an LC, from `GET …/bills?q=` (H4 #51).
///
/// The pre-sales host answered 400 (DIGX_PROD_DEF_0000), so the success
/// shape is NOT CAPTURED. Fields are read tolerantly using OBDX `BillDTO`
/// naming, and should be confirmed against a successful capture.
class LcBill {
  const LcBill({
    required this.id,
    required this.raw,
    this.amount,
    this.outstandingAmount,
    this.status,
    this.billDate,
    this.maturityDate,
    this.stage,
  });

  final String id;
  final Map<String, dynamic> raw;
  final MoneyAmount? amount;
  final MoneyAmount? outstandingAmount;
  final String? status;
  final DateTime? billDate;
  final DateTime? maturityDate;
  final String? stage;

  static List<LcBill> listFromPayload(dynamic data) {
    final root = TfJson.root(data);
    final raw = root['billsDTOs'] ??
        root['billDTOs'] ??
        root['bills'] ??
        root['billsDTO'] ??
        root['list'];
    return [
      for (final map in TfJson.maps(raw))
        if ((TfJson.str(map['id']) ??
                TfJson.str(map['billReferenceNo']) ??
                TfJson.str(map['billRefNo'])) case final id?)
          LcBill(
            id: id,
            raw: map,
            amount: _money(map['billAmount'] ?? map['amount']),
            outstandingAmount: _money(map['outstandingAmount']),
            status: TfJson.str(map['status']) ?? TfJson.str(map['billStatus']),
            billDate: TfJson.date(map['billDate']) ??
                TfJson.date(map['bookingDate']) ??
                TfJson.date(map['applicationDate']),
            maturityDate: TfJson.date(map['maturityDate']),
            stage: TfJson.str(map['stage']) ?? TfJson.str(map['operation']),
          ),
    ];
  }
}

/// A shipping guarantee linked to an LC, from
/// `GET …/shippingGuarantees?q=` (H4 #53, `shippingGuarantees[]`).
class LcShippingGuarantee {
  const LcShippingGuarantee({
    required this.id,
    this.counterPartyName,
    this.amount,
    this.outstandingAmount,
    this.status,
    this.applicationDate,
    this.expiryDate,
    this.productId,
  });

  final String id;
  final String? counterPartyName;
  final MoneyAmount? amount;
  final MoneyAmount? outstandingAmount;
  final String? status;
  final DateTime? applicationDate;
  final DateTime? expiryDate;
  final String? productId;

  static List<LcShippingGuarantee> listFromPayload(dynamic data) {
    final root = TfJson.root(data);
    return [
      for (final map in TfJson.maps(root['shippingGuarantees']))
        if (TfJson.str(map['id']) case final id?)
          LcShippingGuarantee(
            id: id,
            counterPartyName: TfJson.str(map['counterPartyName']),
            amount: _money(map['amount']),
            outstandingAmount: _money(map['outstandingAmount']),
            status: TfJson.str(map['status']),
            applicationDate: TfJson.date(map['applicationDate']),
            expiryDate: TfJson.date(map['expiryDate']),
            productId: TfJson.str(map['productId']),
          ),
    ];
  }
}

/// Branch id → name, from `locations/country/all/city/all/branchCode`
/// (H4 #26, `branchAddressDTO[]`).
class LcBranchNames {
  LcBranchNames._();

  static Map<String, String> fromPayload(dynamic data) {
    final root = TfJson.root(data);
    return {
      for (final map in TfJson.maps(root['branchAddressDTO']))
        if (TfJson.str(map['id']) case final id?)
          id: TfJson.str(map['branchName']) ?? id,
    };
  }
}

MoneyAmount? _money(dynamic json) {
  final map = TfJson.map(json);
  if (map.isEmpty || map['amount'] == null) return null;
  return MoneyAmount.fromJson(map);
}
