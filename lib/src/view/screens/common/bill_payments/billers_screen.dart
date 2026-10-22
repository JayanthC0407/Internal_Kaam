import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/bill_payments/biller_models.dart';
import 'package:ubci_bank/src/core/utils/common/money_format.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/view/providers/common/bill_payments_providers.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/bill_payments/add_biller_screen.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// Billers — OBDX `manage-bill-payments` (Bill Payments → Billers).
///
/// The user's registered billers in OBDX's three groups, searchable by
/// nickname and category, each opening Biller Details. Delete follows
/// OBDX's rules (blocked while auto pay / a scheduled payment is active)
/// and asks for an OTP when the bank wants one. Add Billers opens
/// [AddBillerScreen] in place; Pay and Edit Biller are not built yet.
/// Evidence: docs/obdx/features/bill-payments.md §3-4.
class BillersScreen extends ConsumerStatefulWidget {
  const BillersScreen({super.key, this.embedded = false, this.onBack});

  final bool embedded;
  final VoidCallback? onBack;

  @override
  ConsumerState<BillersScreen> createState() => _BillersScreenState();
}

class _BillersScreenState extends ConsumerState<BillersScreen> {
  String _query = '';

  /// Biller Details shown in place of the list (works embedded and pushed).
  RegisteredBiller? _open;

  /// Add Billers shown in place of the list.
  bool _adding = false;

  /// Registration ids being deleted.
  final _deleting = <String>{};

  DateTime get _today => DateTime.now();

