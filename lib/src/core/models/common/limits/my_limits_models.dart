import 'dart:math' as math;

import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// My Limits (OBDX `limits-enquiry/my-limit`). Every rule here is from
/// docs/obdx/features/my-limits.md; hooks.js line numbers are cited inline.

/// One channel (OBDX "Channel"): `accessPointListDTO[]` of
/// `GET sms/v1/accessPoints?accessType=INT&accessPointStatus=Y`.
class LimitChannel {
  const LimitChannel({required this.id, required this.description, this.currentLoggedIn = false});

  final String id;
  final String description;

  /// OBDX selects the channel the user is signed in on (hooks.js:295-299).
  final bool currentLoggedIn;

  static List<LimitChannel> listFromPayload(Map<String, dynamic> body) => [
        for (final raw in _list(body['accessPointListDTO']))
          if (_str(raw['id']) != null)
            LimitChannel(
              id: _str(raw['id'])!,
              description: _str(raw['description']) ?? _str(raw['id'])!,
              currentLoggedIn: raw['currentLoggedIn'] == true,
            ),
      ];

  /// The signed-in channel, else the first one (`[APP]` fallback).
  static LimitChannel? defaultOf(List<LimitChannel> channels) {
    if (channels.isEmpty) return null;
    return channels.firstWhere((c) => c.currentLoggedIn, orElse: () => channels.first);
  }
}

/// One entry of OBDX "Transactions": `taskList[]` of
/// `GET security/v1/resourceTasks?aspects=limit&view=list` (hooks.js:594-601).
class LimitTransaction {
  const LimitTransaction({required this.id, required this.name});

  final String id;
  final String name;

  static List<LimitTransaction> listFromPayload(Map<String, dynamic> body) => [
        for (final raw in _list(body['taskList']))
          if (_str(raw['id']) != null) LimitTransaction(id: _str(raw['id'])!, name: _str(raw['name']) ?? _str(raw['id'])!),
      ];
}

/// The limit tabs, in OBDX order (hooks.js:455-493). Labels: nls/my-limit.js.
enum LimitTab {
  /// "{taskName} Limits".
  transaction('TL'),

  /// "Transaction Group Limits".
  transactionGroup('TGL'),

  /// "Channel Group Limits".
  channelGroup('CGL'),

  /// "Channel & Transaction Group Limits".
  channelTransactionGroup('CTGL'),

  /// "Consolidated Limits".
  consolidated('COL'),

  /// "Consolidated & Transaction Group Limits".
  consolidatedTransactionGroup('COTGL');

  const LimitTab(this.code);

  final String code;
}

/// `accessPointGroupType` of a limit package, and the tab pair it brings:
/// one for `TASK` linkages, one for `TASK_GROUP` linkages.
enum _PackageType {
  single(LimitTab.transaction, LimitTab.transactionGroup),
  group(LimitTab.channelGroup, LimitTab.channelTransactionGroup),
  global(LimitTab.consolidated, LimitTab.consolidatedTransactionGroup);

  const _PackageType(this.taskTab, this.groupTab);

  final LimitTab taskTab;
  final LimitTab groupTab;

  static _PackageType? parse(dynamic value) => switch (_str(value)?.toUpperCase()) {
        'SINGLE' => single,
        'GROUP' => group,
        'GLOBAL' => global,
        _ => null,
      };
}

/// Daily or monthly limit with what is used so far (limit-graph/hooks.js).
class PeriodicLimit {
  const PeriodicLimit({
    this.maxAmount,
    this.currency = '',
    this.maxCount,
    this.utilizedAmount = 0,
    this.utilizedCount = 0,
  });

  final double? maxAmount;

  /// The bank-allocated currency; OBDX shows every amount in it.
  final String currency;
  final int? maxCount;
  final double utilizedAmount;
  final int utilizedCount;

  /// False for a bank limit that only becomes effective tomorrow (OBDX
  /// blanks its max, hooks.js:733-735); the app then shows "not assigned".
  bool get isAssigned => maxAmount != null || maxCount != null;

  /// "Available": max − utilized, never below 0.
  double get availableAmount => math.max(0, (maxAmount ?? 0) - utilizedAmount);
  int get availableCount => math.max(0, (maxCount ?? 0) - utilizedCount);

  /// Centre of the donut: utilized / max × 100, at most 100, rounded.
  int get amountPercent => _percent(utilizedAmount, maxAmount ?? 0);
  int get countPercent => _percent(utilizedCount.toDouble(), (maxCount ?? 0).toDouble());

  PeriodicLimit copyWith({double? maxAmount, int? maxCount, double? utilizedAmount, int? utilizedCount}) => PeriodicLimit(
        maxAmount: maxAmount ?? this.maxAmount,
        currency: currency,
        maxCount: maxCount ?? this.maxCount,
        utilizedAmount: utilizedAmount ?? this.utilizedAmount,
        utilizedCount: utilizedCount ?? this.utilizedCount,
      );

