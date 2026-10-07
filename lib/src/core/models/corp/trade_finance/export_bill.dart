import 'dart:convert';

import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/corp_letter_of_credit.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/lc_common.dart';

/// Export Bills — View Export Bill (manual ch. 14).
///
/// Where the names come from: the `bills` call failed (400) in both
/// captures, so no response has been seen. The OBDX web client's own bill
/// screens are in the captures, though (`components/bills/modify-bills`,
/// `initiate-bill`), and they give:
///  - the search — `GET …/bills?partyIds=…&q={criteria…}`, the criteria
///    built exactly as [ExportBillSearch.criteria] does;
///  - the list — `billDTOs[]`, and the row fields the web table reads;
///  - the detail — `GET …/bills/{billReferenceNo}`, answering `bill`, with
///    the bill model's field names.
/// Not in those screens: the fields *inside* a discrepancy, SWIFT message
/// or advice (the web's view-bill screen was not captured). Those are read
/// by the usual OBDX names — see [ExportBillDiscrepancy] and
/// [ExportBillMessage].

/// Bill status — the `status` criterion; the values and their order are
/// the web screen's (`statusPairs`).
enum ExportBillStatus {
  active('ACTIVE', 'Active'),
  hold('HOLD', 'Hold'),
  liquidated('LIQUIDATED', 'Liquidated'),
  closed('CLOSED', 'Closed'),
  cancelled('CANCELLED', 'Cancelled'),
  reversed('REVERSED', 'Reversed');

  const ExportBillStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// One removable filter of an [ExportBillSearch].
enum ExportBillFilter {
  billNumber,
  importer,
  status,
  currency,
  amount,
  billDate,
}

/// The View Export Bill search. Every criterion goes to the host, as the
/// web client sends it.
class ExportBillSearch {
  const ExportBillSearch({
    this.billNumber,
    this.importerName,
    this.status,
    this.currency,
    this.fromAmount,
    this.toAmount,
    this.dateFrom,
    this.dateTo,
  });

  /// The web screen opens on Active bills.
  static const initial = ExportBillSearch(status: ExportBillStatus.active);
  static const none = ExportBillSearch();

  final String? billNumber;

  /// The drawee — the importer.
  final String? importerName;
  final ExportBillStatus? status;
  final String? currency;
  final double? fromAmount;
  final double? toAmount;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  List<ExportBillFilter> get activeFilters => [
        if (_text(billNumber) != null) ExportBillFilter.billNumber,
        if (_text(importerName) != null) ExportBillFilter.importer,
        if (status != null) ExportBillFilter.status,
        if (_text(currency) != null) ExportBillFilter.currency,
        if (fromAmount != null || toAmount != null) ExportBillFilter.amount,
        if (dateFrom != null || dateTo != null) ExportBillFilter.billDate,
      ];

  int get activeCount => activeFilters.length;

  ExportBillSearch without(ExportBillFilter f) => ExportBillSearch(
        billNumber: f == ExportBillFilter.billNumber ? null : billNumber,
        importerName: f == ExportBillFilter.importer ? null : importerName,
        status: f == ExportBillFilter.status ? null : status,
        currency: f == ExportBillFilter.currency ? null : currency,
        fromAmount: f == ExportBillFilter.amount ? null : fromAmount,
        toAmount: f == ExportBillFilter.amount ? null : toAmount,
        dateFrom: f == ExportBillFilter.billDate ? null : dateFrom,
        dateTo: f == ExportBillFilter.billDate ? null : dateTo,
      );

  /// The `criteria` list, operand by operand as the web client's
  /// `createQquery` builds it.
  List<Map<String, dynamic>> get criteria {
    Map<String, dynamic> c(String operand, String operator, Object value) => {
          'operand': operand,
          'operator': operator,
          'value': [value],
        };
    return [
      c('billType', 'EQUALS', 'EXPORT'),
      c('transactionType', 'EQUALS', 'CONVENTIONAL'),
      if (status != null) c('status', 'ENUM', status!.apiValue),
      if (_text(billNumber) case final n?)
        c('billReferenceNo', 'EQUALS', n.toUpperCase()),
      if (_text(currency) case final ccy?) c('ccy', 'EQUALS', ccy),
      if (_text(importerName) case final name?) c('drawee', 'CONTAINS', name),
      if (fromAmount != null)
        c('billAmtFrom', 'GREATERTHANEQUALTO', _amount(fromAmount!)),
      if (toAmount != null)
        c('billAmtTo', 'LESSTHANEQUALTO', _amount(toAmount!)),
      if (dateFrom != null)
        c('billDateFrom', 'GREATERTHANEQUALTO', _day(dateFrom!)),
      if (dateTo != null) c('billDateTo', 'LESSTHANEQUALTO', _day(dateTo!)),
    ];
  }

