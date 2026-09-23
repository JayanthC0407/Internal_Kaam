import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/utils/corp/corp_widget_labels.dart';

void main() {
  group('CorpWidgetLabels.forComponent', () {
    test('derives the label the real Personalize screen shows', () {
      // Verified against the corporate Personalize screen listing.
      expect(
        CorpWidgetLabels.forComponent('account-financial-summary'),
        'Account Financial Summary',
      );
      expect(
        CorpWidgetLabels.forComponent('account-quick-links'),
        'Account Quick Links',
      );
      expect(
        CorpWidgetLabels.forComponent('currency-exposure'),
        'Currency Exposure',
      );
      expect(
        CorpWidgetLabels.forComponent('bulk-file-upload'),
        'Bulk File Upload',
      );
      expect(
        CorpWidgetLabels.forComponent('cash-flow-forecast'),
        'Cash Flow Forecast',
      );
      expect(
        CorpWidgetLabels.forComponent('financial-overview'),
        'Financial Overview',
      );
    });

    test('applies the overrides where the real screen differs', () {
      expect(
        CorpWidgetLabels.forComponent('pickup-point-collections'),
        'Collections as per Pickup Points',
      );
      expect(
        CorpWidgetLabels.forComponent('view-cash-flow-widget'),
        'View Cash Flow Details',
      );
      expect(CorpWidgetLabels.forComponent('limits-widget'), 'Limits');
      expect(
        CorpWidgetLabels.forComponent('credit-line'),
        'Credit Line Usage',
      );
      expect(
        CorpWidgetLabels.forComponent('cash-flow-snapshot'),
        "Cash Flow Today's Snapshot",
      );
      expect(
        CorpWidgetLabels.forComponent('td-calculator'),
        'Deposit Calculator',
      );
    });

    test('keeps acronyms uppercase', () {
      expect(CorpWidgetLabels.forComponent('td-summary'), 'TD Summary');
      expect(
        CorpWidgetLabels.forComponent('td-accounts-overview'),
        'TD Accounts Overview',
      );
    });

    test('still names a component the catalog has never seen', () {
      // The environment's catalog is richer than ours, so unknown
      // componentNames must not render blank.
      expect(
        CorpWidgetLabels.forComponent('purchase-order-status-summary'),
        'Purchase Order Status Summary',
      );
      expect(
        CorpWidgetLabels.forComponent('unreconciled-cash-flows'),
        'Unreconciled Cash Flows',
      );
    });

    test('handles an empty name without throwing', () {
      expect(CorpWidgetLabels.forComponent(''), '');
      expect(CorpWidgetLabels.forComponent('   '), '');
    });
  });

  group('CorpWidgetLabels.forModule', () {
    test('splits camelCase and hyphenated module ids', () {
      // These are the 16 group headings on the real Personalize screen.
      expect(
        CorpWidgetLabels.forModule('corporateDashboard'),
        'Corporate Dashboard',
      );
      expect(CorpWidgetLabels.forModule('cash-management'), 'Cash Management');
      expect(
        CorpWidgetLabels.forModule('liquidity-management'),
        'Liquidity Management',
      );
      expect(
        CorpWidgetLabels.forModule('personal-finance-management'),
        'Personal Finance Management',
      );
      expect(
        CorpWidgetLabels.forModule('virtual-account-management'),
        'Virtual Account Management',
      );
      expect(CorpWidgetLabels.forModule('credit-facility'), 'Credit Facility');
      expect(CorpWidgetLabels.forModule('term-deposits'), 'Term Deposits');
    });

    test('falls back to Other for a missing module', () {
      expect(CorpWidgetLabels.forModule(''), 'Other');
    });
  });
}
