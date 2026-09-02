import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// Generic single-select bottom sheet for short option lists (countries,
/// currencies, payment purposes) — reused across the International
/// Payment form so each of those pickers doesn't need its own widget.
class SimpleOptionPickerSheet<T> {
  SimpleOptionPickerSheet._();

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required List<T> options,
    required String Function(T option) labelBuilder,
    String Function(T option)? subtitleBuilder,
    T? selected,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.viewPaddingOf(ctx).bottom;
        final card = HomeColors.card(ctx);
        final divider = HomeColors.divider(ctx);
        final textPrimary = HomeColors.textPrimary(ctx);
        final textSecondary = HomeColors.textSecondary(ctx);
        final brand = HomeColors.brand(ctx);

        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: divider,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ),
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: options.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: divider,
                        indent: 20,
                      ),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final label = labelBuilder(option);
                        final subtitle = subtitleBuilder?.call(option);
                        final isSelected = option == selected;

                        return ListTile(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(ctx).pop(option);
                          },
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          title: Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: textPrimary,
                            ),
                          ),
                          subtitle: subtitle == null
                              ? null
                              : Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle_rounded, color: brand)
                              : null,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