  /// The list call's query.
  Map<String, dynamic> toQuery({String? partyId}) => {
        if (partyId != null && partyId.isNotEmpty) 'partyIds': partyId,
        'q': jsonEncode({'criteria': criteria}),
      };

  static String? _text(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static num _amount(double v) => v == v.truncateToDouble() ? v.toInt() : v;
}

/// An Export Bill — a `billDTOs[]` row or the `bill` of the detail.
class CorpExportBill {
  const CorpExportBill({
    required this.id,
    required this.raw,
    this.productName,
    this.operationName,
    this.stageName,
    this.transactionDate,
    this.amount,
    this.equivalentAmount,
    this.outstandingAmount,
    this.status,
    this.importerName,
    this.importerAddress = const LcAddress(),
    this.exporterName,
    this.exporterAddress = const LcAddress(),
    this.partyId = const TfId(),
    this.branchId,
    this.lcRefNo,
    this.maturityDate,
    this.tenor,
    this.baseDateDescription,
    this.customerRefNo,
    this.bankRefNo,
    this.documentsAttached,
    this.paymentType,
    this.issuingBankName,
    this.issuingBankAddress = const LcAddress(),
    this.issuingBankSwift,
    this.shipment = const LcShipmentDetails(),
    this.goods = const [],
    this.remarks,
    this.charges = const [],
    this.discrepancies = const [],
    this.swiftMessages = const [],
    this.advices = const [],
  });

  /// The bill reference number (`id`).
  final String id;
  final Map<String, dynamic> raw;

  /// "Release against" in the web list.
  final String? productName;
  final String? operationName;
  final String? stageName;
  final DateTime? transactionDate;
  final MoneyAmount? amount;

  /// [amount] in the bank's local currency.
  final MoneyAmount? equivalentAmount;
  final MoneyAmount? outstandingAmount;

  /// `contractStatus` — ACTIVE, HOLD, LIQUIDATED…
  final String? status;

  /// The drawee (`counterPartyName`).
  final String? importerName;
  final LcAddress importerAddress;

  /// The drawer (`partyName`, or `name` as the list sends it).
  final String? exporterName;
  final LcAddress exporterAddress;
  final TfId partyId;
  final String? branchId;

  /// The export LC the bill is drawn under (`lcRefNo`).
  final String? lcRefNo;
  final DateTime? maturityDate;
  final String? tenor;
  final String? baseDateDescription;
  final String? customerRefNo;
  final String? bankRefNo;

  /// Documentary (true) or clean (false); null when not sent.
  final bool? documentsAttached;

  /// Sight / usance, when the host names it.
  final String? paymentType;
  final String? issuingBankName;
  final LcAddress issuingBankAddress;
  final String? issuingBankSwift;
  final LcShipmentDetails shipment;
  final List<LcGoods> goods;
  final String? remarks;
  final List<LcCharge> charges;
  final List<ExportBillDiscrepancy> discrepancies;
  final List<ExportBillMessage> swiftMessages;
  final List<ExportBillMessage> advices;

  /// Financed: negotiated, discounted or purchased, at the `FIN` stage —
  /// the web list's rule.
  bool get isFinanced =>
      stageName?.toUpperCase() == 'FIN' &&
      const {'NEGOTIATION', 'DISCOUNT', 'PURCHASE'}
          .contains(operationName?.toUpperCase());

  String get statusLabel =>
      (status == null || status!.isEmpty) ? 'Unknown' : status!;

  static CorpExportBill? fromJson(dynamic json) {
    final map = TfJson.map(json);
    final id = TfJson.str(map['id']) ?? TfJson.str(map['billReferenceNo']);
    if (id == null) return null;
    final docAttached = map['docAttached'];
    return CorpExportBill(
      id: id,
      raw: map,
      productName: TfJson.str(map['productName']),
      operationName: TfJson.str(map['operationName']),
      stageName: TfJson.str(map['stageName']),
      transactionDate: TfJson.date(map['transactionDate']) ??
          TfJson.date(map['lodgementDate']),
      amount: _money(map['amount']),
      equivalentAmount: _money(map['equivalentAmount']),
      outstandingAmount: _money(map['outstandingAmount']),
      status: TfJson.str(map['contractStatus']),
      importerName: TfJson.str(map['counterPartyName']),
      importerAddress: LcAddress.fromJson(map['counterPartyAddress']),
      exporterName: TfJson.str(map['partyName']) ?? TfJson.str(map['name']),
      exporterAddress: LcAddress.fromJson(map['partyAddress']),
      partyId: TfId.fromJson(map['partyId']),
      branchId: TfJson.str(map['branchId']),
      lcRefNo: TfJson.str(map['lcRefNo']),
      maturityDate: TfJson.date(map['maturityDate']),
      tenor: TfJson.str(map['tenor']),
      baseDateDescription: TfJson.str(map['baseDateDescription']),
      customerRefNo: TfJson.str(map['customerRefNo']),
      bankRefNo: TfJson.str(map['bankRefNo']),
      documentsAttached: docAttached == null
          ? null
          : TfJson.boolean(docAttached) ||
              docAttached.toString().toUpperCase() == 'Y',
      paymentType: TfJson.str(map['paymentType']) ?? TfJson.str(map['type']),
      issuingBankName: TfJson.str(map['bankName']),
      issuingBankAddress: LcAddress.fromJson(map['bankAddress']),
      issuingBankSwift: TfJson.str(map['swiftId']),
      shipment: LcShipmentDetails.fromJson(map['shipmentDetails']),
      goods: [
        for (final g in TfJson.maps(map['goods']))
          if (LcGoods.fromJson(g) case final goods?) goods,
      ],
      remarks: TfJson.str(map['remarks']),
      charges: [
        ...LcCharge.listFrom(map['charges']),
        // Top-level commissions, the shape of a `charges[]` block's own.
        ...LcCharge.listFrom([
          {'commissions': map['commissions']},
        ]),
      ],
      discrepancies: [
        for (final d in TfJson.maps(map['discrepancies']))
          if (ExportBillDiscrepancy.fromJson(d) case final x?) x,
      ],
      swiftMessages: [
        for (final m in TfJson.maps(map['swiftMessages']))
          if (ExportBillMessage.fromJson(m) case final x?) x,
      ],
      advices: [
        for (final m in TfJson.maps(map['advices']))
          if (ExportBillMessage.fromJson(m) case final x?) x,
      ],
    );
  }

