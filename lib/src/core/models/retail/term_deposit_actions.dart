import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/retail/term_deposit.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Requests and responses of the retail TD actions — top-up, redeem,
/// maturity edit and open — shaped as the OBDX web client builds them
/// (its `td-topup`, `td-redeem`, `td-amend` and `td-open` flows, bundled in
/// the TD capture). The capture's submits all failed on the UAT host, so
/// the success responses come from that client code, not from a capture.

String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty || s.toLowerCase() == 'null' ? null : s;
}

double? _dbl(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', ''));
}

MoneyAmount? _money(dynamic v) {
  final map = ObdxApiUtils.asMap(v is Map ? v : null);
  if (map.isEmpty || map['amount'] == null) return null;
  return MoneyAmount.fromJson(map);
}

Map<String, dynamic> _moneyJson(String? currency, double? amount) =>
    {'currency': currency, 'amount': amount};

/// OBDX task codes the TD flows filter accounts by.
abstract final class TdTask {
  static const open = 'TD_F_OTD';
  static const topUp = 'TD_F_TTD';
  static const redeem = 'TD_F_RTD';
  static const amend = 'TD_N_ATD';
}

/// A CASA account a TD flow pays from or into (`GET .../demandDeposit
/// ?taskCode=` → `accounts[]`), with what an own-account payout needs.
class TdPayAccount {
  const TdPayAccount({
    required this.id,
    required this.displayNumber,
    required this.currencyCode,
    this.balance,
    this.partyName,
    this.branchCode,
    this.holdingPattern,
    this.nickname,
  });

  final String id;
  final String displayNumber;
  final String currencyCode;
  final MoneyAmount? balance;
  final String? partyName;
  final String? branchCode;
  final String? holdingPattern;
  final String? nickname;

  String get lastFour {
    final digits = displayNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
  }

  factory TdPayAccount.fromJson(Map<String, dynamic> json) {
    final id = ObdxApiUtils.asMap(json['id']);
    final currency = _str(json['currencyCode']) ?? '';
    return TdPayAccount(
      id: _str(id['value']) ?? '',
      displayNumber: _str(id['displayValue']) ?? '',
      currencyCode: currency,
      balance: _money(json['availableBalance']),
      partyName: _str(json['partyName']) ?? _str(json['displayName']),
      branchCode: _str(json['branchCode']),
      holdingPattern: _str(json['holdingPattern']),
      nickname: _str(json['accountNickname']),
    );
  }

  /// The open flow skips wallets (`productDTO.productId == 'WALLET'`), as
  /// the web client does.
  static List<TdPayAccount> listFromPayload(dynamic data) {
    final root = ObdxApiUtils.asMap(data);
    final list = root['accounts'];
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map)
          if (ObdxApiUtils.asMap(item['productDTO'])['productId'] != 'WALLET')
            TdPayAccount.fromJson(Map<String, dynamic>.from(item)),
    ].where((a) => a.id.isNotEmpty).toList();
  }
}

/// A branch's name and postal address
/// (`GET .../locations/branches?branchCode=` → `addressDTO[0]`).
class TdBranch {
  const TdBranch({
    this.name,
    this.line1,
    this.line2,
    this.city,
    this.country,
  });

  final String? name;
  final String? line1;
  final String? line2;
  final String? city;
  final String? country;

  static TdBranch? fromPayload(dynamic data) {
    final root = ObdxApiUtils.asMap(data);
    final list = root['addressDTO'];
    if (list is! List || list.isEmpty) return null;
    final dto = ObdxApiUtils.asMap(list.first);
    final postal = ObdxApiUtils.asMap(
      ObdxApiUtils.asMap(dto['branchAddress'])['postalAddress'],
    );
    return TdBranch(
      name: _str(dto['branchName']),
      line1: _str(postal['line1']),
      line2: _str(postal['line2']),
      city: _str(postal['city']),
      country: _str(postal['country']),
    );
  }

  Map<String, dynamic> toAddressJson() =>
      {'line1': line1, 'line2': line2, 'city': city, 'country': country};
}

/// Where money goes: OBDX payout options `O` (one of the customer's own
/// accounts) and `I` (another account at this bank, by number). Domestic
/// (`E`) and international (`INT`) payouts need the payments clearing
/// lookups and are not offered.
enum TdPayoutType {
  own('O'),
  internal('I');

  const TdPayoutType(this.code);

  final String code;
}

/// One payout instruction being entered.
class TdPayout {
  const TdPayout.own({required TdPayAccount this.account, this.branch})
      : type = TdPayoutType.own,
        accountNumber = null;

  const TdPayout.internal({required String this.accountNumber})
      : type = TdPayoutType.internal,
        account = null,
        branch = null;

  final TdPayoutType type;
  final TdPayAccount? account;
  final TdBranch? branch;
  final String? accountNumber;

