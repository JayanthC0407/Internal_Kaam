import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/account_settings/account_settings_models.dart';
import 'package:ubci_bank/src/view/providers/common/account_settings_providers.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/widgets/preferences_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

String alertModeLabel(AppLocalizations l10n, AlertMode m) => switch (m) {
      AlertMode.push => l10n.asPush,
      AlertMode.sms => l10n.asSms,
      AlertMode.onScreen => l10n.asOnScreen,
      AlertMode.email => l10n.asEmail,
    };

/// `9090 0929 0976 0982`.
String _grouped(String digits) {
  final plain = digits.replaceAll(RegExp(r'\s+'), '');
  final out = StringBuffer();
  for (var i = 0; i < plain.length; i++) {
    if (i > 0 && i % 4 == 0) out.write(' ');
    out.write(plain[i]);
  }
  return out.toString();
}

/// Preferences → Alerts Subscription (OBDX `alerts/user-alerts-subscription`),
/// in the app's design: the user strip; Select Module and Select Party
/// (an account, or the party for party-level modules), with Search Party
/// to narrow it and Apply to load its alerts; then each alert with its
/// four channels (Push Notification, SMS, On Screen, Email) and "Map All
/// Modes". Save writes that account's alerts in that module — OBDX's
/// `actionSubscriptions` POST / PUT, or DELETE when nothing is left.
class AlertsSubscriptionSection extends ConsumerStatefulWidget {
  const AlertsSubscriptionSection({super.key});

  @override
  ConsumerState<AlertsSubscriptionSection> createState() => _AlertsSubscriptionSectionState();
}

class _AlertsSubscriptionSectionState extends ConsumerState<AlertsSubscriptionSection> {
  String? _moduleId;
  AlertTarget? _target;
  final _search = TextEditingController();

  /// The account / party whose alerts are on screen (after Apply).
  AlertTarget? _applied;

  /// eventId → channels, as edited; [_loaded] is what the bank has.
  Map<String, Set<AlertMode>> _selection = {};
  Map<String, Set<AlertMode>> _loaded = {};
  bool _saving = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetFor(String? moduleId) => setState(() {
        _moduleId = moduleId;
        _target = null;
        _applied = null;
        _selection = {};
        _loaded = {};
        _search.clear();
      });

  AlertSubscription? _subscriptionFor(List<AlertSubscription> subs, AlertModule module) {
    final level = module.partyLevel ? 'PARTY' : 'ACCOUNT';
    return subs.where((s) => s.level == level).firstOrNull ?? (subs.length == 1 && subs.first.level.isEmpty ? subs.first : null);
  }

  void _apply(AlertModule module, List<AlertSubscription> subs) {
    final target = _target;
    if (target == null) {
      prefSnack(context, AppLocalizations.of(context).asSelectPartyFirst);
      return;
    }
    final modes = _subscriptionFor(subs, module)?.modesFor(module.id, target.value) ?? {};
    setState(() {
      _applied = target;
      _loaded = {for (final e in modes.entries) e.key: {...e.value}};
      _selection = {for (final e in modes.entries) e.key: {...e.value}};
    });
  }

  Future<void> _pickModule(List<AlertModule> modules, String current) async {
    final picked = await showPayPicker<String>(
      context,
      title: AppLocalizations.of(context).asSelectModule,
      selected: current,
      options: [for (final m in modules) PayOption(value: m.id, title: m.description)],
    );
    if (picked != null && picked != current && mounted) _resetFor(picked);
  }

  Future<void> _pickTarget(List<AlertTarget> targets, Set<String> subscribed) async {
    final l10n = AppLocalizations.of(context);
    final q = _search.text.trim().toLowerCase();
    final shown = q.isEmpty ? targets : targets.where((t) => t.displayValue.toLowerCase().contains(q)).toList();
    final picked = await showPayPicker<String>(
      context,
      title: l10n.asSelectParty,
      selected: _target?.value,
      empty: l10n.asNoParties,
      options: [
        for (final t in shown)
          PayOption(value: t.value, title: t.displayValue, trailing: subscribed.contains(t.value) ? l10n.asSubscribed : null),
      ],
    );
    if (picked != null && mounted) setState(() => _target = targets.firstWhere((t) => t.value == picked));
  }

