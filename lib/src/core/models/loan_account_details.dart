import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Full loan account details from
/// `GET /digx-common/loan/v1/loan/{id}?module=CON`.
class LoanAccountDetails {
  const LoanAccountDetails({
    required this.id,
    required this.displayNumber,
    this.status,
    this.productName,
    this.holderName,
    this.branchName,
    this.branchCode,
    this.openingDate,
    this.maturityDate,
    this.firstDisbursementDate,
    this.lastDisbursementDate,
    this.numberOfInstallment,
    this.interestRate,
    this.penaltyRate,
    this.repaymentMode,
    this.tenureMonths,
    this.tenureDays,
    this.approvedAmount,
    this.disbursedAmount,
    this.outstandingAmount,
    this.nextDueDate,
    this.nextInstallmentAmount,
    this.installmentPaidCount,
    this.installmentDueCount,
  });

  final String id;
  final String displayNumber;
  final String? status;
  final String? productName;

  /// Primary account holder's name. OBDX loan DTOs are inconsistent about
  /// where this lands, so we check every key seen across capture variants
  /// (`accountHolderName`, `customerName`, `primaryHolderName`, `partyName`,
  /// `holderName`) — `null` if the host doesn't return one for this loan.
  final String? holderName;
  final String? branchName;
  final String? branchCode;
  final DateTime? openingDate;
  final DateTime? maturityDate;
  final DateTime? firstDisbursementDate;
  final DateTime? lastDisbursementDate;
  final int? numberOfInstallment;
  final double? interestRate;
  final double? penaltyRate;
  final String? repaymentMode;
  final int? tenureMonths;
  final int? tenureDays;
  final MoneyAmount? approvedAmount;
  final MoneyAmount? disbursedAmount;
  final MoneyAmount? outstandingAmount;
  final DateTime? nextDueDate;
  final MoneyAmount? nextInstallmentAmount;
  final int? installmentPaidCount;
  final int? installmentDueCount;

