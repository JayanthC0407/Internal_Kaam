import 'dart:convert';

import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Service Requests (OBDX `service-requests` module, retail and corporate):
/// Track Requests (`service-requests-track`) and Raise a New Request
/// (`service-requests-base-main` → `-base-form` → `-verify`). Payload
/// shapes follow those components' model.js.

/// `{code, description}` of an OBDX enumeration (`srStatus`,
/// `srRequestType`, `gender`, `salutation`, `country`, `…/state`).
class SrOption {
  const SrOption({required this.code, required this.description});

  final String code;
  final String description;

  static List<SrOption> listFromEnumeration(Map<String, dynamic> body) {
    final reps = body['enumRepresentations'];
    if (reps is! List || reps.isEmpty) return const [];
    return [
      for (final row in _maps(ObdxApiUtils.asMap(reps.first)['data']))
        SrOption(code: _str(row['code']), description: _str(row['description'] ?? row['code'])),
    ];
  }

  /// A field's `values[]` (`{code, description, sequenceNumber}`).
  static List<SrOption> listFromValues(dynamic raw) {
    final rows = _maps(raw)..sort((a, b) => (_int(a['sequenceNumber']) ?? 0).compareTo(_int(b['sequenceNumber']) ?? 0));
    return [
      for (final row in rows) SrOption(code: _str(row['code'] ?? row['description']), description: _str(row['description'] ?? row['code'])),
    ];
  }
}

/// `servicerequest/products/{product}/categories` → `categoryResponse[]`.
class SrCategory {
  const SrCategory({required this.id, required this.name});

  final String id;
  final String name;

  static List<SrCategory> listFromPayload(Map<String, dynamic> body) => [
        for (final row in _maps(body['categoryResponse']))
          SrCategory(id: _str(row['id']), name: _str(row['categoryName'] ?? row['id'])),
      ];

  /// `servicerequest/products` → `productResponse[].productName`, sorted.
  static List<String> productsFromPayload(Map<String, dynamic> body) =>
      [for (final row in _maps(body['productResponse'])) _str(row['productName'])].where((p) => p.isNotEmpty).toList()..sort();
}

/// A request the customer can raise: `servicerequest/definitions` →
/// `serviceRequestResponse[]`.
class SrDefinition {
  const SrDefinition({
    required this.id,
    required this.name,
    required this.product,
    required this.categoryType,
    this.priorityType,
    this.form,
  });

  final String id;
  final String name;
  final String product;

  /// The category it is listed under (an id of `categoryResponse[]`).
  final String categoryType;
  final String? priorityType;

  /// Only on `servicerequest/definitions/{id}`.
  final SrForm? form;

  factory SrDefinition.fromJson(Map<String, dynamic> json) => SrDefinition(
        id: _str(json['id']),
        name: _str(json['name']),
        product: _str(json['product']),
        categoryType: _str(json['categoryType']),
        priorityType: _nullable(json['priorityType']),
        form: json['form'] is Map ? SrForm.fromJson(ObdxApiUtils.asMap(json['form'])) : null,
      );

  static List<SrDefinition> listFromPayload(Map<String, dynamic> body) => [
        for (final row in _maps(body['serviceRequestResponse'])) SrDefinition.fromJson(row),
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// `serviceRequestResponse[0]` of `servicerequest/definitions/{id}`.
  static SrDefinition? oneFromPayload(Map<String, dynamic> body) {
    final list = _maps(body['serviceRequestResponse']);
    if (list.isNotEmpty) return SrDefinition.fromJson(list.first);
    final single = body['serviceRequestResponse'];
    return single is Map ? SrDefinition.fromJson(ObdxApiUtils.asMap(single)) : null;
  }
}

/// `definition.form`, authored in the bank's form builder.
class SrForm {
  const SrForm({
    required this.fields,
    this.header,
    this.confirmMessage,
    this.infoHeader,
    this.infoDescription,
    this.infoIconId,
  });

  final String? header;
  final String? confirmMessage;
  final String? infoHeader;
  final String? infoDescription;

  /// `infoNote.icon.value`, a `contents` id.
  final String? infoIconId;

  /// Sorted by `sequenceNumber`.
  final List<SrField> fields;

