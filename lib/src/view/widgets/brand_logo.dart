import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';

/// Demo Bank lockup used in place of the legacy UBCI image asset.
///
/// [demo_bank_logo_dark] is the white wordmark for dark surfaces.
/// [demo_bank_logo_light] is the black wordmark for light surfaces.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 32,
    this.color,
  });

  static const lightAsset = 'assets/images/demo_bank_logo_light.png';
  static const darkAsset = 'assets/images/demo_bank_logo_dark.png';

  /// Rendered height; width follows the asset aspect ratio.
  final double height;

  /// Optional hint: a light [color] selects the white-on-dark lockup.
  /// The image is not tinted, so the teal mark stays intact.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onDark = _isOnDarkBackground(context);
    return Image.asset(
      onDark ? darkAsset : lightAsset,
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      filterQuality: FilterQuality.high,
      semanticLabel: l10n.brandName,
      errorBuilder: (_, __, ___) => Text(
        l10n.brandName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color ?? Theme.of(context).colorScheme.primary,
          fontSize: height * 0.72,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          height: 1.0,
        ),
      ),
    );
  }

  bool _isOnDarkBackground(BuildContext context) {
    if (color != null) {
      return ThemeData.estimateBrightnessForColor(color!) == Brightness.light;
    }
    return Theme.of(context).brightness == Brightness.dark;
  }
}
