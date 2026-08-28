/// Account type option from OBDX enumerations API.
class AccountTypeOption {
  const AccountTypeOption({
    required this.code,
    required this.label,
    this.ordinal,
  });

  final String code;
  final String label;
  final int? ordinal;

  factory AccountTypeOption.fromJson(Map<String, dynamic> json) {
    final code = (json['code'] ??
            json['value'] ??
            json['id'] ??
            json['enumCode'] ??
            '')
        .toString();
    final label = (json['description'] ??
            json['label'] ??
            json['name'] ??
            json['displayValue'] ??
            code)
        .toString();
    final ordinalRaw = json['ordinal'];
    final ordinal = ordinalRaw is int
        ? ordinalRaw
        : int.tryParse(ordinalRaw?.toString() ?? '');
    return AccountTypeOption(code: code, label: label, ordinal: ordinal);
  }

  /// Parses OBDX payloads such as:
  /// `{ "enumRepresentations": [ { "data": [ { "code": "CSA", ... } ] } ] }`
  /// and flat lists under common enumeration keys.
  static List<AccountTypeOption> listFromPayload(dynamic data) {
    if (data is! Map) return const [];

    for (final key in [
      'enumRepresentations',
      'accountTypes',
      'enumerationDTOs',
      'items',
    ]) {
      final list = data[key];
      if (list is! List || list.isEmpty) continue;

      final options = <AccountTypeOption>[];
      for (final entry in list) {
        if (entry is! Map) continue;
        final map = Map<String, dynamic>.from(entry);

        // Live OBDX: enumRepresentations[].data[] holds the enum items.
        final nested = map['data'] ?? map['enumRepresentations'] ?? map['items'];
        if (nested is List) {
          for (final item in nested) {
            if (item is! Map) continue;
            final option =
                AccountTypeOption.fromJson(Map<String, dynamic>.from(item));
            if (option.code.isNotEmpty) options.add(option);
          }
          continue;
        }

        final option = AccountTypeOption.fromJson(map);
        if (option.code.isNotEmpty) options.add(option);
      }

      if (options.isNotEmpty) {
        options.sort((a, b) {
          final ao = a.ordinal ?? 1 << 30;
          final bo = b.ordinal ?? 1 << 30;
          return ao.compareTo(bo);
        });
        return options;
      }
    }

    final status = data['status'];
    if (status is Map) {
      return listFromPayload(status);
    }
    return const [];
  }
}
