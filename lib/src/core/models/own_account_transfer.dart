import 'package:http_status_code/http_status_code.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/models/obdx_challenge.dart';
import 'package:ubci_bank/src/infra/network/api_constants.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Credit currency option from `GET …/payments/currencies`.
class PaymentCurrencyOption {
  const PaymentCurrencyOption({
    required this.code,
    this.description,
    this.type,
  });

  final String code;
  final String? description;
  final String? type;

  factory PaymentCurrencyOption.fromJson(Map<String, dynamic> json) {
    return PaymentCurrencyOption(
      code: (json['code'] ?? json['currency'] ?? json['value'] ?? '')
          .toString()
          .trim(),
      description: json['description']?.toString(),
      type: json['type']?.toString(),
    );
  }
}

/// Payment network from `GET …/payments/fetchNetwork`.
class PaymentNetwork {
  const PaymentNetwork({
    required this.code,
    this.description,
    this.paymentType,
  });

  final String code;
  final String? description;
  final String? paymentType;

  factory PaymentNetwork.fromJson(Map<String, dynamic> json) {
    return PaymentNetwork(
      code: (json['code'] ??
              json['network'] ??
              json['networkCode'] ??
              json['value'] ??
              '')
          .toString()
          .trim(),
      description: (json['description'] ?? json['name'])?.toString(),
      paymentType: (json['paymentType'] ?? json['type'])?.toString(),
    );
  }

  static List<PaymentNetwork> listFromPayload(Map<String, dynamic> body) {
    final raw = body['networks'] ??
        body['paymentNetworks'] ??
        body['networkList'] ??
        body['items'] ??
        body['list'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => PaymentNetwork.fromJson(Map<String, dynamic>.from(e)))
        .where((n) => n.code.isNotEmpty)
        .toList();
  }
}

/// Bank value date from payments current-date API.
class PaymentCurrentDate {
  const PaymentCurrentDate({required this.valueDate});

  final DateTime valueDate;

  factory PaymentCurrentDate.fromPayload(Map<String, dynamic> body) {
    final current = ObdxApiUtils.asMap(body['currentDate']);
    final raw = (current['valueDate'] ?? body['valueDate'] ?? '').toString();
    final parsed = DateTime.tryParse(raw);
    return PaymentCurrentDate(valueDate: parsed ?? DateTime.now());
  }
}

/// Validate-only response from `POST …/pay/network` with `X-Validate-Only`.
class TransferValidationResult {
  const TransferValidationResult({
    required this.systemReferenceId,
    this.valueDate,
    this.referenceNumber,
    this.exchangeRate,
    this.sourceCurrency,
    this.targetCurrency,
    this.calculatedAmount,
    this.calculatedCurrency,
  });

  final String systemReferenceId;
  final DateTime? valueDate;
  final String? referenceNumber;
  final double? exchangeRate;
  final String? sourceCurrency;
  final String? targetCurrency;
  final double? calculatedAmount;
  final String? calculatedCurrency;

  factory TransferValidationResult.fromPayload(Map<String, dynamic> body) {
    final status = ObdxApiUtils.asMap(body['status']);
    final exchange = ObdxApiUtils.asMap(body['currencyExchange']);
    final instructed = ObdxApiUtils.asMap(exchange['instructedAmount']);

    double? parseAmount(dynamic raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw?.toString().replaceAll(',', '') ?? '');
    }

    final rateRaw = exchange['exchangeRate'] ?? body['exchangeRate'];
    final rate = rateRaw is num
        ? rateRaw.toDouble()
        : double.tryParse(rateRaw?.toString() ?? '');

    return TransferValidationResult(
      systemReferenceId: (body['systemReferenceId'] ?? '').toString(),
      valueDate: DateTime.tryParse((body['valueDate'] ?? '').toString()),
      referenceNumber: status['referenceNumber']?.toString(),
      exchangeRate: rate,
      sourceCurrency: exchange['sourceCurrency']?.toString(),
      targetCurrency: exchange['targetCurrency']?.toString(),
      calculatedAmount: parseAmount(instructed['amount'] ?? body['amount']),
      calculatedCurrency: instructed['currency']?.toString(),
    );
  }
}

/// Successful transfer submission.
class TransferSubmitResult {
  const TransferSubmitResult({
    required this.referenceNumber,
    this.externalReferenceNumber,
    this.valueDate,
    this.receiptAvailable = false,
  });

  final String referenceNumber;
  final String? externalReferenceNumber;
  final DateTime? valueDate;
  final bool receiptAvailable;

  factory TransferSubmitResult.fromPayload(Map<String, dynamic> body) {
    final status = ObdxApiUtils.asMap(body['status']);
    final statusRef = (status['referenceNumber'] ?? '').toString().trim();
    final external = status['externalReferenceNumber']?.toString().trim();
    final systemRef = (body['systemReferenceId'] ?? '').toString().trim();
    final reference = statusRef.isNotEmpty
        ? statusRef
        : ((external != null && external.isNotEmpty) ? external : systemRef);
    return TransferSubmitResult(
      referenceNumber: reference,
      externalReferenceNumber:
          (external != null && external.isNotEmpty) ? external : null,
      valueDate: DateTime.tryParse((body['valueDate'] ?? '').toString()),
      receiptAvailable: status['receiptAvailable'] == true,
    );
  }
}

/// Display snapshot for the confirmation screen (API result + form values).
class TransferConfirmationSnapshot {
  const TransferConfirmationSnapshot({
    required this.result,
    required this.toMask,
    required this.toMeta,
    required this.fromMask,
    required this.fromMeta,
    required this.payBy,
    required this.amountText,
    required this.whenText,
    required this.chargesMask,
    required this.chargesMeta,
    this.note = '',
  });

