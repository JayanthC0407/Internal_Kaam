import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/money_amount.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/payee/payee_models.dart';
import 'package:ubci_bank/src/core/models/retail/cheque_book_models.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/apis/retail/obdx_cheque_book_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/retail/cheque_book_repository.dart';
import 'package:ubci_bank/src/view/providers/retail/cheque_book_providers.dart';
import 'package:ubci_bank/src/view/screens/retail/accounts/cheque_book_request_screen.dart';

// Shapes follow the OBDX cheque-book-request flow and obdx-address element
// (docs/obdx/features/cheque-book-request.md). Values are made up.

const _account = ChequeAccount(id: 'A0139', display: 'xxxx0139', balance: MoneyAmount(amount: 112542, currency: 'GBP'));
const _wallet = ChequeAccount(id: 'W1', display: 'Wallet');
const _type = ChequeBookType(code: 'CHQBOOK', description: 'CHQBOOK INR');

const _postal = ChequePartyAddress(
  type: 'PST',
  description: 'POSTAL',
  address: ChequeAddress({'line1': 'ADDRESS1', 'line2': 'ADDRESS2', 'country': 'IN'}),
);
const _work = ChequePartyAddress(type: 'WRK', description: 'WORK', address: ChequeAddress({'line1': 'OFFICE 1'}));

