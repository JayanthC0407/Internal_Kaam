import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/common/obdx_batch.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/obdx_otp_outcome.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Sweep-In (OBDX `flows/sweep-in-instruction`). Shapes and rules from the
/// source: docs/obdx/features/sweep-in.md.

/// Linked Account Type: OBDX's radio values.
enum SweepType { casa, td }

/// An account from the picker or the CASA / TD lists.
class SweepAccount {
  const SweepAccount({
    required this.id,
    required this.display,
    this.partyName,
    this.balance,
    this.type,
    this.productId,
    this.isDefault = false,
  });

  /// `id.value`.
  final String id;

  /// `id.displayValue` (masked).
  final String display;
  final String? partyName;

  /// `availableBalance` (shown for Current and Savings only).
  final MoneyAmount? balance;

  /// `type`, sent as `providerAccountType` (review/hooks.js:162).
  final String? type;

  /// `productDTO.productId`; "WALLET" is never offered (stage1/hooks.js:444, 500).
  final String? productId;
  final bool isDefault;

  static List<SweepAccount> listFromPayload(Map<String, dynamic> body) {
    final raw = body['accounts'];
    if (raw is! List) return const [];
    return [
      for (final r in raw.whereType<Map>())
        if (_idOf(r['id']) case final id?)
          SweepAccount(
            id: id.$1,
            display: id.$2,
            partyName: _str(r['partyName']),
            balance: r['availableBalance'] == null ? null : MoneyAmount.fromJson(r['availableBalance']),
            type: _str(r['type']),
            productId: _str(ObdxApiUtils.asMap(r['productDTO'])['productId']),
            isDefault: '${r['defaultAccount']}'.toLowerCase() == 'true',
          ),
    ];
  }

  static SweepAccount? initial(List<SweepAccount> list) =>
      list.where((a) => a.isDefault).firstOrNull ?? list.firstOrNull;
}

/// `sweepInInstructions[]`: one provider linked to the account.
class SweepInstruction {
  const SweepInstruction({required this.instructionNumber, required this.providerId});

  final String instructionNumber;

  /// `providerAccountId.value`.
  final String providerId;

  static List<SweepInstruction> listFromPayload(Map<String, dynamic> body) {
    final raw = body['sweepInInstructions'];
    if (raw is! List) return const [];
    return [
      for (final r in raw.whereType<Map>())
        if (_str(ObdxApiUtils.asMap(r['providerAccountId'])['value']) case final provider?)
          SweepInstruction(instructionNumber: _str(r['instructionNumber']) ?? '', providerId: provider),
    ];
  }
}

/// A row of Linked Accounts / Deposits, with the instruction Delete removes.
class SweepLinked {
  const SweepLinked({required this.account, required this.instructionNumber});

  final SweepAccount account;
  final String instructionNumber;
}

/// The messages OBDX raises while building the lists.
enum SweepNotice {
  /// "…You need to have two or more accounts…" (CASA list of 1 or fewer).
  noCasaAccounts,

  /// "…You need to have at least one Term Deposit…" (empty TD list).
  noDeposits,

  /// "All the accounts are already linked…" (nothing left to link).
  allLinked,
}

/// Both lists for one account and type, built as OBDX builds them.
class SweepLists {
  const SweepLists({required this.linked, required this.providers, this.notices = const []});

  final List<SweepLinked> linked;
  final List<SweepAccount> providers;
  final List<SweepNotice> notices;

  factory SweepLists.build({
    required SweepType type,
    required String selectedId,
    required List<SweepInstruction> instructions,
    required List<SweepAccount> accounts,
  }) {
    final providerIds = {for (final i in instructions) i.providerId};
    // Linked: CASA needs two or more accounts, TD at least one
    // (stage1/hooks.js:367-380, 398-411); the account itself is left out
    // (showDetails).
    final enough = type == SweepType.casa ? accounts.length > 1 : accounts.isNotEmpty;
    final linked = [
      if (enough)
        for (final a in accounts)
          if (providerIds.contains(a.id) && a.id != selectedId)
            SweepLinked(
              account: a,
              // OBDX deletes the first instruction for that provider (hooks.js:559-562).
              instructionNumber: instructions.firstWhere((i) => i.providerId == a.id).instructionNumber,
            ),
    ];
    // Providers: not linked, not the account itself, not a wallet (hooks.js:421-531).
    final providers = [
      for (final a in accounts)
        if (!providerIds.contains(a.id) && a.id != selectedId && a.productId != 'WALLET') a,
    ];
    return SweepLists(
      linked: linked,
      providers: providers,
      notices: [
        if (!enough) type == SweepType.casa ? SweepNotice.noCasaAccounts : SweepNotice.noDeposits,
        if (providers.isEmpty) SweepNotice.allLinked,
      ],
    );
  }
}

