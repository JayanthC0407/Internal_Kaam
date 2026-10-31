import 'package:flutter/material.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/utils/common/statement_file_saver.dart';
import 'package:ubci_bank/src/core/utils/corp/corp_money_format.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';

/// Shared pieces of the Credit Facility screens.

String cfMoney(MoneyAmount? m) => CorpMoneyFormat.formatAmount(m);

String cfDateOr(DateTime? d, [String placeholder = '—']) => d == null ? placeholder : CorpFigures.date(d);

String cfYesNo(bool v) => v ? 'Yes' : 'No';

/// A percentage without a trailing `.0` (`80%`, `12.5%`), or `--`.
String cfPercent(num? v) => v == null ? '--' : '${v == v.roundToDouble() ? v.round() : v}%';

void cfSnack(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

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
  const CfDownloadButton({super.key, required this.fileName, required this.download, this.enabled = true});

  final String fileName;
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
        await StatementFileSaver.savePdf(
          bytes: result.data!,
          fileName: widget.fileName,
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
