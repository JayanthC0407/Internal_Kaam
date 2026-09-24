/// A cash-management pickup / delivery point, from
/// `GET /digx-cms/cms/v1/cashmanagement/collections/maintenances/pickupAndDeliveryPoints`
/// (Home widgets capture, entry #45).
///
/// digx-ui requests these twice — once per collection type (`CASH`,
/// `PAPERBASE`) — and merges the results, which is what
/// `CorpCashManagementRepository.fetchPickupPoints` reproduces.
class CorpPickupPoint {
  const CorpPickupPoint({
    required this.code,
    this.collectionType,
    this.serviceType,
    this.locationCode,
    this.description,
    this.locationDescription,
    this.status,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    this.address,
    this.country,
    this.frequency,
    this.dayOfWeek,
    this.scheduleType,
  });

  final String code;

  /// `CASH` / `PAPERBASE` — which request this row came back from. The
  /// payload itself does not carry it, so the repository tags each row.
  final String? collectionType;

  final String? serviceType;
  final String? locationCode;
  final String? description;
  final String? locationDescription;
  final String? status;

  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;
  final String? address;
  final String? country;

  /// `scheduleDetails.frequency`, e.g. `Daily`.
  final String? frequency;

  /// `scheduleDetails.dayOfWeek`, e.g. `Monday`.
  final String? dayOfWeek;

  /// `scheduleDetails.type`, e.g. `Adhoc/On Call`.
  final String? scheduleType;

  /// Best available label for the point.
  String get title {
    final location = locationDescription?.trim();
    if (location != null && location.isNotEmpty) return location;
    final desc = description?.trim();
    if (desc != null && desc.isNotEmpty) return desc;
    return code;
  }

  /// One-line schedule summary, or null when the host sent nothing usable.
  String? get scheduleSummary {
    final parts = <String>[];
    final freq = frequency?.trim();
    if (freq != null && freq.isNotEmpty) parts.add(freq);
    final day = dayOfWeek?.trim();
    if (day != null && day.isNotEmpty) parts.add(day);
    final type = scheduleType?.trim();
    if (type != null && type.isNotEmpty) parts.add(type);
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  /// Single-line address assembled from the contact block.
  String? get addressSummary {
    final line = address?.trim();
    final countryName = country?.trim();
    if ((line == null || line.isEmpty) &&
        (countryName == null || countryName.isEmpty)) {
      return null;
    }
    return [
      if (line != null && line.isNotEmpty) line,
      if (countryName != null && countryName.isNotEmpty) countryName,
    ].join(', ');
  }

  factory CorpPickupPoint.fromJson(
    Map<String, dynamic> json, {
    String? collectionType,
  }) {
    final contact = json['contactDetails'];
    final contactMap =
        contact is Map ? Map<String, dynamic>.from(contact) : const {};
    final schedule = json['scheduleDetails'];
    final scheduleMap =
        schedule is Map ? Map<String, dynamic>.from(schedule) : const {};

    return CorpPickupPoint(
      code: (json['code'] ?? '').toString().trim(),
      collectionType: collectionType,
      serviceType: _trimmed(json['serviceType']),
      locationCode: _trimmed(json['locationCode']),
      description: _trimmed(json['description']),
      locationDescription: _trimmed(json['locationDescription']),
      status: _trimmed(json['status']),
      contactName: _trimmed(contactMap['name']),
      contactPhone: _trimmed(contactMap['phoneNumber']),
      contactEmail: _trimmed(contactMap['email']),
      address: _trimmed(contactMap['address1']) ?? _trimmed(contactMap['address']),
      country: _trimmed(contactMap['country']),
      frequency: _trimmed(scheduleMap['frequency']),
      dayOfWeek: _trimmed(scheduleMap['dayOfWeek']),
      scheduleType: _trimmed(scheduleMap['type']),
    );
  }

  static List<CorpPickupPoint> listFromPayload(
    dynamic data, {
    String? collectionType,
  }) {
    final root = _unwrap(data);
    if (root == null) return const [];
    final raw = root['pointDetails'] ?? root['points'] ?? root['items'];
    if (raw is! List) return const [];

    final parsed = <CorpPickupPoint>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final point = CorpPickupPoint.fromJson(
        Map<String, dynamic>.from(item),
        collectionType: collectionType,
      );
      if (point.code.isEmpty) continue;
      parsed.add(point);
    }
    return parsed;
  }

  static Map<String, dynamic>? _unwrap(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map.containsKey('pointDetails') ||
        map.containsKey('points') ||
        map.containsKey('items')) {
      return map;
    }
    final body = map['body'];
    if (body is Map) return _unwrap(body);
    return map;
  }

  static String? _trimmed(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }
}
