import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// A repeat transfer — a standing instruction — as OBDX's "View Repeat
/// Transfers" lists it (`GET payments/instructions`,
/// `components/payments/standing-instructions-list`).
///
/// The bank's core system makes each payment on its date; the app only
/// shows the instruction, its history, and can stop it.
class StandingInstruction {
  const StandingInstruction({
    required this.reference,
    required this.payeeName,
    required this.amount,
    required this.currency,
    required this.active,
    this.debitAccount,
    this.debitAccountValue,
    this.startDate,
    this.endDate,
    this.nextDate,
    this.instances,
    this.everyDays,
    this.everyWeeks,
    this.everyMonths,
    this.everyYears,
    this.transactionType,
    this.paymentType,
    this.partyId,
    this.network,
    this.remarks,
  });

  /// `externalReferenceNumber` — what detail and stop are keyed by.
  final String reference;
  final String payeeName;
  final double amount;
  final String currency;

  /// `statusType` O (active) — C is cancelled ("Closed" in OBDX).
  final bool active;

  /// The account paid from, as shown (`debitAccountId.displayValue`) and as
  /// the bank knows it (`.value`).
  final String? debitAccount;
  final String? debitAccountValue;

  final DateTime? startDate;

  /// Ends on this date — or after [instances] payments.
  final DateTime? endDate;
  final DateTime? nextDate;
  final int? instances;

  /// `freqDays` / `freqWeeks` / `freqMonths` / `freqYears`: the one set says
  /// how often.
  final int? everyDays;
  final int? everyWeeks;
  final int? everyMonths;
  final int? everyYears;

  /// `B` within the bank, `A` domestic (SEPA), `X` international.
  final String? transactionType;
  final String? paymentType;
  final String? partyId;
  final String? network;
  final String? remarks;

  /// "Once every month", "Once every 2 weeks"… — OBDX's own wording of
  /// the counts, largest unit first.
  String get frequencyLabel {
    String every(int? n, String one, String many) =>
        n == 1 ? 'Once every $one' : 'Once every $n $many';
    if ((everyYears ?? 0) > 0) return every(everyYears, 'year', 'years');
    if ((everyMonths ?? 0) > 0) return every(everyMonths, 'month', 'months');
    if ((everyWeeks ?? 0) > 0) return every(everyWeeks, 'week', 'weeks');
    if ((everyDays ?? 0) > 0) return every(everyDays, 'day', 'days');
    return 'Repeating';
  }

  /// "Within the bank", "Domestic", "International".
  String? get kindLabel => switch (transactionType?.toUpperCase()) {
        'B' => 'Within the bank',
        'A' => 'Domestic',
        'X' => 'International',
        _ => null,
      };

  /// "Until 31 Dec 2026" / "12 payments" / "No end date".
  bool get endsByCount => endDate == null && (instances ?? 0) > 0;

  static StandingInstruction? fromJson(Map<String, dynamic> json) {
    final reference = _str(json['externalReferenceNumber']) ?? _str(json['instructionNumber']);
    if (reference == null) return null;
    final amount = ObdxApiUtils.asMap(json['amount']);
    final debit = json['debitAccountId'];
    final debitMap = debit is Map ? Map<String, dynamic>.from(debit) : const <String, dynamic>{};
    final party = json['partyId'];
    final status = (_str(json['statusType']) ?? _str(json['status']) ?? '').toUpperCase();
    return StandingInstruction(
      reference: reference,
      payeeName: _str(json['payeeNickName']) ?? _str(json['beneficiaryName']) ?? 'Payee',
      amount: _num(amount['amount']) ?? 0,
      currency: _str(amount['currency']) ?? '',
      // O open / ACTIVE; C closed / CANCELLED.
      active: status != 'C' && status != 'CANCELLED',
      debitAccount: _str(debitMap['displayValue']) ?? (debit is String ? debit : null),
      debitAccountValue: _str(debitMap['value']),
      startDate: obdxDate(json['startDate']),
      endDate: obdxDate(json['endDate']),
      nextDate: obdxDate(json['nextExecutionDate']),
      instances: _int(json['instances']),
      everyDays: _int(json['freqDays']),
      everyWeeks: _int(json['freqWeeks']),
      everyMonths: _int(json['freqMonths']),
      everyYears: _int(json['freqYears']),
      transactionType: _str(json['transactionType']),
      paymentType: _str(json['paymentType']),
      partyId: party is Map ? _str(party['value']) : _str(party),
      network: _str(json['network']),
      remarks: _str(json['remarks']),
    );
  }
}

