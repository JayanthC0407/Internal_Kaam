import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/common/mailbox/mailbox_models.dart';
import 'package:ubci_bank/src/core/models/common/obdx_challenge.dart';
import 'package:ubci_bank/src/core/utils/common/statement_file_saver.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/infra/network/statement_download.dart';
import 'package:ubci_bank/src/view/providers/common/mailbox_providers.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';
import 'package:ubci_bank/src/view/screens/common/mailbox/mail_compose.dart';
import 'package:ubci_bank/src/view/screens/common/payments/widgets/payment_flow_widgets.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';
import 'package:ubci_bank/src/view/widgets/paginated_list_controls.dart';

/// The three parts of OBDX's Mailbox menu.
enum MailboxTab { mails, alerts, notifications }

/// Mailbox (OBDX `components/mailbox`). Tabs Mails ({n}) / Alerts ({n}) /
/// Notifications ({n}) as OBDX's header view; Mails has Inbox / Sent Mails
/// / Deleted Mails, Compose Mail and Reply (mail_compose.dart). Opening an
/// item marks it read; every write (delete, restore, send, reply, upload)
/// handles 417 OTP and approval. Wide screens show the open item or Compose
/// beside the list (OBDX's right panel), a phone shows it full screen.
/// Evidence: docs/obdx/features/mailbox.md.
class MailboxScreen extends ConsumerStatefulWidget {
  const MailboxScreen({
    super.key,
    required this.userName,
    this.embedded = false,
    this.onBack,
    this.initialTab = MailboxTab.mails,
  });

  /// The signed-in user's `userProfile.userName`; OBDX finds "my" mapping
  /// (read / unread) by it.
  final String userName;
  final bool embedded;
  final VoidCallback? onBack;
  final MailboxTab initialTab;

  @override
  ConsumerState<MailboxScreen> createState() => _MailboxScreenState();
}

class _MailboxScreenState extends ConsumerState<MailboxScreen> {
  late MailboxTab _tab = widget.initialTab;
  MailFolder _folder = MailFolder.inbox;

  /// The open item: a [Mail], [MailboxAlert] or [MailboxNotification].
  Object? _open;

  /// Compose Mail is showing (in place of an open item).
  bool _composing = false;

  /// Ticked rows of the current list, by id.
  final _selected = <String>{};

  /// Read here already, before the list reloads.
  final _readIds = <String>{};

  /// 10 rows a page: the server sends the whole list, and OBDX's tables
  /// show it 10 rows at a time (mb/inbox/inbox.html:13).
  static const _pageSize = 10;
  final _pager = ListPager<Object>(pageSize: _pageSize);
  bool _busy = false;

  String get _user => widget.userName;

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

  void _switchTab(MailboxTab tab) => setState(() {
        _tab = tab;
        _open = null;
        _composing = false;
        _selected.clear();
        _pager.reset();
      });

  void _switchFolder(MailFolder folder) => setState(() {
        _folder = folder;
        _open = null;
        _composing = false;
        _selected.clear();
        _pager.reset();
      });

  void _refresh() {
    setState(() {
      _selected.clear();
      _pager.reset();
    });
    ref.invalidate(mailboxCountsProvider);
    switch (_tab) {
      case MailboxTab.mails:
        ref.invalidate(mailsProvider((_folder, _user)));
      case MailboxTab.alerts:
        ref.invalidate(mailboxAlertsProvider(_user));
      case MailboxTab.notifications:
        ref.invalidate(mailboxNotificationsProvider(_user));
    }
  }

  // ── Open → mark read (OBDX does it on open; a failure keeps it unread) ──

  Future<void> _openMail(Mail mail) async {
    setState(() {
      _open = mail;
      _composing = false;
    });
    if (!mail.unread || _readIds.contains(mail.id)) return;
    setState(() => _readIds.add(mail.id));
    if (await ref.read(mailboxRepositoryProvider).markMailRead(mail, _folder)) ref.invalidate(mailboxCountsProvider);
  }

  Future<void> _openAlert(MailboxAlert alert) async {
    setState(() => _open = alert);
    if (!alert.unread || _readIds.contains(alert.id)) return;
    setState(() => _readIds.add(alert.id));
    if (await ref.read(mailboxRepositoryProvider).markAlertRead(alert)) ref.invalidate(mailboxCountsProvider);
  }