  static int _percent(double utilized, double max) {
    // OBDX divides by zero here (NaN); the app shows 0, or 100 if anything
    // was used against a zero limit. [APP]
    if (max <= 0) return utilized > 0 ? 100 : 0;
    return math.min(100, utilized / max * 100).round();
  }
}

/// Minimum Amount / Maximum Amount of the `TXN` limit.
class TransactionAmountRange {
  const TransactionAmountRange({this.min, this.max, this.minCurrency = '', this.maxCurrency = ''});

  final double? min;
  final double? max;
  final String minCurrency;
  final String maxCurrency;
}

/// What one tab shows for one transaction.
class LimitSlot {
  const LimitSlot({this.amountRange, this.daily, this.monthly});

  final TransactionAmountRange? amountRange;
  final PeriodicLimit? daily;
  final PeriodicLimit? monthly;

  LimitSlot copyWith({PeriodicLimit? daily, PeriodicLimit? monthly}) =>
      LimitSlot(amountRange: amountRange, daily: daily ?? this.daily, monthly: monthly ?? this.monthly);
}

/// Everything My Limits shows for one channel, built from the five
/// parallel calls (hooks.js:428-436 → setData :450-558).
class MyLimits {
  const MyLimits._({required this.tabs, required Map<(String, LimitTab), LimitSlot> slots, required this.effectiveSameDay})
      : _slots = slots;

  /// Tabs in OBDX order, one pair per assigned package type.
  final List<LimitTab> tabs;
  final Map<(String, LimitTab), LimitSlot> _slots;

  /// `isEffectiveSameDay === "Y"`; OBDX shows Minimum / Maximum Amount
  /// only then (hooks.js:242-247).
  final bool effectiveSameDay;

  LimitSlot? slotFor(String transactionId, LimitTab tab) => _slots[(transactionId, tab)];

  factory MyLimits.fromPayloads({
    required Map<String, dynamic> taskGroups,
    required Map<String, dynamic> assigned,
    required Map<String, dynamic> utilizedDaily,
    required Map<String, dynamic> utilizedMonthly,
    required Map<String, dynamic> custom,
    required bool effectiveSameDay,
    required DateTime today,
  }) {
    final day = DateTime(today.year, today.month, today.day);
    final tomorrow = day.add(const Duration(days: 1));

    // Task group id → its transactions (taskGroups?taskAspect=limits).
    final groupTasks = <String, List<String>>{
      for (final g in _list(taskGroups['taskGroupDTOlist']))
        if (_str(g['id']) != null)
          _str(g['id'])!: [
            for (final t in _list(g['taskDTOs']))
              if (_str(t['id']) != null) _str(t['id'])!,
          ],
    };

    // Calls [visit] with each (transaction, tab, linkage) a package fills:
    // a TASK linkage fills its transaction, a TASK_GROUP linkage every
    // transaction of the group (hooks.js:603-701).
    void forEachTarget(Map<String, dynamic> package, void Function(String taskId, LimitTab tab, Map<String, dynamic> linkage) visit) {
      final type = _PackageType.parse(package['accessPointGroupType']);
      if (type == null) return;
      for (final linkage in _list(package['targetLimitLinkages'])) {
        final target = ObdxApiUtils.asMap(linkage['target']);
        final value = _str(target['value']);
        if (value == null) continue;
        switch (_str(ObdxApiUtils.asMap(target['type'])['id'])) {
          case 'TASK':
            visit(value, type.taskTab, linkage);
          case 'TASK_GROUP':
            for (final task in groupTasks[value] ?? const <String>[]) {
              visit(task, type.groupTab, linkage);
            }
        }
      }
    }

    // 1. The bank's limits.
    final tabs = <LimitTab>{};
    final slots = <(String, LimitTab), LimitSlot>{};
    final assignedPackages = _list(assigned['limitPackageDTOList']);
    for (final package in assignedPackages) {
      final type = _PackageType.parse(package['accessPointGroupType']);
      if (type != null) tabs.addAll([type.taskTab, type.groupTab]);
      forEachTarget(package, (task, tab, linkage) {
        slots[(task, tab)] = _slotFromLinkage(linkage, effectiveTomorrow: _sameDay(linkage['effectiveDate'], tomorrow));
      });
    }

    // 2. Custom limits: only on a tab the bank filled, only when lower,
    // skipping expired ones (hooks.js:784-886, 1077-1121). One effective
    // tomorrow has a blank max, so it changes nothing today.
    for (final package in _list(custom['limitPackageDTOList'])) {
      forEachTarget(package, (task, tab, linkage) {
        final current = slots[(task, tab)];
        if (current == null) return;
        final expiry = _day(linkage['expiryDate']);
        if (expiry != null && !expiry.isAfter(day)) return;
        if (_sameDay(linkage['effectiveDate'], tomorrow)) return;
        final own = _slotFromLinkage(linkage, effectiveTomorrow: false);
        slots[(task, tab)] = current.copyWith(
          daily: _lower(current.daily, own.daily),
          monthly: _lower(current.monthly, own.monthly),
        );
      });
    }

    // 3. Utilisation (hooks.js:990-1029). An id that is a transaction goes
    // to that package type's TASK tab; otherwise it is a task group and
    // every transaction in it gets it on the TASK_GROUP tab.
    final knownTasks = {for (final key in slots.keys) key.$1};
    void applyUtilization(Map<String, dynamic> body) {
      for (final u in _list(body['limitUtilizationDTOs'])) {
        final id = _str(u['utilizationId']);
        final type = _PackageType.parse(u['accessPointGroupType']);
        final period = _str(u['limitType'])?.split('#').last.toUpperCase();
        if (id == null || type == null) continue;
        final amount = _num(ObdxApiUtils.asMap(u['amount'])['amount'])?.toDouble() ?? 0;
        final count = _num(u['count'])?.toInt() ?? 0;

        void put(String task, LimitTab tab) {
          final slot = slots[(task, tab)];
          if (slot == null) return;
          if (period == 'DAILY' && slot.daily != null) {
            slots[(task, tab)] = slot.copyWith(daily: slot.daily!.copyWith(utilizedAmount: amount, utilizedCount: count));
          } else if (period == 'MONTHLY' && slot.monthly != null) {
            slots[(task, tab)] = slot.copyWith(monthly: slot.monthly!.copyWith(utilizedAmount: amount, utilizedCount: count));
          }
        }

        if (knownTasks.contains(id)) {
          put(id, type.taskTab);
        } else {
          for (final task in groupTasks[id] ?? const <String>[]) {
            put(task, type.groupTab);
          }
        }
      }
    }

    applyUtilization(utilizedDaily);
    applyUtilization(utilizedMonthly);

    return MyLimits._(
      tabs: [for (final t in LimitTab.values) if (tabs.contains(t)) t],
      slots: slots,
      effectiveSameDay: effectiveSameDay,
    );
  }