  /// For review screens.
  String get label => switch (type) {
        TdPayoutType.own => account!.displayNumber,
        TdPayoutType.internal => accountNumber!,
      };

  /// The web client's payout instruction. [componentType] is `P` principal
  /// or `I` interest (null for redemptions); an internal payout sends no
  /// address.
  Map<String, dynamic> toJson({String? componentType}) {
    final own = type == TdPayoutType.own;
    return {
      'accountId': {
        'displayValue': own ? account!.displayNumber : null,
        'value': own ? account!.id : null,
      },
      'account': own ? '' : accountNumber,
      'branchId': own ? account!.branchCode : null,
      'id': null,
      'percentage': 100,
      'type': type.code,
      'beneficiaryName': own ? account!.partyName : null,
      'bankName': own ? branch?.name : null,
      'address': own ? (branch ?? const TdBranch()).toAddressJson() : null,
      'clearingCode': '',
      'networkType': null,
      'payoutComponentType': componentType,
    };
  }
}

// ── Top-up ───────────────────────────────────────────────────────────────

/// The top-up simulation's answer (`topUpDetail`). The confirm sends this
/// object back unchanged, as the web client does.
class TdTopUpQuote {
  const TdTopUpQuote({
    required this.raw,
    this.revisedPrincipal,
    this.revisedMaturity,
    this.revisedInterestRate,
  });

  final Map<String, dynamic> raw;
  final MoneyAmount? revisedPrincipal;
  final MoneyAmount? revisedMaturity;
  final double? revisedInterestRate;

  /// [request] is what was simulated — kept as the confirm body if the
  /// host answers without a `topUpDetail`.
  factory TdTopUpQuote.fromPayload(
    dynamic data, {
    required Map<String, dynamic> request,
  }) {
    final root = ObdxApiUtils.asMap(data);
    final dto = ObdxApiUtils.asMap(root['topUpDetail']);
    final raw = dto.isEmpty ? request : dto;
    return TdTopUpQuote(
      raw: raw,
      // OBDX spells it `revisedPricipal`.
      revisedPrincipal:
          _money(raw['revisedPricipal']) ?? _money(raw['revisedPrincipal']),
      revisedMaturity: _money(raw['revisedMaturity']) ??
          _money(raw['revisedMaturityAmount']),
      revisedInterestRate: _dbl(raw['revisedInterestRate']),
    );
  }

  /// The simulation body.
  static Map<String, dynamic> request({
    required TermDeposit deposit,
    required double amount,
    required TdPayAccount source,
  }) =>
      {
        'amount': _moneyJson(deposit.currencyCode, amount),
        'sourceAccountId': {
          'value': source.id,
          'displayValue': source.displayNumber,
        },
        'account': {
          'displayValue': deposit.displayNumber,
          'value': deposit.id,
        },
        'currentPrincipal': _moneyJson(
          deposit.currencyCode,
          deposit.availableBalance?.amount ?? deposit.currentValue?.amount,
        ),
      };
}

// ── Redeem ───────────────────────────────────────────────────────────────

/// `F` full or `P` partial redemption.
enum TdRedemptionType {
  full('F'),
  partial('P');

  const TdRedemptionType(this.code);

  final String code;
}

/// The redemption quote (`POST .../penalities` → `redemptionDetailDTO`).
class TdRedemptionQuote {
  const TdRedemptionQuote({
    this.charges,
    this.maturityAmount,
    this.netCredit,
    this.revisedPrincipal,
    this.revisedMaturity,
    this.revisedInterestRate,
  });

  /// Charges / penalty for redeeming early.
  final MoneyAmount? charges;
  final MoneyAmount? maturityAmount;

  /// What reaches the payout account.
  final MoneyAmount? netCredit;
  final MoneyAmount? revisedPrincipal;
  final MoneyAmount? revisedMaturity;
  final double? revisedInterestRate;

  factory TdRedemptionQuote.fromPayload(dynamic data) {
    final root = ObdxApiUtils.asMap(data);
    final dto = ObdxApiUtils.asMap(root['redemptionDetailDTO']);
    return TdRedemptionQuote(
      charges: _money(dto['charges']),
      maturityAmount: _money(dto['maturityAmount']),
      netCredit: _money(dto['netCreditAmt']),
      revisedPrincipal: _money(dto['revisedPrincipalAmount']),
      revisedMaturity: _money(dto['revisedMaturityAmount']),
      revisedInterestRate: _dbl(dto['revisedInterestRate']),
    );
  }
}

/// The redeem body, for both the quote and the redemption itself.
class TdRedeemRequest {
  const TdRedeemRequest({
    required this.deposit,
    required this.type,
    required this.amount,
    required this.payout,
  });

  final TermDeposit deposit;
  final TdRedemptionType type;

