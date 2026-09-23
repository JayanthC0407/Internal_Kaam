import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/corp/corp_account.dart';
import 'package:ubci_bank/src/core/models/corp/corp_currency.dart';
import 'package:ubci_bank/src/core/utils/corp/corp_money_format.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_accounts_providers.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_profile_providers.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_colors.dart';
import 'package:ubci_bank/src/view/screens/corp/widgets/corp_card_shell.dart';

/// OBDX `currency-exposure` — the party's cash position per currency.
///
/// There is no dedicated exposure endpoint: OBDX derives this from the
/// accounts list, and so does this widget. `common/v1/currency` is used
/// only to label each row ("UAE Dirham" rather than "AED"), and a failed
/// lookup degrades to the raw ISO code rather than blocking the widget.
///
/// **Scope: CASA accounts only.** Deposits and Loans load lazily when their
/// tab is first opened, so including them would make the figures change
/// underneath the user depending on what they had browsed. Loans are a
/// liability besides, and netting them against cash would misrepresent the
/// position.
///
/// Takes no constructor arguments so the widget registry can build it from
/// a `componentName` alone.
class CorpCurrencyExposureWidget extends ConsumerWidget {
  const CorpCurrencyExposureWidget({super.key});

  /// Builds one row per currency, largest absolute exposure first.
  static List<CorpCurrencyExposure> buildExposures({
    required CorpAccountsSummary summary,
    Map<String, CorpCurrency> currencies = const {},
  }) {
    final totals = <String, double>{};
    final counts = <String, int>{};

    for (final account in summary.accountsIn(CorpAccountGroup.casa)) {
      final balance = account.displayBalance;
      if (balance == null) continue;
      final code =
          (balance.currency ?? account.currencyCode).trim().toUpperCase();
      if (code.isEmpty) continue;
      totals.update(code, (value) => value + balance.amount,
          ifAbsent: () => balance.amount);
      counts.update(code, (value) => value + 1, ifAbsent: () => 1);
    }

    final exposures = [
      for (final entry in totals.entries)
        CorpCurrencyExposure(
          currencyCode: entry.key,
          total: entry.value,
          accountCount: counts[entry.key] ?? 0,
          label: currencies[entry.key]?.label,
        ),
    ];

    exposures.sort((a, b) => b.total.abs().compareTo(a.total.abs()));
    return exposures;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsState = ref.watch(corpAccountsProvider);
    final currencies = ref.watch(corpProfileProvider).currencies;
    final exposures = buildExposures(
      summary: accountsState.summary,
      currencies: currencies,
    );

    return CorpCardShell(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CorpCardHeader(
            title: 'Currency Exposure',
            trailing: exposures.length > 1
                ? Text(
                    '${exposures.length} currencies',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: CorpColors.textSecondary(context),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          _buildBody(context, accountsState, exposures),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CorpAccountsState state,
    List<CorpCurrencyExposure> exposures,
  ) {
    if (state.isLoading && exposures.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (exposures.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            state.errorMessage ?? 'No currency exposure to show.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: CorpColors.textSecondary(context),
            ),
          ),
        ),
      );
    }

    // Bars are scaled against the largest absolute position so a single
    // dominant currency does not flatten the rest to invisibility.
    final largest = exposures
        .map((exposure) => exposure.total.abs())
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Column(
      children: [
        for (var i = 0; i < exposures.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _ExposureRow(exposure: exposures[i], largestAbsolute: largest),
        ],
      ],
    );
  }
}

class _ExposureRow extends StatelessWidget {
  const _ExposureRow({required this.exposure, required this.largestAbsolute});

  final CorpCurrencyExposure exposure;
  final double largestAbsolute;

  @override
  Widget build(BuildContext context) {
    final isNegative = exposure.isNegative;
    final barColor = isNegative
        ? CorpColors.negativeBalance(context)
        : CorpColors.brand(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: barColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                exposure.currencyCode,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: barColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                exposure.label ?? exposure.currencyCode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: CorpColors.textSecondary(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              CorpMoneyFormat.format(
                exposure.total,
                currencyCode: exposure.currencyCode,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isNegative
                    ? CorpColors.negativeBalance(context)
                    : CorpColors.textPrimary(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: exposure.shareOf(largestAbsolute),
            minHeight: 6,
            backgroundColor: CorpColors.divider(context),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          exposure.accountCount == 1
              ? '1 account'
              : '${exposure.accountCount} accounts',
          style: TextStyle(
            fontSize: 11,
            color: CorpColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}
