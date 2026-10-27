import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';

/// The Demobank logo, following the theme: the teal artwork on light
/// surfaces, white in dark mode (the same artwork tinted, as on the auth
/// screens' dark frame) so it never sits teal-on-navy.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 32,
    this.alignment = Alignment.center,
    this.onDark,
    this.fallbackColor,
  });

  static const asset = 'assets/images/demobank_logo.png';

  /// Rendered height; width follows the asset aspect ratio.
  final double height;
  final Alignment alignment;

  /// Forces white (true) or the original colours (false); null follows
  /// the theme's brightness.
  final bool? onDark;

  /// Colour of the text shown if the image cannot load.
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    // Nullable lookup: the logo also shows where no localizations exist.
    final name = Localizations.of<AppLocalizations>(context, AppLocalizations)?.brandName ?? 'Demobank';
    final white = onDark ?? Theme.of(context).brightness == Brightness.dark;
    final image = Image.asset(
      asset,
      height: height,
      fit: BoxFit.contain,
      alignment: alignment,
      filterQuality: FilterQuality.high,
      semanticLabel: name,
      errorBuilder: (_, __, ___) => Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: white ? Colors.white : (fallbackColor ?? Theme.of(context).colorScheme.primary),
          fontSize: height * 0.7,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
    if (!white) return image;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      child: image,
    );
  }
}
