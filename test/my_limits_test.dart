import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/limits/my_limits_models.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_limits_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/limits_repository.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/limits/my_limits_screen.dart';

// Field names follow OBDX my-limit/hooks.js (docs/obdx/features/my-limits.md
// §3-4); ids and values are made up.

const _today = '2026-10-23T00:00:00';

Map<String, dynamic> _per(String period, double amount, int count) => {
      'limitType': 'PER',
      'periodicity': period,
      'maxAmount': {'amount': amount, 'currency': 'GBP'},
      'maxCount': count,
    };

Map<String, dynamic> _linkage(String value, String type, List<Map<String, dynamic>> limits,
        {String? effectiveDate, String? expiryDate}) =>
    {
      'target': {
        'value': value,
        'type': {'id': type, 'name': type},
      },
      if (effectiveDate != null) 'effectiveDate': effectiveDate,
      if (expiryDate != null) 'expiryDate': expiryDate,
      'limits': limits,
    };

final _taskGroups = {
  'taskGroupDTOlist': [
    {
      'id': 'TG1',
      'taskDTOs': [
        {'id': 'TXN_A'},
        {'id': 'TXN_B'},
      ],
    },
  ],
};

final _assigned = {
  'limitPackageDTOList': [
    {
      'accessPointGroupType': 'SINGLE',
      'targetLimitLinkages': [
        _linkage('TXN_A', 'TASK', [
          {
            'limitType': 'TXN',
            'amountRange': {
              'minTransaction': {'amount': 1, 'currency': 'GBP'},
              'maxTransaction': {'amount': 5000, 'currency': 'GBP'},
            },
          },
          _per('DAILY', 10000, 10),
          _per('MONTHLY', 100000, 100),
        ]),
        _linkage('TG1', 'TASK_GROUP', [_per('DAILY', 20000, 20)]),
      ],
    },
    {
      'accessPointGroupType': 'GLOBAL',
      'targetLimitLinkages': [
        _linkage('TXN_A', 'TASK', [_per('DAILY', 50000, 50)]),
      ],
    },
  ],
};

Map<String, dynamic> _util(String id, String type, String group, int count, double amount) => {
      'utilizationId': id,
      'limitType': 'PER#$type',
      'accessPointGroupType': group,
      'count': count,
      'amount': {'amount': amount, 'currency': 'GBP'},
    };

final _daily = {
  'limitUtilizationDTOs': [
    _util('TXN_A', 'DAILY', 'SINGLE', 3, 2500),
    _util('TG1', 'DAILY', 'SINGLE', 4, 4000),
    _util('TXN_A', 'DAILY', 'GLOBAL', 60, 60000),
  ],
};

final _monthly = {
  'limitUtilizationDTOs': [_util('TXN_A', 'MONTHLY', 'SINGLE', 12, 30000)],
};

final _custom = {
  'limitPackageDTOList': [
    {
      'accessPointGroupType': 'SINGLE',
      'targetLimitLinkages': [
        // Amount lower → used; count higher → ignored.
        _linkage('TXN_A', 'TASK', [_per('DAILY', 8000, 15)], effectiveDate: '2026-10-01T00:00:00'),
        // Expired today → ignored.
        _linkage('TG1', 'TASK_GROUP', [_per('DAILY', 1, 1)], expiryDate: _today),
      ],
    },
  ],
};

MyLimits _build({Map<String, dynamic>? assigned, Map<String, dynamic>? custom, bool sameDay = true}) => MyLimits.fromPayloads(
      taskGroups: _taskGroups,
      assigned: assigned ?? _assigned,
      utilizedDaily: _daily,
      utilizedMonthly: _monthly,
      custom: custom ?? _custom,
      effectiveSameDay: sameDay,
      today: DateTime.parse(_today),
    );

Map<String, dynamic> _wrap(Map<String, dynamic> body) =>
    {'statusCode': 200, 'headers': const <String, dynamic>{}, 'rawBody': '', 'body': body};