  Future<void> _save(AlertsUser user, AlertModule module, List<AlertEvent> events, List<AlertSubscription> subs) async {
    final l10n = AppLocalizations.of(context);
    final target = _applied;
    if (target == null) {
      prefSnack(context, l10n.asSelectPartyFirst);
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(accountSettingsRepositoryProvider);
    final result = await runPrefWrite(
      context,
      (c, otp) => repo.saveAlerts(
        user: user,
        module: module,
        target: target,
        events: events,
        selection: _selection,
        existing: _subscriptionFor(subs, module),
        challenge: c,
        otp: otp,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (prefReportWrite(context, result, success: l10n.asSaved)) {
      _loaded = {for (final e in _selection.entries) e.key: {...e.value}};
      ref.invalidate(alertSubscriptionsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(alertsUserProvider);
    final modules = ref.watch(alertModulesProvider);
    final events = ref.watch(alertEventsProvider);
    final subs = ref.watch(alertSubscriptionsProvider);
    if (user.hasError) return PrefFailed(error: user.error!, onRetry: () => ref.invalidate(alertsUserProvider));
    if (modules.hasError) return PrefFailed(error: modules.error!, onRetry: () => ref.invalidate(alertModulesProvider));
    if (events.hasError) return PrefFailed(error: events.error!, onRetry: () => ref.invalidate(alertEventsProvider));
    if (subs.hasError) return PrefFailed(error: subs.error!, onRetry: () => ref.invalidate(alertSubscriptionsProvider));
    if (!user.hasValue || !modules.hasValue || !events.hasValue || !subs.hasValue) return const PrefLoading();
    final moduleList = modules.value!;
    if (moduleList.isEmpty) return PayCard(child: PayMuted(AppLocalizations.of(context).asNoModules));

    // OBDX starts on Current and Savings (`CH`).
    final module = moduleList.where((m) => m.id == _moduleId).firstOrNull ??
        moduleList.where((m) => m.id == 'CH').firstOrNull ??
        moduleList.first;
    final moduleEvents = [for (final e in events.value!) if (e.moduleType == module.id) e];
    final subscription = _subscriptionFor(subs.value!, module);
    final targets = ref.watch(alertTargetsProvider(module.id));

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 640;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _UserStrip(user: user.value!, wide: wide),
            const SizedBox(height: 22),
            _pairs(wide, [
              _SelectBox(
                label: AppLocalizations.of(context).asSelectModule,
                value: module.description,
                onTap: () => _pickModule(moduleList, module.id),
              ),
              _SelectBox(
                label: AppLocalizations.of(context).asSelectParty,
                value: _target?.displayValue,
                loading: targets.isLoading,
                onTap: targets.valueOrNull == null
                    ? null
                    : () => _pickTarget(targets.value!, subscription?.subscribedTargets(module.id) ?? const {}),
              ),
            ]),
            const SizedBox(height: 16),
            _pairs(wide, [
              _SearchBox(controller: _search, hint: AppLocalizations.of(context).asSearchParty, onSubmitted: () {
                // One match is picked straight away.
                final q = _search.text.trim().toLowerCase();
                final hits = (targets.valueOrNull ?? const <AlertTarget>[]).where((t) => t.displayValue.toLowerCase().contains(q)).toList();
                if (hits.length == 1) setState(() => _target = hits.single);
              }),
              _DesignButton(label: AppLocalizations.of(context).asApply, onPressed: () => _apply(module, subs.value!)),
            ]),
            const SizedBox(height: 16),
            _pairs(wide, [
              Center(
                child: Text(
                  AppLocalizations.of(context).asSubscribeModes,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _DesignButton(
                      label: AppLocalizations.of(context).prefCancel,
                      onPressed: _applied == null
                          ? null
                          : () => setState(() => _selection = {for (final e in _loaded.entries) e.key: {...e.value}}),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _DesignButton(
                      label: AppLocalizations.of(context).prefSave,
                      loading: _saving,
                      onPressed: _applied == null ? null : () => _save(user.value!, module, moduleEvents, subs.value!),
                    ),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 14),
            _AlertsList(
              events: moduleEvents,
              selection: _selection,
              enabled: _applied != null,
              onChanged: (s) => setState(() => _selection = s),
            ),
          ],
        );
      },
    );
  }

  /// Two side by side on wide layouts, stacked on a phone.
  Widget _pairs(bool wide, List<Widget> pair) => wide
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [Expanded(child: pair[0]), const SizedBox(width: 84), Expanded(child: pair[1])],
        )
      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [pair[0], const SizedBox(height: 12), pair[1]]);
}

/// Party Id (grouped, with copy), Party Name, User Name, Status.
class _UserStrip extends StatelessWidget {
  const _UserStrip({required this.user, required this.wide});

  final AlertsUser user;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brand = HomeColors.brand(context);
    final label = TextStyle(fontSize: 14, color: HomeColors.textSecondary(context));
    final value = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: brand);

    Widget cell(String title, Widget child) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [Text(title, style: label), const SizedBox(height: 10), child],
        );

    final cells = [
      cell(
        l10n.asPartyId,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                _grouped(user.partyDisplay),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 2.4, color: HomeColors.textPrimary(context)),
              ),
            ),
            IconButton(
              tooltip: l10n.asCopyPartyId,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.copy_rounded, size: 16, color: brand),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: user.partyDisplay));
                prefSnack(context, l10n.asCopied);
              },
            ),
          ],
        ),
      ),
      cell(l10n.asPartyName, Text(user.partyName.isEmpty ? '-' : user.partyName, style: value)),
      cell(l10n.asUserName, Text(user.userId.toUpperCase(), style: value)),
      cell(
        l10n.asStatus,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: (user.active ? HomeColors.success(context) : HomeColors.error(context)).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            user.active ? l10n.asActive : l10n.asInactive,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: user.active ? HomeColors.success(context) : HomeColors.error(context),
            ),
          ),
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: brand.withValues(alpha: 0.45)),
        boxShadow: [BoxShadow(color: brand.withValues(alpha: 0.10), blurRadius: 12)],
      ),
      child: wide
          ? IntrinsicHeight(
              child: Row(
                children: [
                  for (final (i, c) in cells.indexed) ...[
                    Expanded(flex: i == 0 ? 5 : 3, child: c),
                    VerticalDivider(width: 32, thickness: 1.5, color: HomeColors.divider(context)),
                  ],
                ],
              ),
            )
          : Wrap(
              spacing: 24,
              runSpacing: 18,
              children: [for (final c in cells) c],
            ),
    );
  }
}

