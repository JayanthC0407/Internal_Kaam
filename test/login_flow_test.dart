import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/alternate_login_method.dart';
import 'package:ubci_bank/src/core/models/common/lfw_progress.dart';
import 'package:ubci_bank/src/core/models/common/security_question.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/pref/preference_helper.dart';
import 'package:ubci_bank/src/infra/repositories/common/login_wizard_repository.dart';
import 'package:ubci_bank/src/infra/security/biometric_service.dart';
import 'package:ubci_bank/src/infra/security/biometric_unlock_policy.dart';
import 'package:ubci_bank/src/infra/session/session_manager.dart';
import 'package:ubci_bank/src/view/providers/global_providers.dart';
import 'package:ubci_bank/src/view/screens/common/auth/login_screen.dart';
import 'package:ubci_bank/src/view/screens/common/auth/login_wizard_screen.dart';
import 'package:ubci_bank/src/view/screens/retail/home_dashboard_screen.dart';
import 'package:ubci_bank/src/view/widgets/auth/otp_challenge_body.dart';
import 'package:ubci_bank/src/view/widgets/biometric_enrollment_prompt.dart';

// ── Fakes ────────────────────────────────────────────────────────────────

/// Biometric enrollment as the phone would store it after OBDX enrollment.
class _FakePrefs implements PreferenceHelper {
  _FakePrefs({
    this.enabled = false,
    this.serverEnrolled = false,
    this.hasToken = false,
    this.method,
  });

  final bool enabled;
  final bool serverEnrolled;
  final bool hasToken;
  final AlternateLoginMethod? method;

  @override
  Future<bool> isKeepSignedIn() async => true;
  @override
  Future<bool> isBiometricEnabled() async => enabled;
  @override
  Future<bool> isBiometricServerEnrolled() async => serverEnrolled;
  @override
  Future<bool> hasBiometricSetupToken() async => hasToken;
  @override
  Future<AlternateLoginMethod?> getAlternateLoginMethod() async => method;
  @override
  Future<({String userName, String encryptedPassword, String? plainPassword})?>
      getPendingBiometricEnrollment() async => null;
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('prefs ${i.memberName}');
}

class _FakeBiometrics implements BiometricService {
  _FakeBiometrics({this.canAuth = true});

  final bool canAuth;

  @override
  Future<bool> canAuthenticate() async => canAuth;
  @override
  Future<BiometricPresentation> presentation() async => BiometricPresentation.android;
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('biometrics ${i.memberName}');
}

/// Records whether the post-login step renewed the OBDX token.
class _FakeEnrollment implements BiometricEnrollmentController {
  _FakeEnrollment({required this.enabled});

  final bool enabled;
  int renewals = 0;

  @override
  Future<bool> isEnabled() async => enabled;
  @override
  Future<void> refreshSetupTokenFromPendingQuietly() async => renewals++;
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('enrollment ${i.memberName}');
}

class _FakeSession implements SessionManager {
  @override
  Future<String?> getLastUserName() async => null;
  @override
  Future<bool> isAuthenticated() async => true;
  @override
  Future<bool> isSessionExpired() async => false;
  @override
  Future<void> recordActivity() async {}
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('session ${i.memberName}');
}

class _FakeWizardRepo implements LoginWizardRepository {
  @override
  Future<ResponseHandler<int>> fetchRequiredQuestionCount() async => ResponseHandler.success(2, code: 200);

  @override
  Future<ResponseHandler<SecurityQuestionCatalog>> fetchMasterSecurityQuestions() async =>
      ResponseHandler.success(
        const SecurityQuestionCatalog(options: [
          SecurityQuestionOption(id: 'Q1', text: 'What was the name of your first pet?'),
          SecurityQuestionOption(id: 'Q2', text: 'In which city were you born?'),
        ]),
        code: 200,
      );

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('wizard ${i.memberName}');
}

final _enrolled = _FakePrefs(
  enabled: true,
  serverEnrolled: true,
  hasToken: true,
  method: AlternateLoginMethod.fingerprint,
);

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  PreferenceHelper? prefs,
  BiometricService? biometrics,
  BiometricEnrollmentController? enrollment,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Fresh screen state for each pump (the same screen may be pumped twice).
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferenceHelperProvider.overrideWithValue(prefs ?? _FakePrefs()),
        sessionManagerProvider.overrideWithValue(_FakeSession()),
        biometricServiceProvider.overrideWithValue(biometrics ?? _FakeBiometrics()),
        loginWizardRepositoryProvider.overrideWithValue(_FakeWizardRepo()),
        if (enrollment != null) biometricEnrollmentProvider.overrideWithValue(enrollment),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: LocaleConfig.supportedLocales,
        home: home,
        onGenerateRoute: (s) => MaterialPageRoute<void>(
          settings: s,
          builder: (_) => Scaffold(body: Text('ROUTE ${s.name}')),
        ),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

LoginWizardScreen _wizard({required bool mandatory}) => LoginWizardScreen(
      args: LoginWizardArgs(
        homeArgs: const HomeDashboardArgs(userName: 'alexm'),
        initialProgress: LfwProgress(
          status: 'INPROGRESS',
          steps: [
            for (final (i, id) in const ['001', '002'].indexed)
              LfwStepProgress(
                id: '${101 + i}',
                wizardStepId: id,
                order: i + 1,
                mandatory: mandatory,
                enabled: true,
                completed: false,
              ),
          ],
        ),
      ),
    );

