import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/infra/network/obdx_api_utils.dart';

/// Mailbox (OBDX `components/mailbox`). Every rule here is from
/// docs/obdx/features/mailbox.md; `mb/` paths are cited inline.

/// Mails folder: Inbox, Sent Mails or Deleted Mails.
enum MailFolder {
  inbox,
  sent,
  deleted;

  /// `GET mailbox/mails` query (mailbox.md §3). Inbox asks for every mail,
  /// not just unread ones as OBDX's first load does (`msgStatus=U`): the
  /// user chose all mails with unread in bold (2026-10-23). [APP]
  Map<String, dynamic> get query => switch (this) {
        MailFolder.inbox => const {'msgFlag': 'T', 'deleteStatus': 'false'},
        MailFolder.sent => const {'msgFlag': 'F', 'deleteStatus': 'false'},
        MailFolder.deleted => const {'deleteStatus': 'true'},
      };
}

/// An attachment as the mail lists it (`contentDTO[]`).
class MailAttachment {
  const MailAttachment({required this.contentId, required this.displayValue, this.title});

  final String contentId;
  final String displayValue;

  /// From `GET contents/{id}` (`contentDTOList[0].title`); OBDX falls back
  /// to [displayValue].
  final String? title;

  String get name => (title?.isNotEmpty ?? false) ? title! : displayValue;

  MailAttachment withTitle(String? title) =>
      MailAttachment(contentId: contentId, displayValue: displayValue, title: title);
}

/// One mail, or an earlier message of its thread (`linkedParent`).
class Mail {
  const Mail({
    required this.id,
    required this.displayValue,
    required this.subject,
    this.interactionId,
    this.date,
    this.body = '',
    this.senderName,
    this.unread = false,
    this.myStatus,
    this.attachments = const [],
    this.thread = const [],
    this.subjectId,
  });

  /// `messageId.value` / `.displayValue`.
  final String id;
  final String displayValue;
  final String subject;

  /// "Reference No".
  final String? interactionId;

  /// `creationDate`.
  final DateTime? date;

  /// `messageBody`, shown as plain text like OBDX.
  final String body;

  /// "From :": the `msgFlag == "F"` mapping's `userGroupName`, else its
  /// `username`. OBDX sets it only for Inbox and Deleted
  /// (mb/mailbox-base/hooks.js:165-180).
  final String? senderName;

  /// My mapping (`userId` == signed-in user name) has `status == "U"`.
  final bool unread;

  /// My mapping's `status`, sent back unchanged on delete / restore.
  final String? myStatus;

  final List<MailAttachment> attachments;

  /// Earlier messages, newest first (the `linkedParent` chain).
  final List<Mail> thread;

  /// The mail's subject category; Reply sends it back (message-detail/hooks.js:503).
  final String? subjectId;

  Mail copyWith({bool? unread, String? myStatus, List<MailAttachment>? attachments}) => Mail(
        id: id,
        displayValue: displayValue,
        subject: subject,
        interactionId: interactionId,
        date: date,
        body: body,
        senderName: senderName,
        unread: unread ?? this.unread,
        myStatus: myStatus ?? this.myStatus,
        attachments: attachments ?? this.attachments,
        thread: thread,
        subjectId: subjectId,
      );

  static List<Mail> listFromPayload(Map<String, dynamic> body, {required String userName, required MailFolder folder}) => [
        for (final raw in _list(body['mails']))
          if (_str(ObdxApiUtils.asMap(raw['messageId'])['value']) != null) _fromMap(raw, userName, folder),
      ];

  static Mail _fromMap(Map<String, dynamic> raw, String userName, MailFolder folder) {
    final id = ObdxApiUtils.asMap(raw['messageId']);
    String? sender;
    String? myStatus;
    for (final m in _list(raw['messageUserMappings'])) {
      if (folder != MailFolder.sent && _str(m['msgFlag']) == 'F') {
        sender = _str(m['userGroupName']) ?? _str(m['username']);
      }
      if (_sameUser(m['userId'], userName)) myStatus = _str(m['status']);
    }
    final parent = raw['linkedParent'];
    return Mail(
      id: _str(id['value']) ?? '',
      displayValue: _str(id['displayValue']) ?? _str(id['value']) ?? '',
      subject: _str(raw['subject']) ?? '',
      interactionId: _str(raw['interactionId']),
      subjectId: _str(raw['subjectId']),
      date: _date(raw['creationDate']),
      body: _str(raw['messageBody']) ?? '',
      senderName: sender ?? _str(raw['senderName']),
      unread: myStatus == 'U',
      myStatus: myStatus,
      attachments: [
        for (final c in _list(raw['contentDTO']))
          if (_str(ObdxApiUtils.asMap(c['contentId'])['value']) != null)
            MailAttachment(
              contentId: _str(ObdxApiUtils.asMap(c['contentId'])['value'])!,
              displayValue: _str(ObdxApiUtils.asMap(c['contentId'])['displayValue']) ?? '',
              title: _str(c['title']),
            ),
      ],
      thread: [
        // mb/message-detail/hooks.js:189-196: walk linkedParent upwards.
        for (var p = parent; p is Map; p = p['linkedParent'])
          _fromMap(Map<String, dynamic>.from(p)..remove('linkedParent'), userName, folder),
      ],
    );
  }

