import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/service_requests/service_request_models.dart';
import 'package:ubci_bank/src/core/utils/common/statement_file_saver.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/providers/common/service_requests_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/design_page.dart';

// ── Shared ───────────────────────────────────────────────────────────────

/// OBDX's `statusDesc` labels, used until (or unless) `srStatus` loads.
String srStatusLabel(AppLocalizations l10n, String code, [List<SrOption>? fromServer]) {
  final server = fromServer?.where((o) => o.code == code).firstOrNull?.description;
  if (server != null && server.isNotEmpty) return server;
  return switch (code) {
    'PE' => l10n.srStatusPending,
    'DL' => l10n.srStatusDelivered,
    'CO' => l10n.srStatusCompleted,
    'RE' => l10n.srStatusRejected,
    'IN' => l10n.srStatusInitiated,
    'IP' => l10n.srStatusInProgress,
    'RQ' => l10n.srStatusRequested,
    'CL' => l10n.srStatusClosed,
    'RT' => l10n.srStatusReturned,
    'DP' => l10n.srStatusDispatched,
    'IS' => l10n.srStatusIssued,
    'AC' => l10n.srStatusAccepted,
    _ => code,
  };
}

class SrLoading extends StatelessWidget {
  const SrLoading({super.key});

  @override
  Widget build(BuildContext context) => const PayCard(
        child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      );
}

class SrFailed extends StatelessWidget {
  const SrFailed({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final e = error;
    return PayErrorRetry(
      message: e is ServiceRequestsLoadError && e.message != null ? e.message! : AppLocalizations.of(context).srLoadFailed,
      onRetry: onRetry,
    );
  }
}

/// A status as a coloured pill: open in the brand colour, done in green,
/// rejected / returned in red.
class SrStatusChip extends ConsumerWidget {
  const SrStatusChip({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statuses = ref.watch(srEnumerationProvider('srStatus')).valueOrNull;
    final color = SrStatus.isNegative(code)
        ? HomeColors.error(context)
        : SrStatus.isOpen(code)
            ? HomeColors.brand(context)
            : HomeColors.success(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(
        srStatusLabel(l10n, code, statuses),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ── Track Requests (service-requests-track + -track-panel) ───────────────

class SrTrackView extends ConsumerStatefulWidget {
  const SrTrackView({super.key, required this.filter, required this.wide, required this.onApply, required this.onOpen});

  /// The filter in effect; the list follows it.
  final SrFilter? filter;
  final bool wide;
  final ValueChanged<SrFilter> onApply;
  final ValueChanged<ServiceRequestSummary> onOpen;

  @override
  ConsumerState<SrTrackView> createState() => _SrTrackViewState();
}

/// Track Requests in the app's design: Product Name and Status, From and
/// To Date in boxed fields, applied as they change (no Apply button); the
/// criteria in a tinted strip; then the requests, or "No Service Request
/// Found" with Change filters.
class _SrTrackViewState extends ConsumerState<SrTrackView> {
  late String? _product = widget.filter?.product;
  late DateTime? _from = widget.filter?.fromDate;
  late DateTime? _to = widget.filter?.toDate;
  late String? _status = widget.filter?.status;
  String? _fromError;
  String? _toError;

  /// OBDX pages by 10.
  int _shown = 10;

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    // The list shows from the start: every request until narrowed.
    if (widget.filter == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onApply(const SrFilter());
      });
    }
  }

  /// Checks OBDX's date rules, then applies the filter. Each date is
  /// required once the other is given; To Date is at most 90 days after
  /// From Date and never in the future.
  void _apply() {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _fromError = _from == null && _to != null ? l10n.srDateRequired : null;
      _toError = _to == null && _from != null ? l10n.srDateRequired : null;
      if (_from != null && _to != null) {
        if (_to!.isBefore(_from!)) {
          _toError = l10n.srToBeforeFrom;
        } else if (_to!.difference(_from!).inDays > 90) {
          _toError = l10n.srDateRange90;
        }
      }
    });
    if (_fromError != null || _toError != null) return;
    _shown = 10;
    widget.onApply(SrFilter(product: _product, fromDate: _from, toDate: _to, status: _status));
  }

  void _reset() {
    setState(() {
      _product = null;
      _from = null;
      _to = null;
      _status = null;
      _fromError = null;
      _toError = null;
    });
    _apply();
  }

  Future<void> _pickProduct(List<String> products) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showPayPicker<String>(
      context,
      title: l10n.srProductName,
      selected: _product,
      options: [for (final p in products) PayOption(value: p, title: p)],
    );
    if (picked != null && picked != _product && mounted) {
      setState(() => _product = picked);
      _apply();
    }
  }

