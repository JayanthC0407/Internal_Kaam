import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/src/core/models/corp/corp_loans_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/providers/corp/corp_loans_providers.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/corp/loans/corp_loans_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/design_page.dart';

const _requestTypes = {null: 'All', 'Loan Drawdown': 'Loan Drawdown', 'Trade Loan Drawdown': 'Trade Loan Drawdown'};
const _durations = {
  7: 'Last 7 days',
  15: 'Last 15 days',
  30: 'Last 30 days',
  90: 'Last 90 days',
  180: 'Last 180 days',
  365: 'Last 365 days'
};

/// Application Tracker (OBDX `process-management/loan-application-listing`
/// for the OBCLPM module): Draft / Submitted / In Progress / Completed tabs,
/// a search over the reference / bank reference / draft name, and a filter
/// on Request Type and Duration. A draft can be deleted; any application
/// opens its details and documents.
class CorpLoanApplicationTrackerScreen extends ConsumerStatefulWidget {
  const CorpLoanApplicationTrackerScreen({super.key, required this.onBack, this.today});

  final VoidCallback onBack;

  /// For tests; defaults to now.
  final DateTime? today;

  @override
  ConsumerState<CorpLoanApplicationTrackerScreen> createState() => _CorpLoanApplicationTrackerScreenState();
}

class _CorpLoanApplicationTrackerScreenState extends ConsumerState<CorpLoanApplicationTrackerScreen> {
  CorpAppStatus _tab = CorpAppStatus.draft;
  final _search = TextEditingController();
  String? _type;
  int? _days;
  String? _deleted;
  CorpLoanApplicationItem? _open;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CorpLoanApplicationItem> _filter(List<CorpLoanApplicationItem> all) {
    final q = _search.text.trim().toLowerCase();
    final today = widget.today ?? DateTime.now();
    final since = _days == null ? null : DateTime(today.year, today.month, today.day).subtract(Duration(days: _days!));
    return [
      for (final a in all)
        if ((q.isEmpty || [a.refId, a.midOfficeRefNo, a.draftName].any((s) => (s ?? '').toLowerCase().contains(q))) &&
            (_type == null || a.type.toLowerCase() == _type!.toLowerCase()) &&
            (since == null || (a.date != null && !a.date!.isBefore(since))))
          a,
    ];
  }

