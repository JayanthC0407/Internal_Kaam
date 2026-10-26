import 'dart:convert';
import 'dart:typed_data';

import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/preferences/preferences_models.dart';
import 'package:ubci_bank/src/core/models/common/security_question.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_preferences_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/obdx_repository_base.dart';

/// Account Settings → Preferences: parses [ObdxPreferencesApi] into
/// `preferences_models.dart`. Every write can come back with an OTP
/// ([PrefWriteOutcome.otpRequired]); the screen asks for it and calls again
/// with the challenge.
class PreferencesRepository extends ObdxRepositoryBase {
  PreferencesRepository({required ObdxPreferencesApi api}) : _api = api;

  final ObdxPreferencesApi _api;

  // ── Profile ──

  /// OBDX reads `me/party` and `profileConfig` together (Promise.all).
  Future<ResponseHandler<PartyProfile>> fetchProfile() async {
    final results = await Future.wait([_body(_api.fetchParty()), _body(_api.fetchProfileConfig())]);
    for (final r in results) {
      if (r is! Success<Map<String, dynamic>>) return mapFailure(r);
    }
    try {
      return ResponseHandler.success(
        PartyProfile.fromPayloads(
          party: (results[0] as Success<Map<String, dynamic>>).data!,
          config: (results[1] as Success<Map<String, dynamic>>).data!,
        ),
        code: 200,
      );
    } catch (_) {
      return ResponseHandler.exceptionError();
    }
  }

  Future<ResponseHandler<List<int>>> downloadProfileCsv() => _api.downloadPartyCsv();

  Future<ResponseHandler<List<ProfileCountry>>> fetchCountries() async =>
      parseBody(await _api.fetchCountries(), ProfileCountry.listFromPayload);

  /// `PUT me/party {attr_name, attr_value}`: [value] is a string, or the
  /// phone / address object.
  Future<ResponseHandler<PrefWriteOutcome>> updateProfileField(String name, Object value, {ObdxChallenge? challenge, String? otp}) =>
      _write((h) => _api.updateParty({'attr_name': name, 'attr_value': value}, challengeResponseHeader: h), challenge, otp);

  // ── userPreferences ──

  Future<ResponseHandler<UserPreferences>> fetchUserPreferences() async =>
      parseBody(await _api.fetchUserPreferences(), UserPreferences.new);

  Future<ResponseHandler<PrefWriteOutcome>> updateUserPreferences(Map<String, dynamic> body, {ObdxChallenge? challenge, String? otp}) =>
      _write((h) => _api.updateUserPreferences(body, challengeResponseHeader: h), challenge, otp);

  // ── Third Party Applications ──

  /// The user's `EXT` access points with their logos. OBDX batches the
  /// `accessPoints/{id}` and `contents/{id}` reads; here they run in parallel.
  Future<ResponseHandler<List<ThirdPartyApp>>> fetchThirdPartyApps(UserPreferences prefs) async {
    final status = prefs.accessPointStatus;
    final points = await Future.wait([for (final id in status.keys) _body(_api.fetchAccessPoint(id))]);
    final apps = <ThirdPartyApp>[];
    for (final r in points) {
      if (r is! Success<Map<String, dynamic>>) continue;
      final dto = ObdxApiUtils.asMap(r.data!['accessPointDTO']);
      final id = dto['id']?.toString() ?? '';
      if (dto['type']?.toString() != 'EXT' || !status.containsKey(id)) continue;
      final img = ObdxApiUtils.asMap(dto['imgRefno'])['value']?.toString();
      apps.add(ThirdPartyApp(
        id: id,
        name: (dto['description'] ?? id).toString(),
        granted: status[id]!,
        contentId: img == null || img.isEmpty ? null : img,
      ));
    }
    final withLogos = await Future.wait([
      for (final app in apps) app.contentId == null ? Future.value(app) : _logo(app.contentId!).then(app.withLogo),
    ]);
    return ResponseHandler.success(withLogos, code: 200);
  }

  Future<Uint8List?> _logo(String contentId) async {
    final r = await _body(_api.fetchContent(contentId));
    if (r is! Success<Map<String, dynamic>>) return null;
    final list = r.data!['contentDTOList'];
    if (list is! List || list.isEmpty) return null;
    final content = ObdxApiUtils.asMap(list.first)['content']?.toString();
    if (content == null || content.isEmpty) return null;
    try {
      return base64Decode(content);
    } catch (_) {
      return null;
    }
  }

  Future<ResponseHandler<ConsentSetup>> fetchConsentSetup(String accessPointId) async =>
      parseBody(await _api.fetchConsentSetup(accessPointId), ConsentSetup.fromPayload);