  Future<void> _pickStatus(List<SrOption> statuses) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showPayPicker<String>(
      context,
      title: l10n.srStatus,
      selected: _status,
      options: [for (final s in statuses) PayOption(value: s.code, title: s.description)],
    );
    if (picked != null && mounted) {
      setState(() => _status = picked);
      _apply();
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final today = _today;
    final first = from ? DateTime(today.year - 10) : (_from ?? DateTime(today.year - 10));
    final last = from
        ? (_to ?? today)
        : (_from == null ? today : (_from!.add(const Duration(days: 90)).isBefore(today) ? _from!.add(const Duration(days: 90)) : today));
    final current = from ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isBefore(first) && !current.isAfter(last) ? current : last,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    setState(() => from ? _from = picked : _to = picked);
    // One date alone waits for the other before applying.
    if ((_from == null) == (_to == null)) _apply();
  }

  /// `10/8/26`.
  static String _short(DateTime d) => '${d.month}/${d.day}/${(d.year % 100).toString().padLeft(2, '0')}';

  Widget _filters(AppLocalizations l10n) {
    final products = ref.watch(srProductsProvider);
    final statuses = ref.watch(srEnumerationProvider('srStatus'));
    final statusList = statuses.valueOrNull ?? [for (final c in SrStatus.all) SrOption(code: c, description: srStatusLabel(l10n, c))];
    final cells = [
      DesignBoxSelect(
        label: l10n.srProductName,
        value: _product,
        placeholder: l10n.srPleaseSelect,
        loading: products.isLoading,
        onTap: products.valueOrNull == null ? null : () => _pickProduct(products.value!),
      ),
      DesignBoxSelect(
        label: l10n.srStatus,
        value: _status == null ? null : srStatusLabel(l10n, _status!, statuses.valueOrNull),
        placeholder: l10n.srPleaseSelect,
        onTap: () => _pickStatus(statusList),
      ),
      _DateBox(label: l10n.srFromDate, value: _from, error: _fromError, onTap: () => _pickDate(from: true)),
      _DateBox(label: l10n.srToDate, value: _to, error: _toError, onTap: () => _pickDate(from: false)),
    ];
    if (!widget.wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final (i, c) in cells.indexed) ...[if (i > 0) const SizedBox(height: 12), c]],
      );
    }
    Widget pair(Widget a, Widget b) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: a), const SizedBox(width: 88), Expanded(child: b)],
        );
    return Padding(
      padding: const EdgeInsets.only(right: 28),
      child: Column(
        children: [pair(cells[0], cells[1]), const SizedBox(height: 24), pair(cells[2], cells[3])],
      ),
    );
  }

  /// The tinted strip of what is being searched for: product in the brand
  /// colour, the dates, the status in green.
  Widget? _strip(AppLocalizations l10n, SrFilter f) {
    final statuses = ref.watch(srEnumerationProvider('srStatus')).valueOrNull;
    final parts = <Widget>[
      if (f.product != null)
        Text(f.product!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: HomeColors.brand(context))),
      if (f.category != null)
        Text(f.category!.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context))),
      if (f.fromDate != null && f.toDate != null)
        Text(
          '${_short(f.fromDate!)} - ${_short(f.toDate!)}',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
        ),
      if (f.status != null)
        Text(
          srStatusLabel(l10n, f.status!, statuses),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: SrStatus.isNegative(f.status!) ? HomeColors.error(context) : HomeColors.success(context),
          ),
        ),
    ];
    if (parts.isEmpty) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      color: HomeColors.brand(context).withValues(alpha: 0.12),
      child: Wrap(spacing: 80, runSpacing: 8, children: parts),
    );
  }

  Widget _results(AppLocalizations l10n, SrFilter f) => ref.watch(srRequestsProvider(f)).when(
        loading: () => const SrLoading(),
        error: (e, _) => SrFailed(error: e, onRetry: () => ref.invalidate(srRequestsProvider(f))),
        data: (list) {
          if (list.isEmpty) return _Empty(onChangeFilters: _reset);
          final shown = list.take(_shown).toList();
          return Container(
            decoration: BoxDecoration(
              color: HomeColors.card(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: HomeColors.divider(context)),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.wide) _TableHeader(l10n: l10n),
                for (final (i, r) in shown.indexed)
                  _RequestRow(request: r, wide: widget.wide, last: i == shown.length - 1, onTap: () => widget.onOpen(r)),
                if (list.length > _shown)
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _shown += 10),
                      style: TextButton.styleFrom(foregroundColor: HomeColors.brand(context)),
                      child: Text(l10n.srShowMore(list.length - _shown)),
                    ),
                  ),
              ],
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final applied = widget.filter;
    final strip = applied == null ? null : _strip(l10n, applied);
    return DesignCard(
      padding: EdgeInsets.fromLTRB(widget.wide ? 22 : 14, 22, widget.wide ? 20 : 14, widget.wide ? 120 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _filters(l10n),
          const SizedBox(height: 36),
          if (strip != null) ...[strip, const SizedBox(height: 18)],
          if (applied != null) _results(l10n, applied),
        ],
      ),
    );
  }
}

