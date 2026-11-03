import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:demo_bank/src/core/models/common/money_amount.dart';
import 'package:demo_bank/src/core/models/corp/corp_loans_models.dart';
import 'package:demo_bank/src/core/utils/common/money_format.dart';
import 'package:demo_bank/src/core/utils/common/statement_file_saver.dart';
import 'package:demo_bank/src/infra/network/response_handler.dart';
import 'package:demo_bank/src/view/providers/corp/corp_loans_providers.dart';
import 'package:demo_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:demo_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:demo_bank/src/view/widgets/design_page.dart';

// TODO(l10n): Corporate screens use English labels, like the rest of the
// Corporate dashboard (see `CorpNavDestination`).

String corpMoney(MoneyAmount? m, [String fallbackCurrency = '']) =>
    m == null ? '-' : MoneyFormat.format(m.amount, currencyCode: m.currency ?? fallbackCurrency);

Widget corpLoading() => const DesignCard(child: Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())));

Widget corpFailed(Object error, VoidCallback retry, {String fallback = 'This could not be loaded.'}) => PayErrorRetry(
      message: error is CorpLoansLoadError && error.message != null ? error.message! : fallback,
      onRetry: retry,
    );

void corpSnack(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

/// Saves downloaded [bytes] (a PDF unless [mimeType] says otherwise).
Future<void> corpSaveFile(
  BuildContext context,
  Future<ResponseHandler<List<int>>> download,
  String fileName, {
  String mimeType = 'application/pdf',
}) async {
  final r = await download;
  if (!context.mounted) return;
  if (r is Success<List<int>> && r.data != null) {
    try {
      await StatementFileSaver.saveStatement(bytes: r.data!, fileName: fileName, mimeType: mimeType);
      return;
    } catch (_) {}
  }
  if (context.mounted) corpSnack(context, 'The file could not be downloaded.');
}

/// "Loan Account": OBDX's account-input over `corporateloan` (LN_I_CDD).
class CorpLoanAccountField extends ConsumerWidget {
  const CorpLoanAccountField({super.key, required this.selected, required this.onChanged});

  final CorpLoan? selected;
  final ValueChanged<CorpLoan> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loans = ref.watch(corpLoansProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesignBoxSelect(
          label: 'Loan Account',
          value: selected?.title,
          placeholder: 'Please Select',
          loading: loans.isLoading,
          onTap: loans.valueOrNull == null
              ? null
              : () async {
                  final list = loans.value!;
                  final picked = await showPayPicker<String>(
                    context,
                    title: 'Loan Account',
                    selected: selected?.id,
                    empty: 'You have no loan accounts.',
                    options: [
                      for (final l in list)
                        PayOption(
                          value: l.id,
                          title: l.displayNumber,
                          subtitle: l.productName,
                          trailing: l.outstanding == null ? null : corpMoney(l.outstanding, l.currency),
                          icon: Icons.account_balance_outlined,
                        ),
                    ],
                  );
                  if (picked != null) onChanged(list.firstWhere((l) => l.id == picked));
                },
        ),
        if (loans.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: corpFailed(loans.error!, () => ref.invalidate(corpLoansProvider), fallback: 'Loan accounts could not be loaded.'),
          ),
      ],
    );
  }
}

/// A header row of a table, in the designs' grey band.
class CorpTableHeader extends StatelessWidget {
  const CorpTableHeader({super.key, required this.cells, required this.flex});

  final List<String> cells;
  final List<int> flex;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: HomeColors.textSecondary(context));
    return Container(
      color: HomeColors.bg(context),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [for (final (i, c) in cells.indexed) Expanded(flex: flex[i], child: Text(c, style: style))],
      ),
    );
  }
}

/// "No … found" inside a card.
class CorpEmpty extends StatelessWidget {
  const CorpEmpty(this.text, {super.key, this.icon = Icons.inbox_outlined});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, size: 36, color: HomeColors.textSecondary(context)),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: HomeColors.textSecondary(context))),
          ],
        ),
      );
}