  Future<void> _openNotification(MailboxNotification n) async {
    setState(() => _open = n);
    if (!n.unread || _readIds.contains(n.mapId)) return;
    setState(() => _readIds.add(n.mapId));
    if (await ref.read(mailboxRepositoryProvider).markNotificationRead(n)) ref.invalidate(mailboxCountsProvider);
  }

  // ── Delete / restore ──

  Future<bool> _confirm(String title, String message, {required bool mailButtons}) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(mailButtons ? l10n.mailboxNo : l10n.mailboxCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(mailButtons ? l10n.mailboxYes : l10n.mailboxConfirm),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /// Runs [call] for each item, one after another (OBDX sends them all at
  /// once; one at a time lets each 417 ask for its OTP). [APP]
  Future<void> _runWrites<T>(
    List<T> items,
    Future<ResponseHandler<MailboxWriteOutcome>> Function(T item, ObdxChallenge? challenge, String? otp) call,
  ) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    var done = 0, pending = 0, failed = 0;
    String? failure;
    for (final item in items) {
      final result = await runMailboxWrite(context, (c, otp) => call(item, c, otp));
      if (!mounted) return;
      if (result is Success<MailboxWriteOutcome> && result.data?.challenge == null) {
        result.data!.pendingApproval ? pending++ : done++;
      } else if (result is! Success<MailboxWriteOutcome>) {
        failed++;
        failure ??= result.resolveUserMessage(l10n: l10n, fallback: l10n.mailboxActionFailed);
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _selected.clear();
      if (done + pending > 0) _open = null;
    });
    if (failed > 0) {
      _snack(failure ?? l10n.mailboxActionFailed);
    } else if (pending > 0) {
      HapticFeedback.mediumImpact();
      _snack(l10n.mailboxPendingApproval);
    } else if (done > 0) {
      HapticFeedback.mediumImpact();
      _snack(l10n.mailboxDone);
    }
    if (done + pending > 0) _refresh();
  }

