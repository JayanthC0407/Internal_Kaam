import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/config/locale_config.dart';
import 'package:ubci_bank/src/core/models/common/mailbox/mailbox_models.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/theme/app_theme.dart';
import 'package:ubci_bank/src/infra/network/apis/common/obdx_mailbox_api.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/repositories/common/mailbox_repository.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/mailbox/mailbox_screen.dart';

// Field names follow OBDX components/mailbox (docs/obdx/features/mailbox.md);
// ids, names and texts are made up.

const _me = 'jdoe';

Map<String, dynamic> _mail(String id, String subject, {String myStatus = 'U', Map<String, dynamic>? parent, bool attachment = false}) => {
      'messageId': {'value': id, 'displayValue': 'D$id'},
      'subject': subject,
      'interactionId': 'REF$id',
      'creationDate': '2026-10-20T09:30:00',
      'messageBody': 'Body of $subject',
      'messageUserMappings': [
        {'userId': _me, 'msgFlag': 'T', 'status': myStatus},
        {'userId': 'bank', 'msgFlag': 'F', 'status': 'R', 'username': 'bankuser', 'userGroupName': 'Customer Care'},
      ],
      if (attachment)
        'contentDTO': [
          {
            'contentId': {'value': 'C1', 'displayValue': 'statement.pdf'},
          },
        ],
      if (parent != null) 'linkedParent': parent,
    };

final _alerts = {
  'alertDTOs': [
    {
      'messageId': {'value': 'A1', 'displayValue': 'A1'},
      'subject': 'Login from a new device',
      'creationDate': '2026-10-21T08:00:00',
      'messageBody': '<p>Hello,<br>you signed in.</p>',
      'messageUserMappings': [
        {'userId': _me, 'status': 'U'},
      ],
    },
  ],
};

final _notifications = {
  'mailerUserMapDTOs': [
    {
      'messageId': {'value': 'M9'},
      'mapId': 'MAP9',
      'subject': 'Holiday notice',
      'creationDate': '2026-10-22T10:00:00',
      'priority': 'H',
      'userId': _me,
      'status': 'U',
    },
  ],
};

Map<String, dynamic> _wrap(Map<String, dynamic> body, {int status = 200, Map<String, dynamic> headers = const {}}) =>
    {'statusCode': status, 'headers': headers, 'rawBody': '', 'body': body};

