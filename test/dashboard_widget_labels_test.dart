import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/utils/common/dashboard_widget_labels.dart';

void main() {
  group('DashboardWidgetLabels.forComponent', () {
    test('derives the label the real Personalize screen shows', () {
      // Verified against the corporate Personalize screen listing.
      expect(
        DashboardWidgetLabels.forComponent('account-financial-summary'),
        'Account Financial Summary',
      );
      expect(
        DashboardWidgetLabels.forComponent('account-quick-links'),
        'Account Quick Links',
      );
      expect(
        DashboardWidgetLabels.forComponent('currency-exposure'),
        'Currency Exposure',
      );
      expect(
        DashboardWidgetLabels.forComponent('bulk-file-upload'),
        'Bulk File Upload',
      );
      expect(
        DashboardWidgetLabels.forComponent('cash-flow-forecast'),
        'Cash Flow Forecast',
      );
      expect(
        DashboardWidgetLabels.forComponent('financial-overview'),
        'Financial Overview',
      );
    });

    test('applies the overrides where the real screen differs', () {
      expect(
        DashboardWidgetLabels.forComponent('pickup-point-collections'),
        'Collections as per Pickup Points',
      );
      expect(
        DashboardWidgetLabels.forComponent('view-cash-flow-widget'),
        'View Cash Flow Details',
      );
      expect(DashboardWidgetLabels.forComponent('limits-widget'), 'Limits');
      expect(
        DashboardWidgetLabels.forComponent('credit-line'),
        'Credit Line Usage',
      );
      expect(
        DashboardWidgetLabels.forComponent('cash-flow-snapshot'),
        "Cash Flow Today's Snapshot",
      );
      expect(
        DashboardWidgetLabels.forComponent('td-calculator'),
        'Deposit Calculator',
      );
    });

    test('keeps acronyms uppercase', () {
      expect(DashboardWidgetLabels.forComponent('td-summary'), 'TD Summary');
      expect(
        DashboardWidgetLabels.forComponent('td-accounts-overview'),
        'TD Accounts Overview',
      );
    });

    test('still names a component the catalog has never seen', () {
      // The environment's catalog is richer than ours, so unknown
      // componentNames must not render blank.
      expect(
        DashboardWidgetLabels.forComponent('purchase-order-status-summary'),
        'Purchase Order Status Summary',
      );
      expect(
        DashboardWidgetLabels.forComponent('unreconciled-cash-flows'),
        'Unreconciled Cash Flows',
      );
    });

    test('handles an empty name without throwing', () {
      expect(DashboardWidgetLabels.forComponent(''), '');
      expect(DashboardWidgetLabels.forComponent('   '), '');
    });
  });

  group('DashboardWidgetLabels.forModule', () {
    test('splits camelCase and hyphenated module ids', () {
      // These are the 16 group headings on the real Personalize screen.
      expect(
        DashboardWidgetLabels.forModule('corporateDashboard'),
        'Corporate Dashboard',
      );
      expect(DashboardWidgetLabels.forModule('cash-management'), 'Cash Management');
      expect(
        DashboardWidgetLabels.forModule('liquidity-management'),
        'Liquidity Management',
      );
      expect(
        DashboardWidgetLabels.forModule('personal-finance-management'),
        'Personal Finance Management',
      );
      expect(
        DashboardWidgetLabels.forModule('virtual-account-management'),
        'Virtual Account Management',
      );
      expect(DashboardWidgetLabels.forModule('credit-facility'), 'Credit Facility');
      expect(DashboardWidgetLabels.forModule('term-deposits'), 'Term Deposits');
    });

    test('falls back to Other for a missing module', () {
      expect(DashboardWidgetLabels.forModule(''), 'Other');
    });
  });
}
