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

/// The filter, then — once applied — the requests it finds.
class SrTrackView extends ConsumerStatefulWidget {
  const SrTrackView({super.key, required this.filter, required this.wide, required this.onApply, required this.onOpen});

  /// The filter last applied; null shows the filter alone, as OBDX does.
  final SrFilter? filter;
  final bool wide;
  final ValueChanged<SrFilter> onApply;
  final ValueChanged<ServiceRequestSummary> onOpen;

  @override
  ConsumerState<SrTrackView> createState() => _SrTrackViewState();
}

class _SrTrackViewState extends ConsumerState<SrTrackView> {
  late String? _product = widget.filter?.product;
  late SrCategory? _category = widget.filter?.category;
  late DateTime? _from = widget.filter?.fromDate;
  late DateTime? _to = widget.filter?.toDate;
  late String? _status = widget.filter?.status;
  String? _fromError;
  String? _toError;

  /// The filter folds away once applied; the filter button reopens it.
  late bool _editing = widget.filter == null;

  /// OBDX pages by 10.
  int _shown = 10;

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _pickProduct(List<String> products) async {
    final picked = await showPayPicker<String>(
      context,
      title: AppLocalizations.of(context).srProductName,
      selected: _product,
      options: [for (final p in products) PayOption(value: p, title: p)],
    );
    // A new product clears the rest of the filter (track-panel).
    if (picked != null && picked != _product && mounted) {
      setState(() {
        _product = picked;
        _category = null;
        _status = null;
        _from = null;
        _to = null;
      });
    }
  }

  Future<void> _pickCategory(List<SrCategory> categories) async {
    final picked = await showPayPicker<String>(
      context,
      title: AppLocalizations.of(context).srCategoryName,
      selected: _category?.id,
      options: [for (final c in categories) PayOption(value: c.id, title: c.name)],
    );
    if (picked != null && mounted) setState(() => _category = categories.firstWhere((c) => c.id == picked));
  }