  /// `POST mailbox/mails/{id}/replyMail` body (message-detail/hooks.js:493-517).
  /// The subject gets OBDX's "Re :" prefix (no space after it) unless it
  /// already has one; [contents] are the attachments' `contentId` objects.
  Map<String, dynamic> replyBody(String text, List<Map<String, dynamic>> contents) => {
        'messageType': 'M',
        'subject': subject.contains(replyPrefix) ? subject : '$replyPrefix$subject',
        'messageBody': text,
        'expiryDate': null,
        'subjectId': subjectId,
        'messageId': id,
        'contentDTO': [
          for (final c in contents) {'contentId': c},
        ],
        'linkedParent': {
          'messageId': id,
          'messageType': 'M',
          'subject': subject,
          'messageBody': body,
          'subjectId': subjectId,
        },
      };

  /// nls compose-mail.js `replyPrefix`.
  static const replyPrefix = 'Re :';

  /// `PUT mailbox/mails/{id}` body (mailbox.md §4-5).
  Map<String, dynamic> updateBody({required String status, required bool deleteStatus}) => {
        'messageId': {'displayValue': displayValue, 'value': id},
        'messageUserMappings': [
          {'status': status, 'deleteStatus': deleteStatus},
        ],
      };
}

/// One alert (`alertDTOs[]`).
class MailboxAlert {
  const MailboxAlert({
    required this.id,
    required this.displayValue,
    required this.subject,
    this.date,
    this.body = '',
    this.unread = false,
  });

  final String id;
  final String displayValue;
  final String subject;
  final DateTime? date;

  /// `messageBody`: HTML in OBDX, shown here as plain text.
  final String body;
  final bool unread;

  MailboxAlert markedRead() =>
      MailboxAlert(id: id, displayValue: displayValue, subject: subject, date: date, body: body);

  static List<MailboxAlert> listFromPayload(Map<String, dynamic> body, {required String userName}) => [
        for (final raw in _list(body['alertDTOs']))
          if (_str(ObdxApiUtils.asMap(raw['messageId'])['value']) != null)
            MailboxAlert(
              id: _str(ObdxApiUtils.asMap(raw['messageId'])['value'])!,
              displayValue: _str(ObdxApiUtils.asMap(raw['messageId'])['displayValue']) ?? '',
              subject: _str(raw['subject']) ?? '',
              date: _date(raw['creationDate']),
              body: _str(raw['messageBody']) ?? '',
              unread: _list(raw['messageUserMappings'])
                  .any((m) => _sameUser(m['userId'], userName) && _str(m['status']) == 'U'),
            ),
      ];

  /// `PUT mailbox/alerts/{id}`: read is `R`, delete is `PD` (mailbox.md §7).
  Map<String, dynamic> updateBody(String status) => {
        'messageId': {'displayValue': displayValue, 'value': id},
        'messageUserMappings': [
          {'status': status},
        ],
      };
}

/// One notification (`mailerUserMapDTOs[]`).
class MailboxNotification {
  const MailboxNotification({
    required this.messageId,
    required this.mapId,
    required this.subject,
    this.date,
    this.highPriority = false,
    this.unread = false,
  });

  final String messageId;
  final String mapId;
  final String subject;
  final DateTime? date;

  /// `priority == "H"` (OBDX shows a high-priority icon).
  final bool highPriority;
  final bool unread;

  MailboxNotification markedRead() => MailboxNotification(
        messageId: messageId,
        mapId: mapId,
        subject: subject,
        date: date,
        highPriority: highPriority,
      );