  /// `billDTOs[]`.
  static List<CorpExportBill> listFromPayload(dynamic data) {
    final root = TfJson.root(data);
    return [
      for (final item in TfJson.maps(root['billDTOs']))
        if (CorpExportBill.fromJson(item) case final bill?) bill,
    ];
  }

  /// `bill`.
  static CorpExportBill? fromDetailPayload(dynamic data) =>
      CorpExportBill.fromJson(TfJson.root(data)['bill']);

  static MoneyAmount? _money(dynamic json) {
    final map = TfJson.map(json);
    if (map.isEmpty || map['amount'] == null) return null;
    return MoneyAmount.fromJson(map);
  }
}

/// A discrepancy the bank found in the documents (manual 14.2).
///
/// **Unconfirmed names** — see the file comment.
class ExportBillDiscrepancy {
  const ExportBillDiscrepancy({
    required this.description,
    this.receivedDate,
    this.status,
    this.resolvedDate,
    this.approvedDate,
  });

  final String description;
  final DateTime? receivedDate;
  final String? status;
  final DateTime? resolvedDate;
  final DateTime? approvedDate;

  static ExportBillDiscrepancy? fromJson(Map<String, dynamic> json) {
    final description = TfJson.str(json['description']) ??
        TfJson.str(json['discrepancyDescription']) ??
        TfJson.str(json['code']);
    if (description == null) return null;
    final resolved = json['resolved'];
    return ExportBillDiscrepancy(
      description: description,
      receivedDate:
          TfJson.date(json['receivedDate']) ?? TfJson.date(json['date']),
      status: TfJson.str(json['status']) ??
          (resolved == null
              ? null
              : (TfJson.boolean(resolved) ? 'Resolved' : 'Not resolved')),
      resolvedDate: TfJson.date(json['resolvedDate']),
      approvedDate: TfJson.date(json['approvedDate']),
    );
  }
}

/// A SWIFT message or an advice on the bill (manual 14.4, 14.5).
///
/// **Unconfirmed names** — see the file comment.
class ExportBillMessage {
  const ExportBillMessage({
    required this.id,
    this.date,
    this.description,
    this.messageType,
    this.bank,
    this.eventDescription,
    this.content,
  });

  final String id;
  final DateTime? date;
  final String? description;

  /// SWIFT only — MT 740 and the like.
  final String? messageType;

  /// SWIFT only — the sending / receiving bank.
  final String? bank;
  final String? eventDescription;

  /// The message text, when the list carries it.
  final String? content;

  static ExportBillMessage? fromJson(Map<String, dynamic> json) {
    final id = TfJson.str(json['messageId']) ??
        TfJson.str(json['id']) ??
        TfJson.str(json['adviceId']);
    if (id == null) return null;
    return ExportBillMessage(
      id: id,
      date: TfJson.date(json['messageDate']) ??
          TfJson.date(json['date']) ??
          TfJson.date(json['eventDate']),
      description: TfJson.str(json['description']) ??
          TfJson.str(json['messageDescription']),
      messageType: TfJson.str(json['messageType']) ?? TfJson.str(json['type']),
      bank: TfJson.str(json['bankName']) ??
          TfJson.str(json['sendingBank']) ??
          TfJson.str(json['receivingBank']),
      eventDescription: TfJson.str(json['eventDescription']),
      content: TfJson.str(json['message']) ?? TfJson.str(json['content']),
    );
  }
}
