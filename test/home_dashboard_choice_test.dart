import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/lfw_progress.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/core/utils/common/user_type_resolver.dart';
import 'package:ubci_bank/src/infra/repositories/common/login_wizard_repository.dart';
import 'package:ubci_bank/src/infra/session/session_manager.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/routes/routes_const.dart';
import 'package:ubci_bank/src/view/screens/corp/corp_dashboard_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/home_dashboard_screen.dart';
import 'package:ubci_bank/src/view/widgets/session_activity_scope.dart';

Map<String, dynamic> _me({
  required List<String> roles,
  List<Map<String, dynamic>> dashboards = const [],
  int statusCode = 200,
}) =>
    {
      'statusCode': statusCode,
      'body': {
        'userProfile': {'userName': 'someone', 'roles': roles},
        'dashboardResponse': {'dashboardDTOs': dashboards},
      },
    };

const _corporateDashboard = {
  'dashboardId': '18',
  'dashboardClass': 'USER_TYPE',
  'dashboardClassValue': 'corporateuser',
  'factory': true,
};

/// Serves a fixed `me` result and records logouts. Only what the gate calls
/// before it has a dashboard to build is faked.
class _FakeSessionManager implements SessionManager {
  _FakeSessionManager({this.profile});

  Map<String, dynamic>? profile;
  int profileReads = 0;
  int logouts = 0;

  @override
  Future<Map<String, dynamic>?> fetchProfileResponse() async {
    profileReads++;
    return profile;
  }

  @override
  Future<void> logout() async => logouts++;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

class _AllowingWizardRepository implements LoginWizardRepository {
  @override
  Future<LfwGateResult> checkGate() async => const LfwGateAllowed();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

void main() {
  group('homeDashboardFor', () {
    test('no `me` is unresolved — not Retail', () {
      // The bug: a restored session whose `me` call failed arrived here
      // with nothing, and was sent to the Retail dashboard.
      expect(homeDashboardFor(null), HomeDashboardKind.unresolved);
    });

    test('a failed or empty `me` is unresolved', () {
      expect(
        homeDashboardFor(_me(roles: ['corporateuser'], statusCode: 500)),
        HomeDashboardKind.unresolved,
      );
      expect(
        homeDashboardFor(const {'statusCode': 200, 'body': {}}),
        HomeDashboardKind.unresolved,
      );
    });

    test('a corporate `me` opens the Corporate dashboard', () {
      expect(
        homeDashboardFor(
          _me(roles: ['corporateuser'], dashboards: [_corporateDashboard]),
        ),
        HomeDashboardKind.corporate,
      );
    });

    test('a retail `me` opens the Retail dashboard', () {
      expect(
        homeDashboardFor(_me(roles: ['retailuser'])),
        HomeDashboardKind.retail,
      );
    });

    test('a `me` with an unrecognised type still falls back to Retail', () {
      // Unchanged, documented behaviour — this fallback is only for a user
      // whose `me` we have, never for a missing one.
      expect(
        homeDashboardFor(_me(roles: ['someotherrole'])),
        HomeDashboardKind.retail,
      );
    });
  });

  group('AuthenticatedHomeGate without `me`', () {
    Future<_FakeSessionManager> pumpGate(
      WidgetTester tester, {
      Map<String, dynamic>? fetched,
    }) async {
      final session = _FakeSessionManager(profile: fetched);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionManagerProvider.overrideWithValue(session),
            loginWizardRepositoryProvider
                .overrideWithValue(_AllowingWizardRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: LocaleConfig.supportedLocales,
            // A restored session: the trace has no `me`.
            home: const AuthenticatedHomeGate(
              args: HomeDashboardArgs(userName: 'nazcorp'),
            ),
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(body: Text('ROUTE ${settings.name}')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return session;
    }

    testWidgets('reads `me` itself, and never opens Retail as a guess',
        (tester) async {
      final session = await pumpGate(tester);

      expect(session.profileReads, 1);
      expect(find.byType(HomeDashboardScreen), findsNothing);
      expect(find.byType(CorpDashboardScreen), findsNothing);
      expect(find.text("We couldn't load your profile"), findsOneWidget);
    });

    testWidgets('Retry reads `me` again', (tester) async {
      final session = await pumpGate(tester);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(session.profileReads, 2);
      expect(find.byType(HomeDashboardScreen), findsNothing);
    });

    testWidgets('Sign in again logs out and returns to login', (tester) async {
      final session = await pumpGate(tester);

      await tester.tap(find.text('Sign in again'));
      await tester.pumpAndSettle();

      expect(session.logouts, 1);
      expect(find.text('ROUTE ${RoutesConst.loginScreen}'), findsOneWidget);
    });
  });
}