  static List<MailboxNotification> listFromPayload(Map<String, dynamic> body, {required String userName}) => [
        for (final raw in _list(body['mailerUserMapDTOs']))
          if (_str(raw['mapId']) != null)
            MailboxNotification(
              messageId: _str(ObdxApiUtils.asMap(raw['messageId'])['value']) ?? _str(raw['messageId']) ?? '',
              mapId: _str(raw['mapId'])!,
              subject: _str(raw['subject']) ?? '',
              date: _date(raw['creationDate']),
              highPriority: _str(raw['priority']) == 'H',
              unread: _sameUser(raw['userId'], userName) && _str(raw['status']) == 'U',
            ),
      ];

  /// `PUT mailbox/mailers/{mapId}`: read `{messageId, status: R, mapId}`,
  /// delete `{status: D, mapId}` (mailbox.md §8).
  Map<String, dynamic> readBody() => {'messageId': messageId, 'status': 'R', 'mapId': mapId};
  Map<String, dynamic> deleteBody() => {'status': 'D', 'mapId': mapId};
}

/// `GET mailbox/mailers/{messageId}` → `mailerUserMapDTO`.
class NotificationDetail {
  const NotificationDetail({this.body = '', this.date});

  final String body;

  /// `receivedDate`.
  final DateTime? date;

  factory NotificationDetail.fromPayload(Map<String, dynamic> body) {
    final dto = ObdxApiUtils.asMap(body['mailerUserMapDTO']);
    return NotificationDetail(body: _str(dto['messageBody']) ?? '', date: _date(dto['receivedDate']));
  }
}

/// `GET mailbox/count`: `summary.items[0|1|2].unReadCount`, read by
/// position like OBDX (mb/mini-mailbox/hooks.js:273-275).
class MailboxCounts {
  const MailboxCounts({this.mails = 0, this.alerts = 0, this.notifications = 0});

  final int mails;
  final int alerts;
  final int notifications;

  /// The header bell's badge.
  int get total => mails + alerts + notifications;

  factory MailboxCounts.fromPayload(Map<String, dynamic> body) {
    final items = _list(ObdxApiUtils.asMap(body['summary'])['items']);
    int at(int i) => i < items.length ? (_num(items[i]['unReadCount']) ?? 0) : 0;
    return MailboxCounts(mails: at(0), alerts: at(1), notifications: at(2));
  }
}

/// Result of a mailbox write (delete, restore, send, reply, upload): done,
/// possibly pending approval, or an OTP to enter first (417).
class MailboxWriteOutcome {
  const MailboxWriteOutcome.done({this.pendingApproval = false, this.contentId})
      : challenge = null,
        invalidOtp = false;

  const MailboxWriteOutcome.otpRequired(ObdxChallenge this.challenge, {this.invalidOtp = false})
      : pendingApproval = false,
        contentId = null;

  final ObdxChallenge? challenge;
  final bool invalidOtp;
  final bool pendingApproval;

  /// An upload's `contentDTOList[0].contentId` (`{value, displayValue}`),
  /// sent back as is in `contentDTO`.
  final Map<String, dynamic>? contentId;
}

/// A Compose category subject (`mailCategoryDTOs[].subjects[]`).
class MailSubject {
  const MailSubject({required this.id, required this.label, required this.category});

  /// `subjectId`, sent as the mail's `subjectId`.
  final String id;

  /// `subject`, sent as the mail's subject (unless OTHERS).
  final String label;

  /// The group name (`mailCategoryDTOs[].name`).
  final String category;

  /// OBDX shows "Other Remark" and sends it as the subject instead
  /// (compose-mail/hooks.js:115, 223).
  bool get isOthers => label.toUpperCase() == 'OTHERS';

  static List<MailSubject> listFromPayload(Map<String, dynamic> body) => [
        for (final c in _list(body['mailCategoryDTOs']))
          for (final s in _list(c['subjects']))
            if (_str(s['subjectId']) != null)
              MailSubject(id: _str(s['subjectId'])!, label: _str(s['subject']) ?? '', category: _str(c['name']) ?? ''),
      ];
}

/// A party the mail can be sent for: the user's own, then related parties
/// (`me/party`, `me/party/relations`; compose-mail/hooks.js:127-155).
class MailParty {
  const MailParty({required this.id, required this.name});

  final String id;
  final String name;

