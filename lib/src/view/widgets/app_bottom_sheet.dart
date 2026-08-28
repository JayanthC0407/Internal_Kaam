import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/theme/app_radius.dart';
import 'package:ubci_bank/src/core/theme/app_spacing.dart';

/// Shared themed overlays for confirmations and single-choice pickers.
///
/// Uses a modal bottom sheet on mobile and a centered [Dialog] on web.
class AppBottomSheet {
  AppBottomSheet._();

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
    bool destructive = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    final result = await _present<bool>(
      context: context,
      builder: (ctx) {
        final brand = HomeColors.brand(ctx);
        final textPrimary = HomeColors.textPrimary(ctx);
        final textSecondary = HomeColors.textSecondary(ctx);
        final card = HomeColors.card(ctx);
        final divider = HomeColors.divider(ctx);
        // Web keeps brand primary to match other dialogs; mobile keeps
        // destructive red for high-risk confirms.
final confirmColor =
    (!kIsWeb && destructive)
        ? AppColors.of(ctx).error
        : brand;
        final actions = kIsWeb
            ? _WebConfirmActions(
                cancelLabel: cancelLabel ?? l10n.cancel,
                confirmLabel: confirmLabel ?? l10n.confirm,
                confirmColor: confirmColor,
                textPrimary: textPrimary,
                divider: divider,
                onCancel: () => Navigator.of(ctx).pop(false),
                onConfirm: () => Navigator.of(ctx).pop(true),
              )
            : Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textPrimary,
                        side: BorderSide(color: divider),
                       padding: const EdgeInsets.symmetric(
  vertical: AppSpacing.md,
),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: Text(cancelLabel ?? l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: confirmColor,
                        foregroundColor: Colors.white,
                                               padding: const EdgeInsets.symmetric(
  vertical: AppSpacing.md,
),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: Text(confirmLabel ?? l10n.confirm),
                    ),
                  ),
                ],
              );
        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            actions,
          ],
        );

        if (kIsWeb) {
          return _WebOverlayDialog(
            backgroundColor: card,
            padding: const EdgeInsets.fromLTRB(
  AppSpacing.xl,
  AppSpacing.xl,
  AppSpacing.xl,
  AppSpacing.lg,
),
            child: content,
          );
        }

        return _MobileSheetShell(
          backgroundColor: card,
          dividerColor: divider,
          padding: const EdgeInsets.fromLTRB(
    AppSpacing.xl,
    AppSpacing.md,
    AppSpacing.xl,
    AppSpacing.xl,
),
          child: content,
        );
      },
    );
    return result == true;
  }

  static Future<T?> pick<T>({
    required BuildContext context,
    required String title,
    required List<({T value, String label})> options,
    required T selected,
  }) {
    return _present<T>(
      context: context,
      builder: (ctx) {
        final brand = HomeColors.brand(ctx);
        final textPrimary = HomeColors.textPrimary(ctx);
        final card = HomeColors.card(ctx);
        final divider = HomeColors.divider(ctx);
        final inactive = HomeColors.navInactive(ctx);
        final listMaxHeight = MediaQuery.sizeOf(ctx).height * (kIsWeb ? 0.45 : 0.55);

        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                kIsWeb ? 4 : 12,
                kIsWeb ? 0 : 4,
                4,
                8,
              ),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: kIsWeb ? 20 : 18,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: listMaxHeight),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: options.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: divider),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final isSelected = option.value == selected;
                  return ListTile(
                    onTap: () => Navigator.of(ctx).pop(option.value),
                    title: Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: textPrimary,
                      ),
                    ),
                    trailing: Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected ? brand : inactive,
                    ),
                  );
                },
              ),
            ),
          ],
        );

        if (kIsWeb) {
          return _WebOverlayDialog(
            backgroundColor: card,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Material(
              type: MaterialType.transparency,
              child: content,
            ),
          );
        }

        return _MobileSheetShell(
          backgroundColor: card,
          dividerColor: divider,
          padding: const EdgeInsets.all(
    AppSpacing.md,
),
          child: Material(
            type: MaterialType.transparency,
            child: content,
          ),
        );
      },
    );
  }

  static Future<T?> custom<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    EdgeInsetsGeometry? padding,
  }) {
    return _present<T>(
      context: context,
      builder: (ctx) {
        final card = HomeColors.card(ctx);
        final divider = HomeColors.divider(ctx);
        final child = builder(ctx);
        if (kIsWeb) {
          return _WebOverlayDialog(
            backgroundColor: card,
            padding: padding ?? const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Material(
              type: MaterialType.transparency,
              child: child,
            ),
          );
        }
        final keyboard = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: _MobileSheetShell(
            backgroundColor: card,
            dividerColor: divider,
            padding: padding ??
    const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.md,
      AppSpacing.xl,
      AppSpacing.xl,
    ),
            child: Material(
              type: MaterialType.transparency,
              child: child,
            ),
          ),
        );
      },
    );
  }

  static Future<T?> _present<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) {
    if (kIsWeb) {
      return showDialog<T>(
        context: context,
        barrierDismissible: true,
        builder: builder,
      );
    }
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }
}

class _WebConfirmActions extends StatelessWidget {
  const _WebConfirmActions({
    required this.cancelLabel,
    required this.confirmLabel,
    required this.confirmColor,
    required this.textPrimary,
    required this.divider,
    required this.onCancel,
    required this.onConfirm,
  });

  final String cancelLabel;
  final String confirmLabel;
  final Color confirmColor;
  final Color textPrimary;
  final Color divider;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 768;
    final buttonHeight = isWide ? 48.0 : 46.0;
    final radius =
    BorderRadius.circular(AppRadius.md);

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: textPrimary,
                backgroundColor: Colors.transparent,
                side: BorderSide(color: divider),
                shape: RoundedRectangleBorder(borderRadius: radius),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(cancelLabel),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: SizedBox(
            height: buttonHeight,
            child: FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: confirmColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: radius),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(confirmLabel),
            ),
          ),
        ),
      ],
    );
  }
}

class _WebOverlayDialog extends StatelessWidget {
  const _WebOverlayDialog({
    required this.backgroundColor,
    required this.padding,
    required this.child,
  });

  final Color backgroundColor;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 768;
    final cardWidth = (isWide ? 480.0 : width - 32).clamp(280.0, 480.0);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isWide ? 40 : 16,
        vertical: isWide ? 40 : 24,
      ),
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
    AppRadius.xxl,
),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cardWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _MobileSheetShell extends StatelessWidget {
  const _MobileSheetShell({
    required this.backgroundColor,
    required this.dividerColor,
    required this.padding,
    required this.child,
  });

  final Color backgroundColor;
  final Color dividerColor;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: dividerColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}
