import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// A corporate lending application in progress, from
/// `GET /digx-processmanagement/v1/processManagement?moduleId=OBCLPM`.
///
/// **No record has been captured yet** — the captured party had none
/// (`processManagementDTOs: []`). Each field is read from the usual OBDX
/// names; this is the one place to correct once a filled response is seen.
class CorpLoanApplication {
  const CorpLoanApplication({
    required this.id,
    this.product,
    this.amount,
    this.status,
    this.submittedOn,
  });

  final String id;
  final String? product;
  final MoneyAmount? amount;
  final String? status;
  final DateTime? submittedOn;

  static CorpLoanApplication? fromJson(Map<String, dynamic> json) {
    final idMap = ObdxApiUtils.asMap(json['id']);
    final id = _text([
      json['applicationId'],
      json['processId'],
      json['referenceNumber'],
      json['referenceNo'],
      idMap['displayValue'],
      idMap['value'],
      json['id'] is Map ? null : json['id'],
    ]);
    if (id == null) return null;
    return CorpLoanApplication(
      id: id,
      product: _text([
        json['productName'],
        json['productDescription'],
        json['facilityName'],
        json['processName'],
        json['description'],
      ]),
      amount: MoneyAmount.readFirst(
        json,
        const ['requestedAmount', 'loanAmount', 'facilityAmount', 'amount'],
        '',
      ),
      status: _text([
        json['stage'],
        json['currentStage'],
        json['stageName'],
        json['processStatus'],
        json['status'],
      ]),
      submittedOn: _date([
        json['submittedDate'],
        json['applicationDate'],
        json['creationDate'],
        json['createdDate'],
        json['startDate'],
      ]),
    );
  }

  static List<CorpLoanApplication> listFromPayload(Map<String, dynamic> body) {
    final raw = body['processManagementDTOs'];
    if (raw is! List) return const [];
    return raw
        .map((item) => CorpLoanApplication.fromJson(ObdxApiUtils.asMap(item)))
        .whereType<CorpLoanApplication>()
        .toList();
  }

  static String? _text(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  static DateTime? _date(List<dynamic> values) {
    for (final value in values) {
      final parsed =
          value == null ? null : DateTime.tryParse(value.toString().trim());
      if (parsed != null) return parsed;
    }
    return null;
  }
}