  /// Own party first.
  static List<MailParty> fromPayloads(Map<String, dynamic> me, Map<String, dynamic> relations) {
    final party = ObdxApiUtils.asMap(me['party']);
    final ownId = _str(ObdxApiUtils.asMap(party['id'])['value']);
    return [
      if (ownId != null)
        MailParty(id: ownId, name: _str(ObdxApiUtils.asMap(party['personalDetails'])['fullName']) ?? ownId),
      for (final r in _list(relations['partyToPartyRelationship']))
        if (_str(ObdxApiUtils.asMap(r['relatedParty'])['value']) != null)
          MailParty(
            id: _str(ObdxApiUtils.asMap(r['relatedParty'])['value'])!,
            name: _str(r['relatedPartyName']) ?? _str(ObdxApiUtils.asMap(r['relatedParty'])['value'])!,
          ),
    ];
  }
}

/// What Compose needs before it can show its form.
class ComposeSetup {
  const ComposeSetup({required this.subjects, required this.parties});

  final List<MailSubject> subjects;
  final List<MailParty> parties;

  /// OBDX shows the Party field only when there are related parties.
  bool get showParty => parties.length > 1;
}

/// `POST mailbox/mails` body (compose-mail/hooks.js:220-240). [party] is
/// the chosen party id. OBDX sends `partyOptionValue()[0]`, which on a
/// single-select value is only the first character; the app sends the
/// whole id. [APP]
Map<String, dynamic> composeMailBody({
  required MailSubject subject,
  required String otherRemark,
  required String text,
  required List<Map<String, dynamic>> contents,
  required String? party,
}) =>
    {
      'interactionId': null,
      'messageId': null,
      'messageType': 'M',
      'subject': subject.isOthers ? otherRemark : subject.label,
      'messageBody': text,
      'creationDate': null,
      'expiryDate': null,
      'messageUserMappings': null,
      'subjectId': subject.id,
      'linkedParent': null,
      'contentDTO': [
        for (final c in contents) {'contentId': c},
      ],
      if (party != null) 'party': {'value': party},
    };

/// OBDX attachment rules (compose-mail/hooks.js:288-355,
/// message-detail/hooks.js:311-382).
class MailUploadRules {
  const MailUploadRules._();

  /// Message limit (textarea `maxlength`, "{number} Characters Left").
  static const maxMessageLength = 1000;

  /// 5 MB.
  static const maxFileBytes = 5242880;

  /// The extension must be all lower or all upper case (".Pdf" is refused).
  static const pickerExtensions = ['pdf', 'jpeg', 'png', 'txt', 'doc', 'docx', 'zip', 'xlsx'];

  static bool allowedName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return false;
    final ext = name.substring(dot + 1);
    return pickerExtensions.contains(ext) || pickerExtensions.map((e) => e.toUpperCase()).contains(ext);
  }

  /// OBDX checks the whole batch before uploading any of it, and the first
  /// problem refuses every file: a name already attached, then size, then
  /// type.
  static MailUploadProblem? check(List<(String, int)> picked, Iterable<String> attachedNames) {
    final attached = attachedNames.toSet();
    if (picked.any((f) => attached.contains(f.$1))) return MailUploadProblem.duplicate;
    if (picked.any((f) => f.$2 > maxFileBytes)) return MailUploadProblem.tooLarge;
    if (picked.any((f) => !allowedName(f.$1))) return MailUploadProblem.badType;
    return null;
  }
}

enum MailUploadProblem { duplicate, tooLarge, badType }

/// Alerts and notifications carry HTML (OBDX binds it as HTML); the app has
/// no HTML renderer, so it shows the text with line breaks kept. [APP]
String mailboxHtmlToText(String html) {
  var s = html
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</\s*(p|div|li|tr|h[1-6])\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '');
  const entities = {'&nbsp;': ' ', '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'"};
  entities.forEach((k, v) => s = s.replaceAll(k, v));
  return s.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

/// OBDX: `userId === AppData.userData.userProfile.userName`.
bool _sameUser(dynamic userId, String userName) => userName.isNotEmpty && _str(userId) == userName;

List<Map<String, dynamic>> _list(dynamic value) =>
    value is List ? [for (final e in value) if (e is Map) Map<String, dynamic>.from(e)] : const [];

String? _str(dynamic value) {
  if (value == null || value is Map || value is List) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _num(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

DateTime? _date(dynamic value) {
  final text = _str(value);
  if (text == null) return null;
  final dmy = RegExp(r'^(\d{2})-(\d{2})-(\d{4})').firstMatch(text);
  if (dmy != null) return DateTime(int.parse(dmy.group(3)!), int.parse(dmy.group(2)!), int.parse(dmy.group(1)!));
  return DateTime.tryParse(text);
}
