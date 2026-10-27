import 'package:flutter/material.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/service_requests/service_request_models.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/common/service_requests/raise_request_views.dart';
import 'package:ubci_bank/src/view/screens/common/service_requests/track_requests_views.dart';

/// OBDX's two Service Requests menu entries, one module page.
enum SrTab { track, raise }

/// Service Requests (OBDX `service-requests-menu`), Retail and Corporate:
/// Track Requests and Raise a New Request as the two halves of one page,
/// switched at the top — OBDX links them from each other's menu too.
///
///  - Track: the filter (Product, Category, From / To Date, Status), Apply,
///    then the requests; a request opens its details.
///  - Raise: search or Product → Category → request; its form (built by
///    the bank in the form builder); Review; Confirm; the reference.
///
/// Back walks up one step (details → list, review → form → catalogue)
/// before leaving the module.
class ServiceRequestsScreen extends StatefulWidget {
  const ServiceRequestsScreen({super.key, this.initialTab = SrTab.track, this.embedded = false, this.onBack});

  final SrTab initialTab;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<ServiceRequestsScreen> createState() => _ServiceRequestsScreenState();
}

class _ServiceRequestsScreenState extends State<ServiceRequestsScreen> {
  late SrTab _tab = widget.initialTab;

  /// Track: the filter last applied (null before Apply) and the open request.
  SrFilter? _filter;
  ServiceRequestSummary? _openRequest;

  /// Raise: the chosen request, the answers, and how far along it is.
  SrDefinition? _definition;
  SrSubmission? _review;
  ({String title, String message, String? reference, bool pending})? _done;

  /// Kept across Review → Back so nothing has to be typed again.
  Map<String, SrAnswer> _answers = {};

  @override
  void didUpdateWidget(ServiceRequestsScreen old) {
    super.didUpdateWidget(old);
    // The side menu picked the other entry while this page was open.
    if (old.initialTab != widget.initialTab) _switchTab(widget.initialTab);
  }

  void _switchTab(SrTab tab) => setState(() {
        _tab = tab;
        _openRequest = null;
        _resetRaise();
      });

  void _resetRaise() {
    _definition = null;
    _review = null;
    _done = null;
    _answers = {};
  }

  bool get _atTop => _tab == SrTab.track ? _openRequest == null : (_definition == null && _done == null);

  void _back() {
    if (_atTop) {
      widget.embedded ? widget.onBack?.call() : Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      if (_tab == SrTab.track) {
        _openRequest = null;
      } else if (_done != null) {
        _resetRaise();
      } else if (_review != null) {
        _review = null;
      } else {
        _definition = null;
        _answers = {};
      }
    });
  }

  Widget _body(bool wide) {
    if (_tab == SrTab.track) {
      final open = _openRequest;
      if (open != null) return SrRequestDetailView(summary: open, onBack: _back);
      return SrTrackView(
        filter: _filter,
        wide: wide,
        onApply: (f) => setState(() => _filter = f),
        onOpen: (r) => setState(() => _openRequest = r),
      );
    }
    final done = _done;
    if (done != null) {
      final l10n = AppLocalizations.of(context);
      return PayResultView(
        title: done.title,
        message: done.pending ? l10n.srPendingApproval : done.message,
        reference: done.reference,
        warning: done.pending,
        rows: const [],
        doneLabel: l10n.srTrackRequest,
        onDone: () => _switchTab(SrTab.track),
        anotherLabel: l10n.srRaiseAnother,
        onAnother: () => setState(_resetRaise),
      );
    }
    final review = _review;
    if (review != null) {
      return SrReviewView(
        submission: review,
        onBack: () => setState(() => _review = null),
        onCancel: () => setState(_resetRaise),
        onSubmitted: (reference, pending) => setState(() {
          final l10n = AppLocalizations.of(context);
          final form = review.definition.form;
          _done = (
            title: form?.header ?? review.definition.name,
            message: form?.confirmMessage ?? l10n.srSubmitted,
            reference: reference,
            pending: pending,
          );
          _review = null;
        }),
      );
    }
    final definition = _definition;
    if (definition != null) {
      return SrFormView(
        definitionId: definition.id,
        answers: _answers,
        wide: wide,
        onCancel: () => setState(_resetRaise),
        onReview: (full, answers) => setState(() {
          _answers = answers;
          _review = SrSubmission(definition: full, answers: answers);
        }),
      );
    }
    return SrCatalogView(onPick: (d) => setState(() => _definition = d));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final step = _tab == SrTab.track
        ? (_openRequest == null ? l10n.srTrackRequests : l10n.srRequestDetails)
        : (_done != null
            ? l10n.srRaiseNew
            : _review != null
                ? l10n.prefReview
                : _definition?.name ?? l10n.srRaiseNew);
    return PopScope(
      canPop: _atTop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: PayMenuPage(
        title: l10n.srTitle,
        subtitle: step,
        onBack: _back,
        builder: (context, wide) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: PaySegmented<SrTab>(
                options: [(SrTab.track, l10n.srTrackRequests), (SrTab.raise, l10n.srRaiseNew)],
                selected: _tab,
                onChanged: (t) {
                  if (t != _tab) _switchTab(t);
                },
              ),
            ),
            const SizedBox(height: 16),
            KeyedSubtree(
              key: ValueKey('$_tab-${_openRequest?.id}-${_definition?.id}-${_review != null}-${_done != null}'),
              child: _body(wide),
            ),
          ],
        ),
      ),
    );
  }
}
