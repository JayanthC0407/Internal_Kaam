import 'package:ubci_bank/src/core/models/common/account_settings/account_settings_models.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/preferences/preferences_models.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_account_settings_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/obdx_repository_base.dart';
import 'package:ubci_bank/src/infra/security/obdx_password_crypto_service.dart';

/// Session Summary, Alerts Subscription and Change Password. Writes come
/// back as [PrefWriteOutcome], like every other Preferences write.
class AccountSettingsRepository extends ObdxRepositoryBase {
  AccountSettingsRepository({required ObdxAccountSettingsApi api, required ObdxPasswordCryptoService crypto})
      : _api = api,
        _crypto = crypto;

  final ObdxAccountSettingsApi _api;
  final ObdxPasswordCryptoService _crypto;

  // ── Session Summary ──

  Future<ResponseHandler<List<UserSession>>> fetchSessions() async =>
      parseBody(await _api.fetchSessions(), UserSession.listFromPayload);

  Future<ResponseHandler<List<SessionActivity>>> fetchSessionActivity(String sessionId) async =>
      parseBody(await _api.fetchSessionActivity(sessionId), SessionActivity.listFromPayload);

  // ── Change Password ──

  Future<ResponseHandler<PasswordPolicy>> fetchPasswordPolicy() async =>
      parseBody(await _api.fetchPasswordPolicy(), PasswordPolicy.fromPayload);

  /// Encrypts both passwords as login does (bank public key + salt), then
  /// `PUT me/credentials`.
  Future<ResponseHandler<PrefWriteOutcome>> changePassword({
    required String userName,
    required String current,
    required String next,
    ObdxChallenge? challenge,
    String? otp,
  }) async {
    final oldEnc = await _crypto.encryptForUser(userName: userName, plainPassword: current);
    if (oldEnc is! Success<String> || oldEnc.data == null) return mapFailure(oldEnc);
    final newEnc = await _crypto.encryptForUser(userName: userName, plainPassword: next);
    if (newEnc is! Success<String> || newEnc.data == null) return mapFailure(newEnc);
    return _write(
      (h) => _api.changePassword({'oldPassword': oldEnc.data, 'changedPassword': newEnc.data}, challengeResponseHeader: h),
      challenge,
      otp,
    );
  }

  // ── Alerts Subscription ──

  Future<ResponseHandler<AlertsUser>> fetchUser() async => parseBody(await _api.fetchMe(), AlertsUser.fromPayload);

  Future<ResponseHandler<List<AlertModule>>> fetchModules() async =>
      parseBody(await _api.fetchModules(), AlertModule.listFromPayload);

  Future<ResponseHandler<List<AlertEvent>>> fetchEvents() async => parseBody(await _api.fetchEvents(), AlertEvent.listFromPayload);

  Future<ResponseHandler<List<AlertSubscription>>> fetchSubscriptions(AlertsUser user) async => parseBody(
        await _api.fetchSubscriptions(user.corporate ? {'userId': user.userId} : {'party': user.partyValue}),
        AlertSubscription.listFromPayload,
      );

  /// A module's accounts (one call per account type, as OBDX makes); a
  /// party-level module is the user's own party.
  Future<ResponseHandler<List<AlertTarget>>> fetchTargets(AlertsUser user, AlertModule module) async {
    if (module.partyLevel) {
      return ResponseHandler.success([AlertTarget(value: user.partyValue, displayValue: user.partyDisplay)], code: 200);
    }
    final results = await Future.wait([
      for (final type in module.accountTypes) _api.fetchPartyAccounts(user.partyValue, type),
    ]);
    final targets = <String, AlertTarget>{};
    ResponseHandler<List<AlertTarget>>? failure;
    for (final r in results) {
      final parsed = await parseBody(r, AlertTarget.accountsFromPayload);
      if (parsed is Success<List<AlertTarget>>) {
        for (final t in parsed.data ?? const <AlertTarget>[]) {
          targets[t.value] = t;
        }
      } else {
        failure ??= parsed;
      }
    }
    if (targets.isEmpty && failure != null) return failure;
    return ResponseHandler.success(targets.values.toList(), code: 200);
  }

  /// Save for one module and account: that pair's actions are replaced by
  /// [selection] (eventId → modes); every other subscribed action stays.
  /// `POST` a new record, `PUT` an existing one, or `DELETE` it when
  /// nothing is left at that level (OBDX's only way to unsubscribe).
  Future<ResponseHandler<PrefWriteOutcome>> saveAlerts({
    required AlertsUser user,
    required AlertModule module,
    required AlertTarget target,
    required List<AlertEvent> events,
    required Map<String, Set<AlertMode>> selection,
    AlertSubscription? existing,
    ObdxChallenge? challenge,
    String? otp,
    DateTime? today,
  }) {
    final level = module.partyLevel ? 'PARTY' : 'ACCOUNT';
    final kept = [
      for (final a in existing?.actions ?? const <Map<String, dynamic>>[])
        if (!(a['module']?.toString() == module.id && AlertSubscription.keyOf(a) == target.value)) a,
    ];
    final added = [
      for (final e in events)
        if ((selection[e.eventId] ?? const {}).isNotEmpty)
          _action(user, module, target, e, selection[e.eventId]!, level, existing?.id ?? '', today ?? DateTime.now()),
    ];
    final all = [...kept, ...added];
    if (existing == null && all.isEmpty) {
      return Future.value(ResponseHandler.success(const PrefWriteOutcome.done(), code: 200));
    }
    if (existing != null && all.isEmpty) {
      return _write((h) => _api.deleteSubscription(existing.id, challengeResponseHeader: h), challenge, otp);
    }
    final body = _subscription(user, level, existing?.id ?? '', all, today ?? DateTime.now());
    return _write(
      (h) => existing == null
          ? _api.createSubscription(body, challengeResponseHeader: h)
          : _api.updateSubscription(existing.id, body, challengeResponseHeader: h),
      challenge,
      otp,
    );
  }

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static const _endDate = '2099-02-01';