  Future<void> _openFilter() async {
    var type = _type;
    var days = _days;
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: const Text('Filter'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PaySectionLabel('Request Type'),
                const SizedBox(height: 8),
                PayChoiceChips<String?>(
                  options: [for (final e in _requestTypes.entries) (e.key, e.value)],
                  selected: type,
                  onChanged: (v) => set(() => type = v),
                ),
                const SizedBox(height: 18),
                const PaySectionLabel('Duration'),
                const SizedBox(height: 8),
                PayChoiceChips<int?>(
                  options: [(null, 'Any time'), for (final e in _durations.entries) (e.key, e.value)],
                  selected: days,
                  onChanged: (v) => set(() => days = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => set(() {
                type = null;
                days = null;
              }),
              child: const Text('Reset'),
            ),
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Apply')),
          ],
        ),
      ),
    );
    if (apply == true && mounted) {
      setState(() {
        _type = type;
        _days = days;
      });
    }
  }

  Future<void> _delete(CorpLoanApplicationItem a) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Draft'),
        content: Text('Are you sure you want to delete the draft application named ${a.title} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final r = await ref.read(corpLoansRepositoryProvider).deleteDraft(a.refId);
    if (!mounted) return;
    if (r is Success<bool> && r.data == true) {
      setState(() => _deleted = a.title);
      ref.invalidate(corpLoanApplicationsByStatusProvider(CorpAppStatus.draft));
    } else {
      corpSnack(context, (r is Error<bool> ? r.error : null) ?? 'The draft could not be deleted.');
    }
  }

  Widget _card(CorpLoanApplicationItem a) {
    final muted = TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context));
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _open = a),
        child: DesignCard(
          padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: HomeColors.brand(context).withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(Icons.request_quote_outlined, color: HomeColors.brand(context), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title, style: TextStyle(fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context))),
                    const SizedBox(height: 2),
                    Text(a.type.isEmpty ? '-' : a.type, style: muted),
                    if (a.date != null) Text('On ${payDate(a.date)}', style: muted),
                  ],
                ),
              ),
              if (a.amount != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(corpMoney(a.amount), style: TextStyle(fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context))),
                ),
              if (_tab == CorpAppStatus.draft)
                IconButton(
                  tooltip: 'Delete',
                  icon: Icon(Icons.delete_outline, color: HomeColors.error(context)),
                  onPressed: () => _delete(a),
                )
              else
                Icon(Icons.chevron_right, color: HomeColors.textSecondary(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list() {
    final async = ref.watch(corpLoanApplicationsByStatusProvider(_tab));
    return async.when(
      loading: corpLoading,
      error: (e, _) => corpFailed(e, () => ref.invalidate(corpLoanApplicationsByStatusProvider(_tab))),
      data: (all) {
        final rows = _filter(all);
        if (rows.isEmpty) return const DesignCard(child: CorpEmpty('No applications found.'));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final a in rows) ...[_card(a), const SizedBox(height: 10)]
          ],
        );
      },
    );
  }

  Widget _tracker() {
    final filtered = _type != null || _days != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PaySegmented<CorpAppStatus>(
          options: [for (final s in CorpAppStatus.values) (s, s.label)],
          selected: _tab,
          onChanged: (s) => setState(() {
            _tab = s;
            _deleted = null;
          }),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: DesignBoxField(
                label: 'Search',
                controller: _search,
                hint: 'Reference number or draft name',
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Filter',
              icon: Badge(
                isLabelVisible: filtered,
                smallSize: 8,
                backgroundColor: HomeColors.brand(context),
                child: Icon(Icons.filter_list_rounded, color: HomeColors.brand(context)),
              ),
              onPressed: _openFilter,
            ),
          ],
        ),
        if (_deleted != null) ...[
          const SizedBox(height: 12),
          PayNote('The draft application named $_deleted has been deleted successfully.', icon: Icons.check_circle_outline),
        ],
        const SizedBox(height: 14),
        _list(),
      ],
    );
  }

  Widget _details(CorpLoanApplicationItem a) {
    final docs = ref.watch(corpLoanApplicationDocumentsProvider(a.refId));
    final partyId = ref.watch(corpLoansPartyIdProvider).valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesignCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PayReviewRow(label: 'Request Type', value: a.type.isEmpty ? '-' : a.type),
              PayReviewRow(label: 'Reference Number', value: a.refId),
              if (a.midOfficeRefNo != null) PayReviewRow(label: 'Bank Reference Number', value: a.midOfficeRefNo!),
              if (a.draftName != null) PayReviewRow(label: 'Draft Name', value: a.draftName!),
              PayReviewRow(label: 'Status', value: _tab.label),
              if (a.amount != null) PayReviewRow(label: 'Loan Applied for', value: corpMoney(a.amount)),
              if (a.date != null) PayReviewRow(label: 'Date', value: 'On ${payDate(a.date)}'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const PaySectionLabel('Documents'),
        const SizedBox(height: 8),
        docs.when(
          loading: corpLoading,
          error: (e, _) => corpFailed(e, () => ref.invalidate(corpLoanApplicationDocumentsProvider(a.refId))),
          data: (list) => list.isEmpty
              ? const DesignCard(child: CorpEmpty('No documents uploaded.', icon: Icons.description_outlined))
              : DesignCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final d in list)
                        ListTile(
                          leading: Icon(Icons.description_outlined, color: HomeColors.brand(context)),
                          title: Text(d.title.isEmpty ? d.contentId : d.title),
                          trailing: IconButton(
                            tooltip: 'Download',
                            icon: Icon(Icons.file_download_outlined, color: HomeColors.brand(context)),
                            onPressed: partyId == null
                                ? null
                                : () => corpSaveFile(
                                      context,
                                      ref.read(corpLoansRepositoryProvider).downloadDocument(d.contentId, partyId),
                                      d.title.isEmpty ? d.contentId : d.title,
                                      mimeType: _mime(d.title),
                                    ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  static String _mime(String name) => switch (name.split('.').last.toLowerCase()) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'doc' => 'application/msword',
        'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'xls' => 'application/vnd.ms-excel',
        'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'txt' => 'text/plain',
        _ => 'application/pdf',
      };

  @override
  Widget build(BuildContext context) {
    final open = _open;
    return DesignPage(
      title: open == null ? 'Application Tracker' : 'Application Details',
      onBack: open == null ? widget.onBack : () => setState(() => _open = null),
      child: open == null ? _tracker() : _details(open),
    );
  }
}