  factory SrForm.fromJson(Map<String, dynamic> json) {
    final note = ObdxApiUtils.asMap(json['infoNote']);
    return SrForm(
      header: _nullable(json['header']),
      confirmMessage: _nullable(json['confirmMessage']),
      infoHeader: _nullable(note['header']),
      infoDescription: _nullable(note['description']),
      infoIconId: _nullable(ObdxApiUtils.asMap(note['icon'])['value']),
      fields: [for (final f in _maps(json['fields'])) SrField.fromJson(f)]..sort((a, b) => a.sequence.compareTo(b.sequence)),
    );
  }
}

/// The form builder's field types.
enum SrFieldType {
  textBox('FFTB'),
  radio('FFRB'),
  checkBoxes('FFMC'),
  dropList('FFDL'),
  multiSelect('FFMS'),
  toggle('FFTC'),
  fileUpload('FFFU'),
  account('PDAN'),
  accountDebitCard('PDAD'),
  gender('PDGS'),
  salutation('PDSS'),
  countryState('PDCS'),
  date('PDDP'),
  sectionHeader('SCH'),
  subHeader('SBH');

  const SrFieldType(this.code);

  final String code;

  static SrFieldType? parse(String code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return null;
  }

  bool get isHeader => this == sectionHeader || this == subHeader;
}

/// One `form.fields[]` entry.
class SrField {
  const SrField({
    required this.typeCode,
    required this.name,
    required this.label,
    required this.sequence,
    this.hint,
    this.errorMessage,
    this.mandatory = false,
    this.minLength,
    this.maxLength,
    this.validationType,
    this.options = const [],
    this.firstOption,
    this.secondOption,
  });

  /// As sent back (`FFTB`, `PDAN`, …); [type] is null for one this app
  /// does not know, which is then shown read-only.
  final String typeCode;
  final String name;
  final String label;
  final int sequence;
  final String? hint;
  final String? errorMessage;
  final bool mandatory;
  final int? minLength;
  final int? maxLength;

  /// `ALPHABETS`, `NUMBERS`, `ALPHANUMERIC`, `ALPHANUMERIC_WITH_SPACE`,
  /// `ALPHANUMERIC_WITH_SOME_SPECIAL`, `ALPHANUMERIC_WITH_ALL_SPECIAL`,
  /// `CUSTOM_TEXT`.
  final String? validationType;
  final List<SrOption> options;

  /// A toggle's two choices (`values.firstOption` / `secondOption`).
  final String? firstOption;
  final String? secondOption;

  SrFieldType? get type => SrFieldType.parse(typeCode);

  /// A header's text: `values[0].description`.
  String get headerText => options.isNotEmpty ? options.first.description : label;

  factory SrField.fromJson(Map<String, dynamic> json) {
    final validation = ObdxApiUtils.asMap(json['validation']);
    final values = json['values'];
    final toggle = values is Map ? ObdxApiUtils.asMap(values) : const <String, dynamic>{};
    return SrField(
      typeCode: _str(json['type']),
      name: _str(json['name']),
      label: _str(json['label']),
      sequence: _int(json['sequenceNumber']) ?? 0,
      hint: _nullable(json['hintText']),
      errorMessage: _nullable(json['errorMessage']),
      mandatory: validation['mandatory'] == true || validation['mandatory']?.toString().toLowerCase() == 'true',
      minLength: _int(validation['minLength']),
      maxLength: _int(validation['maxLength']),
      validationType: _nullable(validation['textBoxValidationType']),
      options: values is List ? SrOption.listFromValues(values) : const [],
      firstOption: _nullable(toggle['firstOption']),
      secondOption: _nullable(toggle['secondOption']),
    );
  }
}

/// What the customer entered in one field, in OBDX's `requestData`
/// element shape.
class SrAnswer {
  const SrAnswer({required this.values, required this.displayValues, this.indirectionTypes});

  final List<String> values;
  final List<String> displayValues;

  /// `["Account"]` (PDAN), `["File"]` (FFFU), `["Account","Debit"]` (PDAD).
  final List<String>? indirectionTypes;

  bool get isEmpty => values.every((v) => v.trim().isEmpty);

  static const empty = SrAnswer(values: [], displayValues: []);
}

/// The request status codes (`srStatus`).
abstract final class SrStatus {
  static const all = ['IN', 'PE', 'IP', 'RQ', 'AC', 'IS', 'DP', 'DL', 'CO', 'CL', 'RT', 'RE'];

