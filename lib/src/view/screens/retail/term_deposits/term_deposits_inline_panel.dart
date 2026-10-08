import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/retail/term_deposit.dart';
import 'package:ubci_bank/src/view/providers/retail/term_deposit_providers.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/term_deposits_list_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/term_deposits/widgets/td_shared_widgets.dart';

/// The home Accounts tab's "Term Deposits" category: the active deposits
/// as cards, with "View all" for the full list.
class TermDepositsInlinePanel extends ConsumerStatefulWidget {
  const TermDepositsInlinePanel({
    super.key,
    this.onDepositTap,
    this.onViewAll,
  });

  final ValueChanged<TermDeposit>? onDepositTap;
  final VoidCallback? onViewAll;

  @override
  ConsumerState<TermDepositsInlinePanel> createState() =>
      _TermDepositsInlinePanelState();
}

class _TermDepositsInlinePanelState
    extends ConsumerState<TermDepositsInlinePanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(termDepositsProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(termDepositsProvider);
    final summary = state.summary;

    if (state.isLoading && summary == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (summary == null) {
      return TdOuterCard(
        child: TdErrorRetry(
          message: state.errorMessage ?? l10n.tdLoadFailed,
          onRetry: () => ref.read(termDepositsProvider.notifier).refresh(),
        ),
      );
    }
    final active = summary.active;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (active.isEmpty)
          TdOuterCard(child: TdMuted(l10n.tdNoDeposits))
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 640 ? 2 : 1;
              const gap = 12.0;
              final width =
                  (constraints.maxWidth - (columns - 1) * gap) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final d in active)
                    SizedBox(
                      width: width,
                      child: TdDepositCard(
                        deposit: d,
                        onTap: () => widget.onDepositTap?.call(d),
                      ),
                    ),
                ],
              );
            },
          ),
        if (widget.onViewAll != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: widget.onViewAll,
              icon: Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: HomeColors.brand(context),
              ),
              label: Text(l10n.menuTermDeposits),
            ),
          ),
        ],
      ],
    );
  }
}
