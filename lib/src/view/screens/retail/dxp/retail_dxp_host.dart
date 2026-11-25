import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:demo_bank/src/core/models/common/cards/credit_card_models.dart';
import 'package:demo_bank/src/core/models/common/cards/debit_card_models.dart';
import 'package:demo_bank/src/core/models/common/payee/payee_models.dart';
import 'package:demo_bank/src/core/models/retail/casa_account.dart';
import 'package:demo_bank/src/core/models/retail/casa_transaction.dart';
import 'package:demo_bank/src/infra/network/response_handler.dart';
import 'package:demo_bank/src/sdui/dxp_runtime.dart';
import 'package:demo_bank/src/view/providers/common/repository_providers.dart';
import 'package:demo_bank/src/view/providers/retail/accounts_providers.dart';
import 'package:demo_bank/src/view/screens/retail/dxp/retail_app_widgets.dart';
import 'package:demo_bank/src/view/screens/retail/home/widgets/retail_nav.dart';

/// The Retail dashboard's half of the DXP contract: what a published
/// screen may read (CONTRACT-OBDX §6) and which existing screens it may open
/// (§7). Built by the dashboard, which owns the data and the navigation.
///
/// Every source is read-only and goes through an existing repository. What
/// reaches a screen never carries a real account or card number: numbers are
/// masked to their last four digits, and ids are positions (`a1`, `c1`, …),
/// because OBDX's own ids *are* the full numbers.
class RetailDxpHost implements DxpHost {
  RetailDxpHost({
    required this.loadAccounts,
    required this.openNavItem,
    required String firstName,
    required String fullName,
    Future<List<CasaTransaction>> Function(String accountId)? loadTransactions,
    Future<List<CreditCard>> Function()? loadCreditCards,
    Future<List<DebitCard>> Function()? loadDebitCards,
    Future<List<PayeeSummary>> Function()? loadPayees,
  })  : loadTransactions = loadTransactions ?? _none,
        loadCreditCards = loadCreditCards ?? _none,
        loadDebitCards = loadDebitCards ?? _none,
        loadPayees = loadPayees ?? _none,
        customer = {
          'firstName': firstName,
          'name': fullName,
          'segment': 'RETAIL',
        };

  /// The host the dashboard uses: every source on the app's existing
  /// providers and repositories, so OBDX is called exactly as elsewhere.
  factory RetailDxpHost.live(
    WidgetRef ref, {
    required void Function(String navId) openNavItem,
    required String firstName,
    required String fullName,
  }) {
    return RetailDxpHost(
      openNavItem: openNavItem,
      firstName: firstName,
      fullName: fullName,
      loadAccounts: () async {
        await ref.read(casaAccountsProvider.notifier).ensureLoaded();
        return ref.read(casaAccountsProvider).summary?.accounts ?? const [];
      },
      loadTransactions: (accountId) async => _data(
        await ref.read(accountsRepositoryProvider).fetchCasaTransactions(accountId),
      ).transactions,
      loadCreditCards: () async =>
          _data(await ref.read(cardsRepositoryProvider).fetchCreditCards()),
      loadDebitCards: () async =>
          _data(await ref.read(cardsRepositoryProvider).fetchDebitCards()),
      loadPayees: () async =>
          _data(await ref.read(payeeRepositoryProvider).fetchPayees()),
    );
  }

  static Future<List<T>> _none<T>([Object? _]) async => const [];

  /// The data of a successful call; anything else fails the source.
  static T _data<T>(ResponseHandler<T> result) {
    if (result is Success<T> && result.data != null) return result.data as T;
    throw StateError('OBDX call failed');
  }

  /// The CASA accounts the dashboard already loads from OBDX.
  final Future<List<CasaAccount>> Function() loadAccounts;
  final Future<List<CasaTransaction>> Function(String accountId) loadTransactions;
  final Future<List<CreditCard>> Function() loadCreditCards;
  final Future<List<DebitCard>> Function() loadDebitCards;
  final Future<List<PayeeSummary>> Function() loadPayees;

  /// Selects a Retail menu item, exactly as a tap in the menu does.
  final void Function(String navId) openNavItem;

  @override
  final Map<String, dynamic> customer;

  @override
  Map<String, Widget Function()> get appWidgets => RetailAppWidgets.builders;

  /// Source names this app resolves (CONTRACT-OBDX §6). Keep in step with
  /// the platform's `DATA_SOURCES` (dxp-platform `src/validate.js`).
  static const dataSources = <String>[
    'customer.profile',
    'accounts.list',
    'txn.history',
    'cards.list',
    'payees.list',
  ];

  /// How many transactions `txn.history` returns.
  static const txnHistoryLimit = 10;

