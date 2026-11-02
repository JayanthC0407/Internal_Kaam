import 'package:flutter/material.dart';
import 'package:demo_bank/src/core/models/common/money_amount.dart';
import 'package:demo_bank/src/core/models/corp/credit_facility_models.dart';
import 'package:demo_bank/src/core/utils/common/statement_file_saver.dart';
import 'package:demo_bank/src/core/utils/corp/corp_money_format.dart';
import 'package:demo_bank/src/infra/network/response_handler.dart';
import 'package:demo_bank/src/view/screens/corp/corp_colors.dart';
import 'package:demo_bank/src/view/providers/corp/corp_credit_facility_providers.dart';
import 'package:demo_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';
import 'package:demo_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';

/// Shared pieces of the Credit Facility screens.

String cfMoney(MoneyAmount? m) => CorpMoneyFormat.formatAmount(m);

String cfDateOr(DateTime? d, [String placeholder = '—']) => d == null ? placeholder : CorpFigures.date(d);

String cfYesNo(bool v) => v ? 'Yes' : 'No';

/// A percentage without a trailing `.0` (`80%`, `12.5%`), or `--`.
String cfPercent(num? v) => v == null ? '--' : '${v == v.roundToDouble() ? v.round() : v}%';

void cfSnack(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

/// OBDX's message when the server sent one, else [fallback].
String cfError(Object? error, String fallback) =>
    error is CfLoadError && error.message != null && error.message!.trim().isNotEmpty ? error.message! : fallback;

/// A load failure: the message and Retry.
class CfFailed extends StatelessWidget {
  const CfFailed({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LcMessageBanner(message: message),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
        ),
      ],
    );
  }
}

/// A bordered block: a header over its content.
class CfPanel extends StatelessWidget {
  const CfPanel({super.key, required this.header, required this.child});

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: CorpColors.divider(context))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, const SizedBox(height: 10), child]),
    );
  }
}

/// The utilized bar with its label beside it.
class CfUtilizedBar extends StatelessWidget {
  const CfUtilizedBar({super.key, required this.percent, required this.label});

  final double percent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0, 1).toDouble(),
              minHeight: 6,
              color: CorpColors.brand(context),
              backgroundColor: CorpColors.divider(context),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: CorpColors.textSecondary(context))),
      ],
    );
  }
}

/// Covenants (`facility-covenants`): one card per `covenantDTO`, for a
/// facility or a collateral.
class CfCovenants extends StatelessWidget {
  const CfCovenants({super.key, required this.covenants});

  final List<CfCovenant> covenants;

  @override
  Widget build(BuildContext context) {
    if (covenants.isEmpty) return const LcEmptyState(icon: Icons.gavel_rounded, title: 'No covenants to show.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in covenants)
          CfPanel(
            header: LcInfoItem(label: 'Covenant Id', value: c.name ?? '--'),
            child: LcInfoGrid(items: [
              ('Revision Date', cfDateOr(c.revisionDate, '--')),
              ('Description', c.description ?? '--'),
            ]),
          ),
      ],
    );
  }
}

/// A collateral linked to a group (Facility Details' Collateral Groups tab
/// and Collateral Summary): its code opens Collateral Details.
class CfLinkedCollateralCard extends StatelessWidget {
  const CfLinkedCollateralCard({super.key, required this.collateral, this.onOpen});

  final CfLinkedCollateral collateral;

  /// Null when the user may not open Collateral Details.
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    final c = collateral;
    return CfPanel(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CfLink(label: c.code, onTap: onOpen == null ? null : () => onOpen!(c.code)),
          if (c.description != null)
            Text(c.description!, style: TextStyle(fontSize: 12.5, color: CorpColors.textSecondary(context))),
        ],
      ),
      child: LcInfoGrid(items: [
        ('Collateral Value', cfMoney(c.value)),
        ('Collateral Amount (After Haircut)', cfMoney(c.limitContribution)),
        ('End Date', cfDateOr(c.endDate, '--')),
        ('Margin', cfPercent(c.lendableMargin)),
        (
          'Contribution to Group',
          '${cfMoney(c.utilization)}${c.contributionPercent == null ? '' : '  ${cfPercent(c.contributionPercent)}'}'
        ),
      ]),
    );
  }
}

/// A teal, underlined text link (OBDX's facility and collateral links).
class CfLink extends StatelessWidget {
  const CfLink({super.key, required this.label, required this.onTap, this.size = 15});

  final String label;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w700,
            color: onTap == null ? CorpColors.textPrimary(context) : brand,
            decoration: onTap == null ? null : TextDecoration.underline,
            decorationColor: brand,
          ),
        ),
      ),
    );
  }
}

/// A small rounded tag ("Main line", "Sub Line", "Group").
class CfTag extends StatelessWidget {
  const CfTag(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final brand = CorpColors.brand(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: brand.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: brand)),
    );
  }
}

/// The page header: back arrow, title and OBDX's "party | id" caption.
class CfPageHeader extends StatelessWidget {
  const CfPageHeader({super.key, required this.title, required this.onBack, this.caption, this.trailing});

  final String title;
  final String? caption;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: CorpColors.card(context),
          shape: CircleBorder(side: BorderSide(color: CorpColors.divider(context))),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onBack,
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(Icons.arrow_back_rounded, size: 20, color: CorpColors.textPrimary(context)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: CorpColors.textPrimary(context))),
              if (caption != null)
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: CorpColors.textSecondary(context)),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Download (PDF) as an icon button, with progress and a result message.
class CfDownloadButton extends StatefulWidget {
  const CfDownloadButton({
    super.key,
    required this.fileName,
    required this.download,
    this.enabled = true,
    this.mimeType = 'application/pdf',
  });

  final String fileName;

  /// The saved file's type (Charges Inquiry downloads `text/csv`).
  final String mimeType;
  final Future<ResponseHandler<List<int>>> Function() download;
  final bool enabled;

  @override
  State<CfDownloadButton> createState() => _CfDownloadButtonState();
}

class _CfDownloadButtonState extends State<CfDownloadButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    final result = await widget.download();
    if (!mounted) return;
    if (result is Success<List<int>> && result.data != null) {
      try {
        final box = context.findRenderObject() as RenderBox?;
        await StatementFileSaver.saveStatement(
          bytes: result.data!,
          fileName: widget.fileName,
          mimeType: widget.mimeType,
          sharePositionOrigin: box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null,
        );
        if (mounted) cfSnack(context, 'Downloaded ${widget.fileName}');
      } catch (_) {
        if (mounted) cfSnack(context, 'Could not save the file.');
      }
    } else if (mounted) {
      final message = result is Error<List<int>> ? result.error : null;
      cfSnack(context, message?.trim().isNotEmpty == true ? message! : 'Could not download the file.');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Download',
      onPressed: _busy || !widget.enabled ? null : _run,
      icon: _busy
          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(Icons.download_rounded, color: CorpColors.textSecondary(context)),
    );
  }
}