  /// The amount to redeem — the current principal for a full redemption.
  final double amount;
  final TdPayout? payout;

  /// [quote] fills the amounts the redemption needs (the host rejects it
  /// without them — the capture's "This Field is Mandatory" errors).
  Map<String, dynamic> toJson({TdRedemptionQuote? quote}) {
    final ccy = deposit.currencyCode;
    Map<String, dynamic> m(MoneyAmount? v) =>
        _moneyJson(v == null ? null : (v.currency ?? ccy), v?.amount);
    return {
      'redemptionId': null,
      'partyId': null,
      'module': deposit.module,
      'accountId': {
        'displayValue': deposit.displayNumber,
        'value': deposit.id,
      },
      'date': null,
      'maturityAmount': m(quote?.maturityAmount),
      'netCreditAmt': m(quote?.netCredit),
      'charges': m(quote?.charges),
      'redemptionAmount': _moneyJson(ccy, amount),
      'revisedPrincipalAmount': m(quote?.revisedPrincipal),
      'revisedMaturityAmount': m(quote?.revisedMaturity),
      'revisedInterestRate': quote?.revisedInterestRate ?? 0,
      'typeRedemption': type.code,
      'payoutInstructions': [
        if (payout != null) payout!.toJson(),
      ],
    };
  }
}

// ── Maturity instructions ────────────────────────────────────────────────

/// The maturity-instruction edit (`PUT .../deposit/{id}`). Which payout
/// goes with which roll-over follows the web client: close (`A`) pays the
/// principal (`P`), renew-principal (`P`) pays the interest (`I`), renew
/// a special amount (`S`) pays the rest (`P`) and sends the amount, and
/// renew-all (`I`) pays nothing out.
class TdMaturityUpdate {
  const TdMaturityUpdate({
    required this.deposit,
    required this.rollOverType,
    this.payout,
    this.rollOverAmount,
  });

  final TermDeposit deposit;
  final String rollOverType;
  final TdPayout? payout;

  /// Only for `S`.
  final double? rollOverAmount;

  static String? componentFor(String rollOverType) => switch (rollOverType) {
        TdRollOver.closeOnMaturity => 'P',
        TdRollOver.renewPrincipal => 'I',
        TdRollOver.renewSpecialAmount => 'P',
        _ => null,
      };

  Map<String, dynamic> toJson() => {
        'id': {'displayValue': deposit.displayNumber, 'value': deposit.id},
        'rollOverType': rollOverType,
        'module': deposit.module,
        if (TdRollOver.needsPayout(rollOverType) && payout != null)
          'payoutInstructions': [
            payout!.toJson(componentType: componentFor(rollOverType)),
          ],
        if (rollOverType == TdRollOver.renewSpecialAmount)
          'rollOverAmount': _moneyJson(deposit.currencyCode, rollOverAmount),
      };
}

// ── Open ─────────────────────────────────────────────────────────────────

/// One currency's deposit limits on a product (`amountParameters[]`).
class TdAmountLimit {
  const TdAmountLimit({required this.currency, this.min, this.max});

  final String currency;
  final double? min;
  final double? max;
}

/// A TD product (`GET .../termDepositProducts` → `tdProductDTOList[]`).
class TdProduct {
  const TdProduct({
    required this.id,
    required this.name,
    this.module,
    this.accrualFrequency,
    this.discounted = false,
    this.minTenure,
    this.maxTenure,
    this.limits = const [],
  });

  final String id;
  final String name;
  final String? module;
  final String? accrualFrequency;

  /// Discounted products (`paymentType: 'D'`) pay interest up front, so
  /// they cannot renew interest (`I`) or a special amount (`S`).
  final bool discounted;
  final TdTenure? minTenure;
  final TdTenure? maxTenure;
  final List<TdAmountLimit> limits;

  List<String> get currencies => [for (final l in limits) l.currency];

  TdAmountLimit? limitFor(String currency) {
    for (final l in limits) {
      if (l.currency == currency) return l;
    }
    return null;
  }

  factory TdProduct.fromJson(Map<String, dynamic> json) {
    final tenure = ObdxApiUtils.asMap(json['tenureParameter']);
    TdTenure? t(dynamic v) => v is Map ? TdTenure.fromJson(v) : null;
    return TdProduct(
      id: _str(json['productId']) ?? _str(json['id']) ?? '',
      name: _str(json['name']) ?? _str(json['productId']) ?? '',
      module: _str(json['module']),
      accrualFrequency: _str(json['accrualFrequency']),
      discounted: _str(json['paymentType']) == 'D',
      minTenure: t(tenure['minTenure']),
      maxTenure: t(tenure['maxTenure']),
      limits: [
        for (final p in (json['amountParameters'] is List
            ? json['amountParameters'] as List
            : const []))
          if (p is Map)
            if (_str(p['currency']) case final currency?)
              TdAmountLimit(
                currency: currency,
                min: _money(p['minAmount'])?.amount,
                max: _money(p['maxAmount'])?.amount,
              ),
      ],
    );
  }

