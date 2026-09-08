
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// "Activity Centre" / "Quick Actions" grid — 6 shortcut tiles shown
/// under the Accounts hero card and Loan Tracker on the redesigned Home
/// screen (web + mobile).
class QuickActionsGrid extends StatelessWidget {
  const QuickActionsGrid({
    super.key,
    this.onTermDeposit,
    this.onViewStatement,
    this.onChequeBook,
    this.onPassbook,
    this.onNewDebitCard,
    this.onCalculator,
    this.title = 'Activity Centre',
    this.crossAxisCount = 3,
  });

  final VoidCallback? onTermDeposit;
  final VoidCallback? onViewStatement;
  final VoidCallback? onChequeBook;
  final VoidCallback? onPassbook;
  final VoidCallback? onNewDebitCard;
  final VoidCallback? onCalculator;

  // TODO(l10n): move these labels into AppLocalizations once translated
  // strings are available for every supported locale.
  final String title;

  /// 3 on phones/tablets (2 rows of 3); web callers may pass 6 for a
  /// single-row layout inside a wider card.
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    final items = <_QuickAction>[
      _QuickAction(Icons.add_circle_outline_rounded, 'Term Deposit', onTermDeposit),
      _QuickAction(Icons.description_outlined, 'View Statement', onViewStatement),
      _QuickAction(Icons.edit_note_rounded, 'Cheque Book', onChequeBook),
      _QuickAction(Icons.menu_book_outlined, 'Passbook', onPassbook),
      _QuickAction(Icons.credit_card_outlined, 'New Debit card', onNewDebitCard),
      _QuickAction(Icons.calculate_outlined, 'Calculator', onCalculator),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: HomeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              // A short, wide tile keeps the activity centre compact on web.
              // The slightly taller ratio on phones leaves enough room for
              // labels which wrap to two lines.
              final isCompact = constraints.maxWidth < 420;
              return GridView.builder(
                shrinkWrap: true,
                clipBehavior: Clip.none,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: isCompact ? 1.08 : 1.32,
                ),
                itemBuilder: (context, i) => _QuickActionTile(action: items[i]),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({required this.action});

  final _QuickAction action;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  Offset _pointerPosition = Offset.zero;
  bool _isHovered = false;

  void _updatePointer(PointerHoverEvent event) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final localPosition = box.globalToLocal(event.position);
    setState(() => _pointerPosition = Offset(
          (localPosition.dx / box.size.width - 0.5)
              .clamp(-0.5, 0.5)
              .toDouble(),
          (localPosition.dy / box.size.height - 0.5)
              .clamp(-0.5, 0.5)
              .toDouble(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileColor = HomeColors.backgroundSecondary(context);
    final hoverColor = isDark
        ? brand.withValues(alpha: 0.10)
        : Color.alphaBlend(brand.withValues(alpha: 0.055), tileColor);
    final hoverBorder = brand.withValues(alpha: isDark ? 0.70 : 0.38);
    final hoverShadow = brand.withValues(alpha: isDark ? 0.22 : 0.12);
    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0015)
      ..rotateX(_isHovered ? -_pointerPosition.dy * 0.12 : 0)
      ..rotateY(_isHovered ? _pointerPosition.dx * 0.12 : 0)
      ..translate(0.0, _isHovered ? -4.0 : 0.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onHover: _updatePointer,
      onExit: (_) => setState(() {
        _isHovered = false;
        _pointerPosition = Offset.zero;
      }),
      child: TweenAnimationBuilder<Matrix4>(
        tween: Matrix4Tween(end: transform),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Transform(
          alignment: Alignment.center,
          transform: value!,
          child: child,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.action.onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: _isHovered ? hoverColor : tileColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isHovered
                      ? hoverBorder
                      : HomeColors.divider(context),
                ),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: hoverShadow,
                          blurRadius: 14,
                          offset: const Offset(0, 7),
                        ),
                      ]
                    : const [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: _isHovered ? 1.08 : 1,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(widget.action.icon, size: 20, color: brand),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.action.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      color: HomeColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