  Future<void> _pickStatus(List<SrOption> statuses) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showPayPicker<String>(
      context,
      title: l10n.srStatus,
      selected: _status,
      options: [for (final s in statuses) PayOption(value: s.code, title: s.description)],
    );
    if (picked != null && mounted) setState(() => _status = picked);
  }

  void _apply() {
    final l10n = AppLocalizations.of(context);
    // Each date is required once the other is given; To Date is at most 90
    // days after From Date and never in the future.
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
    setState(() => _editing = false);
    widget.onApply(SrFilter(product: _product, category: _category, fromDate: _from, toDate: _to, status: _status));
  }

  void _reset() => setState(() {
        _product = null;
        _category = null;
        _from = null;
        _to = null;
        _status = null;
        _fromError = null;
        _toError = null;
      });

  Widget _filterForm(AppLocalizations l10n) {
    final products = ref.watch(srProductsProvider);
    final categories = _product == null ? null : ref.watch(srCategoriesProvider(_product!));
    final statuses = ref.watch(srEnumerationProvider('srStatus'));
    final statusList = statuses.valueOrNull ?? [for (final c in SrStatus.all) SrOption(code: c, description: srStatusLabel(l10n, c))];
    final today = _today;

    Widget field(String label, Widget child) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [PayFieldLabel(label), child],
        );

    final fields = <Widget>[
      field(
        l10n.srProductName,
        PayPickerField(
          placeholder: l10n.srPleaseSelect,
          title: _product,
          dense: true,
          loading: products.isLoading,
          error: products.hasError ? l10n.srLoadFailed : null,
          onTap: products.valueOrNull == null ? null : () => _pickProduct(products.value!),
        ),
      ),
      if (_product != null)
        field(
          l10n.srCategoryName,
          PayPickerField(
            placeholder: l10n.srPleaseSelect,
            title: _category?.name,
            dense: true,
            loading: categories?.isLoading ?? false,
            onTap: categories?.valueOrNull == null ? null : () => _pickCategory(categories!.value!),
          ),
        ),
      field(
        l10n.srFromDate,
        PayDateField(
          value: _from,
          placeholder: l10n.srPleaseSelect,
          first: DateTime(today.year - 10),
          last: _to ?? today,
          error: _fromError,
          onChanged: (d) => setState(() {
            _from = d;
            _fromError = null;
          }),
        ),
      ),
      field(
        l10n.srToDate,
        PayDateField(
          value: _to,
          placeholder: l10n.srPleaseSelect,
          first: _from ?? DateTime(today.year - 10),
          last: _from == null
              ? today
              : (_from!.add(const Duration(days: 90)).isBefore(today) ? _from!.add(const Duration(days: 90)) : today),
          error: _toError,
          onChanged: (d) => setState(() {
            _to = d;
            _toError = null;
          }),
        ),
      ),
      field(
        l10n.srStatus,
        PayPickerField(
          placeholder: l10n.srPleaseSelect,
          title: _status == null ? null : srStatusLabel(l10n, _status!, statuses.valueOrNull),
          dense: true,
          onTap: () => _pickStatus(statusList),
        ),
      ),
    ];

    return PaySection(
      title: l10n.srFilter,
      icon: Icons.filter_list_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.wide)
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [for (final f in fields) SizedBox(width: 260, child: f)],
            )
          else
            for (final (i, f) in fields.indexed) ...[if (i > 0) const SizedBox(height: 14), f],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _reset,
                style: TextButton.styleFrom(foregroundColor: HomeColors.brand(context)),
                child: Text(l10n.srReset),
              ),
              const SizedBox(width: 12),
              SizedBox(width: 160, child: PayPrimaryButton(label: l10n.srApply, onPressed: _apply)),
            ],
          ),
        ],
      ),
    );
  }

  /// OBDX's grey strip of what was searched for, with the filter button.
  Widget _summary(AppLocalizations l10n, SrFilter f) {
    final statuses = ref.watch(srEnumerationProvider('srStatus')).valueOrNull;
    final parts = [
      if (f.product != null) f.product!,
      if (f.category != null) f.category!.name,
      if (f.fromDate != null && f.toDate != null) '${payDate(f.fromDate)} - ${payDate(f.toDate)}',
      if (f.status != null) srStatusLabel(l10n, f.status!, statuses),
    ];
    return PayCard(
      padding: 10,
      child: Row(
        children: [
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (parts.isEmpty) PayMuted(l10n.srAllRequests),
                for (final p in parts)
                  Chip(
                    label: Text(p, style: TextStyle(fontSize: 12.5, color: HomeColors.textPrimary(context))),
                    backgroundColor: HomeColors.bg(context),
                    side: BorderSide(color: HomeColors.divider(context)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.srFilter,
            icon: Icon(Icons.filter_list_rounded, color: HomeColors.brand(context)),
            onPressed: () => setState(() => _editing = true),
          ),
        ],
      ),
    );
  }

  Widget _results(AppLocalizations l10n, SrFilter f) => ref.watch(srRequestsProvider(f)).when(
        loading: () => const SrLoading(),
        error: (e, _) => SrFailed(error: e, onRetry: () => ref.invalidate(srRequestsProvider(f))),
        data: (list) {
          if (list.isEmpty) return PayCard(child: PayMuted(l10n.srNoRequests));
          final shown = list.take(_shown).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PayCard(
                padding: 8,
                child: Column(
                  children: [
                    if (widget.wide) _TableHeader(l10n: l10n),
                    for (final (i, r) in shown.indexed)
                      _RequestRow(request: r, wide: widget.wide, last: i == shown.length - 1, onTap: () => widget.onOpen(r)),
                  ],
                ),
              ),
              if (list.length > _shown) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _shown += 10),
                    style: TextButton.styleFrom(foregroundColor: HomeColors.brand(context)),
                    child: Text(l10n.srShowMore(list.length - _shown)),
                  ),
                ),
              ],
            ],
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final applied = widget.filter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_editing || applied == null) _filterForm(l10n) else _summary(l10n, applied),
        if (applied != null) ...[const SizedBox(height: 16), _results(l10n, applied)],
      ],
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