  /// `assignLimitPackage` (hooks.js:703-782): TXN → min/max amount; PER
  /// DAILY / MONTHLY → max amount and count. Last one of a kind wins.
  static LimitSlot _slotFromLinkage(Map<String, dynamic> linkage, {required bool effectiveTomorrow}) {
    TransactionAmountRange? range;
    PeriodicLimit? daily;
    PeriodicLimit? monthly;
    for (final limit in _list(linkage['limits'])) {
      switch (_str(limit['limitType'])) {
        case 'TXN':
          final r = ObdxApiUtils.asMap(limit['amountRange']);
          final min = ObdxApiUtils.asMap(r['minTransaction']);
          final max = ObdxApiUtils.asMap(r['maxTransaction']);
          range = TransactionAmountRange(
            min: _num(min['amount'])?.toDouble(),
            max: _num(max['amount'])?.toDouble(),
            minCurrency: _str(min['currency']) ?? '',
            maxCurrency: _str(max['currency']) ?? '',
          );
        case 'PER':
          final money = ObdxApiUtils.asMap(limit['maxAmount']);
          final periodic = PeriodicLimit(
            maxAmount: effectiveTomorrow ? null : _num(money['amount'])?.toDouble(),
            currency: _str(money['currency']) ?? '',
            maxCount: effectiveTomorrow ? null : _num(limit['maxCount'])?.toInt(),
          );
          switch (_str(limit['periodicity'])?.toUpperCase()) {
            case 'DAILY':
              daily = periodic;
            case 'MONTHLY':
              monthly = periodic;
          }
      }
    }
    return LimitSlot(amountRange: range, daily: daily, monthly: monthly);
  }

  /// The custom value replaces the bank's only when set and lower.
  static PeriodicLimit? _lower(PeriodicLimit? bank, PeriodicLimit? own) {
    if (bank == null || own == null) return bank;
    final amount = own.maxAmount;
    final count = own.maxCount;
    return bank.copyWith(
      maxAmount: amount != null && amount != 0 && bank.maxAmount != null && amount < bank.maxAmount! ? amount : null,
      maxCount: count != null && count != 0 && bank.maxCount != null && count < bank.maxCount! ? count : null,
    );
  }

  static bool _sameDay(dynamic value, DateTime day) {
    final d = _day(value);
    return d != null && d == day;
  }

  /// Calendar day of an OBDX date (`yyyy-MM-dd…` or `dd-MM-yyyy`). OBDX
  /// compares the raw strings; the format is [UNKNOWN].
  static DateTime? _day(dynamic value) {
    final text = _str(value);
    if (text == null) return null;
    final dmy = RegExp(r'^(\d{2})-(\d{2})-(\d{4})').firstMatch(text);
    if (dmy != null) return DateTime(int.parse(dmy.group(3)!), int.parse(dmy.group(2)!), int.parse(dmy.group(1)!));
    final parsed = DateTime.tryParse(text);
    return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
  }
}

List<Map<String, dynamic>> _list(dynamic value) =>
    value is List ? [for (final e in value) if (e is Map) Map<String, dynamic>.from(e)] : const [];

String? _str(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

num? _num(dynamic value) => value is num ? value : num.tryParse(value?.toString().replaceAll(',', '') ?? '');