  factory LoanAccountDetails.fromJson(Map<String, dynamic> json) {
    final idMap = ObdxApiUtils.asMap(json['id']);
    final id = (idMap['value'] ?? '').toString().trim();
    final display =
        (idMap['displayValue'] ?? id).toString().trim();
    final product = ObdxApiUtils.asMap(json['productDTO']);
    final branch = ObdxApiUtils.asMap(json['branchAddressDTO']);
    final schedule = ObdxApiUtils.asMap(json['loanScheduleDTO']);
    final tenure = ObdxApiUtils.asMap(json['tenure']);

    return LoanAccountDetails(
      id: id,
      displayNumber: display,
      status: json['status']?.toString(),
      productName: _firstNonEmpty([
        product['description'],
        product['name'],
      ]),
      holderName: _firstNonEmpty([
        json['accountHolderName'],
        json['customerName'],
        json['primaryHolderName'],
        json['partyName'],
        json['holderName'],
      ]),
      branchName: branch['branchName']?.toString(),
      branchCode: json['branchCode']?.toString(),
      openingDate: _parseDate(json['openingDate']),
      maturityDate: _parseDate(json['maturityDate']),
      firstDisbursementDate: _parseDate(json['firstDisbursementDate']),
      lastDisbursementDate: _parseDate(json['lastDisbursementDate']),
      numberOfInstallment: _parseInt(json['numberOfInstallment']),
      interestRate: _parseDouble(json['interestRate']),
      penaltyRate: _parseDouble(json['penaltyRate']),
      repaymentMode: json['repaymentMode']?.toString(),
      tenureMonths: _parseInt(tenure['months']),
      tenureDays: _parseInt(tenure['days']),
      approvedAmount: json['approvedAmount'] != null
          ? MoneyAmount.fromJson(json['approvedAmount'])
          : null,
      disbursedAmount: json['disbursedAmount'] != null
          ? MoneyAmount.fromJson(json['disbursedAmount'])
          : null,
      outstandingAmount: json['outstandingAmount'] != null
          ? MoneyAmount.fromJson(json['outstandingAmount'])
          : null,
      nextDueDate: _parseDate(schedule['nextDueDate']),
      nextInstallmentAmount: schedule['nextInstallmentAmount'] != null
          ? MoneyAmount.fromJson(schedule['nextInstallmentAmount'])
          : null,
      installmentPaidCount: _parseInt(schedule['installementPaidCount']),
      installmentDueCount: _parseInt(schedule['installementDueCount']),
    );
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

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

/// A single installment row from the loan repayment schedule.
class LoanScheduleItem {
  const LoanScheduleItem({
    required this.dueDate,
    required this.installmentAmount,
    required this.principal,
    required this.interest,
    this.paymentStatus,
  });

  final DateTime? dueDate;
  final MoneyAmount installmentAmount;
  final MoneyAmount principal;
  final MoneyAmount interest;
  final String? paymentStatus;

  bool get isPaid => (paymentStatus ?? '').toLowerCase() == 'paid';

  factory LoanScheduleItem.fromJson(Map<String, dynamic> json) {
    return LoanScheduleItem(
      dueDate: json['installmentDueDate'] != null
          ? DateTime.tryParse(json['installmentDueDate'].toString())
          : null,
      installmentAmount: MoneyAmount.fromJson(json['installmentAmount']),
      principal: MoneyAmount.fromJson(json['principal']),
      interest: MoneyAmount.fromJson(json['interest']),
      paymentStatus: json['paymentStatus']?.toString(),
    );
  }
}

/// Full repayment schedule from
/// `GET /digx-common/loan/v1/loan/{id}/schedule?module=CON`.
class LoanSchedule {
  const LoanSchedule({
    required this.items,
    this.amountDue,
    this.amountPaid,
    this.installmentPaidCount,
    this.installmentDueCount,
  });

  final List<LoanScheduleItem> items;
  final MoneyAmount? amountDue;
  final MoneyAmount? amountPaid;
  final int? installmentPaidCount;
  final int? installmentDueCount;

  bool get isEmpty => items.isEmpty;

  factory LoanSchedule.fromPayload(dynamic data) {
    final root = ObdxApiUtils.asMap(data);
    final dto = ObdxApiUtils.asMap(root['loanScheduleDTO']);
    final rawItems = dto['loanScheduleItemDTO'];
    final items = <LoanScheduleItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          items.add(LoanScheduleItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return LoanSchedule(
      items: items,
      amountDue: dto['amountDue'] != null
          ? MoneyAmount.fromJson(dto['amountDue'])
          : null,
      amountPaid: dto['amountPaid'] != null
          ? MoneyAmount.fromJson(dto['amountPaid'])
          : null,
      installmentPaidCount:
          LoanAccountDetails._parseInt(dto['installementPaidCount']),
      installmentDueCount:
          LoanAccountDetails._parseInt(dto['installementDueCount']),
    );
  }
}

/// Outstanding balance breakdown from
/// `GET /digx-common/loan/v1/loan/{id}/outstanding?module=CON`.
class LoanOutstanding {
  const LoanOutstanding({
    this.principalBalance,
    this.interestAmount,
    this.penaltyInterestAmount,
    this.outstandingAmount,
    this.installmentArrear,
    this.amountDue,
  });

  final MoneyAmount? principalBalance;
  final MoneyAmount? interestAmount;
  final MoneyAmount? penaltyInterestAmount;
  final MoneyAmount? outstandingAmount;
  final MoneyAmount? installmentArrear;
  final MoneyAmount? amountDue;

  factory LoanOutstanding.fromPayload(dynamic data) {
    final root = ObdxApiUtils.asMap(data);
    final dto = ObdxApiUtils.asMap(root['outStandingLoanDetailsDTO']);
    MoneyAmount? read(String key) =>
        dto[key] != null ? MoneyAmount.fromJson(dto[key]) : null;
    return LoanOutstanding(
      principalBalance: read('principalBalance'),
      interestAmount: read('interestAmount'),
      penaltyInterestAmount: read('penaltyInterestAmount'),
      outstandingAmount: read('outstandingAmount'),
      installmentArrear: read('installmentArrear'),
      amountDue: read('amountDue'),
    );
  }
}

/// A single disbursement record from
/// `GET /digx-common/loan/v1/loan/{id}/disbursements?module=CON`.
class LoanDisbursement {
  const LoanDisbursement({
    required this.amount,
    this.date,
    this.branchId,
  });

  final MoneyAmount amount;
  final DateTime? date;
  final String? branchId;

  factory LoanDisbursement.fromJson(Map<String, dynamic> json) {
    return LoanDisbursement(
      amount: MoneyAmount.fromJson(json['amount']),
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString())
          : null,
      branchId: json['branchId']?.toString(),
    );
  }

  static List<LoanDisbursement> listFromPayload(dynamic data) {
    final root = ObdxApiUtils.asMap(data);
    final rawList = root['loanDisbursementDetailsDTOs'];
    if (rawList is! List) return const [];
    final list = <LoanDisbursement>[];
    for (final item in rawList) {
      if (item is Map) {
        list.add(LoanDisbursement.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return list;
  }
}