  /// Still with the bank.
  static bool isOpen(String code) => const {'IN', 'PE', 'IP', 'RQ', 'AC'}.contains(code);

  static bool isNegative(String code) => const {'RE', 'RT'}.contains(code);
}

/// One row of Track Requests: `GET servicerequest` → `list[]`.
class ServiceRequestSummary {
  const ServiceRequestSummary({
    required this.id,
    required this.name,
    required this.status,
    required this.requestType,
    this.creationDate,
  });

  /// The reference number.
  final String id;
  final String name;
  final String status;

  /// `OTHERS` for a form-builder request, else a predefined type code.
  final String requestType;
  final DateTime? creationDate;

  factory ServiceRequestSummary.fromJson(Map<String, dynamic> json) => ServiceRequestSummary(
        id: _str(json['id']),
        name: _str(ObdxApiUtils.asMap(json['definition'])['name'] ?? json['requestName'] ?? json['requestType']),
        status: _str(json['status']),
        requestType: _str(json['requestType']),
        creationDate: DateTime.tryParse(_str(json['creationDate'])),
      );

  /// Newest first.
  static List<ServiceRequestSummary> listFromPayload(Map<String, dynamic> body) => [
        for (final row in _maps(body['list'] ?? body['serviceRequestDTOs'])) ServiceRequestSummary.fromJson(row),
      ]..sort((a, b) => (b.creationDate ?? DateTime(0)).compareTo(a.creationDate ?? DateTime(0)));
}

/// One filled-in field of a raised request (`requestData.elements[]`).
class SrElement {
  const SrElement({required this.label, required this.type, required this.values, required this.displayValues});

  final String? label;
  final String type;
  final List<String> values;
  final List<String> displayValues;

  bool get isFile => type == SrFieldType.fileUpload.code;
  bool get isHeader => type == SrFieldType.sectionHeader.code || type == SrFieldType.subHeader.code;
}

/// `GET servicerequest/{id}` → `serviceRequestDTO` (or `response`) with
/// `historyDetails[]`.
class ServiceRequestDetail {
  const ServiceRequestDetail({
    required this.id,
    required this.name,
    required this.status,
    required this.requestType,
    required this.elements,
    required this.history,
    this.creationDate,
    this.comments,
  });

  final String id;
  final String name;
  final String status;
  final String requestType;
  final DateTime? creationDate;

  /// The bank's closure comments.
  final String? comments;
  final List<SrElement> elements;

  /// `historyDetails[]`: status, date, note — oldest first.
  final List<({String status, DateTime? date, String? note})> history;

  factory ServiceRequestDetail.fromPayload(Map<String, dynamic> body) {
    final dto = ObdxApiUtils.asMap(body['serviceRequestDTO'] ?? body['response'] ?? body);
    return ServiceRequestDetail(
      id: _str(dto['id']),
      name: _str(ObdxApiUtils.asMap(dto['definition'])['name'] ?? dto['requestName'] ?? dto['requestType']),
      status: _str(dto['status']),
      requestType: _str(dto['requestType']),
      creationDate: DateTime.tryParse(_str(dto['creationDate'])),
      comments: _nullable(dto['comments']),
      elements: parseRequestData(dto['requestData']),
      history: [
        for (final h in _maps(body['historyDetails'] ?? dto['historyDetails']))
          (
            status: _str(h['status']),
            date: DateTime.tryParse(_str(h['lastUpdatedDate'] ?? h['updatedDate'] ?? h['creationDate'])),
            note: _nullable(h['note'] ?? h['comments'] ?? h['remarks']),
          ),
      ],
    );
  }

  /// `requestData` is a JSON string `{"elements":[…]}` (OBDX HTML-escapes
  /// it, so `&quot;` is undone first); unreadable data gives no elements.
  static List<SrElement> parseRequestData(dynamic raw) {
    Map<String, dynamic> data;
    if (raw is Map) {
      data = ObdxApiUtils.asMap(raw);
    } else {
      final text = _str(raw).replaceAll('&quot;', '"').replaceAll('&amp;', '&');
      if (text.isEmpty) return const [];
      try {
        data = ObdxApiUtils.asMap(jsonDecode(text));
      } catch (_) {
        return const [];
      }
    }
    List<String> strings(dynamic v) => [
          if (v is List)
            for (final x in v) _str(x)
          else if (v != null)
            _str(v),
        ];
    return [
      for (final e in _maps(data['elements']))
        SrElement(
          label: _nullable(e['label']),
          type: _str(e['type']),
          values: strings(e['values']),
          displayValues: strings(e['displayValues']),
        ),
    ];
  }
}

/// A CASA account for PDAN / PDAD (`GET demandDeposit` → `accounts[]`).
class SrAccount {
  const SrAccount({required this.value, required this.displayValue});