  /// third-party-consents `confirm`, second call: OBDX first `PUT`s
  /// userPreferences with the app's status ([updateUserPreferences]), then —
  /// only while access is granted — this, with the accounts and tasks still
  /// checked.
  Future<ResponseHandler<PrefWriteOutcome>> updateConsentAccounts({
    required String accessPointId,
    required ConsentSetup setup,
    required Map<String, ConsentSelection> selection,
    required String userId,
    ObdxChallenge? challenge,
    String? otp,
  }) {
    final body = {
      'accessPointAccountDTOs': [
        for (final type in ConsentAccountType.values)
          {
            'accountAccessId': setup.groups[type]?.accountAccessId,
            'accessPointId': accessPointId,
            'accountType': type.code,
            'accessLevel': 'ACCESSPOINT',
            'accessStatus': false,
            'userId': userId,
            'accountExclusionDTOs': [
              for (final a in setup.groups[type]?.accounts ?? const <ConsentAccount>[])
                if (selection[a.value]?.checked ?? true)
                  {
                    'accountNumber': a.accountNumber,
                    'taskIds': (selection[a.value]?.tasks ?? a.taskIds.toSet()).toList(),
                    'accountExclusionId': a.exclusionId,
                  },
            ],
          },
      ],
    };
    return _write((h) => _api.updateConsentSetup(body, challengeResponseHeader: h), challenge, otp);
  }

  // ── Security questions ──

  Future<ResponseHandler<List<UserSecurityQuestion>>> fetchUserSecurityQuestions() async =>
      parseBody(await _api.fetchUserSecurityQuestions(), UserSecurityQuestion.listFromPayload);

  Future<ResponseHandler<List<SecurityQuestionOption>>> fetchSecurityQuestionCatalog() async =>
      parseBody(await _api.fetchSecurityQuestions(), SecurityQuestionOption.listFromPayload);

  /// `noOfQuestions`; OBDX uses 5 when it is missing.
  Future<int> fetchSecurityQuestionCount() async {
    final r = await _body(_api.fetchSecurityQuestionCount());
    if (r is! Success<Map<String, dynamic>>) return 5;
    final raw = r.data!['noOfQuestions'] ?? r.data!['count'];
    return int.tryParse('${raw ?? ''}') ?? 5;
  }

  Future<ResponseHandler<PrefWriteOutcome>> saveSecurityQuestions(
    List<UserSecurityQuestionAnswer> answers, {
    required bool create,
    ObdxChallenge? challenge,
    String? otp,
  }) =>
      _write(
        (h) => _api.saveUserSecurityQuestions(UserSecurityQuestionAnswer.buildSubmitBody(answers), create: create, challengeResponseHeader: h),
        challenge,
        otp,
      );

  // ── Soft token, SMS banking ──

  /// The QR comes back in the write's body, so this is not a [PrefWriteOutcome].
  Future<ResponseHandler<SoftTokenSeed>> generateSoftToken({required bool oracleAuthenticator}) async =>
      parseBody(await _api.generateSoftToken(authType: oracleAuthenticator ? 'OMA' : null), SoftTokenSeed.fromPayload,
          successCodes: const {200, 201});

  Future<ResponseHandler<SmsBankingRegistration>> fetchSmsBanking() async =>
      parseBody(await _api.fetchSmsBanking(), SmsBankingRegistration.fromPayload);

  Future<ResponseHandler<PrefWriteOutcome>> updateSmsBanking(Map<String, dynamic> body, {ObdxChallenge? challenge, String? otp}) =>
      _write((h) => _api.updateSmsBanking(body, challengeResponseHeader: h), challenge, otp);

  // ── Devices and push ──

  Future<ResponseHandler<DeviceCounts>> fetchRegisteredDevices() async =>
      parseBody(await _api.fetchRegisteredDevices(), DeviceCounts.fromPayload);

  Future<ResponseHandler<DeviceCounts>> fetchPushTokens() async => parseBody(await _api.fetchPushTokens(), DeviceCounts.fromPayload);

  Future<ResponseHandler<PrefWriteOutcome>> unregisterDevices(String os, {ObdxChallenge? challenge, String? otp}) =>
      _write((h) => _api.unregisterDevices(os, challengeResponseHeader: h), challenge, otp);

  Future<ResponseHandler<PrefWriteOutcome>> unregisterPush(String os, {ObdxChallenge? challenge, String? otp}) =>
      _write((h) => _api.unregisterPush(os, challengeResponseHeader: h), challenge, otp);

  // ── Shared ──

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

  /// [parseBody] without a model: the checked body itself.
  Future<ResponseHandler<Map<String, dynamic>>> _body(Future<ResponseHandler<Map<String, dynamic>>> call) async =>
      parseBody(await call, (b) => b);
}
