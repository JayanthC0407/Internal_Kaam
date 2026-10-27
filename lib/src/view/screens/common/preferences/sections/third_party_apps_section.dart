import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/preferences/preferences_models.dart';
import 'package:ubci_bank/src/view/providers/common/preferences_providers.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/widgets/preferences_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

enum _Mode { view, edit, review, done }

/// Preferences → Third Party Applications (OBDX `third-party-consents`): a
/// tab per external app, "Application Access" Granted / Revoked and — while
/// granted — the accounts it may use per type (Current & Savings, Term
/// Deposits, Loans) with their Open Banking tasks. View → Edit → Review →
/// Confirm: `PUT userPreferences` with the status, then (granted only)
/// `PUT accountAccess/me/accessPointAccount`.
class ThirdPartyAppsSection extends ConsumerStatefulWidget {
  const ThirdPartyAppsSection({super.key, required this.userName, required this.onCancel});

  final String userName;

  /// Cancel / Ok leave the section.
  final VoidCallback onCancel;

  @override
  ConsumerState<ThirdPartyAppsSection> createState() => _ThirdPartyAppsSectionState();
}

class _ThirdPartyAppsSectionState extends ConsumerState<ThirdPartyAppsSection> {
  String? _appId;
  _Mode _mode = _Mode.view;
  ConsentAccountType _tab = ConsentAccountType.csa;

  /// Edited copy: access, and per account number its selection.
  bool? _granted;
  final _selection = <String, ConsentSelection>{};
  bool _saving = false;

  void _resetEdits() {
    _granted = null;
    _selection.clear();
  }

  void _selectApp(String id) => setState(() {
        _appId = id;
        _mode = _Mode.view;
        _tab = ConsentAccountType.csa;
        _resetEdits();
      });

  ConsentSelection _of(ConsentAccount a) =>
      _selection[a.value] ?? ConsentSelection(checked: true, tasks: a.taskIds.toSet());

  Future<void> _confirm(ThirdPartyApp app, ConsentSetup setup) async {
    final prefs = ref.read(userPreferencesProvider).valueOrNull;
    if (prefs == null) return;
    final granted = _granted ?? app.granted;
    final repo = ref.read(preferencesRepositoryProvider);
    setState(() => _saving = true);
    var result = await runPrefWrite(
      context,
      (c, otp) => repo.updateUserPreferences(prefs.withAccessPointStatus(app.id, granted), challenge: c, otp: otp),
    );
    if (granted && prefWriteDone(result) && mounted) {
      result = await runPrefWrite(
        context,
        (c, otp) => repo.updateConsentAccounts(
          accessPointId: app.id,
          setup: setup,
          selection: Map.of(_selection),
          userId: widget.userName,
          challenge: c,
          otp: otp,
        ),
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (prefWriteDone(result)) {
      ref.invalidate(userPreferencesProvider);
      ref.invalidate(consentSetupProvider(app.id));
      setState(() => _mode = _Mode.done);
    } else {
      final error = prefWriteError(context, result);
      if (error != null) prefSnack(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_mode == _Mode.done) {
      return PayResultView(
        title: l10n.prefStatusSuccessful,
        message: l10n.prefConsentSuccess,
        rows: [(l10n.prefStatus, l10n.prefStatusSuccessful), (l10n.prefMessage, l10n.prefConsentSuccess)],
        doneLabel: l10n.prefOk,
        onDone: () => setState(() {
          _mode = _Mode.view;
          _resetEdits();
        }),
      );
    }
    return ref.watch(thirdPartyAppsProvider).when(
          loading: () => const PrefLoading(),
          error: (e, _) => PrefFailed(error: e, onRetry: () => ref.invalidate(userPreferencesProvider)),
          data: (apps) {
            if (apps.isEmpty) {
              return PayCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PayMuted(l10n.prefNoThirdPartyApps),
                    const SizedBox(height: 12),
                    PrefActions(children: [PayPrimaryButton(label: l10n.prefOk, onPressed: widget.onCancel)]),
                  ],
                ),
              );
            }
            final app = apps.firstWhere((a) => a.id == _appId, orElse: () => apps.first);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AppTabs(apps: apps, selected: app.id, enabled: _mode == _Mode.view, onSelect: _selectApp),
                const SizedBox(height: 14),
                if (_mode == _Mode.review) ...[
                  PrefReviewBanner(message: l10n.prefConsentReview),
                  const SizedBox(height: 14),
                ],
                _AppBody(
                  app: app,
                  mode: _mode,
                  granted: _granted ?? app.granted,
                  tab: _tab,
                  selectionOf: _of,
                  onGranted: (v) => setState(() => _granted = v),
                  onTab: (t) => setState(() => _tab = t),
                  onAccount: (a, checked) => setState(() {
                    final current = _of(a);
                    // Unchecking an account clears its tasks; checking it maps them all.
                    _selection[a.value] = current.copyWith(checked: checked, tasks: checked ? a.taskIds.toSet() : {});
                  }),
                  onTask: (a, task, on) => setState(() {
                    final current = _of(a);
                    final tasks = {...current.tasks};
                    on ? tasks.add(task) : tasks.remove(task);
                    _selection[a.value] = current.copyWith(tasks: tasks, checked: tasks.isNotEmpty || a.taskIds.isEmpty);
                  }),
                  actions: (setup) => switch (_mode) {
                    _Mode.view => [
                        PayPrimaryButton(label: l10n.prefEdit, onPressed: () => setState(() => _mode = _Mode.edit)),
                        PaySecondaryButton(label: l10n.prefCancel, onPressed: widget.onCancel),
                      ],
                    _Mode.edit => [
                        PayPrimaryButton(label: l10n.prefSave, onPressed: () => setState(() => _mode = _Mode.review)),
                        PaySecondaryButton(
                          label: l10n.prefBack,
                          onPressed: () => setState(() {
                            _mode = _Mode.view;
                            _resetEdits();
                          }),
                        ),
                        PaySecondaryButton(label: l10n.prefCancel, onPressed: widget.onCancel),
                      ],
                    _ => [
                        PayPrimaryButton(
                          label: l10n.prefConfirm,
                          loading: _saving,
                          // Revoking needs no account setup; granting sends it.
                          onPressed: setup == null && (_granted ?? app.granted)
                              ? null
                              : () => _confirm(app, setup ?? const ConsentSetup({})),
                        ),
                        PaySecondaryButton(label: l10n.prefBack, onPressed: () => setState(() => _mode = _Mode.edit)),
                        PaySecondaryButton(label: l10n.prefCancel, onPressed: widget.onCancel),
                      ],
                  },
                ),
              ],
            );
          },
        );
  }
}

