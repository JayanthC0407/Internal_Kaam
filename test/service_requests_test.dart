import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/preferences/preferences_models.dart';
import 'package:ubci_bank/src/core/models/common/service_requests/service_request_models.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/service_requests_repository.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/providers/common/service_requests_providers.dart';
import 'package:ubci_bank/src/view/screens/common/service_requests/service_requests_screen.dart';

// Field names follow OBDX service-requests-* model.js; values are made up.

final _definitions = {
  'serviceRequestResponse': [
    {'id': 'SR01', 'name': 'Cheque Book Request', 'product': 'Accounts', 'categoryType': 'C1'},
    {'id': 'SR02', 'name': 'Update Address', 'product': 'Profile', 'categoryType': 'C9'},
  ],
};

final _form = {
  'serviceRequestResponse': [
    {
      'id': 'SR01',
      'name': 'Cheque Book Request',
      'product': 'Accounts',
      'categoryType': 'C1',
      'priorityType': 'MEDIUM',
      'form': {
        'header': 'Cheque Book',
        'confirmMessage': 'We have your cheque book request.',
        'infoNote': {'header': 'Note', 'description': 'Delivered in 5 days.'},
        'fields': [
          {
            'type': 'FFTB',
            'name': 'leaves',
            'label': 'Number of Leaves',
            'sequenceNumber': 2,
            'errorMessage': 'Enter the number of leaves',
            'validation': {'mandatory': true, 'minLength': 1, 'maxLength': 3, 'textBoxValidationType': 'NUMBERS'},
          },
          {
            'type': 'SCH',
            'name': 'h1',
            'label': '',
            'sequenceNumber': 1,
            'values': [
              {'code': 'H', 'description': 'Book Details'},
            ],
          },
          {
            'type': 'FFRB',
            'name': 'delivery',
            'label': 'Delivery',
            'sequenceNumber': 3,
            'validation': {'mandatory': true},
            'values': [
              {'code': 'BR', 'description': 'Branch', 'sequenceNumber': 1},
              {'code': 'HM', 'description': 'Home', 'sequenceNumber': 2},
            ],
          },
        ],
      },
    },
  ],
};

final _requests = {
  'list': [
    {
      'id': 'REF001',
      'creationDate': '2026-10-01T10:00:00',
      'status': 'PE',
      'requestType': 'OTHERS',
      'definition': {'name': 'Cheque Book Request'},
    },
    {
      'id': 'REF002',
      'creationDate': '2026-10-20T10:00:00',
      'status': 'CO',
      'requestType': 'OTHERS',
      'definition': {'name': 'Update Address'},
    },
  ],
};

final _detail = {
  'serviceRequestDTO': {
    'id': 'REF001',
    'status': 'PE',
    'requestType': 'OTHERS',
    'creationDate': '2026-10-01T10:00:00',
    'definition': {'name': 'Cheque Book Request'},
    'comments': 'Being printed',
    'requestData':
        '{&quot;elements&quot;:[{&quot;id&quot;:&quot;leaves&quot;,&quot;type&quot;:&quot;FFTB&quot;,&quot;label&quot;:&quot;Number of Leaves&quot;,&quot;values&quot;:[&quot;25&quot;],&quot;displayValues&quot;:[&quot;25&quot;]}]}',
  },
};

/// `implements`, not `extends`: the real one would build the Dio client.
class _FakeRepo implements ServiceRequestsRepository {
  SrSubmission? submitted;