  void _comingSoon(String feature) {
    final l10n = AppLocalizations.of(context);
    _snack('$feature · ${l10n.featureComingSoon}');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _edit(RegisteredBiller biller) {
    final l10n = AppLocalizations.of(context);
    // OBDX refuses edits while a change awaits approval (hooks.js:476-479).
    if (!biller.canEdit) return _snack(l10n.billerEditPending);
    _comingSoon(l10n.billerEdit);
  }

  Future<void> _delete(RegisteredBiller biller) async {
    final l10n = AppLocalizations.of(context);
    // OBDX blocks delete while auto pay / a scheduled payment is active
    // (hooks.js:491-499).
    if (!biller.canDelete(_today)) return _snack(l10n.billerDeleteBlocked);
    if (!await _confirmDelete()) return;
    if (!mounted) return;

    final repository = ref.read(billPaymentsRepositoryProvider);
    setState(() => _deleting.add(biller.id));
    var result = await repository.deleteRegisteredBiller(biller.id, body: biller.raw);
    while (mounted &&
        result is Success<BillerDeleteOutcome> &&
        result.data?.challenge != null) {
      final outcome = result.data!;
      setState(() => _deleting.remove(biller.id));
      if (!mounted) return;
      final otp = await showPayOtpPrompt(
        context,
        title: l10n.billerDeleteOtpTitle(biller.nickname),
        error: outcome.invalidOtp ? l10n.billerOtpInvalid : null,
        attemptsLeft: outcome.challenge!.attemptsLeft,
      );
      // Cancelled: nothing was deleted.
      if (!mounted || otp == null) return;
      setState(() => _deleting.add(biller.id));
      result = await repository.deleteRegisteredBiller(
        biller.id,
        body: biller.raw,
        challenge: outcome.challenge,
        otp: otp,
      );
    }
    if (!mounted) return;
    setState(() => _deleting.remove(biller.id));

    if (result is Success<BillerDeleteOutcome> && result.data != null) {
      HapticFeedback.mediumImpact();
      _snack(result.data!.pendingApproval
          ? l10n.billerDeletePendingApproval(biller.nickname)
          : l10n.billerDeleted(biller.nickname));
      setState(() => _open = null);
      ref.invalidate(registeredBillersProvider);
    } else {
      _snack(result.resolveUserMessage(
        l10n: l10n,
        fallback: l10n.billerDeleteFailed(biller.nickname),
      ));
    }
  }

  Future<bool> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.billerDelete),
        content: Text(l10n.billerDeleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialog).pop(false), child: Text(l10n.billerNo)),
          FilledButton(onPressed: () => Navigator.of(dialog).pop(true), child: Text(l10n.billerYes)),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_adding) {
      return AddBillerScreen(
        onExit: () => setState(() => _adding = false),
        onAdded: (_) {
          setState(() => _adding = false);
          ref.invalidate(registeredBillersProvider);
        },
      );
    }
    final open = _open;
    if (open != null) {
      return _BillerDetailsView(
        biller: open,
        deleting: _deleting.contains(open.id),
        onBack: () => setState(() => _open = null),
        onEdit: () => _edit(open),
        onDelete: () => _delete(open),
        onPay: () => _comingSoon(AppLocalizations.of(context).billerPay),
      );
    }

    final l10n = AppLocalizations.of(context);
    final billers = ref.watch(registeredBillersProvider);
    return PayMenuPage(
      title: l10n.billersTitle,
      subtitle: l10n.billersSubtitle,
      onBack: widget.embedded ? widget.onBack : null,
      builder: (context, wide) {
        final search = TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: payInputDecoration(
            context,
            hint: l10n.billersSearchHint,
            prefixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
              child: Icon(Icons.search_rounded, size: 20, color: HomeColors.textSecondary(context)),
            ),
          ),
        );
        final add = PaySecondaryButton(
          label: l10n.billersAdd,
          icon: Icons.add_rounded,
          onPressed: () => setState(() => _adding = true),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Row(children: [Expanded(child: search), const SizedBox(width: 12), add])
            else ...[
              search,
              const SizedBox(height: 10),
              Align(alignment: AlignmentDirectional.centerEnd, child: add),
            ],
            const SizedBox(height: 16),
            billers.when(
              loading: () => const PayCard(
                child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              ),
              error: (error, _) => PayErrorRetry(
                message: error is BillPaymentsLoadError && error.message != null
                    ? error.message!
                    : l10n.billersLoadFailed,
                onRetry: () => ref.invalidate(registeredBillersProvider),
              ),
              data: (list) => _groups(context, l10n, list, wide),
            ),
          ],
        );
      },
    );
  }

  Widget _groups(BuildContext context, AppLocalizations l10n, List<RegisteredBiller> list, bool wide) {
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? list
        : list
            .where((b) => [b.nickname, b.category?.name ?? '']
                .any((v) => v.toLowerCase().contains(q)))
            .toList();
    final groups = groupBillers(shown);
    final searching = q.isNotEmpty;

    if (searching && groups.values.every((g) => g.isEmpty)) {
      return Padding(padding: const EdgeInsets.all(14), child: PayMuted(l10n.billersNoMatch(_query.trim())));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in groups.entries)
          // OBDX hides empty groups only while searching (hooks.js:338-357).
          if (!searching || entry.value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PaySection(
                title: _groupTitle(l10n, entry.key),
                child: entry.value.isEmpty
                    ? PayMuted(_groupEmpty(l10n, entry.key))
                    : Column(
                        children: [
                          for (final (i, biller) in entry.value.indexed)
                            _BillerTile(
                              biller: biller,
                              today: _today,
                              last: i == entry.value.length - 1,
                              deleting: _deleting.contains(biller.id),
                              onOpen: () => setState(() => _open = biller),
                              onPay: () => _comingSoon(l10n.billerPay),
                              onEdit: () => _edit(biller),
                              onDelete: () => _delete(biller),
                            ),
                        ],
                      ),
              ),
            ),
      ],
    );
  }
}

String _groupTitle(AppLocalizations l10n, BillerType type) => switch (type) {
      BillerType.presentment => l10n.billerGroupPresentment,
      BillerType.recharge => l10n.billerGroupRecharge,
      _ => l10n.billerGroupPayment,
    };

String _groupEmpty(AppLocalizations l10n, BillerType type) => switch (type) {
      BillerType.presentment => l10n.billerEmptyPresentment,
      BillerType.recharge => l10n.billerEmptyRecharge,
      _ => l10n.billerEmptyPayment,
    };

