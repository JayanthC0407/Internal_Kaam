import 'package:flutter/material.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/preferences/preferences_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/providers/common/preferences_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// Pieces shared by the Preferences sections. Colours come from
/// [HomeColors] (the active [AppColors] palette), so every section follows
/// the app's light/dark mode and colour theme.

/// Runs one Preferences write, asking for the OTP on each 417 until it is
/// done, fails or the user cancels (then the last 417 result comes back).
Future<ResponseHandler<PrefWriteOutcome>> runPrefWrite(
  BuildContext context,
  Future<ResponseHandler<PrefWriteOutcome>> Function(ObdxChallenge? challenge, String? otp) call,
) async {
  final l10n = AppLocalizations.of(context);
  var result = await call(null, null);
  while (result is Success<PrefWriteOutcome> && result.data?.challenge != null) {
    final outcome = result.data!;
    if (!context.mounted) return result;
    final otp = await showPayOtpPrompt(
      context,
      title: l10n.prefOtpTitle,
      error: outcome.invalidOtp ? l10n.prefOtpInvalid : null,
      attemptsLeft: outcome.challenge!.attemptsLeft,
    );
    if (otp == null || !context.mounted) return result;
    result = await call(outcome.challenge, otp);
  }
  return result;
}

/// Done: not failed and no OTP still waiting.
bool prefWriteDone(ResponseHandler<PrefWriteOutcome> r) =>
    r is Success<PrefWriteOutcome> && r.data != null && r.data!.challenge == null;

/// OBDX's message for a failed write, else ours. Null when the user only
/// cancelled the OTP.
String? prefWriteError(BuildContext context, ResponseHandler<PrefWriteOutcome> r) {
  if (r is Success<PrefWriteOutcome>) return null;
  final message = r is Error<PrefWriteOutcome> ? r.error?.trim() : null;
  if (message != null && message.isNotEmpty) return message;
  return AppLocalizations.of(context).prefSaveFailed;
}

void prefSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Reports a finished write: [success] (or "Sent for approval."), the error,
/// or nothing when the OTP was cancelled. Returns whether it went through.
bool prefReportWrite(BuildContext context, ResponseHandler<PrefWriteOutcome> r, {String? success}) {
  final l10n = AppLocalizations.of(context);
  if (prefWriteDone(r)) {
    final text = r is Success<PrefWriteOutcome> && r.data!.pendingApproval ? l10n.prefPendingApproval : success;
    if (text != null) prefSnack(context, text);
    return true;
  }
  final error = prefWriteError(context, r);
  if (error != null) prefSnack(context, error);
  return false;
}

/// The loading card every section shows first.
class PrefLoading extends StatelessWidget {
  const PrefLoading({super.key});

  @override
  Widget build(BuildContext context) => const PayCard(
        child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      );
}

/// A load failure with Retry.
class PrefFailed extends StatelessWidget {
  const PrefFailed({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => PayErrorRetry(
        message: error is PreferencesLoadError && (error as PreferencesLoadError).message != null
            ? (error as PreferencesLoadError).message!
            : AppLocalizations.of(context).prefLoadFailed,
        onRetry: onRetry,
      );
}

/// OBDX's green confirmation bar (`success-bar`), closable.
class PrefSuccessBar extends StatelessWidget {
  const PrefSuccessBar({super.key, required this.message, this.onClose});

  final String message;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final success = HomeColors.success(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: success.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: success, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 13, color: HomeColors.textPrimary(context))),
          ),
          if (onClose != null)
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 18, color: HomeColors.textSecondary(context)),
              onPressed: onClose,
            ),
        ],
      ),
    );
  }
}

/// OBDX's review banner: "Review" and what is about to be confirmed.
class PrefReviewBanner extends StatelessWidget {
  const PrefReviewBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brand.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.fact_check_outlined, color: brand, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).prefReview,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
                ),
                const SizedBox(height: 2),
                Text(message, style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A label over its value — the Profile rows.
class PrefLabelValue extends StatelessWidget {
  const PrefLabelValue({super.key, required this.label, required this.value, this.onEdit, this.editTooltip, this.last = false});

  final String label;
  final String value;
  final VoidCallback? onEdit;
  final String? editTooltip;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: HomeColors.divider(context).withValues(alpha: 0.7))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context))),
                  const SizedBox(height: 4),
                  Text(
                    value.isEmpty ? '-' : value,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
                  ),
                ],
              ),
            ),
            if (onEdit != null)
              IconButton(
                tooltip: editTooltip,
                icon: Icon(Icons.edit_outlined, size: 20, color: HomeColors.brand(context)),
                onPressed: onEdit,
              ),
          ],
        ),
      );
}

/// One switch of a Settings block.
class PrefSwitchRow extends StatelessWidget {
  const PrefSwitchRow({super.key, required this.label, required this.value, required this.onChanged, this.busy = false});

  final String label;
  final bool value;

  /// Null disables the switch.
  final ValueChanged<bool>? onChanged;
  final bool busy;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: onChanged == null ? HomeColors.textSecondary(context) : HomeColors.textPrimary(context),
                ),
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              Switch(
                value: value,
                activeThumbColor: HomeColors.brand(context),
                onChanged: onChanged,
              ),
          ],
        ),
      );
}

/// A Settings block: a title, its controls and OBDX's note.
class PrefBlock extends StatelessWidget {
  const PrefBlock({super.key, required this.title, required this.children, this.note, this.icon});

  final String title;
  final IconData? icon;
  final List<Widget> children;
  final String? note;

  @override
  Widget build(BuildContext context) => PaySection(
        title: title,
        icon: icon,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...children,
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(note!, style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context))),
            ],
          ],
        ),
      );
}

/// A radio choice in the brand colour.
class PrefRadio<T> extends StatelessWidget {
  const PrefRadio({super.key, required this.value, required this.group, required this.label, required this.onChanged, this.subtitle});

  final T value;
  final T? group;
  final String label;
  final String? subtitle;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == group;
    final brand = HomeColors.brand(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onChanged == null ? null : () => onChanged!(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? brand : HomeColors.textSecondary(context),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: HomeColors.textPrimary(context),
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context))),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of buttons that wraps on a phone: primary first on the right.
class PrefActions extends StatelessWidget {
  const PrefActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, child) in children.indexed) ...[if (i > 0) const SizedBox(height: 10), child],
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (final (i, child) in children.reversed.indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                ConstrainedBox(constraints: const BoxConstraints(minWidth: 140), child: child),
              ],
            ],
          );
        },
      );
}

/// A sheet on a phone, a dialog on a wide screen — the right panel OBDX
/// opens for "Update Profile".
Future<T?> showPrefPanel<T>(BuildContext context, {required String title, required WidgetBuilder builder}) {
  Widget panel(BuildContext ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(ctx)),
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
                  icon: Icon(Icons.close_rounded, color: HomeColors.textSecondary(ctx)),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: builder(ctx),
            ),
          ),
        ],
      );

  if (MediaQuery.sizeOf(context).width >= 768) {
    return showDialog<T>(
      context: context,
      builder: (dialog) => Dialog(
        backgroundColor: HomeColors.card(dialog),
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520, maxHeight: MediaQuery.sizeOf(dialog).height * 0.85),
          child: panel(dialog),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheet) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.9),
        decoration: BoxDecoration(
          color: HomeColors.card(sheet),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(top: false, child: panel(sheet)),
      ),
    ),
  );
}
