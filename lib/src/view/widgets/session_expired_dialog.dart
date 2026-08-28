import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';

/// Shared session / auth recovery dialog (title, message, Sign in).
class SessionExpiredDialog extends StatelessWidget {
  const SessionExpiredDialog({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onSignIn,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onSignIn;

  /// Presents the dialog; completes when the user taps Sign in (or dismisses).
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: title,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SessionExpiredDialog(
          title: title,
          message: message,
          actionLabel: actionLabel,
          onSignIn: () => Navigator.of(dialogContext).pop(),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final eased = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: eased,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(eased),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 768;
    final cardWidth = isWide ? 480.0 : 400.0;
    final horizontalPadding = isWide ? 40.0 : 28.0;

    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: cardWidth,
            margin: const EdgeInsets.all(24),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: BorderRadius.circular(isWide ? 24 : 22),
              border: Border.all(
                color: colors.divider.withValues(alpha: 0.8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 40,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                isWide ? 36 : 30,
                horizontalPadding,
                isWide ? 32 : 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: isWide ? 72 : 64,
                    height: isWide ? 72 : 64,
                    decoration: BoxDecoration(
                      color: colors.otpBoxFilled,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_clock_rounded,
                      size: isWide ? 34 : 30,
                      color: colors.brand,
                    ),
                  ),
                  SizedBox(height: isWide ? 24 : 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: isWide ? 26 : 24,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: isWide ? 16 : 15,
                        height: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(height: isWide ? 30 : 26),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: onSignIn,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.brand,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(actionLabel),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 19),
                        ],
                      ),
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
