import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/own_account_transfer.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/home_dashboard_screen.dart';
import 'package:ubci_bank/src/view/screens/transfer/transfer_theme.dart';
import 'package:ubci_bank/src/view/screens/transfer/widgets/transfer_account_widgets.dart';
import 'package:ubci_bank/src/view/screens/transfer/widgets/transfer_shared_widgets.dart';

class TransferSuccessScreen extends ConsumerWidget {
  const TransferSuccessScreen({super.key, required this.snapshot});

  final TransferConfirmationSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pad = TransferTheme.horizontalPadding(context);
    final maxWidth = TransferTheme.contentMaxWidth(context);

    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      appBar: AppBar(
        backgroundColor: HomeColors.bg(context),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      decoration: TransferTheme.elevatedCard(context),
                      child: TransferSuccessContent(snapshot: snapshot),
                    ),
                  ),
                ),
              ),
            ),
            TransferBottomActions(
              onBack: () => Navigator.of(context).maybePop(),
              onPrimary: () => _goToHome(context, ref),
              backLabel: l10n.newTransfer,
              primaryLabel: l10n.done,
              useSafeArea: true,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _goToHome(BuildContext context, WidgetRef ref) async {
  final args = await ref.read(sessionManagerProvider).buildHomeArgs();
  if (!context.mounted) return;
  Navigator.of(context).pushNamedAndRemoveUntil(
    RoutesConst.homeScreen,
    (route) => false,
    arguments: HomeDashboardArgs(
      userName: args.userName,
      loginTrace: args.loginTrace,
      initialTab: 0,
    ),
  );
}
