/// Display names for dashboard widgets and their modules.
///
/// `moduleComponents.json` carries **no** human-readable labels — OBDX web
/// resolves them from its i18n resource bundles, which we do not have. So
/// labels are derived from the `componentName` and overridden only where
/// the real Personalize screen is known to differ.
///
/// Deriving rather than hard-coding a full table is deliberate: the
/// environment's catalog is richer than any list we hold (it contains whole
/// modules ours does not, e.g. Purchase Order Management and
/// Reconciliation), so an unknown component must still get a readable name.
/// OBDX does the same — its own Personalize screen shows bare component
/// names such as `trade-dashboard-listing` where no translation exists.
class DashboardWidgetLabels {
  DashboardWidgetLabels._();

  /// Labels confirmed against the real corporate Personalize screen where
  /// they differ from the derived form. Everything not listed here derives
  /// correctly (`account-financial-summary` → "Account Financial Summary").
  static const Map<String, String> _componentOverrides = {
    // corporateDashboard
    'credit-line': 'Credit Line Usage',
    'financial-position-currency': 'Financial Position By Currency',
    'limits-widget': 'Limits',
    'payable-receivable-bills': 'Bills Receivable',
    'pending-for-action-mail-box': 'New Messages',
    // cash-management
    'cash-flow-snapshot': "Cash Flow Today's Snapshot",
    'pickup-point-collections': 'Collections as per Pickup Points',
    'view-cash-flow-widget': 'View Cash Flow Details',
    // calculators
    'td-calculator': 'Deposit Calculator',
    // loans
    'loan-installments-due': 'Installments Due',
  };

  /// Acronyms that must not be title-cased into "Td" / "Api".
  static const Map<String, String> _acronyms = {
    'td': 'TD',
    'dd': 'DD',
    'api': 'API',
    'ui': 'UI',
    'sms': 'SMS',
  };

  /// Display name for a widget's `componentName`.
  static String forComponent(String componentName) {
    final key = componentName.trim();
    if (key.isEmpty) return '';
    final override = _componentOverrides[key];
    if (override != null) return override;
    return _humanize(key);
  }

  /// Display name for a catalog `module`, e.g. `corporateDashboard` →
  /// "Corporate Dashboard", `cash-management` → "Cash Management".
  static String forModule(String module) {
    final key = module.trim();
    if (key.isEmpty) return 'Other';
    return _humanize(key);
  }

  /// `some-component-name` / `someComponentName` → "Some Component Name".
  static String _humanize(String raw) {
    // Split camelCase into separate words before splitting on separators,
    // so `corporateDashboard` becomes "corporate Dashboard".
    final spaced = raw.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    final words = spaced
        .split(RegExp(r'[-_\s]+'))
        .where((word) => word.isNotEmpty)
        .map((word) {
      final lower = word.toLowerCase();
      final acronym = _acronyms[lower];
      if (acronym != null) return acronym;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    });

    return words.join(' ');
  }
}
