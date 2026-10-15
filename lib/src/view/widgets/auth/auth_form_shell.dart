import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';
import 'package:ubci_bank/src/core/utils/common/responsive.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_form_styles.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_mobile_frame.dart';
import 'package:ubci_bank/src/view/widgets/auth/auth_screen_header.dart';
import 'package:ubci_bank/src/core/theme/app_gradients.dart';
/// Flat auth page layout matching login (no card, no step chrome).
///
/// On wide web/desktop viewports this uses the same split brand + form
/// treatment as login so journey pages fill the screen.
class AuthFormShell extends StatelessWidget {
  const AuthFormShell({
    super.key,
    required this.child,
    this.onBack,
    this.title,
    this.subtitle,
    this.maxWidth,
    this.bottomInset = 20,
  });

  final Widget child;
  final VoidCallback? onBack;
  final String? title;
  final String? subtitle;
  final double? maxWidth;
  final double bottomInset;
  @override
Widget build(BuildContext context) {
  final colors = AppColors.of(context);
  final responsive = Responsive.of(context);

  if (responsive.useWideLayout) {
    final wide = responsive.useWideLayout;
    final split = AuthSplitLayout.shouldSplit(context);

    final horizontal =
        split ? 32.0 : responsive.formHorizontalPadding;
    final top =
        responsive.isCompactHeight ? 8.0 : (split ? 28.0 : 16.0);

    final form = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? responsive.formMaxWidth,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (onBack != null) ...[
              AuthScreenHeader(onBack: onBack),
              SizedBox(
                height:
                    responsive.isCompactHeight ? 12 : 22,
              ),
            ],
            if (title != null) ...[
              Text(
                title!,
                style: AuthFormStyles.pageTitle(
                  colors,
                  wide: wide,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: AuthFormStyles.pageSubtitle(
                    colors,
                  ),
                ),
              ],
              SizedBox(
                height:
                    responsive.isCompactHeight ? 14 : 24,
              ),
            ],
            child,
          ],
        ),
      ),
    );

    return AuthSplitLayout(
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontal,
            top,
            horizontal,
            bottomInset,
          ),
          child: form,
        ),
      ),
    );
  }

  // Phones: the designer's frame — gradient, white logo, big title and
  // the wave-topped white card.
  return AuthMobileFrame(
    title: title,
    subtitle: subtitle,
    trailing: onBack == null
        ? null
        : AuthHeaderIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: onBack!,
          ),
    child: child,
  );
}
}

/// Brand panel + content split used by auth journey screens on large web.
class AuthSplitLayout extends StatelessWidget {
  const AuthSplitLayout({super.key, required this.child});

  final Widget child;

  static const double breakpoint = 1000;

  static bool shouldSplit(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= breakpoint;

  @override
  Widget build(BuildContext context) {
    if (!shouldSplit(context)) return child;
    final colors = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Expanded(flex: 5, child: AuthBrandSidePanel()),
        Expanded(
          flex: 6,
          child: ColoredBox(color: colors.scaffoldBg, child: child),
        ),
      ],
    );
  }
}

/// Login-matching brand pane for desktop/web auth journeys.
class AuthBrandSidePanel extends StatelessWidget {
  const AuthBrandSidePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final compact = Responsive.of(context).isCompactHeight;
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.primary(context),
      ),
      // Same leaf pattern as the phone sign-in screens.
      child: CustomPaint(
        painter: const AuthLeafPatternPainter(cell: 80),
        child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            compact ? 28 : 52,
            compact ? 24 : 54,
            compact ? 28 : 52,
            40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: AuthWhiteLogo(height: 46),
              ),
              SizedBox(height: compact ? 28 : 70),
              Text(
                l10n.loginDesktopHeadline,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 34 : 50,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Text(
                  l10n.loginDesktopSubtitle,
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Inline error banner consistent with login error treatment.
class AuthFormErrorBanner extends StatelessWidget {
  const AuthFormErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: scheme.error,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width primary submit button (login-style).
class AuthFormPrimaryButton extends StatelessWidget {
  const AuthFormPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ElevatedButton(
      onPressed: (!enabled || isLoading) ? null : onPressed,
      style: AuthFormStyles.primaryButton(colors),
      child: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }
}