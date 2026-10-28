import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/obdx_otp_outcome.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Cheque Book Request (OBDX `flows/cheque-book-request`). Shapes and rules
/// from the source: docs/obdx/features/cheque-book-request.md.

/// OBDX's task code for the flow (account picker, confirm screen).
const chequeBookTaskCode = 'CH_N_CBR';

/// Number of Leaves per Book: OBDX's fixed options (stage1/hooks.js:132-153).
const chequeLeaveOptions = [10, 25, 50];

/// Number of Cheque Books: digits only, 1 to 10 characters long
/// (stage1.html `NUMBERS`, `length {min: 1, max: 10}`).
bool chequeBooksValid(String text) => RegExp(r'^\d{1,10}$').hasMatch(text.trim());

/// OBDX refuses a request from the wallet (stage1.js:132-136).
bool isWalletAccount(ChequeAccount account) => account.display == 'Wallet';

/// An account in the picker: `demandDeposit?status=ACTIVE&accountType=
/// CURRENT,SAVING` with task code `CH_N_CBR`. OBDX's `hasChequeBook` filter
/// is never wired in (card §2), so every account is listed.
class ChequeAccount {
  const ChequeAccount({required this.id, required this.display, this.balance, this.isDefault = false});

  /// `id.value`.
  final String id;

  /// `id.displayValue` (masked).
  final String display;

  /// `availableBalance`, shown as Account Balance.
  final MoneyAmount? balance;
  final bool isDefault;

  static List<ChequeAccount> listFromPayload(Map<String, dynamic> body) {
    final raw = body['accounts'];
    if (raw is! List) return const [];
    return [
      for (final r in raw.whereType<Map>())
        if (_idOf(ObdxApiUtils.asMap(r)['id']) case final id?)
          ChequeAccount(
            id: id.$1,
            display: id.$2,
            balance: r['availableBalance'] == null ? null : MoneyAmount.fromJson(r['availableBalance']),
            isDefault: '${r['defaultAccount']}'.toLowerCase() == 'true',
          ),
    ];
  }

  /// OBDX's account-input starts on the default account, else the first.
  static ChequeAccount? initial(List<ChequeAccount> list) =>
      list.where((a) => a.isDefault).firstOrNull ?? list.firstOrNull;
}

/// A Type of Cheque Book option from `dda enumerations/chequeBookType`.
class ChequeBookType {
  const ChequeBookType({required this.code, required this.description});

  final String code;

  /// The option's label.
  final String description;

  /// OBDX builds the option value as `code-description-description` and
  /// splits it on `-` into the stock fields (stage1/hooks.js:37-46, 211).
  /// So `stockCurrency` carries the description, as OBDX sends it.
  Map<String, String> get stock {
    final parts = '$code-$description-$description'.split('-');
    String at(int i) => i < parts.length ? parts[i] : '';
    return {'stockCode': at(0), 'stockCurrency': at(1), 'stockDescription': at(2)};
  }

  static List<ChequeBookType> listFromPayload(Map<String, dynamic> body) => [
        for (final e in _enumData(body))
          if (_str(e['code']) case final code?) ChequeBookType(code: code, description: _str(e['description']) ?? code),
      ];
}

/// The two bank settings the form reads.
class ChequeBookConfig {
  const ChequeBookConfig({this.corpDda = false, this.booksEnabled = false});

  /// `corpDDAConfig` → `ddaConfig.corpDDAEnabled`: My Address is then the
  /// account's address.
  final bool corpDda;

  /// `config/inputNoOfChequeBooks` → `noOfChequeBooks === "Y"`: shows
  /// Number of Cheque Books.
  final bool booksEnabled;

  static bool corpDdaFrom(Map<String, dynamic> body) =>
      '${ObdxApiUtils.asMap(body['ddaConfig'])['corpDDAEnabled']}'.toLowerCase() == 'true';

  static bool booksEnabledFrom(Map<String, dynamic> body) => _str(body['noOfChequeBooks']) == 'Y';
}

/// Everything the form needs before it can show.
class ChequeBookSetup {
  const ChequeBookSetup({required this.config, required this.types, required this.accounts});

  final ChequeBookConfig config;
  final List<ChequeBookType> types;
  final List<ChequeAccount> accounts;
}

/// Delivery Location: OBDX's `deliverAt` ids (address.js:25-31).
enum ChequeDelivery {
  myAddress('ACC'),
  branch('BRN');

  const ChequeDelivery(this.code);
  final String code;
}

/// The delivery address: the keys of OBDX's `chequeDeliveryDetailsDTO.
/// address` that the source address has (address.js `setAddress` copies
/// only those; absent ones are left out of the JSON).
class ChequeAddress {
  const ChequeAddress(this.fields);

  static const keys = [
    'line1', 'line2', 'line3', 'line4', 'line5', 'line6', 'line7', 'line8', 'line9', 'line10', 'line11', 'line12', //
    'city', 'addressTypeDescription', 'state', 'country', 'zipCode',
  ];

  static const empty = ChequeAddress({});

  final Map<String, String> fields;

  bool get isEmpty => fields.isEmpty;