  @override
  Future<ResponseHandler<PrefWriteOutcome>> submit(SrSubmission submission, {ObdxChallenge? challenge, String? otp}) async {
    submitted = submission;
    return ResponseHandler.success(const PrefWriteOutcome.done(reference: 'SRREF42'), code: 201);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  group('models', () {
    test('definition form: fields sorted, validation, options, header text', () {
      final d = SrDefinition.oneFromPayload(_form)!;
      expect(d.priorityType, 'MEDIUM');
      final fields = d.form!.fields;
      expect(fields.map((f) => f.name), ['h1', 'leaves', 'delivery']);
      expect(fields[0].type, SrFieldType.sectionHeader);
      expect(fields[0].headerText, 'Book Details');
      expect(fields[1].mandatory, isTrue);
      expect(fields[1].maxLength, 3);
      expect(fields[1].validationType, 'NUMBERS');
      expect(fields[2].options.map((o) => o.description), ['Branch', 'Home']);
    });

    test('requestData: the HTML-escaped JSON string OBDX returns', () {
      final d = ServiceRequestDetail.fromPayload(_detail);
      expect(d.name, 'Cheque Book Request');
      expect(d.comments, 'Being printed');
      expect(d.elements.single.label, 'Number of Leaves');
      expect(d.elements.single.displayValues, ['25']);
    });

    test('submission body: OTHERS request with requestData as a string', () {
      final d = SrDefinition.oneFromPayload(_form)!;
      final body = SrSubmission(
        definition: d,
        answers: const {
          'leaves': SrAnswer(values: ['25'], displayValues: ['25']),
          'delivery': SrAnswer(values: ['HM'], displayValues: ['Home']),
        },
      ).toBody();
      expect(body['requestType'], 'OTHERS');
      expect(body['entityTypeIdentifier'], 'SR01');
      expect(body['status'], 'IN');
      expect(body['entityTypeIdentifierKey'], 'DE');
      expect(body['definition'], {'id': 'SR01'});
      expect(body['priorityType'], 'MEDIUM');
      expect(body['entity'], 'AC');
      final elements = (jsonDecode(body['requestData'] as String) as Map)['elements'] as List;
      expect(elements.map((e) => e['id']), ['h1', 'leaves', 'delivery']);
      expect(elements.first['label'], isNull);
      expect(elements.first['values'], ['Book Details']);
      expect(elements.last['values'], ['HM']);
      expect(elements.last['displayValues'], ['Home']);
    });

    test('track filter query and newest-first list', () {
      final q = SrFilter(
        product: 'Accounts',
        category: const SrCategory(id: 'C1', name: 'Cheques'),
        fromDate: DateTime(2026, 10, 1),
        toDate: DateTime(2026, 10, 20),
        status: 'PE',
      ).toQuery();
      expect(q, {'status': 'PE', 'product': 'Accounts', 'categoryType': 'C1', 'fromDate': '2026-10-01', 'toDate': '2026-10-20'});
      expect(ServiceRequestSummary.listFromPayload(_requests).map((r) => r.id), ['REF002', 'REF001']);
    });
  });

  group('screens', () {
    late _FakeRepo repo;

    Future<void> pump(WidgetTester tester, {SrTab tab = SrTab.track, double width = 400}) async {
      SharedPreferences.setMockInitialValues({});
      repo = _FakeRepo();
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serviceRequestsRepositoryProvider.overrideWithValue(repo),
            srProductsProvider.overrideWith((ref) async => ['Accounts', 'Profile']),
            srCategoriesProvider.overrideWith((ref, p) async => const [SrCategory(id: 'C1', name: 'Cheques')]),
            srEnumerationProvider.overrideWith((ref, name) async => const <SrOption>[]),
            // A product filter matches nothing here.
            srRequestsProvider.overrideWith(
              (ref, f) async => f.product == null ? ServiceRequestSummary.listFromPayload(_requests) : const <ServiceRequestSummary>[],
            ),
            srRequestProvider.overrideWith((ref, id) async => ServiceRequestDetail.fromPayload(_detail)),
            srDefinitionsProvider.overrideWith((ref) async => SrDefinition.listFromPayload(_definitions)),
            srDefinitionProvider.overrideWith((ref, id) async => SrDefinition.oneFromPayload(_form)!),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: LocaleConfig.supportedLocales,
            home: ServiceRequestsScreen(initialTab: tab),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('track: requests listed at once; a request opens its details', (tester) async {
      await pump(tester);
      expect(find.text('Track Requests'), findsOneWidget);
      for (final f in ['Product Name', 'Status', 'From Date', 'To Date']) {
        expect(find.text(f), findsWidgets, reason: f);
      }
      // No Apply button: the list follows the filters.
      expect(find.text('Apply'), findsNothing);
      expect(find.text('REF001'), findsOneWidget);
      expect(find.text('REF002'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);

      await tester.tap(find.text('Cheque Book Request'));
      await tester.pumpAndSettle();
      expect(find.text('Request Details'), findsWidgets);
      expect(find.text('Closure Comments from Bank'), findsOneWidget);
      expect(find.text('Being printed'), findsOneWidget);
      expect(find.text('Number of Leaves'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('REF001'), findsOneWidget);
    });

    testWidgets('track: a filter with no match shows the empty state; Change filters clears it', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Please Select').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      // The strip shows the criteria; nothing matches.
      expect(find.text('Profile'), findsWidgets);
      expect(find.text('No Service Request Found'), findsOneWidget);
      expect(find.text('No request matches the selected search criteria.'), findsOneWidget);

      await tester.tap(find.text('Change filters'));
      await tester.pumpAndSettle();
      expect(find.text('No Service Request Found'), findsNothing);
      expect(find.text('REF001'), findsOneWidget);
    });

    testWidgets('the ⋮ menu goes between Track Requests and Raise a New Ticket', (tester) async {
      // Wide: Products beside the requests.
      await pump(tester, width: 1280);
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Raise a New Ticket').last);
      await tester.pumpAndSettle();
      expect(find.text('Raise a New Ticket'), findsOneWidget);
      expect(find.text('Service Request Form'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
    });

    testWidgets('raise: browse, form checks, Review, Confirm, reference', (tester) async {
      await pump(tester, tab: SrTab.raise);
      expect(find.text('Service Request Form'), findsOneWidget);
      expect(find.text('Cheque Book Request'), findsOneWidget);

      await tester.tap(find.text('Cheque Book Request'));
      await tester.pumpAndSettle();
      expect(find.text('Book Details'), findsOneWidget);
      expect(find.text('Delivered in 5 days.'), findsOneWidget);

      // Nothing filled: the bank's error message, and the radio's default.
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the number of leaves'), findsOneWidget);
      expect(find.text('This field is required.'), findsOneWidget);

      // NUMBERS only.
      await tester.enterText(find.byType(TextField).last, 'ab');
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the number of leaves'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, '25');
      await tester.tap(find.text('Home'));
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();

      expect(find.text('You initiated a Service request. Please review details before you confirm!'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(repo.submitted!.answers['delivery']!.values, ['HM']);
      expect(find.text('We have your cheque book request.'), findsOneWidget);
      expect(find.text('SRREF42'), findsOneWidget);

      // Track Request goes to the other half.
      await tester.tap(find.text('Track Request'));
      await tester.pumpAndSettle();
      expect(find.text('Product Name'), findsOneWidget);
    });

    testWidgets('raise: search finds a request by name', (tester) async {
      await pump(tester, tab: SrTab.raise);
      await tester.enterText(find.byType(TextField).first, 'addr');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update Address').last);
      await tester.pumpAndSettle();
      expect(find.text('Book Details'), findsOneWidget);
    });
  });
}
