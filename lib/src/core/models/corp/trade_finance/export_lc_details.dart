import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/corp_letter_of_credit.dart';
import 'package:ubci_bank/src/core/models/corp/trade_finance/lc_common.dart';

/// Fields of `GET /letterofcredits/{id}` the View Export LC tabs show that
/// [CorpLetterOfCredit] does not parse (manual ch. 11.1–11.4).
///
/// Read from [CorpLetterOfCredit.raw], so the shared model is untouched.
/// Every field here is in the captured detail responses except the
/// document list (see [exportDocuments]).
extension ExportLcDetails on CorpLetterOfCredit {
  /// The beneficiary's — our — address (`partyAddress`).
  LcAddress get partyAddress => LcAddress.fromJson(raw['partyAddress']);

  /// LC amount including the positive tolerance (`exposure`).
  MoneyAmount? get totalExposure => _money(raw['exposure']);

  /// `revolvingDetails.autoReinstatement`.
  bool get autoReinstatement =>
      TfJson.boolean(TfJson.map(raw['revolvingDetails'])['autoReinstatement']);

  /// `revolvingDetails.cumulativeFrequency`.
  bool get cumulative => TfJson.boolean(
        TfJson.map(raw['revolvingDetails'])['cumulativeFrequency'],
      );

  /// `revolvingDetails.frequency` + `frequencyUnit`, e.g. "3 months".
  String? get revolvingFrequency {
    final details = TfJson.map(raw['revolvingDetails']);
    final frequency = TfJson.integer(details['frequency']);
    if (frequency == null || frequency == 0) return null;
    final unit = TfJson.str(details['frequencyUnit'])?.toLowerCase();
    return unit == null ? '$frequency' : '$frequency $unit';
  }

  bool get confirmed => TfJson.boolean(raw['confirmed']);
  bool get draftsRequired => TfJson.boolean(raw['draftsRequired']);

  /// Negotiation / deferred payment details (`paymentDetails`).
  String? get paymentDetails => TfJson.str(raw['paymentDetails']);

  /// `additionalAmountCovered` — insurance, freight, interest…
  String? get additionalAmountCovered =>
      TfJson.str(raw['additionalAmountCovered']);

  /// Special payment conditions for the beneficiary.
  String? get paymentConditionsBeneficiary =>
      TfJson.str(raw['paymentConditionsBene']);

  /// Special payment conditions for the bank only.
  String? get paymentConditionsBank => TfJson.str(raw['paymentConditionsBank']);

  /// Sender-to-receiver information (`instructionDescription`).
  String? get senderToReceiverInfo => TfJson.str(raw['instructionDescription']);

  /// Charges the beneficiary pays (`chargesFromBeneficiary`).
  String? get chargesFromBeneficiary =>
      TfJson.str(raw['chargesFromBeneficiary']);

  /// The party asked to confirm the LC: its name when the host sends
  /// details, else the code (`requestedConfirmationParty`).
  String? get requestedConfirmationParty =>
      TfJson.str(
          TfJson.map(raw['requestedConfirmationPartyDetails'])['name']) ??
      TfJson.str(raw['requestedConfirmationParty']);

  /// OBDX's "Back to Back LC No.": the LCs this one is backed by
  /// (`parentReferenceLCs`, e.g. `["123"]`).
  List<String> get backToBackLcNumbers {
    final list = raw['parentReferenceLCs'];
    return [
      if (list is List)
        for (final v in list)
          if (TfJson.str(v) case final number?) number,
    ];
  }

  /// The documents to present under the LC.
  ///
  /// **Not in any capture** — none of the captured LCs carried a document
  /// list — so this reads the OBDX names for it (`documents`, or the
  /// `document` the amendment detail uses) and returns nothing otherwise.
  List<ExportLcDocument> get exportDocuments {
    final list = TfJson.maps(raw['documents']).isNotEmpty
        ? TfJson.maps(raw['documents'])
        : TfJson.maps(raw['document']);
    return [
      for (final d in list)
        if (ExportLcDocument.fromJson(d) case final doc?) doc,
    ];
  }

  static MoneyAmount? _money(dynamic json) {
    final map = TfJson.map(json);
    if (map.isEmpty || map['amount'] == null) return null;
    return MoneyAmount.fromJson(map);
  }
}

/// One document to present under an LC, with its clauses.
class ExportLcDocument {
  const ExportLcDocument({
    required this.name,
    this.originals,
    this.copies,
    this.clauses = const [],
  });

  final String name;
  final String? originals;
  final String? copies;
  final List<String> clauses;

  static ExportLcDocument? fromJson(Map<String, dynamic> json) {
    final name = TfJson.str(json['name']) ??
        TfJson.str(json['description']) ??
        TfJson.str(json['id']) ??
        TfJson.str(json['code']);
    if (name == null) return null;
    String? count(List<String> keys) {
      for (final k in keys) {
        final v = TfJson.str(json[k]);
        if (v != null) return v;
      }
      return null;
    }

    return ExportLcDocument(
      name: name,
      originals: count(const ['numberOfOriginals', 'originals', 'original']),
      copies: count(const ['numberOfCopies', 'copies']),
      clauses: [
        for (final c in TfJson.maps(json['clauses']))
          if (TfJson.str(c['description']) ?? TfJson.str(c['code'])
              case final text?)
            text,
      ],
    );
  }
}
