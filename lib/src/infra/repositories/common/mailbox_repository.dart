import 'package:ubci_bank/src/core/models/common/mailbox/mailbox_models.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/models/common/statement_format.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_mailbox_api.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/statement_download.dart';
import 'package:ubci_bank/src/infra/repositories/common/obdx_repository_base.dart';

/// Mailbox — parses [ObdxMailboxApi] responses into `mailbox_models.dart`
/// (docs/obdx/features/mailbox.md). [userName] is the signed-in user's
/// `userProfile.userName`, which OBDX compares with each mapping's `userId`.
class MailboxRepository extends ObdxRepositoryBase {
  MailboxRepository({required ObdxMailboxApi api}) : _api = api;

  final ObdxMailboxApi _api;

  Future<ResponseHandler<MailboxCounts>> fetchCounts() async =>
      parseBody(await _api.fetchCount(), MailboxCounts.fromPayload);

  Future<ResponseHandler<List<Mail>>> fetchMails(MailFolder folder, String userName) async => parseBody(
        await _api.fetchMails(folder.query),
        (b) => Mail.listFromPayload(b, userName: userName, folder: folder),
      );

  Future<ResponseHandler<List<MailboxAlert>>> fetchAlerts(String userName) async =>
      parseBody(await _api.fetchAlerts(), (b) => MailboxAlert.listFromPayload(b, userName: userName));

  Future<ResponseHandler<List<MailboxNotification>>> fetchNotifications(String userName) async =>
      parseBody(await _api.fetchNotifications(), (b) => MailboxNotification.listFromPayload(b, userName: userName));

  Future<ResponseHandler<NotificationDetail>> fetchNotificationDetail(String messageId) async =>
      parseBody(await _api.fetchNotification(messageId), NotificationDetail.fromPayload);

  /// The attachments' titles (`contentDTOList[0].title`). One failed call
  /// keeps that attachment's id as its name, as OBDX shows when no title.
  Future<List<MailAttachment>> fetchAttachmentTitles(List<MailAttachment> attachments) => Future.wait([
        for (final a in attachments)
          _api.fetchContent(a.contentId).then((r) async {
            final parsed = await parseBody(r, (b) {
              final list = b['contentDTOList'];
              final first = list is List && list.isNotEmpty ? ObdxApiUtils.asMap(list.first) : const <String, dynamic>{};
              return first['title']?.toString();
            });
            return parsed is Success<String?> ? a.withTitle(parsed.data) : a;
          }),
      ]);

  /// The attachment's file, named after it; the type comes from its
  /// extension (the five types OBDX allows, else a generic file). [APP]
  Future<ResponseHandler<StatementFile>> downloadAttachment(MailAttachment attachment) async {
    final name = attachment.name;
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    return decodeStatementDownload(
      await _api.downloadContent(attachment.contentId),
      format: StatementFormat(code: ext.isEmpty ? 'bin' : ext, mimeType: _mimeTypes[ext] ?? 'application/octet-stream'),
      fileName: name,
    );
  }

  static const _mimeTypes = {
    'pdf': 'application/pdf',
    'jpeg': 'image/jpeg',
    'jpg': 'image/jpeg',
    'png': 'image/png',
    'txt': 'text/plain',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'zip': 'application/zip',
  };

  // ── Mark read: OBDX does it on open and ignores the answer; so does the
  // app (a failure only leaves the item unread). ──

  Future<bool> markMailRead(Mail mail, MailFolder folder) async => _ok(await _api.updateMail(
        mail.id,
        mail.updateBody(status: 'R', deleteStatus: folder == MailFolder.deleted),
      ));

  Future<bool> markAlertRead(MailboxAlert alert) async => _ok(await _api.updateAlert(alert.id, alert.updateBody('R')));

  Future<bool> markNotificationRead(MailboxNotification n) async =>
      _ok(await _api.updateNotification(n.mapId, n.readBody()));

  bool _ok(ResponseHandler<Map<String, dynamic>> r) =>
      r is Success<Map<String, dynamic>> && ((r.data?['statusCode'] as int?) ?? 0) < 300;

  // ── Delete / restore: real writes, so 417 OTP and approval apply. ──

  /// Delete: to Deleted Mails (`deleteStatus: true`, status kept), or for
  /// good from Deleted Mails (`PD`) (mailbox.md §5).
  Future<ResponseHandler<MailboxWriteOutcome>> deleteMail(Mail mail, MailFolder folder, {ObdxChallenge? challenge, String? otp}) =>
      _write(
        (header) => _api.updateMail(
          mail.id,
          mail.updateBody(status: folder == MailFolder.deleted ? 'PD' : (mail.myStatus ?? 'R'), deleteStatus: true),
          challengeResponseHeader: header,
        ),
        challenge,
        otp,
      );

  /// Restore from Deleted Mails: status kept, `deleteStatus: false`.
  Future<ResponseHandler<MailboxWriteOutcome>> restoreMail(Mail mail, {ObdxChallenge? challenge, String? otp}) => _write(
        (header) => _api.updateMail(
          mail.id,
          mail.updateBody(status: mail.myStatus ?? 'R', deleteStatus: false),
          challengeResponseHeader: header,
        ),
        challenge,
        otp,
      );

  Future<ResponseHandler<MailboxWriteOutcome>> deleteAlert(MailboxAlert alert, {ObdxChallenge? challenge, String? otp}) =>
      _write((header) => _api.updateAlert(alert.id, alert.updateBody('PD'), challengeResponseHeader: header), challenge, otp);

  Future<ResponseHandler<MailboxWriteOutcome>> deleteNotification(MailboxNotification n,
          {ObdxChallenge? challenge, String? otp}) =>
      _write((header) => _api.updateNotification(n.mapId, n.deleteBody(), challengeResponseHeader: header), challenge, otp);

  Future<ResponseHandler<MailboxWriteOutcome>> _write(
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
      onOtp: (next, invalid) => MailboxWriteOutcome.otpRequired(next, invalidOtp: invalid),
      onDone: (_, __, pending) => MailboxWriteOutcome.done(pendingApproval: pending),
    );
  }
}
