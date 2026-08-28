import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Full CASA demand-deposit detail from
/// `GET /digx-common/dda/v1/demandDeposit/{accountId}`.
///
/// Live OBDX wraps the account in `demandDepositAccountDTO`.
class CasaAccountDetail {
  const CasaAccountDetail({
    required this.account,
    this.todaysOpeningBalance,
    this.amountOnHold,
    this.underClearingFunds,
    this.advanceAgainstUnclearFunds,
    this.overdraftLimit,
    this.sweepInAmount,
    this.holdingPattern,
    this.primaryAccountHolder,
    this.nominee,
    this.branch,
    this.nomineeRegistered,
  });

  final CasaAccount account;
  final MoneyAmount? todaysOpeningBalance;
  final MoneyAmount? amountOnHold;
  final MoneyAmount? underClearingFunds;
  final MoneyAmount? advanceAgainstUnclearFunds;
  final MoneyAmount? overdraftLimit;
  final MoneyAmount? sweepInAmount;
  final String? holdingPattern;
  final String? primaryAccountHolder;
  final String? nominee;
  final String? branch;

  /// When true/false from API; null if unknown.
  final bool? nomineeRegistered;

  String get id => account.id;
  String get displayNumber => account.displayNumber;
  String get currencyCode => account.currencyCode;
  String? get productName => account.productName;
  String? get nickname => account.nickname;
  MoneyAmount? get availableBalance => account.availableBalance;
  MoneyAmount? get currentBalance => account.currentBalance;
  MoneyAmount? get displayBalance => account.displayBalance;

  String get nicknameOrDefault {
    final nick = nickname?.trim();
    if (nick != null && nick.isNotEmpty) return nick;
    return '';
  }