  Future<void> _deleteMails(List<Mail> mails) async {
    if (mails.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final forever = _folder == MailFolder.deleted;
    final title = switch (_folder) {
      MailFolder.inbox => l10n.mailboxDeleteInboxTitle,
      MailFolder.sent => l10n.mailboxDeleteSentTitle,
      MailFolder.deleted => l10n.mailboxDeleteDeletedTitle,
    };
    final message = mails.length == 1
        ? (forever ? l10n.mailboxDeleteMailForever : l10n.mailboxDeleteMail)
        : (forever ? l10n.mailboxDeleteMailsForever(mails.length) : l10n.mailboxDeleteMails(mails.length));
    if (!await _confirm(title, message, mailButtons: true) || !mounted) return;
    final repo = ref.read(mailboxRepositoryProvider);
    final folder = _folder;
    await _runWrites<Mail>(mails, (m, c, otp) => repo.deleteMail(m, folder, challenge: c, otp: otp));
  }

  /// Restore has no confirmation in OBDX (deleted-mails/hooks.js:182-231).
  Future<void> _restoreMails(List<Mail> mails) async {
    if (mails.isEmpty) return;
    final repo = ref.read(mailboxRepositoryProvider);
    await _runWrites<Mail>(mails, (m, c, otp) => repo.restoreMail(m, challenge: c, otp: otp));
  }

  Future<void> _deleteAlerts(List<MailboxAlert> alerts) async {
    if (alerts.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final message = alerts.length == 1 ? l10n.mailboxDeleteAlert : l10n.mailboxDeleteAlerts(alerts.length);
    if (!await _confirm(l10n.mailboxConfirmation, message, mailButtons: false) || !mounted) return;
    final repo = ref.read(mailboxRepositoryProvider);
    await _runWrites<MailboxAlert>(alerts, (a, c, otp) => repo.deleteAlert(a, challenge: c, otp: otp));
  }

  Future<void> _deleteNotifications(List<MailboxNotification> list) async {
    if (list.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final message = list.length == 1 ? l10n.mailboxDeleteNotification : l10n.mailboxDeleteNotifications(list.length);
    if (!await _confirm(l10n.mailboxConfirmation, message, mailButtons: false) || !mounted) return;
    final repo = ref.read(mailboxRepositoryProvider);
    await _runWrites<MailboxNotification>(list, (n, c, otp) => repo.deleteNotification(n, challenge: c, otp: otp));
  }

  // ── Compose / Reply ──

  void _compose() => setState(() {
        _open = null;
        _composing = true;
      });

  /// After Compose: OBDX shows Sent Mails (compose-mail/hooks.js:249).
  void _afterSend(bool pending) {
    final l10n = AppLocalizations.of(context);
    _snack(pending ? l10n.mailboxPendingApproval : l10n.mailboxSentSuccess);
    _switchFolder(MailFolder.sent);
    _refresh();
  }

  /// After Reply: OBDX closes the mail and reloads the list.
  void _afterReply(bool pending) {
    final l10n = AppLocalizations.of(context);
    _snack(pending ? l10n.mailboxPendingApproval : l10n.mailboxSentSuccess);
    setState(() => _open = null);
    _refresh();
  }

  Future<void> _download(MailAttachment attachment) async {
    final l10n = AppLocalizations.of(context);
    final result = await ref.read(mailboxRepositoryProvider).downloadAttachment(attachment);
    if (!mounted) return;
    final file = result is Success<StatementFile> ? result.data : null;
    if (file == null) return _snack(l10n.mailboxDownloadFailed);
    try {
      await StatementFileSaver.saveStatement(bytes: file.bytes, fileName: file.fileName, mimeType: file.mimeType);
    } catch (_) {
      if (mounted) _snack(l10n.mailboxDownloadFailed);
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final counts = ref.watch(mailboxCountsProvider).valueOrNull;
    String label(String plain, int n, String Function(int) withCount) => n > 0 ? withCount(n) : plain;

    return PayMenuPage(
      title: l10n.mailboxTitle,
      onBack: widget.embedded ? widget.onBack : null,
      builder: (context, wide) {
        final list = _buildList(context);
        final detail = _composing
            ? MailComposeView(onClose: () => setState(() => _composing = false), onSent: _afterSend)
            : _open == null
                ? null
                : _buildDetail(context, onBack: wide ? null : () => setState(() => _open = null));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PayChoiceChips<MailboxTab>(
              options: [
                (MailboxTab.mails, label(l10n.mailboxMails, counts?.mails ?? 0, l10n.mailboxMailsCount)),
                (MailboxTab.alerts, label(l10n.mailboxAlerts, counts?.alerts ?? 0, l10n.mailboxAlertsCount)),
                (
                  MailboxTab.notifications,
                  label(l10n.mailboxNotifications, counts?.notifications ?? 0, l10n.mailboxNotificationsCount)
                ),
              ],
              selected: _tab,
              onChanged: _switchTab,
            ),
            const SizedBox(height: 14),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: list),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 6,
                    child: detail ?? PayCard(child: PayMuted(l10n.mailboxSelectHint)),
                  ),
                ],
              )
            else
              detail ?? list,
          ],
        );
      },
    );
  }

  /// The current page of [items] and its Prev / Next controls.
  (List<T>, Widget) _page<T extends Object>(List<T> items) {
    final page = _pager.clamp(items.length);
    return (
      _pager.slice(items).cast<T>(),
      PaginatedListControls(
        currentPage: page,
        pageCount: _pager.pageCount(items.length),
        totalItems: items.length,
        pageSize: _pageSize,
        onPageChanged: (p) => setState(() => _pager.goTo(p)),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget loading() => const PayCard(
          child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        );
    Widget failed(Object e) => PayErrorRetry(
          message: e is MailboxLoadError && e.message != null ? e.message! : l10n.mailboxLoadFailed,
          onRetry: _refresh,
        );

    switch (_tab) {
      case MailboxTab.mails:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PaySegmented<MailFolder>(
              options: [
                (MailFolder.inbox, l10n.mailboxInbox),
                (MailFolder.sent, l10n.mailboxSentMails),
                (MailFolder.deleted, l10n.mailboxDeletedMails),
              ],
              selected: _folder,
              onChanged: _switchFolder,
            ),
            const SizedBox(height: 10),
            ref.watch(mailsProvider((_folder, _user))).when(
                  loading: loading,
                  error: (e, _) => failed(e),
                  data: (mails) {
                    final picked = mails.where((m) => _selected.contains(m.id)).toList();
                    final (visible, pager) = _page(mails);
                    return _ListCard(
                      pager: pager,
                      toolbar: _Toolbar(
                        busy: _busy,
                        onRefresh: _refresh,
                        onCompose: _compose,
                        onDelete: picked.isEmpty ? null : () => _deleteMails(picked),
                        onRestore: _folder == MailFolder.deleted && picked.isNotEmpty ? () => _restoreMails(picked) : null,
                      ),
                      empty: switch (_folder) {
                        MailFolder.inbox => l10n.mailboxNoInbox,
                        MailFolder.sent => l10n.mailboxNoSent,
                        MailFolder.deleted => l10n.mailboxNoDeleted,
                      },
                      rows: [
                        for (final m in visible)
                          _MessageRow(
                            title: m.subject,
                            subtitle: m.interactionId == null ? null : '${l10n.mailboxReferenceNo}: ${m.interactionId}',
                            date: m.date,
                            unread: m.unread && !_readIds.contains(m.id),
                            hasAttachment: m.attachments.isNotEmpty,
                            selected: _selected.contains(m.id),
                            open: _open is Mail && (_open as Mail).id == m.id,
                            onSelect: (v) => setState(() => v ? _selected.add(m.id) : _selected.remove(m.id)),
                            onTap: () => _openMail(m),
                          ),
                      ],
                    );
                  },
                ),
          ],
        );
      case MailboxTab.alerts:
        return ref.watch(mailboxAlertsProvider(_user)).when(
              loading: loading,
              error: (e, _) => failed(e),
              data: (alerts) {
                final picked = alerts.where((a) => _selected.contains(a.id)).toList();
                final (visible, pager) = _page(alerts);
                return _ListCard(
                  pager: pager,
                  toolbar: _Toolbar(
                    busy: _busy,
                    onRefresh: _refresh,
                    onDelete: picked.isEmpty ? null : () => _deleteAlerts(picked),
                  ),
                  empty: l10n.mailboxNoAlerts,
                  rows: [
                    for (final a in visible)
                      _MessageRow(
                        title: a.subject,
                        date: a.date,
                        unread: a.unread && !_readIds.contains(a.id),
                        selected: _selected.contains(a.id),
                        open: _open is MailboxAlert && (_open as MailboxAlert).id == a.id,
                        onSelect: (v) => setState(() => v ? _selected.add(a.id) : _selected.remove(a.id)),
                        onTap: () => _openAlert(a),
                      ),
                  ],
                );
              },
            );
      case MailboxTab.notifications:
        return ref.watch(mailboxNotificationsProvider(_user)).when(
              loading: loading,
              error: (e, _) => failed(e),
              data: (list) {
                final picked = list.where((n) => _selected.contains(n.mapId)).toList();
                final (visible, pager) = _page(list);
                return _ListCard(
                  pager: pager,
                  toolbar: _Toolbar(
                    busy: _busy,
                    onRefresh: _refresh,
                    onDelete: picked.isEmpty ? null : () => _deleteNotifications(picked),
                  ),
                  empty: l10n.mailboxNoNotifications,
                  rows: [
                    for (final n in visible)
                      _MessageRow(
                        title: n.subject,
                        date: n.date,
                        unread: n.unread && !_readIds.contains(n.mapId),
                        highPriority: n.highPriority,
                        selected: _selected.contains(n.mapId),
                        open: _open is MailboxNotification && (_open as MailboxNotification).mapId == n.mapId,
                        onSelect: (v) => setState(() => v ? _selected.add(n.mapId) : _selected.remove(n.mapId)),
                        onTap: () => _openNotification(n),
                      ),
                  ],
                );
              },
            );
    }
  }

  Widget _buildDetail(BuildContext context, {VoidCallback? onBack}) {
    final open = _open;
    return switch (open) {
      Mail m => _MailDetail(
          key: ValueKey('mail-${m.id}'),
          mail: m,
          folder: _folder,
          busy: _busy,
          onBack: onBack,
          onReplied: _afterReply,
          onDelete: () => _deleteMails([m]),
          onDownload: _download,
        ),
      MailboxAlert a => _DetailCard(
          title: a.subject,
          date: a.date,
          body: mailboxHtmlToText(a.body),
          busy: _busy,
          onBack: onBack,
          onDelete: () => _deleteAlerts([a]),
        ),
      MailboxNotification n => ref.watch(notificationDetailProvider(n.messageId)).when(
            loading: () => const PayCard(
              child: Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            ),
            error: (e, _) => PayErrorRetry(
              message: e is MailboxLoadError && e.message != null ? e.message! : AppLocalizations.of(context).mailboxLoadFailed,
              onRetry: () => ref.invalidate(notificationDetailProvider(n.messageId)),
            ),
            data: (d) => _DetailCard(
              title: n.subject,
              date: d.date ?? n.date,
              body: mailboxHtmlToText(d.body),
              busy: _busy,
              onBack: onBack,
              onDelete: () => _deleteNotifications([n]),
            ),
          ),
      _ => const SizedBox.shrink(),
    };
  }
}