void main() {
  group('fingerprint on Login (OBDX alternate login)', () {
    test('offered only on a device enrolled with OBDX', () async {
      expect(
        await BiometricUnlockPolicy.canOfferQuickLogin(preferences: _enrolled, biometrics: _FakeBiometrics()),
        isTrue,
      );
      // Missing any part of the enrollment → no fingerprint.
      for (final prefs in [
        _FakePrefs(serverEnrolled: true, hasToken: true),
        _FakePrefs(enabled: true, hasToken: true),
        _FakePrefs(enabled: true, serverEnrolled: true),
        _FakePrefs(enabled: true, serverEnrolled: true, hasToken: true, method: AlternateLoginMethod.passcode),
      ]) {
        expect(
          await BiometricUnlockPolicy.canOfferQuickLogin(preferences: prefs, biometrics: _FakeBiometrics()),
          isFalse,
        );
      }
      // Fingerprint removed from the phone since enrolling.
      expect(
        await BiometricUnlockPolicy.canOfferQuickLogin(
          preferences: _enrolled,
          biometrics: _FakeBiometrics(canAuth: false),
        ),
        isFalse,
      );
    });

    testWidgets('Login shows "or" + fingerprint only when enrolled', (tester) async {
      await _pump(tester, const LoginScreen());
      expect(find.text('Welcome Back!'), findsOneWidget);
      expect(find.text('Sign in to continue with your banking activities securely.'), findsOneWidget);
      expect(find.byTooltip('Login with biometrics'), findsNothing);

      await _pump(tester, const LoginScreen(), prefs: _enrolled);
      expect(find.text('or'), findsOneWidget);
      expect(find.byTooltip('Login with biometrics'), findsOneWidget);
    });
  });

  group('OTP Code Verification', () {
    testWidgets('underlined slots, no repeated title, resend after 30 s', (tester) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      var resends = 0;
      await _pump(
        tester,
        Scaffold(
          body: OtpChallengeBody(
            title: 'OTP Code Verification',
            subtitle: 'Enter the 4-digit code',
            controller: controller,
            focusNode: focus,
            isLoading: false,
            onSubmit: () {},
            onResend: () => resends++,
            resendsLeft: 2,
            expandToFill: false,
            showTitle: false,
            underlineBoxes: true,
            resendCooldownSeconds: 30,
            submitLabel: 'Verify',
          ),
        ),
      );
      expect(find.text('OTP Code Verification'), findsNothing);
      expect(find.text('0'), findsNWidgets(4));
      expect(find.text('Resend code in 00:30'), findsOneWidget);
      expect(find.text('Resend'), findsNothing);

      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Resend'), findsOneWidget);
      await tester.tap(find.text('Resend'));
      await tester.pump();
      expect(resends, 1);
      // The countdown starts again after each resend.
      expect(find.text('Resend code in 00:30'), findsOneWidget);
      await tester.pump(const Duration(seconds: 31));
    });
  });

  group('login steps (OBDX login flow)', () {
    testWidgets('mandatory Terms: Accept only — no tick box, no Skip', (tester) async {
      await _pump(tester, _wizard(mandatory: true));
      expect(find.text('Terms and Conditions'), findsOneWidget);
      expect(find.text('Please read the following terms carefully before proceeding.'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
    });

    testWidgets('optional steps: Skip, then Remind Later', (tester) async {
      await _pump(tester, _wizard(mandatory: false));
      expect(find.text('Skip'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('User Security Questions have not been setup yet.'), findsOneWidget);
      expect(find.text('Remind Later'), findsOneWidget);

      // Putting off the last step goes home (no server call).
      await tester.tap(find.text('Remind Later'));
      await tester.pumpAndSettle();
      expect(find.text('Remind Later'), findsNothing);
    });
  });

  group('after a password login', () {
    Future<void> login(WidgetTester tester, _FakeEnrollment enrollment) async {
      await _pump(
        tester,
        Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => BiometricEnrollmentPrompt.afterPasswordLogin(context, ref),
              child: const Text('logged in'),
            ),
          ),
        ),
        enrollment: enrollment,
      );
      await tester.tap(find.text('logged in'));
      await tester.pumpAndSettle();
    }

    testWidgets('not set up → Enable Alternate Login sheet', (tester) async {
      await login(tester, _FakeEnrollment(enabled: false));
      expect(find.text('Enable Alternate Login'), findsOneWidget);
    });

    testWidgets('already set up → straight on: no sheet, no fingerprint prompt', (tester) async {
      // _FakeBiometrics throws if anything asks for a fingerprint.
      final enrollment = _FakeEnrollment(enabled: true);
      await login(tester, enrollment);
      expect(find.text('Enable Alternate Login'), findsNothing);
      expect(enrollment.renewals, 1); // OBDX token renewed quietly
      expect(tester.takeException(), isNull);
    });
  });

  group('Enable Alternate Login', () {
    testWidgets('sheet with Enable / Skip; Skip enrolls nothing', (tester) async {
      bool? result;
      await _pump(
        tester,
        Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () async => result = await BiometricEnrollmentPrompt.showEnableSheet(context, ref),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Enable Alternate Login'), findsOneWidget);
      expect(find.text('Enable'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Enable Alternate Login'), findsNothing);
      expect(result, isFalse);
    });
  });
}