/// One page of [StandingInstruction]s, and how many the bank holds in all
/// (`maxNoOfRecords`).
class StandingInstructionPage {
  const StandingInstructionPage({required this.items, required this.total});

  final List<StandingInstruction> items;
  final int total;

  static StandingInstructionPage fromPayload(Map<String, dynamic> body) {
    final raw = body['instructionsList'];
    final items = <StandingInstruction>[
      if (raw is List)
        for (final item in raw)
          if (item is Map)
            if (StandingInstruction.fromJson(Map<String, dynamic>.from(item)) case final si?) si,
    ];
    final total = raw is List && raw.isNotEmpty && raw.first is Map
        ? _int((raw.first as Map)['maxNoOfRecords'])
        : null;
    return StandingInstructionPage(items: items, total: total ?? items.length);
  }
}

/// One payment the bank made — or tried to — for an instruction.
class InstructionExecution {
  const InstructionExecution({required this.date, required this.completed, this.failureReason});

  final DateTime? date;

  /// `COM` completed; anything else failed.
  final bool completed;
  final String? failureReason;
}

/// An instruction's payment history (`GET payments/instructions/{ref}` →
/// `instructionDetails.paymentDetailsList`), newest first.
class StandingInstructionDetail {
  const StandingInstructionDetail({required this.history});

  final List<InstructionExecution> history;

  static StandingInstructionDetail fromPayload(Map<String, dynamic> body) {
    final details = ObdxApiUtils.asMap(body['instructionDetails']);
    final raw = details['paymentDetailsList'];
    final history = <InstructionExecution>[
      if (raw is List)
        for (final item in raw)
          if (item is Map)
            InstructionExecution(
              date: obdxDate(item['valueDate']),
              completed: _str(item['status'])?.toUpperCase() == 'COM',
              failureReason: _str(item['failureReason']),
            ),
    ]..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
    return StandingInstructionDetail(history: history);
  }
}

/// What stopping an instruction came to: stopped (or sent for approval), or
/// the OTP the bank wants first.
class InstructionStopOutcome {
  const InstructionStopOutcome.stopped({this.reference, this.pendingApproval = false})
      : challenge = null,
        invalidOtp = false;

  const InstructionStopOutcome.otpRequired(ObdxChallenge this.challenge, {this.invalidOtp = false})
      : reference = null,
        pendingApproval = false;

  final String? reference;

  /// 202 — an approver has to agree first.
  final bool pendingApproval;
  final ObdxChallenge? challenge;

  /// The OTP sent with this attempt was not accepted.
  final bool invalidOtp;
}

/// An OBDX date: ISO (`2026-10-01T00:00:00`), the core's compact
/// `yyyyMMddHHmmss`, or `{dateString: …}`.
DateTime? obdxDate(dynamic value) {
  if (value is Map) return obdxDate(value['dateString'] ?? value['value']);
  final text = _str(value);
  if (text == null) return null;
  final iso = DateTime.tryParse(text);
  if (iso != null) return iso;
  final digits = RegExp(r'^(\d{4})(\d{2})(\d{2})').firstMatch(text);
  if (digits == null) return null;
  return DateTime(
    int.parse(digits.group(1)!),
    int.parse(digits.group(2)!),
    int.parse(digits.group(3)!),
  );
}

String? _str(dynamic v) {
  final t = v?.toString().trim();
  return t == null || t.isEmpty || t == 'null' ? null : t;
}

int? _int(dynamic v) => v is num ? v.toInt() : int.tryParse(_str(v) ?? '');

double? _num(dynamic v) => v is num ? v.toDouble() : double.tryParse(_str(v)?.replaceAll(',', '') ?? '');
