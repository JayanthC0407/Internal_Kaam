import 'package:flutter/material.dart';

/// Parsed manifest theme (CONTRACT §2) plus helpers to build [ThemeData].
///
/// Colours are kept as ARGB ints so alpha variants can be produced without
/// relying on Color members that changed across Flutter versions.
class DxpTheme {
  DxpTheme._(this.raw, this._colors, this.brandName, this.radius, this.fontFamily);

  factory DxpTheme.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const <String, dynamic>{};
    final colors = Map<String, int>.from(_defaults);
    final c = j['colors'];
    if (c is Map) {
      c.forEach((k, v) {
        final parsed = parseHexColor(v?.toString());
        if (parsed != null) colors[k.toString()] = parsed;
      });
    }
    final r = j['radius'];
    final font = j['fontFamily']?.toString();
    return DxpTheme._(
      Map<String, dynamic>.from(j),
      colors,
      (j['brandName'] ?? 'Demo Bank').toString(),
      r is num ? r.toDouble() : 14,
      (font == null || font.isEmpty) ? null : font,
    );
  }

  factory DxpTheme.fallback() => DxpTheme.fromJson(null);

  static const Map<String, int> _defaults = <String, int>{
    'primary': 0xFF0B6E69,
    'onPrimary': 0xFFFFFFFF,
    'secondary': 0xFF1B1B1B,
    'background': 0xFFF3F6F6,
    'surface': 0xFFFFFFFF,
    'onSurface': 0xFF1B1B1B,
    'muted': 0xFF6B6B6B,
    'success': 0xFF1E8E3E,
    'danger': 0xFFC62828,
    'warning': 0xFFB26A00,
  };

  final Map<String, dynamic> raw;
  final Map<String, int> _colors;
  final String brandName;
  final double radius;
  final String? fontFamily;

  /// `#RGB`, `#RRGGBB`, `#RRGGBBAA` (CSS order) → ARGB int.
  static int? parseHexColor(String? input) {
    if (input == null) return null;
    var h = input.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 3) {
      h = h.split('').map((ch) => '$ch$ch').join();
    }
    int? v;
    if (h.length == 6) {
      v = int.tryParse(h, radix: 16);
      if (v != null) v = 0xFF000000 | v;
    } else if (h.length == 8) {
      final rgb = int.tryParse(h.substring(0, 6), radix: 16);
      final a = int.tryParse(h.substring(6, 8), radix: 16);
      if (rgb != null && a != null) v = (a << 24) | rgb;
    }
    return v;
  }

  int _argb(String name) => _colors[name] ?? _defaults[name] ?? 0xFF000000;

  Color color(String name) => Color(_argb(name));

  /// [name] colour at [opacity] (0..1).
  Color tint(String name, double opacity) {
    final a = (opacity.clamp(0.0, 1.0) * 255).round();
    return Color((a << 24) | (_argb(name) & 0x00FFFFFF));
  }

  Color get primary => color('primary');
  Color get onPrimary => color('onPrimary');
  Color get secondary => color('secondary');
  Color get background => color('background');
  Color get surface => color('surface');
  Color get onSurface => color('onSurface');
  Color get muted => color('muted');
  Color get success => color('success');
  Color get danger => color('danger');
  Color get warning => color('warning');

  BorderRadius get borderRadius => BorderRadius.circular(radius);

  /// Smaller radius for inner elements (tiles, inputs).
  BorderRadius get innerRadius => BorderRadius.circular(radius * 0.7);

  List<BoxShadow> get softShadow => <BoxShadow>[
        BoxShadow(
          color: tint('secondary', 0.06),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];

  ThemeData toThemeData() {
    final scheme = ColorScheme.fromSeed(seedColor: primary).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: const Color(0xFFFFFFFF),
      surface: surface,
      onSurface: onSurface,
      error: danger,
      onError: const Color(0xFFFFFFFF),
    );
    final shape = RoundedRectangleBorder(borderRadius: innerRadius);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: background,
      dividerColor: tint('muted', 0.18),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: shape,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: tint('primary', 0.5), width: 1.4),
          shape: shape,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(64, 44),
          shape: shape,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    );
  }
}

/// Makes the current [DxpTheme] available to every route.
class DxpThemeScope extends InheritedWidget {
  const DxpThemeScope({super.key, required this.theme, required super.child});

  final DxpTheme theme;

  static DxpTheme of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DxpThemeScope>();
    return scope?.theme ?? _fallback;
  }

  static final DxpTheme _fallback = DxpTheme.fallback();

  @override
  bool updateShouldNotify(DxpThemeScope oldWidget) => !identical(oldWidget.theme, theme);
}
