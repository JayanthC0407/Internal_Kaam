import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/account_settings/account_settings_models.dart';
import 'package:ubci_bank/src/core/models/common/preferences/preferences_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/providers/common/account_settings_providers.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/common/preferences/widgets/preferences_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

enum _Mode { edit, review, done }

/// Preferences → Manage DND Alerts (OBDX `flows/manage-dnd-alerts`):
/// Select Category (ticked = do not disturb), each name opening its events
/// → Review ("Alerts DND", read only) → Confirm (`PUT me/dndRegistry`)
/// → the result. Evidence: docs/obdx/features/manage-dnd-alerts.md.
class DndAlertsSection extends ConsumerStatefulWidget {
  const DndAlertsSection({super.key, required this.onCancel});

  /// Cancel: back to the Preferences list.
  final VoidCallback onCancel;

  @override
  ConsumerState<DndAlertsSection> createState() => _DndAlertsSectionState();
}

class _DndAlertsSectionState extends ConsumerState<DndAlertsSection> {
  _Mode _mode = _Mode.edit;

  /// The ticks as edited; null until the user changes one (then `mapped`).
  Set<String>? _selected;
  bool _saving = false;
  PrefWriteOutcome? _outcome;

  Set<String> _ticks(DndRegistry registry) => _selected ?? registry.mapped;

  Future<void> _confirm(DndRegistry registry) async {
    final repo = ref.read(accountSettingsRepositoryProvider);
    final selected = _ticks(registry);
    setState(() => _saving = true);
    final result = await runPrefWrite(context, (c, otp) => repo.saveDnd(registry, selected, challenge: c, otp: otp));
    if (!mounted) return;
    setState(() => _saving = false);
    if (prefWriteDone(result)) {
      setState(() {
        _outcome = (result as Success<PrefWriteOutcome>).data;
        _mode = _Mode.done;
      });
    } else {
      final error = prefWriteError(context, result);
      if (error != null) prefSnack(context, error);
    }
  }

  /// The category's name link: "DND Alert : {name}" with its events
  /// (dnd-category-template.html; stage1/hooks.js:52-75).
  Future<void> _showEvents(DndCategory category) {
    final l10n = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.dndAlertHeader(category.name)),
        content: SizedBox(
          width: 420,
          child: Consumer(
            builder: (context, ref, _) => ref.watch(dndEventsProvider(category.id)).when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => PayErrorRetry(
                    message: l10n.dndEventsFailed,
                    onRetry: () => ref.invalidate(dndEventsProvider(category.id)),
                  ),
                  data: (events) => events.isEmpty
                      ? PayMuted(l10n.dndNoEvents)
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final e in events)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('•  ', style: TextStyle(color: HomeColors.brand(context))),
                                      Expanded(
                                        child: Text(
                                          e,
                                          style: TextStyle(fontSize: 13.5, color: HomeColors.textPrimary(context)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(dialog).pop(), child: Text(l10n.prefOk))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_mode == _Mode.done) {
      final outcome = _outcome;
      final pending = outcome?.pendingApproval ?? false;
      final message = pending ? l10n.dndInitiated : l10n.dndAccepted;
      return PayResultView(
        title: message,
        message: l10n.dndTitle,
        reference: outcome?.reference,
        rows: [if (outcome?.reference != null) (l10n.dndReferenceNumber, outcome!.reference!)],
        doneLabel: l10n.prefOk,
        onDone: () {
          ref.invalidate(dndRegistryProvider);
          setState(() {
            _mode = _Mode.edit;
            _selected = null;
            _outcome = null;
          });
        },
      );
    }
    return ref.watch(dndRegistryProvider).when(
          loading: () => const PrefLoading(),
          error: (e, _) => PrefFailed(error: e, onRetry: () => ref.invalidate(dndRegistryProvider)),
          data: (registry) {
            final ticks = _ticks(registry);
            final review = _mode == _Mode.review;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (review) ...[
                  PrefReviewBanner(message: l10n.dndReview),
                  const SizedBox(height: 14),
                ],
                PrefBlock(
                  title: l10n.dndSelectCategory,
                  icon: Icons.do_not_disturb_on_outlined,
                  children: registry.categories.isEmpty
                      ? [PayMuted(l10n.dndNoCategories)]
                      : [
                          for (final c in registry.categories)
                            _CategoryRow(
                              category: c,
                              ticked: ticks.contains(c.id),
                              // Review shows the same boxes, disabled.
                              onChanged: review
                                  ? null
                                  : (v) => setState(() {
                                        final next = {...ticks};
                                        v ? next.add(c.id) : next.remove(c.id);
                                        _selected = next;
                                      }),
                              onOpen: review ? null : () => _showEvents(c),
                            ),
                        ],
                ),
                const SizedBox(height: 16),
                PrefActions(
                  children: review
                      ? [
                          PayPrimaryButton(
                            label: l10n.prefConfirm,
                            loading: _saving,
                            onPressed: _saving ? null : () => _confirm(registry),
                          ),
                          PaySecondaryButton(
                            label: l10n.prefBack,
                            onPressed: _saving ? null : () => setState(() => _mode = _Mode.edit),
                          ),
                          PaySecondaryButton(label: l10n.prefCancel, onPressed: _saving ? null : widget.onCancel),
                        ]
                      : [
                          // OBDX's Submit has no checks; no ticks is allowed.
                          PayPrimaryButton(
                            label: l10n.addBillerSubmit,
                            onPressed: registry.categories.isEmpty ? null : () => setState(() => _mode = _Mode.review),
                          ),
                          PaySecondaryButton(label: l10n.prefCancel, onPressed: widget.onCancel),
                        ],
                ),
              ],
            );
          },
        );
  }
}

/// A category: its checkbox, and its name as the link to its events.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.ticked, this.onChanged, this.onOpen});

  final DndCategory category;
  final bool ticked;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Checkbox(value: ticked, onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false)),
          const SizedBox(width: 4),
          Flexible(
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: onOpen == null ? HomeColors.textPrimary(context) : brand,
                    decoration: onOpen == null ? null : TextDecoration.underline,
                    decorationColor: brand,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