/// OBDX's type label (hooks.js:240-266).
String billerTypeLabel(AppLocalizations l10n, BillerType type) => switch (type) {
      BillerType.presentment => l10n.billerTypeEbill,
      BillerType.presentmentPayment => l10n.billerTypeEbillManual,
      BillerType.recharge => l10n.billerTypeRecharge,
      _ => l10n.billerTypeManual,
    };

String? _statusLabel(AppLocalizations l10n, BillerPaymentStatus? status) => switch (status) {
      BillerPaymentStatus.overdue => l10n.billerStatusPastDue,
      BillerPaymentStatus.autopay => l10n.billerStatusAutoPay,
      BillerPaymentStatus.scheduledPay => l10n.billerStatusScheduledPay,
      null => null,
    };

String? _registrationLabel(AppLocalizations l10n, RegisteredBiller biller) {
  switch ((biller.registrationStatus ?? '').toUpperCase()) {
    case 'PENDING':
      return l10n.billerApprovalPending;
    case 'REJECTED':
      return l10n.billerRejected;
  }
  return null;
}

enum _Action { details, pay, edit, delete }

class _BillerTile extends StatelessWidget {
  const _BillerTile({
    required this.biller,
    required this.today,
    required this.last,
    required this.deleting,
    required this.onOpen,
    required this.onPay,
    required this.onEdit,
    required this.onDelete,
  });

  final RegisteredBiller biller;
  final DateTime today;
  final bool last;
  final bool deleting;
  final VoidCallback onOpen;
  final VoidCallback onPay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final secondary = HomeColors.textSecondary(context);
    final status = _statusLabel(l10n, biller.paymentStatus(today));
    final registration = _registrationLabel(l10n, biller);
    final subtitle = [biller.displayBillerName, biller.category?.name ?? '']
        .where((v) => v.isNotEmpty)
        .join(' · ');
    final ebill = biller.ebill;
    final presented = biller.type == BillerType.presentment ||
        (biller.type == BillerType.presentmentPayment && ebill != null);

