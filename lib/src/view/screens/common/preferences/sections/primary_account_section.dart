import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/constants/app_constants.dart';
import 'package:ubci_bank/src/core/models/retail/casa_account.dart';
import 'package:ubci_bank/src/view/providers/common/preferences_providers.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/providers/retail/accounts_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/widgets/preferences_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// Preferences → Primary Account Number (OBDX `sms-primary-account`):
/// "Select Primary Account" from the CASA accounts (Account Type And
/// Number, Party Name, Nick Name), "Clear Selection", Submit. Submit rebuilds
/// `operativeAccount[]` for the current entity and `PUT`s userPreferences.
class PrimaryAccountSection extends ConsumerStatefulWidget {
  const PrimaryAccountSection({super.key});

  @override
  ConsumerState<PrimaryAccountSection> createState() => _PrimaryAccountSectionState();
}

class _PrimaryAccountSectionState extends ConsumerState<PrimaryAccountSection> {
  /// The radio's account id; null before the preferences load.
  String? _selected;
  bool _initialised = false;
  bool _cleared = false;
  bool _saving = false;

  /// OBDX `currentEntity`.
  static const _entity = AppConstants.targetUnit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(casaAccountsProvider.notifier).ensureLoaded();
    });
  }

  String _typeLabel(AppLocalizations l10n, CasaAccount a) {
    final type = (a.accountType ?? '').toUpperCase();
    if (type.contains('WALLET')) return l10n.prefWalletAccount;
    if (a.isCurrent) return l10n.prefCurrentAccount;
    return l10n.prefSavingAccount;
  }

  Future<void> _submit(List<CasaAccount> accounts) async {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.read(userPreferencesProvider).valueOrNull;
    if (prefs == null) return;
    if (_selected == null && !_cleared) {
      prefSnack(context, l10n.prefNoAccountSelected);
      return;
    }
    final account = accounts.where((a) => a.id == _selected).firstOrNull;
    final body = prefs.withPrimaryAccount(_entity, accountId: _selected, displayValue: account?.displayNumber);
    setState(() => _saving = true);
    final repo = ref.read(preferencesRepositoryProvider);
    final result = await runPrefWrite(context, (c, otp) => repo.updateUserPreferences(body, challenge: c, otp: otp));
    if (!mounted) return;
    setState(() => _saving = false);
    final success = _selected != null ? l10n.prefPrimarySaved : l10n.prefPrimaryCleared;
    if (prefReportWrite(context, result, success: success)) {
      _cleared = false;
      ref.invalidate(userPreferencesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final casa = ref.watch(casaAccountsProvider);
    final prefs = ref.watch(userPreferencesProvider);

    if (prefs.hasError) {
      return PrefFailed(error: prefs.error!, onRetry: () => ref.invalidate(userPreferencesProvider));
    }
    if (casa.errorMessage != null && casa.summary == null) {
      return PrefFailed(
        error: PreferencesLoadError(casa.errorMessage),
        onRetry: () => ref.read(casaAccountsProvider.notifier).refresh(),
      );
    }
    final loaded = prefs.valueOrNull;
    if (loaded == null || casa.summary == null) return const PrefLoading();
    if (!_initialised) {
      _initialised = true;
      _selected = loaded.primaryAccountFor(_entity);
    }
    final accounts = casa.summary!.accounts;

    return LayoutBuilder(
      builder: (context, c) {
        final table = c.maxWidth >= 640;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PaySection(
              title: l10n.prefSelectPrimaryAccount,
              icon: Icons.star_outline_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (accounts.isEmpty) PayMuted(l10n.prefNoAccounts),
                  if (table && accounts.isNotEmpty) _TableHeader(l10n: l10n),
                  for (final (i, a) in accounts.indexed)
                    _AccountRow(
                      account: a,
                      typeLabel: _typeLabel(l10n, a),
                      selected: a.id == _selected,
                      table: table,
                      last: i == accounts.length - 1,
                      onTap: () => setState(() {
                        _selected = a.id;
                        _cleared = false;
                      }),
                    ),
                  const SizedBox(height: 10),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(l10n.prefNoPrimaryWish, style: TextStyle(fontSize: 13, color: HomeColors.textSecondary(context))),
                      TextButton(
                        onPressed: _selected == null
                            ? null
                            : () => setState(() {
                                  _selected = null;
                                  _cleared = true;
                                }),
                        style: TextButton.styleFrom(foregroundColor: HomeColors.brand(context)),
                        child: Text(l10n.prefClearSelection),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrefActions(
              children: [PayPrimaryButton(label: l10n.prefSubmit, loading: _saving, onPressed: () => _submit(accounts))],
            ),
          ],
        );
      },
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HomeColors.textSecondary(context));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: HomeColors.divider(context)))),
      child: Row(
        children: [
          SizedBox(width: 44, child: Text(l10n.prefSelect, style: style)),
          Expanded(flex: 5, child: Text(l10n.prefAccountTypeAndNumber, style: style)),
          Expanded(flex: 4, child: Text(l10n.prefPartyName, style: style)),
          Expanded(flex: 3, child: Text(l10n.prefNickName, style: style)),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.typeLabel,
    required this.selected,
    required this.table,
    required this.last,
    required this.onTap,
  });

  final CasaAccount account;
  final String typeLabel;
  final bool selected;
  final bool table;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final primary = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context));
    final secondary = TextStyle(fontSize: 13, color: HomeColors.textSecondary(context));
    final number = '${account.displayNumber} - $typeLabel';
    final party = account.holderName ?? '-';
    final nick = (account.nickname ?? '').trim().isEmpty ? '-' : account.nickname!;
    final radio = Icon(
      selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
      color: selected ? brand : HomeColors.textSecondary(context),
    );
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: last ? null : Border(bottom: BorderSide(color: HomeColors.divider(context).withValues(alpha: 0.7))),
          ),
          child: table
              ? Row(
                  children: [
                    SizedBox(width: 44, child: Align(alignment: AlignmentDirectional.centerStart, child: radio)),
                    Expanded(flex: 5, child: Text(number, style: primary)),
                    Expanded(flex: 4, child: Text(party, style: secondary)),
                    Expanded(flex: 3, child: Text(nick, style: secondary)),
                  ],
                )
              : Row(
                  children: [
                    radio,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(number, style: primary),
                          const SizedBox(height: 3),
                          Text('$party · $nick', style: secondary),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