  static List<TdProduct> listFromPayload(dynamic data) {
    final root = ObdxApiUtils.asMap(data);
    final list = root['tdProductDTOList'];
    if (list is! List) return const [];
    return [
      for (final item in list)
        if (item is Map) TdProduct.fromJson(Map<String, dynamic>.from(item)),
    ].where((p) => p.id.isNotEmpty).toList();
  }
}

/// The open-deposit body (the web client's `createTDData`).
class TdOpenRequest {
  const TdOpenRequest({
    required this.product,
    required this.source,
    required this.currency,
    required this.amount,
    required this.tenure,
    required this.rollOverType,
    required this.holderName,
    this.payout,
    this.rollOverAmount,
  });

  final TdProduct product;
  final TdPayAccount source;
  final String currency;
  final double amount;
  final TdTenure tenure;
  final String rollOverType;
  final String holderName;
  final TdPayout? payout;
  final double? rollOverAmount;

  Map<String, dynamic> toJson() => {
        'partyName': holderName,
        'module': product.module ?? 'CON',
        'partyId': null,
        'holdingPattern': 'SINGLE',
        'productDTO': {
          'productId': product.id,
          'name': product.name,
          'depositProductModule': 'TD',
          'accrualFrequency': product.accrualFrequency,
        },
        'parties': const [],
        'maturityDate': null,
        'principalAmount': _moneyJson(currency, amount),
        'tenure': tenure.toJson(),
        if (TdRollOver.needsPayout(rollOverType) && payout != null)
          'payoutInstructions': [
            payout!.toJson(
              componentType: TdMaturityUpdate.componentFor(rollOverType),
            ),
          ],
        'payInInstruction': [
          {
            'accountId': {
              'displayValue': source.displayNumber,
              'value': source.id,
            },
            'branchId': null,
            'percentage': 100,
          },
        ],
        'rollOverType': rollOverType,
        if (rollOverType == TdRollOver.renewSpecialAmount)
          'rollOverAmount': _moneyJson(currency, rollOverAmount),
        'nomineeDTO': null,
      };
}

/// What the validate-only open answers (`termDepositDetails`).
class TdOpenQuote {
  const TdOpenQuote({
    this.interestRate,
    this.maturityDate,
    this.maturityAmount,
  });

  final double? interestRate;
  final DateTime? maturityDate;
  final MoneyAmount? maturityAmount;

  factory TdOpenQuote.fromPayload(dynamic data) {
    final dto = ObdxApiUtils.asMap(
      ObdxApiUtils.asMap(data)['termDepositDetails'],
    );
    return TdOpenQuote(
      interestRate: _dbl(dto['interestRate']),
      maturityDate: DateTime.tryParse(_str(dto['maturityDate']) ?? ''),
      maturityAmount: _money(dto['maturityAmount']),
    );
  }
}

// ── Submit outcome ───────────────────────────────────────────────────────

/// A confirmed TD action: done, or waiting for the OTP OBDX asked for.
sealed class TdSubmitOutcome {
  const TdSubmitOutcome();
}

class TdSubmitted extends TdSubmitOutcome {
  const TdSubmitted({this.reference, this.newDepositNumber});

  /// The host / OBDX reference to show the customer.
  final String? reference;

  /// The new deposit's number, after an open.
  final String? newDepositNumber;

  /// Reads the reference each flow's web client shows: `hostReference`
  /// (open, maturity edit), `topUpDetail.topUpReferenceNumber` (top-up),
  /// `redemptionDetail[0].redeemReferenceNo` (redeem), then OBDX's own
  /// `status.referenceNumber`.
  factory TdSubmitted.fromPayload(dynamic data) {
    final root = ObdxApiUtils.asMap(data);
    final topUp = ObdxApiUtils.asMap(root['topUpDetail']);
    final redemptions = root['redemptionDetail'];
    final redemption = redemptions is List && redemptions.isNotEmpty
        ? ObdxApiUtils.asMap(redemptions.first)
        : ObdxApiUtils.asMap(redemptions);
    final status = ObdxApiUtils.asMap(root['status']);
    final details = ObdxApiUtils.asMap(root['termDepositDetails']);
    return TdSubmitted(
      reference: _str(root['hostReference']) ??
          _str(topUp['topUpReferenceNumber']) ??
          _str(redemption['redeemReferenceNo']) ??
          _str(status['referenceNumber']),
      newDepositNumber: _str(ObdxApiUtils.asMap(details['id'])['displayValue']),
    );
  }
}

class TdNeedsOtp extends TdSubmitOutcome {
  const TdNeedsOtp(this.challenge);

  final ObdxChallenge challenge;
}
