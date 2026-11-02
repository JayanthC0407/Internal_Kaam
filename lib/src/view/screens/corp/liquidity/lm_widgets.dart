import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/liquidity_overview_models.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_liquidity_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/credit_facility/cf_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/common/corp_widget_kit.dart';
import 'package:ubci_bank/src/view/screens/corp/trade_finance/widgets/lc_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// Shared pieces of the Liquidity Management Overview widgets.

/// OBDX's message when the server sent one, else [fallback].
String lmError(Object? error, String fallback) =>
    error is LmLoadError && error.message?.trim().isNotEmpty == true ? error.message! : fallback;

/// Width from which a widget's rows are a table.
const lmTableWidth = 560.0;

/// A widget: its title (with optional actions) over [child].
class LmWidgetCard extends StatelessWidget {
  const LmWidgetCard({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => CorpCardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CorpWidgetHeader(title: title, trailing: trailing),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

/// Loading and failure for a widget's data.
Widget lmLoad<T>(
  AsyncValue<T> async, {
  required String failed,
  required VoidCallback onRetry,
  required Widget Function(T) data,
}) =>
    async.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (e, _) => CfFailed(message: lmError(e, failed), onRetry: onRetry),
      data: data,
    );

/// A widget's empty state: OBDX's title and its "Check this section…" line.
class LmEmpty extends StatelessWidget {
  const LmEmpty({super.key, required this.title, this.subtitle, this.icon = Icons.inbox_outlined});

  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Icon(icon, size: 34, color: CorpColors.textSecondary(context)),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, color: CorpColors.textPrimary(context))),
            if (subtitle != null)
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: CorpColors.textSecondary(context))),
          ],
        ),
      );
}

/// A currency select for a widget (default: the bank's local currency).
class LmCurrencyField extends StatelessWidget {
  const LmCurrencyField({
    super.key,
    required this.label,
    required this.currencies,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<String> currencies;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => LcPickerField<String>(
        label: label,
        options: [
          ...currencies,
          if (selected != null && !currencies.contains(selected)) selected!,
        ],
        labelOf: (c) => c,
        selected: selected,
        onSelected: onSelected,
      );
}

/// "External" / "Internal", from `external`.
class LmAccountType extends StatelessWidget {
  const LmAccountType({super.key, required this.external});

  final bool external;

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: CfTag(external ? 'External' : 'Internal'),
      );
}

/// The accounts modals (Position By Currency, Position By Region, Accounts
/// Summary): Party Name, Account Number, Account Name, Account Type and
/// the balance, a table on wide dialogs, rows on phones; button **Ok**.
Future<void> showLmAccounts(
  BuildContext context, {
  required String title,
  required List<LmAccount> accounts,
  required String? partyName,
  String balanceLabel = 'Net Balance',
  Widget? header,
}) =>
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (header != null) ...[header, const SizedBox(height: 12)],
                LmAccountsTable(accounts: accounts, partyName: partyName, balanceLabel: balanceLabel),
              ],
            ),
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.of(dialog).pop(), child: const Text('Ok'))],
      ),
    );

class LmAccountsTable extends StatelessWidget {
  const LmAccountsTable({super.key, required this.accounts, required this.partyName, required this.balanceLabel});

  final List<LmAccount> accounts;
  final String? partyName;
  final String balanceLabel;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) return const LmEmpty(title: 'No items to display');
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= lmTableWidth) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle:
                TextStyle(fontWeight: FontWeight.w700, color: CorpColors.textSecondary(context), fontSize: 12.5),
            columns: [
              const DataColumn(label: Text('Party Name')),
              const DataColumn(label: Text('Account Number')),
              const DataColumn(label: Text('Account Name')),
              const DataColumn(label: Text('Account Type')),
              DataColumn(label: Text(balanceLabel), numeric: true),
            ],
            rows: [
              for (final a in accounts)
                DataRow(cells: [
                  DataCell(Text(partyName ?? '--')),
                  DataCell(Text(a.number)),
                  DataCell(Text(a.name ?? '--')),
                  DataCell(LmAccountType(external: a.external)),
                  DataCell(Text(cfMoney(a.money))),
                ]),
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final a in accounts)
            CfPanel(
              header: Row(children: [
                Expanded(
                  child: Text(a.number,
                      style: TextStyle(fontWeight: FontWeight.w700, color: CorpColors.textPrimary(context))),
                ),
                LmAccountType(external: a.external),
              ]),
              child: LcInfoGrid(items: [
                ('Party Name', partyName ?? '--'),
                ('Account Name', a.name ?? '--'),
                (balanceLabel, cfMoney(a.money)),
              ]),
            ),
        ],
      );
    });
  }
}