  final String value;
  final String displayValue;

  static List<SrAccount> listFromPayload(Map<String, dynamic> body) => [
        for (final a in _maps(body['accounts']))
          SrAccount(
            value: _str(ObdxApiUtils.asMap(a['id'])['value']),
            displayValue: _str(ObdxApiUtils.asMap(a['id'])['displayValue'] ?? ObdxApiUtils.asMap(a['id'])['value']),
          ),
      ];

  /// `demandDeposit/{account}/debitCards` → `debitCardDetails[].cardNo`.
  static List<SrOption> cardsFromPayload(Map<String, dynamic> body) => [
        for (final c in _maps(body['debitCardDetails']))
          () {
            final no = c['cardNo'];
            final map = ObdxApiUtils.asMap(no);
            final value = map.isEmpty ? _str(no) : _str(map['value'] ?? map['displayValue']);
            final display = map.isEmpty ? _str(no) : _str(map['displayValue'] ?? map['value']);
            return SrOption(code: value, description: display);
          }(),
      ];
}

/// The request about to be raised: the form, the answers, and the
/// `POST servicerequest` body built from them (service-requests-verify).
class SrSubmission {
  const SrSubmission({required this.definition, required this.answers});

  final SrDefinition definition;

  /// By field name.
  final Map<String, SrAnswer> answers;

  List<Map<String, dynamic>> get elements => [
        for (final f in definition.form?.fields ?? const <SrField>[])
          if (f.type?.isHeader ?? false)
            {
              'id': f.name,
              'type': f.typeCode,
              'label': null,
              'values': [f.headerText],
              'displayValues': const <String>[],
              'indirectionTypes': null,
            }
          else
            {
              'id': f.name,
              'type': f.typeCode,
              'label': f.label,
              'values': answers[f.name]?.values ?? const <String>[],
              'displayValues': answers[f.name]?.displayValues ?? const <String>[],
              'indirectionTypes': answers[f.name]?.indirectionTypes,
            },
      ];

  Map<String, dynamic> toBody() => {
        'requestType': 'OTHERS',
        'entityTypeIdentifier': definition.id,
        'status': 'IN',
        'entityTypeIdentifierKey': 'DE',
        'definition': {'id': definition.id},
        'priorityType': definition.priorityType,
        'entity': 'AC',
        'requestData': jsonEncode({'elements': elements}),
      };
}

/// Result of raising a request.
class SrSubmitOutcome {
  const SrSubmitOutcome({this.reference, this.pendingApproval = false});

  final String? reference;

  /// Corporate: sent to an approver first.
  final bool pendingApproval;
}

/// Track Requests' filter.
class SrFilter {
  const SrFilter({this.product, this.category, this.fromDate, this.toDate, this.status});

  final String? product;
  final SrCategory? category;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? status;

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// The query OBDX sends (status, product, categoryType, fromDate, toDate).
  Map<String, dynamic> toQuery() => {
        if (status != null) 'status': status,
        if (product != null) 'product': product,
        if (category != null) 'categoryType': category!.id,
        if (fromDate != null) 'fromDate': _day(fromDate!),
        if (toDate != null) 'toDate': _day(toDate!),
      };

  @override
  bool operator ==(Object other) =>
      other is SrFilter &&
      other.product == product &&
      other.category?.id == category?.id &&
      other.fromDate == fromDate &&
      other.toDate == toDate &&
      other.status == status;

  @override
  int get hashCode => Object.hash(product, category?.id, fromDate, toDate, status);
}

String _str(dynamic v) => v == null || v is Map || v is List ? '' : v.toString().trim();

String? _nullable(dynamic v) {
  final s = _str(v);
  return s.isEmpty ? null : s;
}

int? _int(dynamic v) => v is num ? v.toInt() : int.tryParse(_str(v));

List<Map<String, dynamic>> _maps(dynamic raw) => [
      if (raw is List)
        for (final item in raw)
          if (item is Map) Map<String, dynamic>.from(item),
    ];