  /// `nativeRoute` route → Retail menu id (CONTRACT-OBDX §7). Keep in step
  /// with the platform's `NATIVE_ROUTES` (dxp-platform `src/validate.js`).
  static const routeTable = <String, String>{
    '/home': RetailNav.home,
    '/transfer': RetailNav.transfer,
    '/accounts': RetailNav.accountsCasa,
    '/accounts/loans': RetailNav.accountsLoans,
    '/accounts/term-deposits': RetailNav.accountsTermDeposits,
    '/cards/credit': RetailNav.creditCards,
    '/bills': RetailNav.billPayments,
  };

  @override
  bool openNative(String route) {
    final navId = routeTable[route];
    if (navId == null) return false;
    openNavItem(navId);
    return true;
  }

  @override
  Future<dynamic> resolveData(String source) async {
    try {
      switch (source) {
        case 'customer.profile':
          return customer;
        case 'accounts.list':
          final accounts = await loadAccounts();
          return [for (var i = 0; i < accounts.length; i++) accountToContract(accounts[i], i)];
        case 'txn.history':
          final account = defaultAccount(await loadAccounts());
          if (account == null) return const [];
          final txns = (await loadTransactions(account.id)).take(txnHistoryLimit).toList();
          return [for (var i = 0; i < txns.length; i++) transactionToContract(txns[i], i)];
        case 'cards.list':
          final results = await Future.wait([loadCreditCards(), loadDebitCards()]);
          final credit = results[0] as List<CreditCard>;
          final debit = results[1] as List<DebitCard>;
          return [
            for (var i = 0; i < credit.length; i++) creditCardToContract(credit[i], i),
            for (var i = 0; i < debit.length; i++) debitCardToContract(debit[i], credit.length + i),
          ];
        case 'payees.list':
          final payees = await loadPayees();
          return [for (var i = 0; i < payees.length; i++) payeeToContract(payees[i], i)];
      }
    } catch (_) {
      // Rendered empty; the runtime posts the ERROR event.
    }
    return null;
  }

  /// The account `txn.history` reads: the default CASA account, else the
  /// first one.
  static CasaAccount? defaultAccount(List<CasaAccount> accounts) {
    if (accounts.isEmpty) return null;
    for (final a in accounts) {
      if (a.isDefault) return a;
    }
    return accounts.first;
  }

  /// `{id, name, number, type, balance, currency}`.
  static Map<String, dynamic> accountToContract(CasaAccount a, int index) {
    final balance = a.displayBalance;
    return {
      'id': 'a${index + 1}',
      'name': a.title,
      'number': maskNumber(a.displayNumber),
      'type': (a.accountType ?? '').toUpperCase(),
      'balance': balance?.amount ?? 0,
      'currency': balance?.currency ?? a.currencyCode,
    };
  }

  /// `{id, date, description, amount, currency, status}`; a debit's amount
  /// is negative (prototype CONTRACT §4).
  static Map<String, dynamic> transactionToContract(CasaTransaction t, int index) {
    final when = t.transactionDate ?? t.dateTime ?? t.valueDate;
    final amount = t.amount.amount.abs();
    return {
      'id': 't${index + 1}',
      'date': when == null ? '' : when.toIso8601String().substring(0, 10),
      'description': t.title,
      'amount': t.isCredit ? amount : -amount,
      'currency': t.amount.currency ?? '',
      'status': t.status ?? '',
    };
  }

  /// `{id, kind, name, number, status, limit, available, currency}`.
  static Map<String, dynamic> creditCardToContract(CreditCard c, int index) => {
        'id': 'c${index + 1}',
        'kind': 'CREDIT',
        'name': 'Credit card',
        'number': maskNumber(c.displayNumber),
        'status': c.status.name.toUpperCase(),
        'limit': c.creditLimit?.amount,
        'available': c.availableCredit?.amount,
        'currency': c.creditLimit?.currency ?? c.availableCredit?.currency ?? '',
      };

  static Map<String, dynamic> debitCardToContract(DebitCard d, int index) => {
        'id': 'c${index + 1}',
        'kind': 'DEBIT',
        'name': (d.cardType?.trim().isNotEmpty ?? false) ? d.cardType!.trim() : 'Debit card',
        'number': maskNumber(d.displayNumber),
        'status': d.status.name.toUpperCase(),
        'limit': null,
        'available': null,
        'currency': '',
      };

  /// `{id, name, account, bank, type}`.
  static Map<String, dynamic> payeeToContract(PayeeSummary p, int index) => {
        'id': 'p${index + 1}',
        'name': p.nickname,
        'account': p.accountNumber == null ? '' : maskNumber(p.accountNumber!),
        'bank': p.accountDetails != '—' ? p.accountDetails : p.accountType,
        'type': p.payeeType ?? '',
      };

  /// Last four characters only: `•••• 1234`. Spaces and mask characters
  /// already in the value are ignored.
  static String maskNumber(String number) {
    final compact = number.replaceAll(RegExp(r'[\s*xX•-]'), '');
    if (compact.length <= 4) return compact;
    return '•••• ${compact.substring(compact.length - 4)}';
  }
}
