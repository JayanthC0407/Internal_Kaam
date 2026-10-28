import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/retail/certificate_models.dart';
import 'package:ubci_bank/src/core/models/retail/nomination_models.dart';
import 'package:ubci_bank/src/view/providers/retail/nominations_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// Nominations — OBDX `nominee/nominations` and its lists, in the
/// designer's layout (UI designs 2, 2026-10-27): Account Category, View
/// Nominees of (Specific / All) and Account Number with Reset / Apply,
/// then the accounts with Holding Pattern, Nominee and OBDX's Action.
/// View and View/Edit open View Nominee (read only; its Edit / Delete are
/// write flows, not built). Add (Add Nominee, Not Working in UAT) is not
/// built either; Know More shows OBDX's joint-account note.
/// Evidence: docs/obdx/features/nominations.md.
class NominationsScreen extends ConsumerStatefulWidget {
  const NominationsScreen({super.key, required this.roles, this.embedded = false, this.onBack});

  /// The login profile's `userProfile.roles`: the Account Category options.
  final List<String> roles;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  ConsumerState<NominationsScreen> createState() => _NominationsScreenState();
}

String nominationCategoryLabel(AppLocalizations l10n, NominationCategory c) => switch (c) {
      NominationCategory.casa => l10n.nomCategoryCasa,
      NominationCategory.termDeposits => l10n.nomCategoryTd,
      NominationCategory.recurringDeposits => l10n.nomCategoryRd,
    };

String nomineeActionLabel(AppLocalizations l10n, NomineeAction a) => switch (a) {
      NomineeAction.viewEdit => l10n.nomActionViewEdit,
      NomineeAction.add => l10n.nomActionAdd,
      NomineeAction.view => l10n.nomActionView,
      NomineeAction.knowMore => l10n.nomActionKnowMore,
    };

class _NominationsScreenState extends ConsumerState<NominationsScreen> {
  NominationCategory? _category;
  bool _all = false;
  CertificateAccount? _account;
  bool _showErrors = false;

  /// The search Apply made: category and account (null = All Accounts).
  (NominationCategory, String?)? _applied;

  /// View Nominee shown in place of the list.
  NominationRow? _viewing;

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  void _onAction(NominationRow row) {
    final l10n = AppLocalizations.of(context);
    switch (row.action) {
      case NomineeAction.view:
      case NomineeAction.viewEdit:
        setState(() => _viewing = row);
      case NomineeAction.add:
        _snack('${l10n.nomAddNominee} · ${l10n.featureComingSoon}');
      case NomineeAction.knowMore:
        showDialog<void>(
          context: context,
          builder: (dialog) => AlertDialog(
            content: Text(l10n.nomJointNote),
            actions: [FilledButton(onPressed: () => Navigator.of(dialog).pop(), child: Text(l10n.payBillOk))],
          ),
        );
    }
  }

