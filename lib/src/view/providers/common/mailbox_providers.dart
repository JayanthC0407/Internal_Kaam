import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/src/core/models/common/mailbox/mailbox_models.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/view/providers/common/repository_providers.dart';

/// Mailbox (docs/obdx/features/mailbox.md). autoDispose: loaded while the
/// bell or the Mailbox is on screen, dropped afterwards and on logout.
/// Lists are keyed by the signed-in user name OBDX matches mappings with.

/// Unread counts (`mailbox/count`); the bell shows [MailboxCounts.total].
final mailboxCountsProvider = FutureProvider.autoDispose<MailboxCounts>((ref) async {
  final result = await ref.read(mailboxRepositoryProvider).fetchCounts();
  if (result is Success<MailboxCounts> && result.data != null) return result.data!;
  throw MailboxLoadError(result is Error<MailboxCounts> ? result.error : null);
});

final mailsProvider = FutureProvider.autoDispose.family<List<Mail>, (MailFolder, String)>((ref, args) async {
  final result = await ref.read(mailboxRepositoryProvider).fetchMails(args.$1, args.$2);
  if (result is Success<List<Mail>> && result.data != null) return result.data!;
  throw MailboxLoadError(result is Error<List<Mail>> ? result.error : null);
});

final mailboxAlertsProvider = FutureProvider.autoDispose.family<List<MailboxAlert>, String>((ref, userName) async {
  final result = await ref.read(mailboxRepositoryProvider).fetchAlerts(userName);
  if (result is Success<List<MailboxAlert>> && result.data != null) return result.data!;
  throw MailboxLoadError(result is Error<List<MailboxAlert>> ? result.error : null);
});

final mailboxNotificationsProvider =
    FutureProvider.autoDispose.family<List<MailboxNotification>, String>((ref, userName) async {
  final result = await ref.read(mailboxRepositoryProvider).fetchNotifications(userName);
  if (result is Success<List<MailboxNotification>> && result.data != null) return result.data!;
  throw MailboxLoadError(result is Error<List<MailboxNotification>> ? result.error : null);
});

/// One notification's body and received date (`mailbox/mailers/{messageId}`).
final notificationDetailProvider = FutureProvider.autoDispose.family<NotificationDetail, String>((ref, messageId) async {
  final result = await ref.read(mailboxRepositoryProvider).fetchNotificationDetail(messageId);
  if (result is Success<NotificationDetail> && result.data != null) return result.data!;
  throw MailboxLoadError(result is Error<NotificationDetail> ? result.error : null);
});

/// Load failure; [message] is OBDX's text when the server sent one.
class MailboxLoadError implements Exception {
  const MailboxLoadError(this.message);

  final String? message;

  @override
  String toString() => message ?? 'MailboxLoadError';
}