String _dateTime(BuildContext context, DateTime? d) {
  if (d == null) return '';
  final loc = MaterialLocalizations.of(context);
  return '${loc.formatMediumDate(d)}, ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(d))}';
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.toolbar, required this.rows, required this.empty, required this.pager});

  final Widget toolbar;

  /// This page's rows.
  final List<Widget> rows;
  final String empty;

  /// Prev / Next; hidden when everything fits one page.
  final Widget pager;

  @override
  Widget build(BuildContext context) => PayCard(
        padding: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            toolbar,
            Divider(height: 1, color: HomeColors.divider(context)),
            if (rows.isEmpty) Padding(padding: const EdgeInsets.all(20), child: PayMuted(empty)) else ...rows,
            Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 12), child: pager),
          ],
        ),
      );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.busy, required this.onRefresh, this.onCompose, this.onDelete, this.onRestore});

  final bool busy;
  final VoidCallback onRefresh;

  /// Mails only: OBDX's "Compose Mail".
  final VoidCallback? onCompose;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(tooltip: l10n.mailboxRefresh, onPressed: busy ? null : onRefresh, icon: const Icon(Icons.refresh_rounded)),
          // Ticked rows switch the bar to their actions, so it fits a phone.
          if (onCompose != null && onDelete == null && onRestore == null)
            TextButton.icon(
              onPressed: busy ? null : onCompose,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(l10n.mailboxComposeMail),
            ),
          const Spacer(),
          if (busy) const Padding(padding: EdgeInsets.all(12), child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))),
          if (onRestore != null)
            TextButton.icon(
              onPressed: busy ? null : onRestore,
              icon: const Icon(Icons.restore_rounded, size: 18),
              label: Text(l10n.mailboxRestore),
            ),
          if (onDelete != null)
            TextButton.icon(
              onPressed: busy ? null : onDelete,
              icon: Icon(Icons.delete_outline_rounded, size: 18, color: HomeColors.error(context)),
              label: Text(l10n.mailboxDelete, style: TextStyle(color: HomeColors.error(context))),
            ),
        ],
      ),
    );
  }
}

