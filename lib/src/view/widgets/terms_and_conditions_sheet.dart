import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/legal/legal_content.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';

/// Scrollable Terms and Conditions viewer backed by [LegalContent].
///
/// Uses a modal bottom sheet on mobile and a centered [Dialog] on web.
class TermsAndConditionsSheet {
  TermsAndConditionsSheet._();

  static Future<void> show(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (kIsWeb) {
      return showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => _TermsContent(l10n: l10n, asDialog: true),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TermsContent(l10n: l10n, asDialog: false),
    );
  }
}

class _TermsContent extends StatelessWidget {
  const _TermsContent({
    required this.l10n,
    required this.asDialog,
  });

  final AppLocalizations l10n;
  final bool asDialog;

  @override
  Widget build(BuildContext context) {
    final textPrimary = HomeColors.textPrimary(context);
    final textSecondary = HomeColors.textSecondary(context);
    final card = HomeColors.card(context);
    final divider = HomeColors.divider(context);
    final brand = HomeColors.brand(context);
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 768;

    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!asDialog) ...[
          const SizedBox(height: 12),
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
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(8, asDialog ? 4 : 8, 8, 0),
          child: Row(
            children: [
              const SizedBox(width: 48),
              Expanded(
                child: Text(
                  l10n.registrationTermsAndConditions,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: asDialog && isWide ? 20 : 18,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: textSecondary),
                tooltip: l10n.cancel,
              ),
            ],
          ),
        ),
        Divider(height: 1, color: divider),
      ],
    );

    final body = FutureBuilder<String>(
      future: LegalContent.loadTermsAndConditions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(
            child: CircularProgressIndicator(color: brand),
          );
        }
        if (snapshot.hasError ||
            snapshot.data == null ||
            snapshot.data!.trim().isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.registrationTermsAndConditions,
                style: TextStyle(color: textSecondary),
              ),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          physics: const BouncingScrollPhysics(),
          child: SelectableText(
            snapshot.data!,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: textPrimary,
            ),
          ),
        );
      },
    );

    final footer = Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(l10n.confirm),
      ),
    );

    if (asDialog) {
      final cardWidth = (isWide ? 640.0 : size.width - 32).clamp(280.0, 640.0);
      final maxHeight = size.height * (isWide ? 0.8 : 0.85);

      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: isWide ? 40 : 16,
          vertical: isWide ? 40 : 24,
        ),
        backgroundColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isWide ? 20 : 16),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: cardWidth,
            maxHeight: maxHeight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(child: body),
              footer,
            ],
          ),
        ),
      );
    }

    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final height = size.height * 0.9;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(child: body),
            footer,
          ],
        ),
      ),
    );
  }
}