    return InkWell(
      onTap: deleting ? null : onOpen,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: HomeColors.divider(context))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PayAvatar(name: biller.nickname),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    biller.nickname,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: HomeColors.textPrimary(context),
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: secondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Chip(billerTypeLabel(l10n, biller.type)),
                      if (registration != null) _Chip(registration, warning: true),
                      if (status != null)
                        _Chip(status, warning: biller.paymentStatus(today) == BillerPaymentStatus.overdue),
                      if (presented) _Chip(biller.hasBillDue ? l10n.billerBillsDue : l10n.billerNoBillsDue),
                    ],
                  ),
                  if (ebill != null && (ebill.totalAmount != null || ebill.dueDate != null)) ...[
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (ebill.totalAmount != null)
                          MoneyFormat.format(
                            ebill.totalAmount!.amount,
                            currencyCode: ebill.totalAmount!.currency ?? biller.biller?.currency ?? '',
                          ),
                        if (ebill.dueDate != null)
                          l10n.billerDueBy(MaterialLocalizations.of(context).formatMediumDate(ebill.dueDate!)),
                      ].join(' · '),
                      style: TextStyle(fontSize: 13, color: HomeColors.textPrimary(context)),
                    ),
                  ],
                ],
              ),
            ),
            if (deleting)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              PopupMenuButton<_Action>(
                tooltip: l10n.billerDetailsTitle,
                icon: Icon(Icons.more_vert_rounded, color: secondary),
                onSelected: (action) => switch (action) {
                  _Action.details => onOpen(),
                  _Action.pay => onPay(),
                  _Action.edit => onEdit(),
                  _Action.delete => onDelete(),
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: _Action.pay, child: Text(l10n.billerPay)),
                  PopupMenuItem(value: _Action.details, child: Text(l10n.billerDetailsTitle)),
                  PopupMenuItem(value: _Action.edit, child: Text(l10n.billerEdit)),
                  PopupMenuItem(value: _Action.delete, child: Text(l10n.billerDelete)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {this.warning = false});

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? HomeColors.error(context) : HomeColors.brand(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

/// Biller Details — OBDX `biller-details` (labels: nls/biller-details.js).
class _BillerDetailsView extends ConsumerWidget {
  const _BillerDetailsView({
    required this.biller,
    required this.deleting,
    required this.onBack,
    required this.onEdit,
    required this.onDelete,
    required this.onPay,
  });

  final RegisteredBiller biller;
  final bool deleting;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final details = ref.watch(billerDetailsProvider(biller.id));
    String date(DateTime? d) => d == null ? '' : MaterialLocalizations.of(context).formatMediumDate(d);

    return PayMenuPage(
      title: l10n.billerDetailsTitle,
      subtitle: biller.nickname,
      onBack: onBack,
      builder: (context, wide) => details.when(
        loading: () => const PayCard(
          child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        ),
        error: (error, _) => PayErrorRetry(
          message: error is BillPaymentsLoadError && error.message != null
              ? error.message!
              : l10n.billerDetailsLoadFailed,
          onRetry: () => ref.invalidate(billerDetailsProvider(biller.id)),
        ),
        data: (data) {
          final reg = data.registration;
          final master = data.biller ?? biller.biller;
          final location = reg.location;
          final schedule = reg.autopayInstructions;
          final rows = <(String, String)>[
            (l10n.billerName, master?.name ?? reg.displayBillerName),
            (l10n.billerCategory, reg.category?.name ?? master?.categoryName ?? ''),
            (
              l10n.billerLocation,
              [location?.areaName, location?.city].whereType<String>().join(', '),
            ),
            (l10n.billerType, billerTypeLabel(l10n, reg.type)),
            (l10n.billerNickname, reg.nickname),
            (l10n.billerCustomerName, reg.customerName ?? ''),
            // Relationship fields, named by the biller's specifications
            // (biller-details/hooks.js:198-206).
            for (final rel in reg.relationships)
              (master?.specLabels[rel.labelId] ?? rel.labelId ?? '', rel.value ?? ''),
            if (reg.ebill?.totalAmount != null)
              (
                l10n.billerBillAmount,
                MoneyFormat.format(
                  reg.ebill!.totalAmount!.amount,
                  currencyCode: reg.ebill!.totalAmount!.currency ?? master?.currency ?? '',
                ),
              ),
            if (reg.ebill?.dueDate != null) (l10n.billerBillDueDate, date(reg.ebill!.dueDate)),
            if (reg.autopay || reg.schedulePayment) ...[
              (
                l10n.billerPaymentType,
                reg.autopay ? l10n.billerStatusAutoPay : l10n.billerStatusScheduledPay,
              ),
              (l10n.billerPayFrom, schedule?.debitAccountDisplay ?? ''),
              (l10n.billerFrequency, schedule?.frequency ?? ''),
              (l10n.billerStartDate, date(schedule?.startDate)),
              (l10n.billerEndDate, date(schedule?.endDate)),
            ],
          ].where((r) => r.$1.isNotEmpty && r.$2.isNotEmpty).toList();

          final actions = [
            PayPrimaryButton(label: l10n.billerPay, onPressed: deleting ? null : onPay),
            PaySecondaryButton(label: l10n.billerEdit, icon: Icons.edit_outlined, onPressed: deleting ? null : onEdit),
            PaySecondaryButton(
              label: l10n.billerDelete,
              icon: Icons.delete_outline_rounded,
              onPressed: deleting ? null : onDelete,
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PaySection(
                child: Column(
                  children: [
                    for (final (label, value) in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 220, child: _Label(label)),
                                  Expanded(child: _Value(value)),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [_Label(label), const SizedBox(height: 2), _Value(value)],
                              ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (deleting)
                const Center(child: CircularProgressIndicator())
              else if (wide)
                Wrap(spacing: 12, runSpacing: 12, children: actions)
              else
                for (final action in actions)
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: action),
            ],
          );
        },
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(fontSize: 13, color: HomeColors.textSecondary(context)));
}

class _Value extends StatelessWidget {
  const _Value(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
      );
}