/// A row: tick box, subject (bold when unread), optional reference, date;
/// icons for an attachment or a high-priority notification.
class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.title,
    required this.date,
    required this.unread,
    required this.selected,
    required this.open,
    required this.onSelect,
    required this.onTap,
    this.subtitle,
    this.hasAttachment = false,
    this.highPriority = false,
  });

  final String title;
  final String? subtitle;
  final DateTime? date;
  final bool unread;
  final bool selected;
  final bool open;
  final bool hasAttachment;
  final bool highPriority;
  final ValueChanged<bool> onSelect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final secondary = HomeColors.textSecondary(context);
    return Material(
      color: open ? HomeColors.brand(context).withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 8, 14, 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: HomeColors.divider(context)))),
          child: Row(
            children: [
              Checkbox(value: selected, onChanged: (v) => onSelect(v ?? false)),
              if (highPriority)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Tooltip(
                    message: l10n.mailboxHighPriority,
                    child: Icon(Icons.priority_high_rounded, size: 18, color: HomeColors.error(context)),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                        color: HomeColors.textPrimary(context),
                      ),
                    ),
                    if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 12, color: secondary)),
                    Text(_dateTime(context, date), style: TextStyle(fontSize: 12, color: secondary)),
                  ],
                ),
              ),
              if (hasAttachment) Icon(Icons.attach_file_rounded, size: 18, color: secondary),
              if (unread)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: HomeColors.brand(context), shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared frame of an open item: back (phone), title, Delete, date, body.
