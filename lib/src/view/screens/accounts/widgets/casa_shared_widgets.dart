import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ubci_bank/src/core/models/casa_account.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// Dark teal summary banner used on CASA details / transactions screens.
/// Matches Figma brand gradient `#005C51 → #004A41 → #002E29` + logomark watermark.
///
/// Logomark placement (mobile details card, Figma `11:6737`):
/// card 361×178 → mark at x=292, y=-73, size ~210×221 (mostly clipped top-right).
class CasaBrandBanner extends StatelessWidget {
  const CasaBrandBanner({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  static const _brand500 = Color(0xFF005C51);
  static const _brand600 = Color(0xFF004A41);
  static const _brand800 = Color(0xFF002E29);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_brand500, _brand600, _brand800],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Watermark anchors to the full card (not the padded content box).
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight.isFinite &&
                          constraints.maxHeight > 0
                      ? constraints.maxHeight
                      : 178.0;

                  // Figma uses two placements:
                  // - Tall details card (≈178): mark 210×221 @ (292, -73)
                  // - Compact balance row (≈74): mark 347×347 @ (247, -20)
                  final compact = h < 110;
                  final markW = w * (compact ? 347.33 / 361.0 : 209.66 / 361.0);
                  final markH = compact ? markW : markW * (220.87 / 209.66);
                  final left = w * (compact ? 247.0 / 361.0 : 291.54 / 361.0);
                  final top = compact
                      ? -20.0 * (w / 361.0)
                      : h * (-73.0 / 178.0);

                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        left: left,
                        top: top,
                        width: markW,
                        height: markH,
                        child: IgnorePointer(
                          child: SvgPicture.asset(
                            'assets/images/figma/brand_logomark.svg',
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label + value pair used in Balance / General details grids.
class CasaDetailField extends StatelessWidget {
  const CasaDetailField({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class CasaSectionCard extends StatelessWidget {
  const CasaSectionCard({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: colors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Compact secondary back control — Figma 24×24, radius 6, `#DCDFEA`.
class CasaBackButton extends StatelessWidget {
  const CasaBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.of(context).secondaryButtonBg;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed ?? () => Navigator.of(context).maybePop(),
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Icon(
            Icons.chevron_left_rounded,
            size: 18,
            color: HomeColors.textPrimary(context),
          ),
        ),
      ),
    );
  }
}

/// Compact header title matching Figma (14 / semibold on mobile).
class CasaScreenHeader extends StatelessWidget {
  const CasaScreenHeader({
    super.key,
    required this.title,
    this.trailing,
    this.wide = false,
    this.onBack,
  });

  final String title;
  final Widget? trailing;
  final bool wide;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CasaBackButton(
          onPressed: onBack,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: wide ? 20 : 14,
              fontWeight: FontWeight.w600,
              color: HomeColors.textPrimary(context),
              letterSpacing: wide ? 0.4 : 0,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Secondary icon button matching Figma 24×24 chrome (download, etc.).
class CasaIconButton extends StatelessWidget {
  const CasaIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.of(context).secondaryButtonBg;
    final button = Material(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Icon(
            icon,
            size: 14,
            color: HomeColors.textPrimary(context),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Masked CASA account picker used on details and transaction filters.
class CasaAccountDropdown extends StatelessWidget {
  const CasaAccountDropdown({
    super.key,
    required this.accounts,
    required this.selectedId,
    required this.onChanged,
    this.enabledWhenSingle = false,
    this.showSubtitle = false,
  });

  final List<CasaAccount> accounts;
  final String selectedId;
  final ValueChanged<String?> onChanged;
  final bool enabledWhenSingle;
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    final seen = <String>{};
    final uniqueAccounts = <CasaAccount>[];
    for (final a in accounts) {
      final id = a.id.trim();
      if (id.isEmpty || !seen.add(id)) continue;
      uniqueAccounts.add(a);
    }

    final items = uniqueAccounts.isEmpty
        ? [
            DropdownMenuItem<String>(
              value: selectedId,
              child: Text(_mask(selectedId)),
            ),
          ]
        : uniqueAccounts
            .map(
              (a) => DropdownMenuItem<String>(
                value: a.id,
                child: showSubtitle
                    ? _AccountItem(account: a)
                    : Text(
                        a.maskedNumber,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            )
            .toList();

    final value = uniqueAccounts.any((a) => a.id == selectedId)
        ? selectedId
        : (uniqueAccounts.isNotEmpty ? uniqueAccounts.first.id : selectedId);

    final enabled =
        uniqueAccounts.length > 1 || (enabledWhenSingle && uniqueAccounts.isNotEmpty);

    return InputDecorator(
      decoration: InputDecoration(
        filled: true,
        fillColor: HomeColors.card(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: HomeColors.divider(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: HomeColors.divider(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: HomeColors.brand(context), width: 1.2),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          isDense: !showSubtitle,
          value: items.any((i) => i.value == value) ? value : null,
          hint: Text(
            _mask(selectedId),
            style: TextStyle(color: HomeColors.textSecondary(context)),
          ),
          items: items,
          onChanged: enabled ? onChanged : null,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: HomeColors.textPrimary(context),
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: HomeColors.textSecondary(context),
          ),
          borderRadius: BorderRadius.circular(8),
          menuMaxHeight: 320,
        ),
      ),
    );
  }

  static String _mask(String id) {
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length <= 4) return id;
    return '${'*' * (digits.length - 4)}${digits.substring(digits.length - 4)}';
  }
}

class _AccountItem extends StatelessWidget {
  const _AccountItem({required this.account});

  final CasaAccount account;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if ((account.title).trim().isNotEmpty) account.title.trim(),
      if (account.currencyCode.trim().isNotEmpty)
        account.currencyCode.trim().toUpperCase(),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          account.maskedNumber,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitleParts.isNotEmpty)
          Text(
            subtitleParts.join(' | '),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: HomeColors.textSecondary(context),
            ),
          ),
      ],
    );
  }
}