  /// OBDX Reset: Current & Savings, Specific Account (hooks.js:56-59).
  void _reset() => setState(() {
        _category = null;
        _all = false;
        _account = null;
        _showErrors = false;
        _applied = null;
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewing = _viewing;
    if (viewing != null) {
      return _ViewNominee(row: viewing, onBack: () => setState(() => _viewing = null));
    }
    final categories = NominationCategory.fromRoles(widget.roles);
    return PayMenuPage(
      title: l10n.nomTitle,
      onBack: widget.embedded ? widget.onBack : null,
      builder: (context, wide) {
        if (categories.isEmpty) return PayCard(child: PayMuted(l10n.nomNoAccounts));
        // OBDX starts and resets on Current & Savings when the user has it.
        final category = _category ??
            (categories.contains(NominationCategory.casa) ? NominationCategory.casa : categories.first);
        final accounts = ref.watch(nominationPickerAccountsProvider(category));
        final list = accounts.valueOrNull;
        final account = _account != null && (list?.any((a) => a.id == _account!.id) ?? false)
            ? _account
            : (list == null ? null : CertificateAccount.initial(list));

        final categoryField = PayBoxedPicker(
          label: l10n.nomAccountCategory,
          value: nominationCategoryLabel(l10n, category),
          onTap: categories.length < 2
              ? null
              : () async {
                  final picked = await showPayPicker<NominationCategory>(
                    context,
                    title: l10n.nomAccountCategory,
                    selected: category,
                    options: [for (final c in categories) PayOption(value: c, title: nominationCategoryLabel(l10n, c))],
                  );
                  if (picked != null && picked != category && mounted) {
                    setState(() {
                      _category = picked;
                      _account = null;
                    });
                  }
                },
        );
        final accountField = accounts.hasError
            ? PayErrorRetry(
                message: _message(l10n, accounts.error),
                onRetry: () => ref.invalidate(nominationPickerAccountsProvider(category)),
              )
            : PayBoxedPicker(
                label: l10n.nomAccountNumber,
                required: true,
                loading: list == null,
                value: account?.display,
                placeholder: l10n.addBillerSelect,
                error: _showErrors && account == null ? l10n.addBillerFieldRequired(l10n.nomAccountNumber) : null,
                onTap: list == null || list.isEmpty
                    ? null
                    : () async {
                        final picked = await showPayPicker<String>(
                          context,
                          title: l10n.nomAccountNumber,
                          selected: account?.id,
                          options: [for (final a in list) PayOption(value: a.id, title: a.display)],
                        );
                        if (picked != null && mounted) setState(() => _account = list.firstWhere((a) => a.id == picked));
                      },
              );
        final viewOf = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.nomViewNomineesOf,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: HomeColors.textSecondary(context)),
            ),
            const SizedBox(height: 8),
            PaySegmented<bool>(
              options: [(false, l10n.nomSpecificAccount), (true, l10n.nomAllAccounts)],
              selected: _all,
              onChanged: (v) => setState(() => _all = v),
            ),
          ],
        );
        final buttons = Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Wrap(
            spacing: 12,
            children: [
              SizedBox(width: 130, child: PaySecondaryButton(label: l10n.nomReset, onPressed: _reset)),
              SizedBox(
                width: 130,
                child: PayPrimaryButton(
                  label: l10n.nomApply,
                  onPressed: () {
                    if (!_all && account == null) return setState(() => _showErrors = true);
                    setState(() {
                      _showErrors = false;
                      _applied = (category, _all ? null : account!.id);
                    });
                  },
                ),
              ),
            ],
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PayCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: categoryField),
                        const SizedBox(width: 24),
                        Expanded(child: viewOf),
                      ],
                    )
                  else ...[
                    categoryField,
                    const SizedBox(height: 14),
                    viewOf,
                  ],
                  if (!_all) ...[
                    const SizedBox(height: 14),
                    wide
                        ? Row(children: [Expanded(child: accountField), const SizedBox(width: 24), const Spacer()])
                        : accountField,
                  ],
                  const SizedBox(height: 18),
                  buttons,
                ],
              ),
            ),
            if (_applied != null) ...[const SizedBox(height: 18), _results(l10n, wide, _applied!)],
          ],
        );
      },
    );
  }

  String _message(AppLocalizations l10n, Object? error) =>
      error is NominationsLoadError && error.message != null ? error.message! : l10n.nomLoadFailed;

  Widget _results(AppLocalizations l10n, bool wide, (NominationCategory, String?) applied) {
    final (category, accountId) = applied;
    final rows = ref.watch(nominationRowsProvider(category));
    return rows.when(
      loading: () => const PayCard(
        child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      ),
      error: (e, _) => PayErrorRetry(
        message: _message(l10n, e),
        onRetry: () => ref.invalidate(nominationRowsProvider(category)),
      ),
      data: (all) {
        // Specific Account keeps the chosen account only (hooks.js:144-160).
        final list = accountId == null ? all : all.where((r) => r.accountId == accountId).toList();
        if (list.isEmpty) return PayCard(child: PayMuted(l10n.nomNoAccounts));
        final primary = HomeColors.textPrimary(context);
        final secondary = HomeColors.textSecondary(context);
        final brand = HomeColors.brand(context);
        Widget action(NominationRow r) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => _onAction(r),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
                child: Text(nomineeActionLabel(l10n, r.action), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            );
        String holding(NominationRow r) => r.joint ? l10n.nomJoint : l10n.nomSingle;
        String nominee(NominationRow r) => r.registered ? l10n.nomRegistered : l10n.nomNotRegistered;

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, r) in list.indexed) ...[
                if (i > 0) const SizedBox(height: 10),
                PayCard(
                  padding: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.accountDisplay, style: TextStyle(fontWeight: FontWeight.w700, color: brand)),
                      const SizedBox(height: 4),
                      Text(r.primaryHolder ?? '', style: TextStyle(color: primary)),
                      const SizedBox(height: 4),
                      Text('${holding(r)}  •  ${nominee(r)}', style: TextStyle(fontSize: 13, color: secondary)),
                      action(r),
                    ],
                  ),
                ),
              ],
            ],
          );
        }
        return PayCard(
          padding: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PayTableHeader(cells: [
                (l10n.nomAccountNumber, 3),
                (l10n.nomPrimaryHolderName, 3),
                (l10n.nomHoldingPattern, 2),
                (l10n.nomNominee, 2),
                (l10n.nomAction, 2),
              ]),
              for (final (i, r) in list.indexed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: i == list.length - 1 ? null : Border(bottom: BorderSide(color: HomeColors.divider(context))),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(r.accountDisplay, style: TextStyle(fontWeight: FontWeight.w700, color: brand))),
                      Expanded(flex: 3, child: Text(r.primaryHolder ?? '', style: TextStyle(color: primary))),
                      Expanded(flex: 2, child: Text(holding(r), style: TextStyle(color: primary))),
                      Expanded(flex: 2, child: Text(nominee(r), style: TextStyle(color: secondary))),
                      Expanded(flex: 2, child: action(r)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// View Nominee (`nominee/view-nominee`): Nominee Details and, for a
/// minor, Guardian Details. Edit and Delete are writes, not built.
class _ViewNominee extends ConsumerWidget {
  const _ViewNominee({required this.row, required this.onBack});

  final NominationRow row;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final details = ref.watch(nomineeDetailsProvider(row.accountId));
    void soon(String what) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what · ${l10n.featureComingSoon}')));
    return PayMenuPage(
      title: l10n.nomViewNominee,
      subtitle: row.accountDisplay,
      onBack: onBack,
      builder: (context, wide) => details.when(
        loading: () => const PayCard(
          child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        ),
        error: (e, _) => PayErrorRetry(
          message: e is NominationsLoadError && e.message != null ? e.message! : l10n.nomLoadFailed,
          onRetry: () => ref.invalidate(nomineeDetailsProvider(row.accountId)),
        ),
        data: (d) {
          final n = d.nominee;
          String address(NomineeAddress a) => a.lines(a.country == null ? null : d.countries[a.country]).join(', ');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PaySummaryCard(
                icon: Icons.person_outline_rounded,
                title: l10n.nomNomineeDetails,
                subtitle: row.accountDisplay,
                rows: [
                  (l10n.nomFullName, n.name),
                  if (n.dateOfBirth != null) (l10n.nomDateOfBirth, payDate(n.dateOfBirth)),
                  if (n.relation != null) (l10n.nomRelationship, d.relations[n.relation] ?? n.relation!),
                  (l10n.nomAddress, address(n.address)),
                ].where((r) => r.$2.isNotEmpty).toList(),
              ),
              if (n.minor) ...[
                const SizedBox(height: 14),
                PaySummaryCard(
                  icon: Icons.shield_outlined,
                  title: l10n.nomGuardianDetails,
                  subtitle: n.name,
                  rows: [
                    (l10n.nomFullName, n.guardianName ?? ''),
                    (l10n.nomAddress, n.guardianAddress == null ? '' : address(n.guardianAddress!)),
                  ].where((r) => r.$2.isNotEmpty).toList(),
                ),
              ],
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  // OBDX's Edit and Delete: only for a single holder (View/Edit).
                  if (row.action == NomineeAction.viewEdit) ...[
                    SizedBox(
                      width: 140,
                      child: PaySecondaryButton(
                        label: l10n.nomEdit,
                        icon: Icons.edit_outlined,
                        onPressed: () => soon(l10n.nomEdit),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: PaySecondaryButton(
                        label: l10n.nomDelete,
                        icon: Icons.delete_outline_rounded,
                        onPressed: () => soon(l10n.nomDelete),
                      ),
                    ),
                  ],
                  SizedBox(width: 140, child: PayPrimaryButton(label: l10n.nomBack, onPressed: onBack)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