  /// Shown under the choice, in OBDX's order (address.js `addressParser`).
  List<String> get lines => [
        for (final k in keys)
          if (k != 'addressTypeDescription' && fields[k] != null) fields[k]!,
      ];

  factory ChequeAddress.fromPostal(dynamic postal) {
    final map = ObdxApiUtils.asMap(postal);
    return ChequeAddress({
      for (final k in keys)
        if (_str(map[k]) case final v?) k: v,
    });
  }

  /// `demandDeposit/{id}/address` → `address.postalAddress`, last key
  /// dropped as OBDX does (stage1/hooks.js:189-195).
  factory ChequeAddress.fromAccountAddress(Map<String, dynamic> body) {
    final postal = Map<String, dynamic>.of(ObdxApiUtils.asMap(ObdxApiUtils.asMap(body['address'])['postalAddress']));
    if (postal.isNotEmpty) postal.remove(postal.keys.last);
    return ChequeAddress.fromPostal(postal);
  }

  /// `locations/branches?branchCode=` → `addressDTO[0].branchAddress.postalAddress`.
  factory ChequeAddress.fromBranchPayload(Map<String, dynamic> body) {
    final list = body['addressDTO'];
    final first = list is List && list.isNotEmpty ? ObdxApiUtils.asMap(list.first) : const <String, dynamic>{};
    return ChequeAddress.fromPostal(ObdxApiUtils.asMap(first['branchAddress'])['postalAddress']);
  }
}

/// One of the user's addresses (`me/party` → `party.addresses[]`), with its
/// type's description from `dda enumerations/addressType`.
class ChequePartyAddress {
  const ChequePartyAddress({required this.type, required this.description, required this.address});

  /// `type`, the Address Type value (e.g. PST).
  final String type;
  final String description;
  final ChequeAddress address;

  /// Only addresses with a `postalAddress` are offered (address.js:118-126).
  static List<ChequePartyAddress> listFrom(Map<String, dynamic> party, Map<String, dynamic> types) {
    final lookup = {
      for (final e in _enumData(types))
        if (_str(e['code']) case final code?) code: _str(e['description']) ?? code,
    };
    final raw = ObdxApiUtils.asMap(party['party'])['addresses'];
    if (raw is! List) return const [];
    return [
      for (final a in raw.whereType<Map>())
        if (a['postalAddress'] != null)
          if (_str(a['type']) case final type?)
            ChequePartyAddress(
              type: type,
              description: lookup[type] ?? type,
              address: ChequeAddress.fromPostal(a['postalAddress']),
            ),
    ];
  }

  /// OBDX first shows the address whose type description is "POSTAL"
  /// (address.js:131-133).
  static ChequePartyAddress? initial(List<ChequePartyAddress> list) =>
      list.where((a) => a.description == 'POSTAL').firstOrNull;
}

/// `POST dda demandDeposit/{accountId}/chequeBooks`. The body is what the
/// OBDX flow sends (card §4); the account goes in the path only.
class ChequeBookRequest {
  const ChequeBookRequest({
    required this.account,
    required this.type,
    required this.leaves,
    required this.delivery,
    required this.address,
    this.books,
    this.addressType,
    this.branchCode,
  });

  final ChequeAccount account;

  /// Null only when the bank sends no types (OBDX then hides the field and
  /// sends an empty list).
  final ChequeBookType? type;
  final int leaves;

  /// Number of Cheque Books, as typed; null when the bank hides the field.
  final String? books;
  final ChequeDelivery delivery;
  final ChequeAddress address;

  /// My Address only.
  final String? addressType;

  /// Branch Near Me only: the branch whose address is shown.
  final String? branchCode;

  Map<String, dynamic> toJson() => {
        // OBDX's option values are strings ("10").
        'noOfChequeLeaves': '$leaves',
        if (books != null) 'noOfChequeBooks': books!.trim(),
        // The current choice only (OBDX can collect one per change; card §4).
        'chequeBookTypeList': [if (type != null) type!.stock],
        'chequeDeliveryDetailsDTO': {
          'address': address.fields,
          'deliveryOption': delivery.code,
          if (delivery == ChequeDelivery.myAddress && addressType != null) 'addressType': addressType,
          if (delivery == ChequeDelivery.branch && branchCode != null) 'branchCode': branchCode,
        },
      };
}

/// Confirm's answer, or the OTP still to enter.
class ChequeBookOutcome implements ObdxOtpOutcome {
  const ChequeBookOutcome.done({this.reference, this.pendingApproval = false})
      : challenge = null,
        invalidOtp = false;

  const ChequeBookOutcome.otpRequired(ObdxChallenge this.challenge, {this.invalidOtp = false})
      : reference = null,
        pendingApproval = false;

  /// `chequeBookDTO.chequeBookRequestRefNo` (review.js:57).
  final String? reference;
  final bool pendingApproval;
  @override
  final ObdxChallenge? challenge;
  @override
  final bool invalidOtp;
}

List<Map<String, dynamic>> _enumData(Map<String, dynamic> body) {
  final reps = body['enumRepresentations'];
  if (reps is! List || reps.isEmpty) return const [];
  final data = ObdxApiUtils.asMap(reps.first)['data'];
  return data is List ? [for (final e in data.whereType<Map>()) ObdxApiUtils.asMap(e)] : const [];
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