void main() {
  group('model', () {
    test('type: OBDX splits code-description-description on "-"', () {
      expect(_type.stock, {'stockCode': 'CHQBOOK', 'stockCurrency': 'CHQBOOK INR', 'stockDescription': 'CHQBOOK INR'});
      final types = ChequeBookType.listFromPayload({
        'enumRepresentations': [
          {
            'data': [
              {'code': 'C1', 'description': 'Personal'},
            ],
          },
        ],
      });
      expect(types.single.description, 'Personal');
    });

    test('body: My Address with its type; one type; books only when enabled', () {
      final body = ChequeBookRequest(
        account: _account,
        type: _type,
        leaves: 25,
        books: '2',
        delivery: ChequeDelivery.myAddress,
        address: _postal.address,
        addressType: 'PST',
        branchCode: 'IGNORED',
      ).toJson();
      expect(body, {
        'noOfChequeLeaves': '25',
        'noOfChequeBooks': '2',
        'chequeBookTypeList': [_type.stock],
        'chequeDeliveryDetailsDTO': {
          'address': {'line1': 'ADDRESS1', 'line2': 'ADDRESS2', 'country': 'IN'},
          'deliveryOption': 'ACC',
          'addressType': 'PST',
        },
      });
      final branch = const ChequeBookRequest(
        account: _account,
        type: null,
        leaves: 10,
        delivery: ChequeDelivery.branch,
        address: ChequeAddress.empty,
        addressType: 'PST',
        branchCode: 'B01',
      ).toJson();
      expect(branch.containsKey('noOfChequeBooks'), isFalse);
      expect(branch['chequeBookTypeList'], isEmpty);
      expect(branch['chequeDeliveryDetailsDTO'], {'address': <String, String>{}, 'deliveryOption': 'BRN', 'branchCode': 'B01'});
    });

    test('addresses: party list + POSTAL first; account address drops the last key; branch address', () {
      final list = ChequePartyAddress.listFrom({
        'party': {
          'addresses': [
            {'type': 'WRK', 'postalAddress': {'line1': 'OFFICE 1'}},
            {'type': 'PST', 'postalAddress': {'line1': 'HOME 1', 'zipCode': '400001', 'extra': 'x'}},
            {'type': 'RES'},
          ],
        },
      }, {
        'enumRepresentations': [
          {
            'data': [
              {'code': 'PST', 'description': 'POSTAL'},
              {'code': 'WRK', 'description': 'WORK'},
            ],
          },
        ],
      });
      expect(list.map((a) => a.type), ['WRK', 'PST'], reason: 'only addresses with a postalAddress');
      expect(ChequePartyAddress.initial(list)!.address.fields, {'line1': 'HOME 1', 'zipCode': '400001'});

      final account = ChequeAddress.fromAccountAddress({
        'address': {
          'postalAddress': {'line1': 'L1', 'city': 'Pune', 'addressTypeDescription': 'drop me'},
        },
      });
      expect(account.fields, {'line1': 'L1', 'city': 'Pune'});
      expect(account.lines, ['L1', 'Pune']);

      final branch = ChequeAddress.fromBranchPayload({
        'addressDTO': [
          {
            'branchAddress': {
              'postalAddress': {'line1': 'BRANCH ST', 'city': 'Leeds', 'country': 'GB'},
            },
          },
        ],
      });
      expect(branch.lines, ['BRANCH ST', 'Leeds', 'GB']);
    });

    test('books rule, wallet, settings', () {
      expect(chequeBooksValid('1'), isTrue);
      expect(chequeBooksValid('1234567890'), isTrue);
      expect(chequeBooksValid('12345678901'), isFalse);
      expect(chequeBooksValid(''), isFalse);
      expect(chequeBooksValid('2a'), isFalse);
      expect(isWalletAccount(_wallet), isTrue);
      expect(ChequeBookConfig.booksEnabledFrom({'noOfChequeBooks': 'Y'}), isTrue);
      expect(ChequeBookConfig.booksEnabledFrom({'noOfChequeBooks': 'N'}), isFalse);
      expect(ChequeBookConfig.corpDdaFrom({'ddaConfig': {'corpDDAEnabled': true}}), isTrue);
    });
  });

  group('repository (OBDX framework behaviour)', () {
    const request = ChequeBookRequest(
      account: _account,
      type: _type,
      leaves: 10,
      delivery: ChequeDelivery.myAddress,
      address: ChequeAddress.empty,
    );
    ChequeBookRepository repo(int status, Map<String, dynamic> body, {Map<String, List<String>> headers = const {}}) =>
        ChequeBookRepository(api: _FakeApi(post: _wrapped(status, body, headers: headers)));

    test('200 → chequeBookDTO.chequeBookRequestRefNo; account in the path', () async {
      final api = _FakeApi(post: _wrapped(200, {
        'chequeBookDTO': {'chequeBookRequestRefNo': 'CBR77'},
      }));
      final r = await ChequeBookRepository(api: api).requestChequeBook(request);
      expect((r as Success<ChequeBookOutcome>).data!.reference, 'CBR77');
      expect(api.postedTo, 'A0139');
      expect(api.posted!['noOfChequeLeaves'], '10');
    });

    test('417 + X-Challenge → OTP; 202 → pending approval', () async {
      final otp = await repo(417, const {}, headers: {
        'x-challenge': [jsonEncode({'referenceNo': 'OTP1', 'authType': 'OTP'})],
      }).requestChequeBook(request);
      expect((otp as Success<ChequeBookOutcome>).data!.challenge?.referenceNo, 'OTP1');
      final pending = await repo(202, {'status': {'result': 'SUCCESSFUL'}}).requestChequeBook(request);
      expect((pending as Success<ChequeBookOutcome>).data!.pendingApproval, isTrue);
    });

    test('setup: settings fall back to off when their calls fail', () async {
      final api = _FakeApi(post: _wrapped(200, const {}), configFails: true);
      final r = await ChequeBookRepository(api: api).fetchSetup();
      final setup = (r as Success<ChequeBookSetup>).data!;
      expect(setup.config.booksEnabled, isFalse);
      expect(setup.config.corpDda, isFalse);
      expect(setup.accounts.single.display, 'xxxx0139');
      expect(setup.types.single.code, 'CHQBOOK');
    });
  });

  group('screen', () {
    Future<_FakeRepo> pump(
      WidgetTester tester, {
      double width = 390,
      bool booksEnabled = true,
      List<ChequeAccount> accounts = const [_account],
      bool pending = false,
    }) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _FakeRepo(booksEnabled: booksEnabled, accounts: accounts, pending: pending);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [chequeBookRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: LocaleConfig.supportedLocales,
            home: Scaffold(body: ChequeBookRequestScreen(onExit: () => repo.exited = true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    Future<void> fill(WidgetTester tester, {bool books = true}) async {
      await tester.tap(find.text('Please Select').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('CHQBOOK INR').last);
      await tester.pumpAndSettle();
      if (books) await tester.enterText(find.byType(TextField), '2');
      await tester.tap(find.text('Please Select').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cheque Book with 25 Leaves').last);
      await tester.pumpAndSettle();
    }

    testWidgets('form checks, Review, Confirm, reference (phone)', (tester) async {
      final repo = await pump(tester);
      expect(find.text('Account Balance'), findsOneWidget);
      expect(find.text('ADDRESS1\nADDRESS2\nIN'), findsOneWidget, reason: 'POSTAL first, as OBDX');

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Type of Cheque Book is required.'), findsOneWidget);
      expect(find.text('Enter Valid Number'), findsOneWidget);
      expect(find.text('Number of Leaves per Book is required.'), findsOneWidget);

      await fill(tester);
      expect(find.text('2 books  •  25 leaves'), findsOneWidget);
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('You initiated a request for Cheque Book. Please review details before you confirm!'), findsWidgets);
      expect(find.text('CHQBOOK INR'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Your request has been accepted.'), findsOneWidget);
      expect(find.text('CBR1'), findsOneWidget);
      final body = repo.request!.toJson();
      expect(body['noOfChequeBooks'], '2');
      expect((body['chequeDeliveryDetailsDTO'] as Map)['addressType'], 'PST');

      await tester.tap(find.text('Done'));
      expect(repo.exited, isTrue);
    });

    testWidgets('Address Type and Branch Near Me: the shown branch is sent', (tester) async {
      final repo = await pump(tester, booksEnabled: false);
      expect(find.text('Number of Cheque Books'), findsNothing, reason: 'config N hides it');

      await tester.tap(find.text('POSTAL'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('WORK').last);
      await tester.pumpAndSettle();
      expect(find.text('OFFICE 1'), findsOneWidget);

      await tester.tap(find.text('Branch Near Me'));
      await tester.pumpAndSettle();
      expect(find.text('Leeds'), findsOneWidget, reason: 'first city');
      expect(find.text('Main Branch'), findsOneWidget, reason: 'its first branch');
      expect(find.text('BRANCH ST\nLeeds\nGB'), findsOneWidget);

      await fill(tester, books: false);
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      final dto = repo.request!.toJson()['chequeDeliveryDetailsDTO'] as Map;
      expect(dto['deliveryOption'], 'BRN');
      expect(dto['branchCode'], 'B01');
      expect(dto.containsKey('addressType'), isFalse);
    });

    testWidgets('wallet is refused; 202 → initiated (web)', (tester) async {
      await pump(tester, width: 1280, accounts: const [_account, _wallet], pending: true);
      expect(find.text('xxxx0139'), findsOneWidget, reason: 'the default (first) account');
      // Pick the wallet.
      await tester.tap(find.text('xxxx0139'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wallet').last);
      await tester.pumpAndSettle();
      await fill(tester);
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Cheque Book Request not allowed from wallet'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Wallet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('xxxx0139').last);
      // Let the SnackBar go before Submit.
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Your request has been initiated successfully.'), findsOneWidget);
    });
  });
}

ResponseHandler<Map<String, dynamic>> _wrapped(
  int status,
  Map<String, dynamic> body, {
  Map<String, List<String>> headers = const {},
}) =>
    ResponseHandler.success({'statusCode': status, 'headers': headers, 'rawBody': jsonEncode(body), 'body': body});

class _FakeApi implements ObdxChequeBookApi {
  _FakeApi({required this.post, this.configFails = false});

  final ResponseHandler<Map<String, dynamic>> post;
  final bool configFails;
  String? postedTo;
  Map<String, dynamic>? posted;

  @override
  Future<ResponseHandler<Map<String, dynamic>>> requestChequeBook(
    String accountId,
    Map<String, dynamic> body, {
    String? challengeResponseHeader,
  }) async {
    postedTo = accountId;
    posted = body;
    return post;
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchCorpDdaConfig() async =>
      configFails ? ResponseHandler.error(500, 'down') : _wrapped(200, const {});

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchBooksConfig() async =>
      configFails ? ResponseHandler.error(500, 'down') : _wrapped(200, {'noOfChequeBooks': 'Y'});

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchBookTypes() async => _wrapped(200, {
        'enumRepresentations': [
          {
            'data': [
              {'code': 'CHQBOOK', 'description': 'CHQBOOK INR'},
            ],
          },
        ],
      });

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchAccounts() async => _wrapped(200, {
        'accounts': [
          {
            'id': {'value': 'A0139', 'displayValue': 'xxxx0139'},
            'availableBalance': {'amount': 10, 'currency': 'GBP'},
          },
        ],
      });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepo implements ChequeBookRepository {
  _FakeRepo({required this.booksEnabled, required this.accounts, required this.pending});

  final bool booksEnabled;
  final List<ChequeAccount> accounts;
  final bool pending;
  ChequeBookRequest? request;
  bool exited = false;

  @override
  Future<ResponseHandler<ChequeBookSetup>> fetchSetup() async => ResponseHandler.success(
        ChequeBookSetup(
          config: ChequeBookConfig(booksEnabled: booksEnabled),
          types: const [_type],
          accounts: accounts,
        ),
        code: 200,
      );

  @override
  Future<ResponseHandler<List<ChequePartyAddress>>> fetchPartyAddresses() async =>
      ResponseHandler.success(const [_postal, _work], code: 200);

  @override
  Future<ResponseHandler<List<String>>> fetchCities() async => ResponseHandler.success(const ['Leeds', 'York'], code: 200);

  @override
  Future<ResponseHandler<List<BranchOption>>> fetchBranches(String city) async => ResponseHandler.success(
        const [BranchOption(code: 'B01', name: 'Main Branch'), BranchOption(code: 'B02', name: 'East Branch')],
        code: 200,
      );

  @override
  Future<ResponseHandler<ChequeAddress>> fetchBranchAddress(String branchCode) async => ResponseHandler.success(
        const ChequeAddress({'line1': 'BRANCH ST', 'city': 'Leeds', 'country': 'GB'}),
        code: 200,
      );

  @override
  Future<ResponseHandler<ChequeBookOutcome>> requestChequeBook(
    ChequeBookRequest request, {
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    this.request = request;
    return ResponseHandler.success(ChequeBookOutcome.done(reference: 'CBR1', pendingApproval: pending), code: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