/// A date in the design box, with the calendar mark at the right.
class _DateBox extends StatelessWidget {
  const _DateBox({required this.label, required this.value, required this.onTap, this.error});

  final String label;
  final DateTime? value;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignBoxSelect(
            label: label,
            value: value == null ? null : payDate(value),
            placeholder: label,
            trailingIcon: Icons.calendar_month_outlined,
            onTap: onTap,
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(error!, style: TextStyle(fontSize: 11.5, color: HomeColors.error(context))),
            ),
        ],
      );
}

/// "No Service Request Found": the icon tile, the line under it, and
/// Change filters (which clears them).
class _Empty extends StatelessWidget {
  const _Empty({required this.onChangeFilters});

  final VoidCallback onChangeFilters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brand = HomeColors.brand(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 56),
      decoration: BoxDecoration(
        color: HomeColors.card(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HomeColors.divider(context)),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: brand.withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.north_east_rounded, color: brand, size: 30),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.srNoRequests,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.srNoRequestsMatch,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context)),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onChangeFilters,
            style: TextButton.styleFrom(foregroundColor: brand),
            child: Text(l10n.srChangeFilters, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: HomeColors.divider(context)))),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(l10n.srDate, style: style)),
          Expanded(flex: 4, child: Text(l10n.srRequestName, style: style)),
          Expanded(flex: 3, child: Text(l10n.srReferenceNumber, style: style)),
          Expanded(flex: 2, child: Text(l10n.srStatus, style: style)),
        ],
      ),
    );
  }
}

/// A table row on wide layouts; OBDX's mobile card otherwise (reference
/// and status on top, then date and the request name).
class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request, required this.wide, required this.last, required this.onTap});

  final ServiceRequestSummary request;
  final bool wide;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomeColors.brand(context));
    final secondary = TextStyle(fontSize: 13, color: HomeColors.textSecondary(context));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: HomeColors.divider(context).withValues(alpha: 0.7))),
        ),
        child: wide
            ? Row(
                children: [
                  Expanded(flex: 2, child: Text(payDate(request.creationDate), style: secondary)),
                  Expanded(flex: 4, child: Text(request.name, style: primary)),
                  Expanded(flex: 3, child: Text(request.id, style: secondary)),
                  Expanded(flex: 2, child: Align(alignment: AlignmentDirectional.centerStart, child: SrStatusChip(code: request.status))),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          request.id,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context)),
                        ),
                      ),
                      SrStatusChip(code: request.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(payDate(request.creationDate), style: secondary),
                  const SizedBox(height: 2),
                  Text(request.name, style: primary),
                ],
              ),
      ),
    );
  }
}

// ── Request details (service-requests-track-details / -detail) ───────────

class SrRequestDetailView extends ConsumerStatefulWidget {
  const SrRequestDetailView({super.key, required this.summary, required this.onBack});

  final ServiceRequestSummary summary;
  final VoidCallback onBack;

  @override
  ConsumerState<SrRequestDetailView> createState() => _SrRequestDetailViewState();
}

class _SrRequestDetailViewState extends ConsumerState<SrRequestDetailView> {
  String? _downloading;

