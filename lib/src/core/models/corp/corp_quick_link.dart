/// The corporate dashboard's "Quick Links" shortcuts.
///
/// Kept as data (rather than hard-coded widgets) so the tile order, labels
/// and destinations can later come from the host's
/// `me/components` / `dashboards/modules` response — which is what drives
/// this panel in digx-ui — without touching the layout code.
enum CorpQuickLinkId {
  adhocPayment,
  fundTransfer,
  selfTransfer,
  fileUpload,
  issueDraft,
  uploadedFileInquiry,
  loanRequest,
}

class CorpQuickLink {
  const CorpQuickLink({
    required this.id,
    required this.label,
    this.routeName,
  });

  final CorpQuickLinkId id;

  /// Two-line label as shown in the design ("Adhoc\nPayment").
  final String label;

  /// Named route to push, or `null` for a destination that is not built yet
  /// (the tile then reports itself as coming soon instead of dead-ending).
  final String? routeName;

  bool get isAvailable => routeName != null && routeName!.isNotEmpty;
}
