import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/preferences/preferences_models.dart';
import 'package:ubci_bank/src/core/models/common/service_requests/service_request_models.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_service_requests_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/obdx_repository_base.dart';

/// Service Requests: parses [ObdxServiceRequestsApi] into
/// `service_request_models.dart`. Raising a request can come back with an
/// OTP or for approval (corporate), the same [PrefWriteOutcome] every
/// other write in the app uses.
class ServiceRequestsRepository extends ObdxRepositoryBase {
  ServiceRequestsRepository({required ObdxServiceRequestsApi api}) : _api = api;

  final ObdxServiceRequestsApi _api;

  Future<ResponseHandler<List<String>>> fetchProducts() async =>
      parseBody(await _api.fetchProducts(), SrCategory.productsFromPayload);

  Future<ResponseHandler<List<SrCategory>>> fetchCategories(String product) async =>
      parseBody(await _api.fetchCategories(product), SrCategory.listFromPayload);

  Future<ResponseHandler<List<SrOption>>> fetchEnumeration(String name) async =>
      parseBody(await _api.fetchEnumeration(name), SrOption.listFromEnumeration);

  Future<ResponseHandler<List<ServiceRequestSummary>>> fetchRequests(SrFilter filter) async =>
      parseBody(await _api.fetchRequests(filter.toQuery()), ServiceRequestSummary.listFromPayload);

  Future<ResponseHandler<ServiceRequestDetail>> fetchRequest(String id) async =>
      parseBody(await _api.fetchRequest(id), ServiceRequestDetail.fromPayload);

  Future<ResponseHandler<List<SrDefinition>>> fetchDefinitions() async =>
      parseBody(await _api.fetchDefinitions(), SrDefinition.listFromPayload);

  Future<ResponseHandler<SrDefinition>> fetchDefinition(String id) async => parseBody(await _api.fetchDefinition(id), (body) {
        final definition = SrDefinition.oneFromPayload(body);
        if (definition == null) throw const FormatException('no definition');
        return definition;
      });

  Future<ResponseHandler<List<SrAccount>>> fetchAccounts() async =>
      parseBody(await _api.fetchAccounts(), SrAccount.listFromPayload);

  Future<ResponseHandler<List<SrOption>>> fetchDebitCards(String accountId) async =>
      parseBody(await _api.fetchDebitCards(accountId), SrAccount.cardsFromPayload);

  /// FFFU: the uploaded file's `contentDTOList[0].contentId.value`.
  Future<ResponseHandler<String>> uploadAttachment({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) async =>
      parseBody(
        await _api.uploadContent(bytes: bytes, fileName: fileName, mimeType: mimeType),
        (body) {
          final list = body['contentDTOList'];
          final first = list is List && list.isNotEmpty ? ObdxApiUtils.asMap(list.first) : const <String, dynamic>{};
          final id = ObdxApiUtils.asMap(first['contentId'])['value']?.toString() ?? '';
          if (id.isEmpty) throw const FormatException('no content id');
          return id;
        },
        successCodes: const {200, 201, 202},
      );

  /// Best effort, as in OBDX (the answer is not checked).
  Future<void> removeAttachment(String contentId) => _api.deleteContent(contentId);

  Future<ResponseHandler<List<int>>> downloadAttachment(String contentId) => _api.downloadContent(contentId);

  /// `POST servicerequest`; the reference is `status.referenceNumber`.
  Future<ResponseHandler<PrefWriteOutcome>> submit(SrSubmission submission, {ObdxChallenge? challenge, String? otp}) async {
    final otpValue = otp?.trim() ?? '';
    final otpSubmitted = challenge != null && otpValue.isNotEmpty;
    final result = await _api.submit(
      submission.toBody(),
      challengeResponseHeader: otpSubmitted ? challenge.toChallengeResponseHeader(otpValue) : null,
    );
    return writeOutcome(
      result,
      otpSubmitted: otpSubmitted,
      onOtp: (next, invalid) => PrefWriteOutcome.otpRequired(next, invalidOtp: invalid),
      onDone: (body, reference, pending) =>
          PrefWriteOutcome.done(pendingApproval: pending, reference: reference ?? body['referenceNumber']?.toString()),
    );
  }
}
