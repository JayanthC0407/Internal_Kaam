import 'dart:convert';

/// Render context (CONTRACT §3): `customer`, one key per screen data alias,
/// `state`, `item` (inside lists) and `theme`. Pure Dart, unit-testable.
class RenderContext {
  RenderContext(Map<String, dynamic> values)
      : values = Map<String, dynamic>.unmodifiable(values);

  /// Builds a context. [state] is kept by reference so input widgets can write to it.
  factory RenderContext.build({
    required Map<String, dynamic> customer,
    Map<String, dynamic> data = const <String, dynamic>{},
    Map<String, dynamic>? state,
    Map<String, dynamic> theme = const <String, dynamic>{},
  }) {
    return RenderContext(<String, dynamic>{
      ...data,
      'customer': customer,
      'state': state ?? <String, dynamic>{},
      'theme': theme,
    });
  }

  final Map<String, dynamic> values;

  static final RegExp _placeholder = RegExp(r'\{\{\s*([^}|]+?)\s*(?:\|\s*([a-zA-Z]+)\s*)?\}\}');

  /// The mutable journey state map (empty map outside journeys).
  Map<String, dynamic> get state {
    final s = values['state'];
    if (s is Map<String, dynamic>) return s;
    return <String, dynamic>{};
  }

  RenderContext withItem(dynamic item) =>
      RenderContext(<String, dynamic>{...values, 'item': item});

  /// Resolves a dot path (`customer.firstName`, `item.balance`, `accounts.0.name`).
  /// Returns null when any segment is missing.
  dynamic resolve(String path) {
    final p = path.trim();
    if (p.isEmpty) return null;
    dynamic cur = values;
    for (final seg in p.split('.')) {
      if (cur is Map) {
        if (!cur.containsKey(seg)) return null;
        cur = cur[seg];
      } else if (cur is List) {
        final i = int.tryParse(seg);
        if (i == null || i < 0 || i >= cur.length) return null;
        cur = cur[i];
      } else {
        return null;
      }
    }
    return cur;
  }

  /// Replaces every `{{path}}`, `{{path|money}}`, `{{path|date}}` in [template].
  /// Missing paths render as an empty string; unknown filters are ignored.
  String interpolate(String template) {
    if (!template.contains('{{')) return template;
    return template.replaceAllMapped(_placeholder, (m) {
      final value = resolve(m.group(1) ?? '');
      final filter = m.group(2);
      if (filter == 'money') {
        final n = toNum(value);
        return n == null ? '' : formatMoney(n);
      }
      if (filter == 'date') return formatDate(value);
      return stringify(value);
    });
  }

  /// Interpolates every string inside maps/lists (used for `props`).
  dynamic interpolateDeep(dynamic v) {
    if (v is String) return interpolate(v);
    if (v is List) return v.map(interpolateDeep).toList();
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), interpolateDeep(val)));
    }
    return v;
  }
}

/// Value → display string. null → '', whole doubles without `.0`.
String stringify(dynamic v) {
  if (v == null) return '';
  if (v is String) return v;
  if (v is double) {
    if (v.isFinite && v == v.truncateToDouble()) return v.toInt().toString();
    return v.toString();
  }
  if (v is num || v is bool) return v.toString();
  if (v is Map || v is List) {
    try {
      return jsonEncode(v);
    } catch (_) {
      return v.toString();
    }
  }
  return v.toString();
}

/// Lenient number parsing (accepts `"1,250.5"`).
num? toNum(dynamic v) {
  if (v is num) return v;
  if (v is String) {
    final s = v.replaceAll(',', '').trim();
    if (s.isEmpty) return null;
    return num.tryParse(s);
  }
  return null;
}

/// `1250.5` → `1,250.500` (3 decimals, thousands separators).
String formatMoney(num value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(3);
  final dot = fixed.indexOf('.');
  final intPart = dot < 0 ? fixed : fixed.substring(0, dot);
  final frac = dot < 0 ? '000' : fixed.substring(dot + 1);
  final b = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) b.write(',');
    b.write(intPart[i]);
  }
  final out = '${b.toString()}.$frac';
  return negative && value != 0 ? '-$out' : out;
}

/// ISO date part `YYYY-MM-DD` of a date string / DateTime.
String formatDate(dynamic v) {
  if (v == null) return '';
  if (v is DateTime) return v.toIso8601String().substring(0, 10);
  final s = v.toString().trim();
  final m = RegExp(r'^\d{4}-\d{2}-\d{2}').firstMatch(s);
  if (m != null) return m.group(0)!;
  final parsed = DateTime.tryParse(s);
  return parsed == null ? s : parsed.toIso8601String().substring(0, 10);
}
