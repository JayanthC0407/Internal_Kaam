import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:demo_bank/src/core/models/corp/corp_loans_models.dart';
import 'package:demo_bank/src/view/providers/corp/corp_loans_providers.dart';
import 'package:demo_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:demo_bank/src/view/screens/corp/loans/corp_loans_widgets.dart';
import 'package:demo_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:demo_bank/src/view/widgets/design_page.dart';

/// Corporate Loans - Messages / - Advices (OBDX `obcl-loan-messages`,
/// `obcl-loan-advices`): pick a Loan Account, then its SWIFT messages or
/// advices — Message ID (opens the text), Date, Description, Message Type
/// or Event Description, and Download (PDF).
class CorpLoanNoticesScreen extends ConsumerStatefulWidget {
  const CorpLoanNoticesScreen({super.key, required this.kind, required this.onBack});

  final CorpLoanNoticeKind kind;
  final VoidCallback onBack;

  @override
  ConsumerState<CorpLoanNoticesScreen> createState() => _CorpLoanNoticesScreenState();
}

class _CorpLoanNoticesScreenState extends ConsumerState<CorpLoanNoticesScreen> {
  CorpLoan? _loan;

  bool get _messages => widget.kind == CorpLoanNoticeKind.message;

  String get _noun => _messages ? 'Messages' : 'Advices';

  void _view(CorpLoanNotice n) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(n.messageId),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: SelectableText(
                n.text.isEmpty ? 'No $_noun Available' : n.text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
        ),
      );

  void _download(CorpLoan loan, CorpLoanNotice n) => corpSaveFile(
        context,
        ref.read(corpLoansRepositoryProvider).downloadNotice(loan.id, widget.kind, n.messageId),
        '${_messages ? 'message' : 'advice'}_${n.messageId}.pdf',
      );

  Widget _table(bool wide, CorpLoan loan, List<CorpLoanNotice> rows) {
    if (rows.isEmpty) return DesignCard(child: CorpEmpty('No $_noun Available'));
    const flex = [3, 2, 4, 3, 2];
    final text = TextStyle(fontSize: 13, color: HomeColors.textPrimary(context));
    final link = text.copyWith(color: HomeColors.brand(context), fontWeight: FontWeight.w600, decoration: TextDecoration.underline);
    Widget id(CorpLoanNotice n) => InkWell(onTap: () => _view(n), child: Text(n.messageId, style: link));
    Widget download(CorpLoanNotice n) => IconButton(
          tooltip: 'Download',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.file_download_outlined, color: HomeColors.brand(context)),
          onPressed: () => _download(loan, n),
        );
    String kindText(CorpLoanNotice n) => (_messages ? n.messageType : n.eventDescription) ?? '-';
    return DesignCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide)
            CorpTableHeader(
              cells: ['Message ID', 'Date', 'Description', _messages ? 'Message Type' : 'Event Description', 'Action'],
              flex: flex,
            ),
          for (final (i, n) in rows.indexed)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: wide ? 4 : 10),
              decoration: BoxDecoration(
                border: i == rows.length - 1 ? null : Border(bottom: BorderSide(color: HomeColors.divider(context))),
              ),
              child: wide
                  ? Row(
                      children: [
                        Expanded(flex: flex[0], child: Align(alignment: Alignment.centerLeft, child: id(n))),
                        Expanded(flex: flex[1], child: Text(payDate(n.date), style: text)),
                        Expanded(flex: flex[2], child: Text(n.description.isEmpty ? '-' : n.description, style: text)),
                        Expanded(flex: flex[3], child: Text(kindText(n), style: text)),
                        Expanded(flex: flex[4], child: Align(alignment: Alignment.centerLeft, child: download(n))),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              id(n),
                              const SizedBox(height: 2),
                              Text(n.description.isEmpty ? kindText(n) : n.description, style: text),
                              Text(
                                '${payDate(n.date)} · ${kindText(n)}',
                                style: TextStyle(fontSize: 12, color: HomeColors.textSecondary(context)),
                              ),
                            ],
                          ),
                        ),
                        download(n),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loan = _loan;
    return DesignPage(
      title: 'Corporate Loans - $_noun',
      onBack: widget.onBack,
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 720;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesignCard(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: CorpLoanAccountField(selected: loan, onChanged: (l) => setState(() => _loan = l)),
                  ),
                ),
              ),
              if (loan != null) ...[
                const SizedBox(height: 14),
                ref.watch(corpLoanNoticesProvider((loan.id, widget.kind))).when(
                      loading: corpLoading,
                      error: (e, _) => corpFailed(e, () => ref.invalidate(corpLoanNoticesProvider((loan.id, widget.kind)))),
                      data: (rows) => _table(wide, loan, rows),
                    ),
              ],
            ],
          );
        },
      ),
    );
  }
}