/// One chip per app: its logo (or initials) and name.
class _AppTabs extends StatelessWidget {
  const _AppTabs({required this.apps, required this.selected, required this.enabled, required this.onSelect});

  final List<ThirdPartyApp> apps;
  final String selected;
  final bool enabled;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (i, app) in apps.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            ChoiceChip(
              selected: app.id == selected,
              onSelected: enabled ? (_) => onSelect(app.id) : null,
              showCheckmark: false,
              selectedColor: brand.withValues(alpha: 0.14),
              backgroundColor: HomeColors.card(context),
              side: BorderSide(color: app.id == selected ? brand : HomeColors.divider(context)),
              avatar: app.logo != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.memory(app.logo!, width: 22, height: 22, fit: BoxFit.contain))
                  : PayAvatar(name: app.name, size: 22),
              label: Text(
                app.name,
                style: TextStyle(
                  fontWeight: app.id == selected ? FontWeight.w700 : FontWeight.w500,
                  color: app.id == selected ? brand : HomeColors.textPrimary(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppBody extends ConsumerWidget {
  const _AppBody({
    required this.app,
    required this.mode,
    required this.granted,
    required this.tab,
    required this.selectionOf,
    required this.onGranted,
    required this.onTab,
    required this.onAccount,
    required this.onTask,
    required this.actions,
  });

  final ThirdPartyApp app;
  final _Mode mode;
  final bool granted;
  final ConsentAccountType tab;
  final ConsentSelection Function(ConsentAccount) selectionOf;
  final ValueChanged<bool> onGranted;
  final ValueChanged<ConsentAccountType> onTab;
  final void Function(ConsentAccount, bool) onAccount;
  final void Function(ConsentAccount, String, bool) onTask;
  final List<Widget> Function(ConsentSetup? setup) actions;

  String _typeLabel(AppLocalizations l10n, ConsentAccountType t) => switch (t) {
        ConsentAccountType.csa => l10n.prefCurrentAndSavings,
        ConsentAccountType.trd => l10n.prefTermDeposits,
        ConsentAccountType.lon => l10n.prefLoans,
      };

  String _taskLabel(AppLocalizations l10n, String task) => switch (task) {
        'OB_I' => l10n.prefTaskObInquiries,
        'OB_P' => l10n.prefTaskObPayments,
        _ => task,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final editable = mode == _Mode.edit;
    final setupAsync = ref.watch(consentSetupProvider(app.id));
    final brand = HomeColors.brand(context);

    Widget accounts() => setupAsync.when(
          loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => PrefFailed(error: e, onRetry: () => ref.invalidate(consentSetupProvider(app.id))),
          data: (setup) {
            final list = setup.groups[tab]?.accounts ?? const <ConsentAccount>[];
            if (list.isEmpty) return PayMuted(l10n.prefNoConsentAccounts);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final a in list) ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: brand,
                    value: selectionOf(a).checked,
                    onChanged: editable ? (v) => onAccount(a, v ?? false) : null,
                    title: Text(
                      a.displayValue,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
                    ),
                  ),
                  for (final task in a.taskIds.isEmpty ? const ['ALL'] : a.taskIds)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 32),
                      child: CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: brand,
                        value: task == 'ALL' ? selectionOf(a).checked : selectionOf(a).tasks.contains(task),
                        onChanged: editable
                            ? (v) => task == 'ALL' ? onAccount(a, v ?? false) : onTask(a, task, v ?? false)
                            : null,
                        title: Text(
                          task == 'ALL' ? l10n.prefMapAllTransactions : _taskLabel(l10n, task),
                          style: TextStyle(fontSize: 13, color: HomeColors.textSecondary(context)),
                        ),
                      ),
                    ),
                  Divider(height: 1, color: HomeColors.divider(context)),
                ],
              ],
            );
          },
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaySection(
          title: app.name,
          icon: Icons.apps_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrefSwitchRow(
                label: '${l10n.prefApplicationAccess} · ${granted ? l10n.prefGranted : l10n.prefRevoked}',
                value: granted,
                onChanged: editable ? onGranted : null,
              ),
              if (granted) ...[
                const SizedBox(height: 12),
                PaySegmented<ConsentAccountType>(
                  options: [for (final t in ConsentAccountType.values) (t, _typeLabel(l10n, t))],
                  selected: tab,
                  onChanged: onTab,
                ),
                const SizedBox(height: 8),
                accounts(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        PrefActions(children: actions(setupAsync.valueOrNull)),
      ],
    );
  }
}
