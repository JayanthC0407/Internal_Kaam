import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/transfer/transfer_theme.dart';

/// Web action row — equal-height Pay / Cancel / Back buttons.
class TransferWebActionBar extends StatelessWidget {
  const TransferWebActionBar({
    super.key,
    required this.primaryLabel,
    required this.cancelLabel,
    required this.backLabel,
    required this.onPrimary,
    required this.onCancel,
    required this.onBack,
    this.loading = false,
    this.primaryEnabled = true,
  });

  final String primaryLabel;
  final String cancelLabel;
  final String backLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onCancel;
  final VoidCallback? onBack;
  final bool loading;
  final bool primaryEnabled;

  static const Size _minSize = Size(108, 40);

  @override
  Widget build(BuildContext context) {
    final canPrimary = primaryEnabled && !loading;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton(
            onPressed: canPrimary ? onPrimary : null,
            style: FilledButton.styleFrom(
              backgroundColor: HomeColors.brand(context),
              foregroundColor: Colors.white,
              minimumSize: _minSize,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: TransferTheme.buttonLabel(context).copyWith(
                color: Colors.white,
              ),
            ),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(primaryLabel),
          ),
          FilledButton(
            onPressed: loading ? null : onCancel,
            style: FilledButton.styleFrom(
              backgroundColor: TransferTheme.webCancelBg,
              foregroundColor: Colors.white,
              minimumSize: _minSize,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: TransferTheme.buttonLabel(context).copyWith(
                color: Colors.white,
              ),
            ),
            child: Text(cancelLabel),
          ),
          OutlinedButton(
            onPressed: loading ? null : onBack,
            style: OutlinedButton.styleFrom(
              foregroundColor: TransferTheme.webLink,
              minimumSize: _minSize,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              side: const BorderSide(color: TransferTheme.webLink),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: TransferTheme.buttonLabel(context).copyWith(
                color: TransferTheme.webLink,
              ),
            ),
            child: Text(backLabel),
          ),
        ],
      ),
    );
  }
}

class TransferWebSuccessActions extends StatelessWidget {
  const TransferWebSuccessActions({
    super.key,
    required this.newTransferLabel,
    required this.doneLabel,
    required this.onNewTransfer,
    required this.onDone,
  });

  final String newTransferLabel;
  final String doneLabel;
  final VoidCallback onNewTransfer;
  final VoidCallback onDone;

  static const Size _minSize = Size(140, 40);

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: onNewTransfer,
            style: OutlinedButton.styleFrom(
              foregroundColor: brand,
              minimumSize: _minSize,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              side: BorderSide(color: brand),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: TransferTheme.buttonLabel(context).copyWith(
                color: brand,
              ),
            ),
            child: Text(newTransferLabel),
          ),
          FilledButton(
            onPressed: onDone,
            style: FilledButton.styleFrom(
              backgroundColor: brand,
              foregroundColor: Colors.white,
              minimumSize: _minSize,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: TransferTheme.buttonLabel(context).copyWith(
                color: Colors.white,
              ),
            ),
            child: Text(doneLabel),
          ),
        ],
      ),
    );
  }
}