  factory CasaAccountDetail.fromJson(Map<String, dynamic> json) {
    // Prefer product/dda type over generic CSA `type` code for display title.
    final normalized = Map<String, dynamic>.from(json);
    if ((normalized['accountType'] == null ||
            normalized['accountType'].toString().trim().isEmpty) &&
        normalized['ddaAccountType'] != null) {
      normalized['accountType'] = normalized['ddaAccountType'];
    }

    final currencyCode = (normalized['currencyCode'] ??
            normalized['currency'] ??
            ObdxApiUtils.asMap(normalized['availableBalance'])['currency'] ??
            ObdxApiUtils.asMap(normalized['availableBalance'])['currencyCode'] ??
            '')
        .toString()
        .trim();

    final party = ObdxApiUtils.asMap(
      normalized['partyDTO'] ??
          normalized['party'] ??
          normalized['accountHolder'],
    );
    final branchMap = ObdxApiUtils.asMap(
      normalized['branchAddressDTO'] ??
          normalized['branchDTO'] ??
          normalized['branch'] ??
          normalized['branchDetails'],
    );
    final nomineeMap =
        ObdxApiUtils.asMap(normalized['nomineeDTO'] ?? normalized['nominee']);

    Map<String, dynamic> postal = {};
    final branchAddressRaw = branchMap['branchAddress'];
    if (branchAddressRaw is Map) {
      final branchAddress = Map<String, dynamic>.from(branchAddressRaw);
      final nestedPostal = branchAddress['postalAddress'];
      if (nestedPostal is Map) {
        postal = Map<String, dynamic>.from(nestedPostal);
      }
    } else if (branchMap['postalAddress'] is Map) {
      postal = Map<String, dynamic>.from(branchMap['postalAddress'] as Map);
    } else if (branchMap['address'] is Map) {
      postal = Map<String, dynamic>.from(branchMap['address'] as Map);
    }

    final composedName = [
      party['firstName'],
      party['lastName'],
    ]
        .whereType<Object>()
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .join(' ');
    final holder = _firstNonEmpty([
      normalized['partyName'],
      normalized['primaryAccountHolder'],
      normalized['accountHolderName'],
      party['displayName'],
      party['partyName'],
      party['name'],
      composedName,
    ]);

    final addressLines = [
      postal['line1'],
      postal['line2'],
      postal['line3'],
      postal['city'],
      postal['state'],
      postal['country'],
    ]
        .whereType<Object>()
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final branchName = _firstNonEmpty([
      branchMap['branchName'],
      branchMap['name'],
      normalized['branchName'],
    ]);
    final flatAddress = _firstNonEmpty([
      branchMap['address'],
      branchMap['branchAddress'] is String ? branchMap['branchAddress'] : null,
      normalized['branchAddress'],
    ]);

    final branchParts = <String>[
      if (branchName != null) branchName,
      if (addressLines.isNotEmpty) addressLines.join(', '),
      if (addressLines.isEmpty && flatAddress != null) flatAddress,
    ];

    final nomineeText = _firstNonEmpty([
      normalized['nomineeName'],
      nomineeMap['name'],
      nomineeMap['displayName'],
      nomineeMap['nomineeName'],
    ]);

    bool? nomineeRegistered;
    final nomineeFlag = normalized['nomineeRegistered'];
    if (nomineeFlag is bool) {
      nomineeRegistered = nomineeFlag;
    } else if (nomineeFlag != null) {
      final text = nomineeFlag.toString().trim().toLowerCase();
      if (text == 'true' || text == 'y' || text == 'yes') {
        nomineeRegistered = true;
      } else if (text == 'false' || text == 'n' || text == 'no') {
        nomineeRegistered = false;
      }
    }

    final overdraftNested = ObdxApiUtils.asMap(normalized['overDraftLimit']);
    final overdraft = CasaAccount.readBalance(
          normalized,
          const [
            'overdraftLimit',
            'odLimit',
          ],
          currencyCode,
        ) ??
        CasaAccount.readBalance(
          overdraftNested,
          const [
            'sanctionedLimitAmount',
            'amount',
            'availableLimit',
            'limitAmount',
          ],
          currencyCode,
        );

    return CasaAccountDetail(
      account: CasaAccount.fromJson(normalized),
      todaysOpeningBalance: CasaAccount.readBalance(
        normalized,
        const [
          'todaysOpeningBalance',
          'todayOpeningBalance',
          'openingBalance',
          'openingBal',
          'bookBalance',
        ],
        currencyCode,
      ),
      amountOnHold: CasaAccount.readBalance(
        normalized,
        const [
          'holdAmount',
          'amountOnHold',
          'fundsOnHold',
          'lienAmount',
        ],
        currencyCode,
      ),
      underClearingFunds: CasaAccount.readBalance(
        normalized,
        const [
          'unclearFund',
          'unclearFunds',
          'underClearingFunds',
          'fundsUnderClearing',
          'unclearedFunds',
        ],
        currencyCode,
      ),
      advanceAgainstUnclearFunds: CasaAccount.readBalance(
        normalized,
        const [
          'fundsAdvanceLimit',
          'advanceAgainstUnclearFunds',
          'advanceAgainstUnclearFundsLimit',
          'aaufLimit',
        ],
        currencyCode,
      ),
      overdraftLimit: overdraft,
      sweepInAmount: CasaAccount.readBalance(
        normalized,
        const [
          'sweepInLienAmount',
          'sweepInAmount',
          'sweepinAmount',
          'sweepIn',
        ],
        currencyCode,
      ),
      holdingPattern: _firstNonEmpty([
        normalized['holdingPattern'],
        normalized['ownershipType'],
        ObdxApiUtils.asMap(normalized['holdingPatternDTO'])['description'],
        ObdxApiUtils.asMap(normalized['holdingPatternDTO'])['code'],
      ]),
      primaryAccountHolder: holder,
      nominee: nomineeText,
      nomineeRegistered: nomineeRegistered,
      branch: branchParts.isEmpty ? null : branchParts.join(', '),
    );
  }

  /// Parses detail payload (raw body or `{ demandDepositAccountDTO: {} }`).
  static CasaAccountDetail? fromPayload(dynamic data) {
    final root = _unwrap(data);
    if (root == null) return null;
    if (root['id'] != null ||
        root['accountId'] != null ||
        root['availableBalance'] != null ||
        root['currencyCode'] != null ||
        root['partyName'] != null) {
      return CasaAccountDetail.fromJson(root);
    }
    final accounts = root['accounts'] ?? root['demandDepositAccounts'];
    if (accounts is List && accounts.isNotEmpty && accounts.first is Map) {
      return CasaAccountDetail.fromJson(
        Map<String, dynamic>.from(accounts.first as Map),
      );
    }
    return null;
  }

  static Map<String, dynamic>? _unwrap(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);

    for (final key in const [
      'demandDepositAccountDTO',
      'demandDepositAccount',
      'demandDeposit',
      'account',
      'body',
    ]) {
      final nested = map[key];
      if (nested is Map) {
        final unwrapped = _unwrap(nested);
        if (unwrapped != null) return unwrapped;
      }
    }

    if (map.containsKey('id') ||
        map.containsKey('availableBalance') ||
        map.containsKey('currencyCode') ||
        map.containsKey('partyName')) {
      return map;
    }

    return map;
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }
}