void main() {
  group('model', () {
    test('folders send OBDX queries; Inbox asks for every mail (user choice b)', () {
      expect(MailFolder.inbox.query, {'msgFlag': 'T', 'deleteStatus': 'false'});
      expect(MailFolder.sent.query, {'msgFlag': 'F', 'deleteStatus': 'false'});
      expect(MailFolder.deleted.query, {'deleteStatus': 'true'});
    });

    test('mail: unread by my mapping, sender from the msgFlag F mapping, thread from linkedParent', () {
      final mails = Mail.listFromPayload({
        'mails': [
          _mail('1', 'Re : Card query', parent: _mail('0', 'Card query', myStatus: 'R'), attachment: true),
          _mail('2', 'Hello', myStatus: 'R'),
        ],
      }, userName: _me, folder: MailFolder.inbox);
      expect(mails.first.unread, isTrue);
      expect(mails.first.myStatus, 'U');
      expect(mails.first.senderName, 'Customer Care');
      expect(mails.first.attachments.single.name, 'statement.pdf');
      expect(mails.first.thread.single.subject, 'Card query');
      expect(mails.last.unread, isFalse);
    });

    test('mail: no sender in Sent Mails (OBDX sets it for Inbox / Deleted only)', () {
      final sent = Mail.listFromPayload({'mails': [_mail('3', 'Mine')]}, userName: _me, folder: MailFolder.sent);
      expect(sent.single.senderName, isNull);
    });

    test('a mapping for another user name does not count as mine', () {
      final mails = Mail.listFromPayload({'mails': [_mail('1', 'x')]}, userName: 'JDOE', folder: MailFolder.inbox);
      expect(mails.single.unread, isFalse, reason: 'OBDX compares with ===');
    });

    test('bodies: mail update, alert, notification read and delete', () {
      final mail = Mail.listFromPayload({'mails': [_mail('1', 'x')]}, userName: _me, folder: MailFolder.inbox).single;
      expect(mail.updateBody(status: 'R', deleteStatus: false), {
        'messageId': {'displayValue': 'D1', 'value': '1'},
        'messageUserMappings': [
          {'status': 'R', 'deleteStatus': false},
        ],
      });
      final alert = MailboxAlert.listFromPayload(_alerts, userName: _me).single;
      expect(alert.unread, isTrue);
      expect(alert.updateBody('PD')['messageUserMappings'], [
        {'status': 'PD'},
      ]);
      final n = MailboxNotification.listFromPayload(_notifications, userName: _me).single;
      expect(n.highPriority, isTrue);
      expect(n.readBody(), {'messageId': 'M9', 'status': 'R', 'mapId': 'MAP9'});
      expect(n.deleteBody(), {'status': 'D', 'mapId': 'MAP9'});
    });

    test('counts by position: mails, alerts, notifications', () {
      final c = MailboxCounts.fromPayload({
        'summary': {
          'items': [
            {'unReadCount': 2},
            {'unReadCount': 1},
            {'unReadCount': 4},
          ],
        },
      });
      expect([c.mails, c.alerts, c.notifications, c.total], [2, 1, 4, 7]);
    });

    test('HTML alert bodies become text with line breaks', () {
      expect(mailboxHtmlToText('<p>Hello,<br>you signed in.</p>&nbsp;&amp; ok'), 'Hello,\nyou signed in.\n & ok');
    });
  });

  group('repository writes', () {
    Mail inboxMail(String status) =>
        Mail.listFromPayload({'mails': [_mail('1', 'x', myStatus: status)]}, userName: _me, folder: MailFolder.inbox).single;

    test('delete keeps my status (Inbox); permanent delete sends PD; restore clears deleteStatus', () async {
      final api = _FakeApi();
      final repo = MailboxRepository(api: api);
      await repo.deleteMail(inboxMail('R'), MailFolder.inbox);
      await repo.deleteMail(inboxMail('R'), MailFolder.deleted);
      await repo.restoreMail(inboxMail('U'));
      expect([for (final b in api.mailBodies) b['messageUserMappings']], [
        [
          {'status': 'R', 'deleteStatus': true},
        ],
        [
          {'status': 'PD', 'deleteStatus': true},
        ],
        [
          {'status': 'U', 'deleteStatus': false},
        ],
      ]);
    });

    test('417 asks for the OTP; the OTP goes back in the challenge header', () async {
      final api = _FakeApi()..answer = 417;
      final repo = MailboxRepository(api: api);
      final first = await repo.deleteMail(inboxMail('R'), MailFolder.inbox);
      final challenge = (first as Success<MailboxWriteOutcome>).data!.challenge;
      expect(challenge, isNotNull);
      api.answer = 200;
      final second = await repo.deleteMail(inboxMail('R'), MailFolder.inbox, challenge: challenge, otp: '1234');
      expect((second as Success<MailboxWriteOutcome>).data!.challenge, isNull);
      expect(api.headers.last, isNotNull);
    });

    test('202 means pending approval', () async {
      final api = _FakeApi()..answer = 202;
      final r = await MailboxRepository(api: api).deleteAlert(MailboxAlert.listFromPayload(_alerts, userName: _me).single);
      expect((r as Success<MailboxWriteOutcome>).data!.pendingApproval, isTrue);
    });
  });

  group('Phase 2 model (compose-mail / message-detail hooks.js)', () {
    test('categories flatten to subjects with their group; OTHERS is spotted', () {
      final subjects = MailSubject.listFromPayload({
        'mailCategoryDTOs': [
          {
            'name': 'Cards',
            'subjects': [
              {'subjectId': 'S1', 'subject': 'Card not received'},
              {'subjectId': 'S9', 'subject': 'Others'},
            ],
          },
        ],
      });
      expect(subjects.map((s) => s.id), ['S1', 'S9']);
      expect(subjects.first.category, 'Cards');
      expect(subjects.last.isOthers, isTrue);
    });

    test('parties: own first, then related; the Party field only with relations', () {
      final parties = MailParty.fromPayloads(
        {
          'party': {
            'id': {'value': 'P001'},
            'personalDetails': {'fullName': 'Jane Doe'},
          },
        },
        {
          'partyToPartyRelationship': [
            {
              'relatedParty': {'value': 'P777'},
              'relatedPartyName': 'Doe Traders',
            },
          ],
        },
      );
      expect([for (final p in parties) p.id], ['P001', 'P777']);
      expect(ComposeSetup(subjects: const [], parties: parties).showParty, isTrue);
      expect(ComposeSetup(subjects: const [], parties: parties.take(1).toList()).showParty, isFalse);
    });

    test('compose body: OTHERS sends the remark as subject; the whole party id goes out', () {
      const others = MailSubject(id: 'S9', label: 'OTHERS', category: 'General');
      final body = composeMailBody(
        subject: others,
        otherRemark: 'Address change',
        text: 'Please update.',
        contents: const [
          {'value': 'C1', 'displayValue': 'a.pdf'},
        ],
        party: 'P777',
      );
      expect(body['subject'], 'Address change');
      expect(body['subjectId'], 'S9');
      expect(body['messageType'], 'M');
      expect(body['party'], {'value': 'P777'}, reason: 'OBDX [0] would send only "P"');
      expect(body['contentDTO'], [
        {
          'contentId': {'value': 'C1', 'displayValue': 'a.pdf'},
        },
      ]);
    });

    test('reply body: "Re :" added once, linkedParent and subjectId from the mail', () {
      final mail = Mail.listFromPayload({
        'mails': [
          {..._mail('7', 'Card query'), 'subjectId': 'S1'},
        ],
      }, userName: _me, folder: MailFolder.inbox).single;
      final body = mail.replyBody('Thanks', const []);
      expect(body['subject'], 'Re :Card query');
      expect(body['messageId'], '7');
      expect(body['subjectId'], 'S1');
      expect((body['linkedParent'] as Map)['messageBody'], 'Body of Card query');
      final again = Mail.listFromPayload({'mails': [_mail('8', 'Re :Card query')]}, userName: _me, folder: MailFolder.inbox);
      expect(again.single.replyBody('x', const [])['subject'], 'Re :Card query');
    });

    test('upload rules: duplicate, then size, then type; mixed-case extension refused', () {
      expect(MailUploadRules.check([('a.pdf', 10)], ['a.pdf']), MailUploadProblem.duplicate);
      expect(MailUploadRules.check([('b.pdf', MailUploadRules.maxFileBytes + 1)], const []), MailUploadProblem.tooLarge);
      expect(MailUploadRules.check([('c.exe', 10)], const []), MailUploadProblem.badType);
      expect(MailUploadRules.allowedName('scan.PDF'), isTrue);
      expect(MailUploadRules.allowedName('scan.Pdf'), isFalse);
      expect(MailUploadRules.allowedName('photo.jpg'), isFalse, reason: 'OBDX lists .jpeg only');
      expect(MailUploadRules.check([('ok.docx', 10)], const []), isNull);
    });
  });

  group('Phase 2 repository', () {
    test('send: 417 asks for the OTP, then 202 is pending approval', () async {
      final api = _FakeApi()..answer = 417;
      final repo = MailboxRepository(api: api);
      final first = await repo.sendMail(const {'messageType': 'M'});
      final challenge = (first as Success<MailboxWriteOutcome>).data!.challenge;
      expect(challenge, isNotNull);
      api.answer = 202;
      final second = await repo.sendMail(const {'messageType': 'M'}, challenge: challenge, otp: '1234');
      expect((second as Success<MailboxWriteOutcome>).data!.pendingApproval, isTrue);
      expect(api.sent.length, 2);
    });

    test('upload: SUCCESSFUL gives the contentId; anything else fails', () async {
      final api = _FakeApi();
      final repo = MailboxRepository(api: api);
      final ok = await repo.uploadAttachment('a.pdf', const [1, 2, 3], composeIndex: 0);
      expect((ok as Success<MailboxWriteOutcome>).data!.contentId, {'value': 'C42', 'displayValue': 'a.pdf'});
      expect(api.uploads.single, ('a.pdf', 'application/pdf', 0));
      api.uploadResult = 'FAILURE';
      expect(await repo.uploadAttachment('b.pdf', const [1]), isA<ExceptionError<MailboxWriteOutcome>>());
    });
  });

  Future<_FakeRepo> pump(WidgetTester tester, {double width = 390, List<Map<String, dynamic>>? mails}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = Size(width, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo(mails ?? [_mail('1', 'Card query', attachment: true), _mail('2', 'Hello', myStatus: 'R')]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mailboxRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: LocaleConfig.supportedLocales,
          home: const MailboxScreen(userName: _me),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('phone: tabs with unread counts; opening a mail shows From and marks it read', (tester) async {
    final repo = await pump(tester);
    expect(find.text('Mails (1)'), findsOneWidget);
    expect(find.text('Alerts (1)'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget, reason: 'no count when 0');
    expect(find.text('Inbox'), findsOneWidget);

    await tester.tap(find.text('Card query'));
    await tester.pumpAndSettle();
    expect(find.textContaining('From : Customer Care', findRichText: true), findsOneWidget);
    expect(find.text('Body of Card query'), findsOneWidget);
    expect(find.text('statement.pdf'), findsOneWidget);
    expect(repo.markedRead, ['1']);
    expect(find.text('Hello'), findsNothing, reason: 'the open mail fills a phone screen');
    expect(tester.takeException(), isNull);
  });

  testWidgets('select two mails → OBDX confirmation → both deleted', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Inbox Mails'), findsOneWidget);
    expect(find.text('You have selected 2 mails. Are you sure you want to delete them?'), findsOneWidget);
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(repo.deleted, ['1', '2']);
    expect(find.text('Done.'), findsOneWidget);
  });

  testWidgets('Deleted Mails: Restore appears for selected mails; empty text per folder', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Deleted Mails'));
    await tester.pumpAndSettle();
    expect(repo.folders.last, MailFolder.deleted);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('Restore'), findsOneWidget);

    await tester.tap(find.text('Sent Mails'));
    await tester.pumpAndSettle();
    expect(find.text('No item in Sent Mail'), findsOneWidget);
  });

  testWidgets('Alerts: open shows the text of the HTML body; Notifications: detail loaded', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Alerts (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Login from a new device'));
    await tester.pumpAndSettle();
    expect(find.text('Hello,\nyou signed in.'), findsOneWidget);
    expect(repo.markedRead, ['A1']);

    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('High priority'), findsOneWidget);
    await tester.tap(find.text('Holiday notice'));
    await tester.pumpAndSettle();
    expect(find.text('Office closed on Friday.'), findsOneWidget);
    expect(repo.markedRead, ['A1', 'MAP9']);
  });

  testWidgets('pagination: 10 a page, Next shows the rest, a folder switch starts again at page 1', (tester) async {
    await pump(tester, mails: [for (var i = 1; i <= 23; i++) _mail('$i', 'Mail $i', myStatus: 'R')]);
    expect(find.text('Mail 1'), findsOneWidget);
    expect(find.text('Mail 11'), findsNothing);
    expect(find.text('Showing 1–10 of 23'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Mail 11'), findsOneWidget);
    expect(find.text('Mail 1'), findsNothing);
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.text('Deleted Mails'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('Compose: OBDX required checks, OTHERS shows Other Remark, send goes to Sent Mails', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Compose Mail'));
    await tester.pumpAndSettle();
    expect(find.text('Party'), findsNothing, reason: 'no related parties');

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Please select a subject category'), findsOneWidget);
    expect(find.text('Cannot send an empty mail'), findsOneWidget);
    expect(repo.sentBodies, isEmpty);

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Others').last);
    await tester.pumpAndSettle();
    expect(find.text('Other Remark'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Address change');
    await tester.enterText(find.byType(TextField).at(1), 'Please update my address.');
    await tester.pumpAndSettle();
    expect(find.text('975 Characters Left'), findsOneWidget);

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    final body = repo.sentBodies.single;
    expect(body['subject'], 'Address change');
    expect(body['subjectId'], 'S9');
    expect(body['party'], {'value': 'P001'}, reason: 'own party when the field is hidden');
    expect(find.text('Your message has been sent successfully.'), findsOneWidget);
    expect(repo.folders.last, MailFolder.sent);
  });

  testWidgets('Reply: under the open mail, sends replyMail; none in Deleted Mails', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.text('Hello'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reply').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Thank you');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(repo.replies, [('2', 'Thank you')]);
    expect(find.text('Your message has been sent successfully.'), findsOneWidget);

    await tester.tap(find.text('Deleted Mails'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hello'));
    await tester.pumpAndSettle();
    expect(find.text('Reply'), findsNothing);
  });

  testWidgets('web: list beside the open item', (tester) async {
    await pump(tester, width: 1280);
    expect(find.text('Select an item to read it.'), findsOneWidget);
    await tester.tap(find.text('Hello'));
    await tester.pumpAndSettle();
    expect(find.text('Card query'), findsOneWidget, reason: 'the list stays');
    expect(find.text('Body of Hello'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRepo implements MailboxRepository {
  _FakeRepo(this.inbox);

  final List<Map<String, dynamic>> inbox;
  final markedRead = <String>[];
  final deleted = <String>[];
  final folders = <MailFolder>[];

  @override
  Future<ResponseHandler<MailboxCounts>> fetchCounts() async =>
      ResponseHandler.success(const MailboxCounts(mails: 1, alerts: 1), code: 200);

  @override
  Future<ResponseHandler<List<Mail>>> fetchMails(MailFolder folder, String userName) async {
    folders.add(folder);
    final raw = folder == MailFolder.sent ? const <Map<String, dynamic>>[] : inbox;
    return ResponseHandler.success(Mail.listFromPayload({'mails': raw}, userName: userName, folder: folder), code: 200);
  }

  @override
  Future<ResponseHandler<List<MailboxAlert>>> fetchAlerts(String userName) async =>
      ResponseHandler.success(MailboxAlert.listFromPayload(_alerts, userName: userName), code: 200);

  @override
  Future<ResponseHandler<List<MailboxNotification>>> fetchNotifications(String userName) async =>
      ResponseHandler.success(MailboxNotification.listFromPayload(_notifications, userName: userName), code: 200);

  @override
  Future<ResponseHandler<NotificationDetail>> fetchNotificationDetail(String messageId) async => ResponseHandler.success(
        NotificationDetail.fromPayload({
          'mailerUserMapDTO': {'messageBody': '<b>Office closed on Friday.</b>', 'receivedDate': '2026-10-22T10:00:00'},
        }),
        code: 200,
      );

  @override
  Future<List<MailAttachment>> fetchAttachmentTitles(List<MailAttachment> attachments) async => attachments;

  @override
  Future<bool> markMailRead(Mail mail, MailFolder folder) async {
    markedRead.add(mail.id);
    return true;
  }

  @override
  Future<bool> markAlertRead(MailboxAlert alert) async {
    markedRead.add(alert.id);
    return true;
  }

  @override
  Future<bool> markNotificationRead(MailboxNotification n) async {
    markedRead.add(n.mapId);
    return true;
  }

  @override
  Future<ResponseHandler<MailboxWriteOutcome>> deleteMail(Mail mail, MailFolder folder, {ObdxChallenge? challenge, String? otp}) async {
    deleted.add(mail.id);
    return ResponseHandler.success(const MailboxWriteOutcome.done(), code: 200);
  }

  final sentBodies = <Map<String, dynamic>>[];
  final replies = <(String, String)>[];

  @override
  Future<ResponseHandler<ComposeSetup>> fetchComposeSetup() async => ResponseHandler.success(
        const ComposeSetup(
          subjects: [
            MailSubject(id: 'S1', label: 'Card not received', category: 'Cards'),
            MailSubject(id: 'S9', label: 'Others', category: 'General'),
          ],
          parties: [MailParty(id: 'P001', name: 'Jane Doe')],
        ),
        code: 200,
      );

  @override
  Future<ResponseHandler<MailboxWriteOutcome>> sendMail(Map<String, dynamic> body, {ObdxChallenge? challenge, String? otp}) async {
    sentBodies.add(body);
    return ResponseHandler.success(const MailboxWriteOutcome.done(), code: 200);
  }

  @override
  Future<ResponseHandler<MailboxWriteOutcome>> replyMail(Mail mail, String text, List<Map<String, dynamic>> contents,
      {ObdxChallenge? challenge, String? otp}) async {
    replies.add((mail.id, text));
    return ResponseHandler.success(const MailboxWriteOutcome.done(), code: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeApi implements ObdxMailboxApi {
  int answer = 200;
  final mailBodies = <Map<String, dynamic>>[];
  final headers = <String?>[];

  Future<ResponseHandler<Map<String, dynamic>>> _answer() async => ResponseHandler.success(_wrap(
        const {},
        status: answer,
        headers: answer == 417
            ? {
                'X-CHALLENGE': ['{"referenceNo":"CH1","authType":"OTP","attemptsLeft":3}'],
              }
            : const {},
      ));

  @override
  Future<ResponseHandler<Map<String, dynamic>>> updateMail(String id, Map<String, dynamic> body, {String? challengeResponseHeader}) {
    mailBodies.add(body);
    headers.add(challengeResponseHeader);
    return _answer();
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> updateAlert(String id, Map<String, dynamic> body, {String? challengeResponseHeader}) =>
      _answer();

  final sent = <Map<String, dynamic>>[];
  final uploads = <(String, String, int?)>[];
  String uploadResult = 'SUCCESSFUL';

  @override
  Future<ResponseHandler<Map<String, dynamic>>> sendMail(Map<String, dynamic> body, {String? challengeResponseHeader}) {
    sent.add(body);
    return _answer();
  }

  @override
  Future<ResponseHandler<Map<String, dynamic>>> uploadContent({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    int? composeIndex,
    String? challengeResponseHeader,
  }) async {
    uploads.add((fileName, mimeType, composeIndex));
    return ResponseHandler.success(_wrap({
      'status': {'result': uploadResult},
      'contentDTOList': [
        {
          'contentId': {'value': 'C42', 'displayValue': fileName},
        },
      ],
    }));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
