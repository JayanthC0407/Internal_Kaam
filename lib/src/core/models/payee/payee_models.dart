class PayeeAccountTypeOption {
  const PayeeAccountTypeOption({
    required this.code,
    required this.value,
    required this.description,
    this.ordinal,
  });

  final String code;
  final String value;
  final String description;
  final int? ordinal;

  factory PayeeAccountTypeOption.fromMap(Map<String, dynamic> map) {
    return PayeeAccountTypeOption(
      code: map['code']?.toString() ?? '',
      value: map['value']?.toString() ?? '',
      description: map['description']?.toString().trim() ?? '',
      ordinal: map['ordinal'] is num ? (map['ordinal'] as num).toInt() : null,
    );
  }
}

class DomesticNetworkOption {
  const DomesticNetworkOption({
    required this.code,
    required this.description,
    required this.taskCode,
    required this.hostNetworkCode,
    required this.enabled,
  });

  final String code;
  final String description;
  final String taskCode;
  final String hostNetworkCode;
  final bool enabled;

  factory DomesticNetworkOption.fromMap(Map<String, dynamic> map) {
    final hosts = map['networkHost'];
    final firstHost = hosts is List && hosts.isNotEmpty && hosts.first is Map
        ? Map<String, dynamic>.from(hosts.first as Map)
        : <String, dynamic>{};

    return DomesticNetworkOption(
      code: map['code']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      taskCode: map['taskCode']?.toString() ?? '',
      hostNetworkCode: firstHost['hostNetworkCode']?.toString() ?? '',
      enabled: firstHost['enabled']?.toString().toUpperCase() != 'N',
    );
  }
}

class PayeeSummary {
  const PayeeSummary({
    required this.nickname,
    required this.accountType,
    required this.accountDetails,
    this.accountNumber,
    this.payeeType,
    this.raw = const {},
  });

  final String nickname;
  final String accountType;
  final String accountDetails;
  final String? accountNumber;
  final String? payeeType;
  final Map<String, dynamic> raw;

  factory PayeeSummary.fromMap(Map<String, dynamic> source) {
    final nested = source['payee'] is Map
        ? Map<String, dynamic>.from(source['payee'] as Map)
        : <String, dynamic>{};
    final map = {...nested, ...source};

    return PayeeSummary(
      nickname: _firstString(map, const [
            'nickName',
            'nickname',
            'payeeNickname',
            'payeeNickName',
          ]) ??
          '—',
      accountType: _firstString(map, const [
            'accountType',
            'payeeAccountType',
            'type',
          ]) ??
          'Account',
      accountDetails: _firstString(map, const [
            'accountDetails',
            'accountDetail',
            'payeeDetails',
            'bankName',
          ]) ??
          '—',
      accountNumber: _firstString(map, const [
        'accountNumber',
        'accountNo',
      ]),
      payeeType: _firstString(map, const [
        'payeeType',
        'type',
      ]),
      raw: Map<String, dynamic>.from(map),
    );
  }

  static String? _firstString(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') return value;
    }
    return null;
  }
}