/// The design's select: a small label over the value, a chevron right.
class _SelectBox extends StatelessWidget {
  const _SelectBox({required this.label, required this.value, required this.onTap, this.loading = false});

  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) => Material(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 64,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: HomeColors.divider(context)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: HomeColors.textSecondary(context))),
                      const SizedBox(height: 4),
                      Text(
                        value ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
                      ),
                    ],
                  ),
                ),
                if (loading)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Icon(Icons.keyboard_arrow_down_rounded, color: HomeColors.textPrimary(context)),
              ],
            ),
          ),
        ),
      );
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.hint, required this.onSubmitted});

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: HomeColors.brand(context).withValues(alpha: 0.6)),
    );
    return SizedBox(
      height: 64,
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onSubmitted(),
        style: TextStyle(fontSize: 14, color: HomeColors.textPrimary(context)),
        decoration: InputDecoration(
          filled: true,
          fillColor: HomeColors.card(context),
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: HomeColors.textSecondary(context)),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 20, right: 28),
            child: Icon(Icons.search_rounded, color: HomeColors.brand(context)),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 22),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(borderSide: BorderSide(color: HomeColors.brand(context), width: 1.5)),
        ),
      ),
    );
  }
}

/// The design's solid buttons (Apply, Cancel, Save): the palette's deep
/// brand shade.
class _DesignButton extends StatelessWidget {
  const _DesignButton({required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final fill = HomeColors.brandDark(context);
    return SizedBox(
      height: 64,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: Colors.white,
          disabledBackgroundColor: fill.withValues(alpha: loading ? 0.85 : 0.4),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            : Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// "Map All Modes" and one numbered card per alert with its channels.
class _AlertsList extends StatelessWidget {
  const _AlertsList({required this.events, required this.selection, required this.enabled, required this.onChanged});

  final List<AlertEvent> events;
  final Map<String, Set<AlertMode>> selection;

  /// Off until Apply has loaded an account's alerts.
  final bool enabled;
  final ValueChanged<Map<String, Set<AlertMode>>> onChanged;

  Set<AlertMode> _of(AlertEvent e) => selection[e.eventId] ?? const {};

  Map<String, Set<AlertMode>> _with(AlertEvent e, Set<AlertMode> modes) => {
        for (final x in selection.entries) x.key: {...x.value},
        e.eventId: modes,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brand = HomeColors.brand(context);
    final all = events.isNotEmpty && events.every((e) => _of(e).length == AlertMode.values.length);
    final none = events.every((e) => _of(e).isEmpty);

    Widget box(bool? value, ValueChanged<bool?>? onChanged) => Checkbox(
          value: value,
          tristate: value == null,
          activeColor: brand,
          side: BorderSide(color: HomeColors.textSecondary(context), width: 1.4),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: enabled ? onChanged : null,
        );
    final text = TextStyle(fontSize: 15, color: HomeColors.textPrimary(context));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(color: brand.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
            child: Row(
              children: [
                box(
                  all ? true : (none ? false : null),
                  (_) => onChanged({for (final e in events) e.eventId: all ? <AlertMode>{} : AlertMode.values.toSet()}),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(l10n.asMapAllModes, style: text.copyWith(fontSize: 16))),
                Flexible(
                  child: Text(
                    l10n.asMapAllModesHint,
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 11, color: brand),
                  ),
                ),
              ],
            ),
          ),
          if (!enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
              child: Text(l10n.asApplyHint, style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context))),
            ),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.asNoAlerts, style: TextStyle(color: HomeColors.textSecondary(context))),
            ),
          for (final (i, e) in events.indexed)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: HomeColors.divider(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      box(
                        _of(e).length == AlertMode.values.length ? true : (_of(e).isEmpty ? false : null),
                        (_) => onChanged(_with(e, _of(e).length == AlertMode.values.length ? {} : AlertMode.values.toSet())),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(e.description, style: text.copyWith(fontSize: 16)))),
                      Text(
                        (i + 1).toString().padLeft(2, '0'),
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: HomeColors.textSecondary(context)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 18,
                    runSpacing: 6,
                    children: [
                      for (final m in AlertMode.values)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            box(
                              _of(e).contains(m),
                              (v) => onChanged(_with(e, v == true ? {..._of(e), m} : ({..._of(e)}..remove(m)))),
                            ),
                            const SizedBox(width: 8),
                            Text(alertModeLabel(l10n, m), style: text),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