  final TransferSubmitResult result;
  final String toMask;
  final String toMeta;
  final String fromMask;
  final String fromMeta;
  final String payBy;
  final String amountText;
  final String whenText;
  final String chargesMask;
  final String chargesMeta;
  final String note;
}

/// Result of `POST …/pay/network` submit (success or OTP step-up).
class TransferSubmitOutcome {
  const TransferSubmitOutcome.success(this.result)
      : challenge = null,
        invalidOtp = false;

  const TransferSubmitOutcome.otpRequired(
    this.challenge, {
    this.invalidOtp = false,
  }) : result = null;

  final TransferSubmitResult? result;
  final ObdxChallenge? challenge;
  final bool invalidOtp;

  bool get requiresOtp => challenge != null && result == null;

  /// Parses a wrapped pay/network response. Returns `null` for hard failures.
  ///
  /// [otpSubmitted] is true when this call included `X-CHALLENGE_RESPONSE`.
  static TransferSubmitOutcome? tryParse({
    required int statusCode,
    required dynamic headers,
    required Map<String, dynamic> body,
    required bool otpSubmitted,
  }) {
    if (statusCode == StatusCode.OK &&
        ObdxApiUtils.isSuccessfulPayload(body)) {
      final parsed = TransferSubmitResult.fromPayload(body);
      if (parsed.referenceNumber.isEmpty) return null;
      return TransferSubmitOutcome.success(parsed);
    }

    if (statusCode != ApiConst.expectationFailed) return null;

    final challenge = ObdxChallenge.fromPaymentChallengeHeaders(headers);
    if (challenge != null) {
      return TransferSubmitOutcome.otpRequired(
        challenge,
        invalidOtp: otpSubmitted,
      );
    }
    return null;
  }
}

/// Payment charges from `GET …/payments/charges`.
class PaymentChargesSummary {
  const PaymentChargesSummary({
    this.totalAmount,
    this.currency,
    this.details = const [],
  });

  final double? totalAmount;
  final String? currency;
  final List<Map<String, dynamic>> details;

  factory PaymentChargesSummary.fromPayload(Map<String, dynamic> body) {
    double? amount;
    String? currency;

    void walk(dynamic node) {
      if (node is Map) {
        final map = Map<String, dynamic>.from(node);
        if (map.containsKey('totalChargeAmount')) {
          final charge = ObdxApiUtils.asMap(map['totalChargeAmount']);
          amount ??= charge['amount'] is num
              ? (charge['amount'] as num).toDouble()
              : double.tryParse(charge['amount']?.toString() ?? '');
          currency ??= charge['currency']?.toString();
        }
        for (final value in map.values) {
          if (value is Map || value is List) walk(value);
        }
      } else if (node is List) {
        for (final item in node) {
          walk(item);
        }
      }
    }

    walk(body);
    return PaymentChargesSummary(
      totalAmount: amount,
      currency: currency,
      details: const [],
    );
  }
}

/// Builds the OBDX self-transfer payment JSON body.
class OwnAccountTransferRequest {
  OwnAccountTransferRequest({
    required this.debitAccount,
    required this.creditAccount,
    required this.amount,
    required this.currency,
    required this.paymentDate,
    this.remarks,
    this.chargesFromDebitAccount = true,
    this.systemReferenceId,
    this.currencyExchange,
  });

  final CasaAccount debitAccount;
  final CasaAccount creditAccount;
  final double amount;
  final String currency;
  final DateTime paymentDate;
  final String? remarks;
  final bool chargesFromDebitAccount;
  final String? systemReferenceId;
  final Map<String, dynamic>? currencyExchange;

  String get accountType =>
      (debitAccount.accountType?.trim().isNotEmpty == true)
          ? debitAccount.accountType!.trim()
          : 'CSA';

  String _formatPaymentDate(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-${d}T00:00:00';
  }

  Map<String, dynamic> toJson() {
    final exchange = currencyExchange ??
        {
          'sourceCurrency': '',
          'targetCurrency': '',
          'exchangeRate': '',
          'instructedAmount': {},
        };

    final body = <String, dynamic>{
      'partyId': {},
      'amount': {
        'currency': currency,
        'amount': amount,
      },
      'remarks': remarks?.trim().isNotEmpty == true ? remarks!.trim() : null,
      'debitAccountId': {
        'displayValue': debitAccount.displayNumber,
        'value': debitAccount.id,
      },
      'adhocPayment': false,
      'accountType': accountType,
      'paymentType': 'SELF',
      'paymentDate': _formatPaymentDate(paymentDate),
      'charges': chargesFromDebitAccount ? 'O' : 'S',
      'chargesAccount': {},
      'network': 'SELF',
      'beneficiary': [
        {
          'creditAccount': {'value': creditAccount.id},
          'creditAccountId': creditAccount.displayNumber,
          'accountType': (creditAccount.accountType?.trim().isNotEmpty == true)
              ? creditAccount.accountType!.trim()
              : 'CSA',
        },
      ],
      'verificationPayeeReport': {},
      'currencyOfTransfer': null,
      'remittance': {
        'remittanceInformationStructured': [],
      },
      'otherDetails': {
        'line1': null,
        'line2': null,
        'line3': null,
        'line4': null,
      },
      'documentsList': [],
      'questionDTO': [],
      'currencyExchange': exchange,
      'paymentChargeDetails': [],
    };

    if (systemReferenceId != null && systemReferenceId!.trim().isNotEmpty) {
      body['systemReferenceId'] = systemReferenceId!.trim();
    }

    return body;
  }
}