class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.title,
    required this.body,
    required this.busy,
    required this.onDelete,
    this.date,
    this.onBack,
    this.onReply,
    this.extra = const [],
    this.after = const [],
  });

  final String title;
  final DateTime? date;
  final String body;
  final bool busy;
  final VoidCallback onDelete;
  final VoidCallback? onBack;

  /// Mails outside Deleted Mails: OBDX's "Reply".
  final VoidCallback? onReply;

  /// Between the title and the body (a mail's From, Sent, Attachments).
  final List<Widget> extra;

  /// After the body (a mail's earlier messages).
  final List<Widget> after;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onBack != null)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: onBack == null ? 0 : 10),
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: HomeColors.textPrimary(context)),
                  ),
                ),
              ),
              if (onReply != null)
                TextButton.icon(
                  onPressed: busy ? null : onReply,
                  icon: const Icon(Icons.reply_rounded, size: 18),
                  label: Text(l10n.mailboxReply),
                ),
              TextButton.icon(
                onPressed: busy ? null : onDelete,
                icon: Icon(Icons.delete_outline_rounded, size: 18, color: HomeColors.error(context)),
                label: Text(l10n.mailboxDelete, style: TextStyle(color: HomeColors.error(context))),
              ),
            ],
          ),
          if (date != null) ...[
            const SizedBox(height: 4),
            Text(_dateTime(context, date), style: TextStyle(fontSize: 12.5, color: HomeColors.textSecondary(context))),
          ],
          ...extra,
          const SizedBox(height: 14),
          SelectableText(body, style: TextStyle(fontSize: 14, height: 1.45, color: HomeColors.textPrimary(context))),
          ...after,
        ],
      ),
    );
  }
}

/// An open mail: From, Sent, Attachments (titles loaded on open, tap to
/// download), the message and the earlier messages of the thread.
class _MailDetail extends ConsumerStatefulWidget {
  const _MailDetail({
    super.key,
    required this.mail,
    required this.folder,
    required this.busy,
    required this.onDelete,
    required this.onDownload,
    required this.onReplied,
    this.onBack,
  });

  final Mail mail;
  final MailFolder folder;
  final bool busy;
  final VoidCallback onDelete;
  final ValueChanged<MailAttachment> onDownload;

  /// After a reply was sent; true when it went for approval.
  final ValueChanged<bool> onReplied;
  final VoidCallback? onBack;

  @override
  ConsumerState<_MailDetail> createState() => _MailDetailState();
}

class _MailDetailState extends ConsumerState<_MailDetail> {
  late List<MailAttachment> _attachments = widget.mail.attachments;
  bool _replying = false;

  @override
  void initState() {
    super.initState();
    if (_attachments.isNotEmpty) {
      ref.read(mailboxRepositoryProvider).fetchAttachmentTitles(_attachments).then((titled) {
        if (mounted) setState(() => _attachments = titled);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mail = widget.mail;
    final secondary = HomeColors.textSecondary(context);
    final primary = HomeColors.textPrimary(context);

    Widget field(String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: '$label ', style: TextStyle(color: secondary)),
              TextSpan(text: value, style: TextStyle(color: primary, fontWeight: FontWeight.w600)),
            ]),
            style: const TextStyle(fontSize: 13),
          ),
        );

    return _DetailCard(
      title: mail.subject,
      body: mail.body,
      busy: widget.busy,
      onBack: widget.onBack,
      onDelete: widget.onDelete,
      // No Reply in Deleted Mails (message-detail.html:131).
      onReply: widget.folder == MailFolder.deleted || _replying ? null : () => setState(() => _replying = true),
      extra: [
        if (mail.senderName != null) field(l10n.mailboxFrom, mail.senderName!),
        field(l10n.mailboxSent, _dateTime(context, mail.date)),
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(l10n.mailboxAttachments, style: TextStyle(fontSize: 13, color: secondary)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in _attachments)
                ActionChip(
                  avatar: const Icon(Icons.download_rounded, size: 16),
                  label: Text(a.name),
                  onPressed: () => widget.onDownload(a),
                ),
            ],
          ),
        ],
      ],
      // The thread: each earlier message with its From and Sent
      // (message-detail/hooks.js:189-211).
      after: [
        if (_replying)
          MailReplyBox(
            mail: mail.copyWith(attachments: _attachments),
            fromSent: widget.folder == MailFolder.sent,
            onCancel: () => setState(() => _replying = false),
            onSent: widget.onReplied,
          ),
        for (final p in mail.thread) ...[
          Divider(height: 28, color: HomeColors.divider(context)),
          if (p.senderName != null) field(l10n.mailboxFrom, p.senderName!),
          field(l10n.mailboxSent, _dateTime(context, p.date)),
          const SizedBox(height: 8),
          SelectableText(p.body, style: TextStyle(fontSize: 13.5, height: 1.45, color: primary)),
        ],
      ],
    );
  }
}