  /// `actionSubscriptionspostv1payload`.
  Map<String, dynamic> _subscription(AlertsUser user, String level, String id, List<Map<String, dynamic>> actions, DateTime today) => {
        'subscriptionId': id,
        'active': true,
        'subscriptionLevel': level,
        'subscriptionStartDate': _day(today),
        'subscriptionEndDate': _endDate,
        'temporaryUnsubscriptionDuration': {'startDate': null, 'endDate': null},
        'subscriber': {
          'id': user.userId,
          'subscriberType': user.corporate ? 'CORPORATE' : 'PARTY',
          'party': user.corporate ? null : {'displayValue': user.partyDisplay, 'value': user.partyValue},
        },
        'subscribedActions': actions,
      };

  /// One `subscribedActions[]` entry with its `subscriptionPreferences[]`.
  Map<String, dynamic> _action(
    AlertsUser user,
    AlertModule module,
    AlertTarget target,
    AlertEvent event,
    Set<AlertMode> modes,
    String level,
    String subscriptionId,
    DateTime today,
  ) {
    final accountKey = level == 'ACCOUNT' ? target.toJson() : null;
    final partyKey = level == 'PARTY' ? target.toJson() : null;
    return {
      'alertName': event.alertName,
      'activityId': event.activityId,
      'eventId': event.eventId,
      'actionId': event.actionId,
      'subscribedActionStartDate': _day(today),
      'subscribedActionEndDate': _endDate,
      'unsubscriptionDuration': {'startDate': null, 'endDate': null},
      'actionTemplate': event.template,
      'module': module.id,
      'eventType': null,
      'subscriptionId': subscriptionId,
      'subscriptionLevel': level,
      'subscriptionLevelKey': target.value,
      'subscriptionLevelAccountKey': accountKey,
      'subscriptionLevelPartyKey': partyKey,
      'subscriptionPreferences': [
        for (final m in AlertMode.values)
          if (modes.contains(m))
            {
              'destination': m.code,
              'recipientCategory': user.corporate ? 'CORPORATE' : 'PARTY',
              'subscriberValue': user.corporate ? 'USER' : 'CUSTOMER',
              'destinationAddress': switch (m) {
                AlertMode.sms => user.mobile,
                AlertMode.email => user.email,
                _ => null,
              },
              'version': 1,
              'startRestrictedTime': 0,
              'endRestrictedTime': 0,
              'timeRestricted': false,
              'transactionAmount': {'amount': 0},
              'consolidationRequired': false,
              'urgencyType': 'H',
              'activityId': event.activityId,
              'eventId': event.eventId,
              'actionId': event.actionId,
              'subscriptionId': subscriptionId,
              'subscriptionLevel': level,
              'subscriptionLevelAccountKey': accountKey,
              'subscriptionLevelPartyKey': partyKey,
            },
      ],
    };
  }

  // ── Manage DND Alerts ──

  Future<ResponseHandler<DndRegistry>> fetchDndRegistry() async =>
      parseBody(await _api.fetchDndRegistry(), DndRegistry.fromPayload);

  Future<ResponseHandler<List<String>>> fetchDndEvents(String categoryId) async =>
      parseBody(await _api.fetchDndEvents(categoryId), dndEventsFromPayload);

  /// Confirm: the ticked categories (an empty list turns DND off for all).
  Future<ResponseHandler<PrefWriteOutcome>> saveDnd(
    DndRegistry registry,
    Set<String> selected, {
    ObdxChallenge? challenge,
    String? otp,
  }) =>
      _write((h) => _api.saveDndRegistry(registry.body(selected), challengeResponseHeader: h), challenge, otp);

  Future<ResponseHandler<PrefWriteOutcome>> _write(
    Future<ResponseHandler<Map<String, dynamic>>> Function(String? challengeResponseHeader) call,
    ObdxChallenge? challenge,
    String? otp,
  ) async {
    final otpValue = otp?.trim() ?? '';
    final otpSubmitted = challenge != null && otpValue.isNotEmpty;
    final result = await call(otpSubmitted ? challenge.toChallengeResponseHeader(otpValue) : null);
    return writeOutcome(
      result,
      otpSubmitted: otpSubmitted,
      onOtp: (next, invalid) => PrefWriteOutcome.otpRequired(next, invalidOtp: invalid),
      onDone: (_, reference, pending) => PrefWriteOutcome.done(pendingApproval: pending, reference: reference),
    );
  }
}