/// Confirm's batch: one `POST /demandDeposit/{account}/sweepInInstructions`
/// per ticked provider (review/hooks.js:146-170).
List<ObdxBatchItem> sweepLinkItems(String accountId, List<SweepAccount> providers) => [
      for (final p in providers)
        ObdxBatchItem(
          method: 'POST',
          uri: '/demandDeposit/${Uri.encodeComponent(accountId)}/sweepInInstructions',
          applicationId: 'digx-common/dda',
          body: {
            'providerAccountId': {'value': p.id},
            'providerAccountType': p.type,
          },
        ),
    ];

/// One provider's line in the status table (review/hooks.js:178-198).
class SweepResultRow {
  const SweepResultRow({
    required this.account,
    required this.completed,
    required this.reference,
    this.failureReason,
    this.failed = false,
  });

  final SweepAccount account;

  /// "Completed" when the part sent `externalReferenceId`, else "Failed".
  final bool completed;

  /// `externalReferenceId`, else "-".
  final String reference;

  /// The part's status was not 201.
  final bool failed;

  /// `message.detail`, else `detail`, for a part that is not 201.
  final String? failureReason;

  /// Answers matched to the ticked providers by position, as OBDX does.
  static List<SweepResultRow> listFrom(Map<String, dynamic> body, List<SweepAccount> providers) {
    final parts = ObdxBatchItemResult.listFromPayload(body);
    return [
      for (var i = 0; i < parts.length && i < providers.length; i++)
        if (parts[i].body.isNotEmpty)
          SweepResultRow(
            account: providers[i],
            completed: _str(parts[i].body['externalReferenceId']) != null,
            reference: _str(parts[i].body['externalReferenceId']) ?? '-',
            failed: parts[i].status != 201,
            failureReason: parts[i].status == 201
                ? null
                : _str(ObdxApiUtils.asMap(parts[i].body['message'])['detail']) ?? _str(parts[i].body['detail']),
          ),
    ];
  }
}

/// Confirm's answer, or the OTP still to enter (one for the whole batch).
class SweepLinkOutcome implements ObdxOtpOutcome {
  const SweepLinkOutcome.done({this.rows = const [], this.pendingApproval = false})
      : challenge = null,
        invalidOtp = false;

  const SweepLinkOutcome.otpRequired(ObdxChallenge this.challenge, {this.invalidOtp = false})
      : rows = const [],
        pendingApproval = false;

  final List<SweepResultRow> rows;
  final bool pendingApproval;
  @override
  final ObdxChallenge? challenge;
  @override
  final bool invalidOtp;

  /// OBDX's failure message when any part was not 201.
  bool get anyFailed => rows.any((r) => r.failed);
}

/// Delete's answer, or the OTP still to enter.
class SweepDelinkOutcome implements ObdxOtpOutcome {
  const SweepDelinkOutcome.done({this.reference, this.pendingApproval = false})
      : challenge = null,
        invalidOtp = false;

  const SweepDelinkOutcome.otpRequired(ObdxChallenge this.challenge, {this.invalidOtp = false})
      : reference = null,
        pendingApproval = false;

  /// `externalReferenceId` (stage1/hooks.js:566).
  final String? reference;
  final bool pendingApproval;
  @override
  final ObdxChallenge? challenge;
  @override
  final bool invalidOtp;
}

(String, String)? _idOf(dynamic raw) {
  final m = ObdxApiUtils.asMap(raw);
  final value = _str(m['value']);
  if (value == null) return null;
  return (value, _str(m['displayValue']) ?? value);
}

String? _str(dynamic v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}