void main() {
  group('model (hooks.js setData)', () {
    test('tabs: one pair per package type, in OBDX order', () {
      expect(_build().tabs, [
        LimitTab.transaction,
        LimitTab.transactionGroup,
        LimitTab.consolidated,
        LimitTab.consolidatedTransactionGroup,
      ]);
    });

    test('TASK linkage → transaction tab; custom lower amount wins, higher count does not', () {
      final slot = _build().slotFor('TXN_A', LimitTab.transaction)!;
      expect(slot.amountRange!.min, 1);
      expect(slot.amountRange!.max, 5000);
      expect(slot.daily!.maxAmount, 8000);
      expect(slot.daily!.maxCount, 10);
      expect(slot.daily!.utilizedAmount, 2500);
      expect(slot.daily!.utilizedCount, 3);
      expect(slot.daily!.amountPercent, 31);
      expect(slot.daily!.availableAmount, 5500);
      expect(slot.daily!.availableCount, 7);
      expect(slot.monthly!.utilizedCount, 12);
    });

    test('TASK_GROUP linkage reaches every transaction of the group; expired custom ignored', () {
      final b = _build().slotFor('TXN_B', LimitTab.transactionGroup)!;
      expect(b.daily!.maxAmount, 20000);
      expect(b.daily!.utilizedAmount, 4000, reason: 'group utilisation goes to each transaction');
      expect(b.monthly, isNull);
      expect(_build().slotFor('TXN_B', LimitTab.transaction), isNull);
    });

    test('utilisation by accessPointGroupType; percent capped at 100, available not below 0', () {
      final global = _build().slotFor('TXN_A', LimitTab.consolidated)!.daily!;
      expect(global.utilizedAmount, 60000);
      expect(global.amountPercent, 100);
      expect(global.availableAmount, 0);
    });

    test('custom effective tomorrow changes nothing today', () {
      final custom = {
        'limitPackageDTOList': [
          {
            'accessPointGroupType': 'SINGLE',
            'targetLimitLinkages': [
              _linkage('TXN_A', 'TASK', [_per('DAILY', 100, 1)], effectiveDate: '2026-10-24T00:00:00'),
            ],
          },
        ],
      };
      expect(_build(custom: custom).slotFor('TXN_A', LimitTab.transaction)!.daily!.maxAmount, 10000);
    });

    test('a bank limit effective tomorrow is not assigned yet', () {
      final assigned = {
        'limitPackageDTOList': [
          {
            'accessPointGroupType': 'SINGLE',
            'targetLimitLinkages': [
              _linkage('TXN_A', 'TASK', [_per('DAILY', 100, 1)], effectiveDate: '2026-10-24T00:00:00'),
            ],
          },
        ],
      };
      expect(_build(assigned: assigned).slotFor('TXN_A', LimitTab.transaction)!.daily!.isAssigned, isFalse);
    });

    test('channel: the signed-in one, else the first', () {
      final list = LimitChannel.listFromPayload({
        'accessPointListDTO': [
          {'id': 'MOBILE', 'description': 'Mobile'},
          {'id': 'INTERNET', 'description': 'Internet', 'currentLoggedIn': true},
        ],
      });
      expect(LimitChannel.defaultOf(list)!.id, 'INTERNET');
      expect(LimitChannel.defaultOf(list.take(1).toList())!.id, 'MOBILE');
    });
  });

  group('repository (Promise.all)', () {
    test('loads the five calls for the channel; effectiveToday sets the flag', () async {
      final api = _FakeApi();
      final r = await LimitsRepository(api: api).fetchMyLimits('INTERNET', today: DateTime.parse(_today));
      final limits = (r as Success<MyLimits>).data!;
      expect(limits.effectiveSameDay, isTrue);
      expect(api.channels, ['INTERNET', 'INTERNET', 'INTERNET', 'INTERNET']);
      expect(api.periods, {'DAILY', 'MONTHLY'});
    });

    test('one failed call fails the load', () async {
      final api = _FakeApi()..failCustom = true;
      expect(await LimitsRepository(api: api).fetchMyLimits('INTERNET'), isA<Error<MyLimits>>());
    });

    test('effectiveToday may fail: flag off, limits still shown', () async {
      final api = _FakeApi()..failConfig = true;
      final r = await LimitsRepository(api: api).fetchMyLimits('INTERNET', today: DateTime.parse(_today));
      expect((r as Success<MyLimits>).data!.effectiveSameDay, isFalse);
    });
  });

  Future<void> pump(WidgetTester tester, {double width = 390, bool sameDay = true}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [limitsRepositoryProvider.overrideWithValue(_FakeRepo(_build(sameDay: sameDay)))],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: LocaleConfig.supportedLocales,
          home: const MyLimitsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('phone: signed-in channel, first transaction, Daily and Monthly donuts', (tester) async {
    await pump(tester);
    expect(find.text('My Limits'), findsWidgets);
    expect(find.text('Internet'), findsOneWidget);
    expect(find.text('Internal Transfer'), findsOneWidget);
    expect(find.text('Internal Transfer Limits'), findsNWidgets(2), reason: 'heading + tab dropdown');
    expect(find.text('Daily Limits'), findsOneWidget);
    expect(find.text('Monthly Limits'), findsOneWidget);
    expect(find.text('31%\nUtilized'), findsOneWidget);
    expect(find.text('Minimum Amount'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('another tab: Monthly not assigned shows the OBDX text with the channel', (tester) async {
    await pump(tester);
    // The tabs are in the dropdown beside the heading (the second label).
    await tester.tap(find.text('Internal Transfer Limits').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transaction Group Limits').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Monthly limit package is not assigned for the selected transaction for Internet Touch Point'),
      findsOneWidget,
    );
    expect(find.text('20%\nUtilized'), findsNWidgets(2), reason: '4000 of 20000 and 4 of 20');
  });

  testWidgets('no effectiveSameDay: no Minimum / Maximum Amount', (tester) async {
    await pump(tester, sameDay: false);
    expect(find.text('Minimum Amount'), findsNothing);
  });

  testWidgets('web: the tab dropdown lists OBDX\'s tabs; a pick reloads the cards', (tester) async {
    await pump(tester, width: 1280);
    await tester.tap(find.text('Internal Transfer Limits').last);
    await tester.pumpAndSettle();
    for (final t in ['Internal Transfer Limits', 'Transaction Group Limits', 'Consolidated Limits']) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    await tester.tap(find.text('Consolidated Limits').last);
    await tester.pumpAndSettle();
    expect(find.text('Consolidated Limits'), findsNWidgets(2), reason: 'heading + dropdown');
    expect(find.text('100%\nUtilized'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}

class _FakeRepo implements LimitsRepository {
  _FakeRepo(this.limits);

  final MyLimits limits;

  @override
  Future<ResponseHandler<List<LimitChannel>>> fetchChannels() async => ResponseHandler.success(const [
        LimitChannel(id: 'MOBILE', description: 'Mobile'),
        LimitChannel(id: 'INTERNET', description: 'Internet', currentLoggedIn: true),
      ], code: 200);

  @override
  Future<ResponseHandler<List<LimitTransaction>>> fetchTransactions() async => ResponseHandler.success(const [
        LimitTransaction(id: 'TXN_A', name: 'Internal Transfer'),
        LimitTransaction(id: 'TXN_B', name: 'Domestic Transfer'),
      ], code: 200);

  @override
  Future<ResponseHandler<MyLimits>> fetchMyLimits(String channelId, {DateTime? today}) async =>
      ResponseHandler.success(limits, code: 200);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeApi implements ObdxLimitsApi {
  bool failCustom = false;
  bool failConfig = false;
  final channels = <String>[];
  final periods = <String>{};

  Future<ResponseHandler<Map<String, dynamic>>> _ok(Map<String, dynamic> body) async => ResponseHandler.success(_wrap(body));

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchTaskGroups() => _ok(_taskGroups);

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchMyAssignedLimits(String channelId) {
    channels.add(channelId);
    return _ok(_assigned);
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchUtilization(String channelId, String period) {
    channels.add(channelId);
    periods.add(period);
    return _ok(period == 'DAILY' ? _daily : _monthly);
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchMyCustomLimits(String channelId) async {
    channels.add(channelId);
    return failCustom ? ResponseHandler.error(500, 'boom') : _ok(_custom);
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> fetchEffectiveToday() async =>
      failConfig ? ResponseHandler.error(500, 'boom') : _ok({'isEffectiveSameDay': 'Y'});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