  Future<void> _download(String contentId, String name) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _downloading = contentId);
    final result = await ref.read(serviceRequestsRepositoryProvider).downloadAttachment(contentId);
    if (!mounted) return;
    setState(() => _downloading = null);
    if (result is Success<List<int>> && result.data != null) {
      final lower = name.toLowerCase();
      final mime = lower.endsWith('.pdf')
          ? 'application/pdf'
          : lower.endsWith('.png')
              ? 'image/png'
              : (lower.endsWith('.jpg') || lower.endsWith('.jpeg'))
                  ? 'image/jpeg'
                  : lower.endsWith('.zip')
                      ? 'application/zip'
                      : 'application/octet-stream';
      try {
        await StatementFileSaver.saveStatement(bytes: result.data!, fileName: name.isEmpty ? 'attachment' : name, mimeType: mime);
        return;
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.srDownloadFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final id = widget.summary.id;
    final isForm = widget.summary.requestType == 'OTHERS';
    final requestTypes = isForm ? null : ref.watch(srEnumerationProvider('srRequestType')).valueOrNull;
    return ref.watch(srRequestProvider(id)).when(
          loading: () => const SrLoading(),
          error: (e, _) => SrFailed(error: e, onRetry: () => ref.invalidate(srRequestProvider(id))),
          data: (d) {
            final typeName = requestTypes?.where((t) => t.code == d.requestType).firstOrNull?.description;
            final name = d.name.isNotEmpty ? d.name : (typeName ?? widget.summary.name);
            final rows = <(String, String)>[
              (l10n.srReferenceNumber, d.id.isEmpty ? id : d.id),
              (isForm ? l10n.srRequestFor : l10n.srRequestName, name),
              (l10n.srDateRequested, payDate(d.creationDate ?? widget.summary.creationDate)),
              if ((d.comments ?? '').isNotEmpty) (isForm ? l10n.srClosureComments : l10n.srCommentsFromBank, d.comments!),
            ];
            final elements = d.elements.where((e) => e.isHeader || e.displayValues.any((v) => v.isNotEmpty) || e.values.any((v) => v.isNotEmpty)).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PaySection(
                  title: l10n.srDetails,
                  icon: Icons.assignment_outlined,
                  trailing: SrStatusChip(code: d.status.isEmpty ? widget.summary.status : d.status),
                  child: Column(
                    children: [
                      for (final (i, (label, value)) in rows.indexed) PayReviewRow(label: label, value: value, last: i == rows.length - 1),
                    ],
                  ),
                ),
                if (elements.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  PaySection(
                    title: l10n.srRequestDetails,
                    icon: Icons.list_alt_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, e) in elements.indexed)
                          if (e.isHeader)
                            Padding(
                              padding: const EdgeInsets.only(top: 12, bottom: 4),
                              child: Text(
                                e.values.isNotEmpty ? e.values.first : (e.label ?? ''),
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
                              ),
                            )
                          else if (e.isFile && e.values.isNotEmpty)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(e.label ?? '', style: TextStyle(fontSize: 13, color: HomeColors.textSecondary(context))),
                                ),
                                TextButton.icon(
                                  onPressed: _downloading == e.values.first
                                      ? null
                                      : () => _download(e.values.first, e.displayValues.isNotEmpty ? e.displayValues.first : ''),
                                  icon: const Icon(Icons.attach_file_rounded, size: 18),
                                  label: Text(e.displayValues.isNotEmpty && e.displayValues.first.isNotEmpty ? e.displayValues.first : l10n.srAttachment),
                                  style: TextButton.styleFrom(foregroundColor: HomeColors.brand(context)),
                                ),
                              ],
                            )
                          else
                            PayReviewRow(
                              label: e.label ?? '',
                              value: (e.displayValues.any((v) => v.isNotEmpty) ? e.displayValues : e.values).where((v) => v.isNotEmpty).join(', '),
                              last: i == elements.length - 1,
                            ),
                      ],
                    ),
                  ),
                ],
                if (d.history.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  PaySection(
                    title: l10n.srStatusHistory,
                    icon: Icons.timeline_rounded,
                    child: Column(
                      children: [
                        for (final (i, h) in d.history.indexed)
                          _HistoryStep(
                            label: srStatusLabel(l10n, h.status),
                            date: h.date,
                            note: h.note,
                            last: i == d.history.length - 1,
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: SizedBox(width: 160, child: PaySecondaryButton(label: l10n.prefBack, onPressed: widget.onBack)),
                ),
              ],
            );
          },
        );
  }
}

/// One step of the status history: a dot and line, the status, its date
/// and the bank's remarks.
class _HistoryStep extends StatelessWidget {
  const _HistoryStep({required this.label, required this.date, required this.note, required this.last});

  final String label;
  final DateTime? date;
  final String? note;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brand = HomeColors.brand(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: brand, shape: BoxShape.circle),
                ),
                if (!last) Expanded(child: Container(width: 2, color: brand.withValues(alpha: 0.3))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context))),
                  if (date != null)
                    Text(payDate(date), style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context))),
                  if (note != null && note!.isNotEmpty)
                    Text(l10n.srRemarks(note!), style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
