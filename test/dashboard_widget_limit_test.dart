import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_config.dart';
import 'package:ubci_bank/src/core/models/common/dashboard/dashboard_widget_catalog.dart';
import 'package:ubci_bank/src/view/providers/common/personalization_providers.dart';
import 'package:ubci_bank/src/view/screens/common/personalize/dashboard_widget_limit.dart';
import 'package:ubci_bank/src/view/screens/corp/dashboard_widgets/corp_widget_registry.dart';
import 'package:ubci_bank/src/view/screens/retail/dashboard_widgets/retail_widget_registry.dart';

/// A loaded state whose saved `small` (phone) layout holds [saved], with an
/// optional open edit [draft].
PersonalizationState _state({
  List<String> saved = const [],
  List<String>? draft,
  Set<String> authorized = const {},
  DashboardBreakpoint breakpoint = DashboardBreakpoint.small,
}) {
  final config = DashboardConfig.fromPayload({
    'dashboardDTO': {
      'dashboardId': 'A',
      'dashboardName': 'n',
      'dashboardDescription': 'd',
      'dashboardClass': 'CUSTOM',
      'dashboardClassValue': 'custom',
      'factory': false,
      'layout': {
        'layout': {
          'defaultLayout': [],
          'large': [
            for (final name in saved) {'componentName': name, 'module': 'm'},
          ],
          'medium': [],
          'small': [
            for (final name in saved) {'componentName': name, 'module': 'm'},
          ],
        },
      },
    },
  });
  return PersonalizationState(
    config: config,
    breakpoint: breakpoint,
    authorized: DashboardAuthorizedComponents(authorized: authorized),
    authorizationStatus: DashboardAuthorizationStatus.loaded,
    draft: draft == null ? null : DashboardDraft(order: draft),
  );
}

const _corp = CorpWidgetRegistry();
const _retail = RetailWidgetRegistry();

void main() {
  test('the limit per screen size — from the widget-defaults sheet', () {
    expect(DashboardWidgetLimit.limitFor(DashboardBreakpoint.large), 8);
    expect(DashboardWidgetLimit.limitFor(DashboardBreakpoint.medium), 6);
    expect(DashboardWidgetLimit.limitFor(DashboardBreakpoint.small), 5);
  });

  test('always-shown tiles count: Corporate\'s accounts card', () {
    final limit = DashboardWidgetLimit.of(_state(), _corp);
    expect(limit.onScreen, 1);
  });

  test(
      'always-shown tiles count: Retail\'s accounts carousel, and My '
      'Spendings only once', () {
    // My Spendings is pinned; being in the saved selection too does not
    // make it two.
    final limit = DashboardWidgetLimit.of(
      _state(
          saved: ['spend-summary', 'loan-summary'],
          authorized: {'spend-summary', 'loan-summary'}),
      _retail,
    );
    expect(limit.onScreen, 3); // carousel + My Spendings + loan-summary
  });

  test('widgets the user is not authorized for are not counted', () {
    // They are never drawn, so they take no room.
    final limit = DashboardWidgetLimit.of(
      _state(saved: ['a', 'b'], authorized: {'a'}),
      _corp,
    );
    expect(limit.onScreen, 2); // a + the accounts card
  });

  test('can add until the limit, then not', () {
    final four = ['a', 'b', 'c', 'd'];
    final authorized = {'a', 'b', 'c', 'd', 'e'};

    final below = DashboardWidgetLimit.of(
      _state(saved: four.take(3).toList(), authorized: authorized),
      _corp,
    );
    expect(below.canAdd, isTrue);

    final atLimit = DashboardWidgetLimit.of(
      _state(saved: four, authorized: authorized),
      _corp,
    );
    expect(atLimit.onScreen, 5);
    expect(atLimit.canAdd, isFalse);
    expect(atLimit.isOverLimit, isFalse);
    expect(atLimit.allowsSave, isTrue);
  });

  test('the edit is counted, not only what is saved', () {
    final limit = DashboardWidgetLimit.of(
      _state(saved: ['a'], draft: ['a', 'b', 'c'], authorized: {'a', 'b', 'c'}),
      _corp,
    );
    expect(limit.savedOnScreen, 2);
    expect(limit.onScreen, 4);
  });

  test('a dashboard saved over the limit can shed widgets, not gain them', () {
    // Saved before the limit existed: 6 picked + the accounts card = 7 of 5.
    final six = ['a', 'b', 'c', 'd', 'e', 'f'];
    final authorized = {...six, 'g'};

    final removingOne = DashboardWidgetLimit.of(
      _state(saved: six, draft: six.take(5).toList(), authorized: authorized),
      _corp,
    );
    expect(removingOne.isOverLimit, isTrue);
    expect(removingOne.excess, 1);
    expect(removingOne.canAdd, isFalse);
    // Still over, but it is progress, so it can be saved.
    expect(removingOne.allowsSave, isTrue);

    final swapping = DashboardWidgetLimit.of(
      _state(saved: six, draft: [...six, 'g'], authorized: authorized),
      _corp,
    );
    expect(swapping.allowsSave, isFalse);
  });

  test('a larger screen allows more', () {
    final limit = DashboardWidgetLimit.of(
      _state(
        saved: ['a', 'b', 'c', 'd', 'e', 'f'],
        authorized: {'a', 'b', 'c', 'd', 'e', 'f'},
        breakpoint: DashboardBreakpoint.large,
      ),
      _corp,
    );
    expect(limit.limit, 8);
    expect(limit.onScreen, 7);
    expect(limit.canAdd, isTrue);
  });
}
