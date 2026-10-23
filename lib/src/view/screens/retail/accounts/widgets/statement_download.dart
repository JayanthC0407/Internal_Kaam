import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/models/retail/casa_transaction.dart';
import 'package:ubci_bank/src/core/models/common/statement_format.dart';
import 'package:ubci_bank/src/infra/network/statement_download.dart';
import 'package:ubci_bank/src/core/utils/common/statement_file_saver.dart';
import 'package:ubci_bank/src/infra/network/response_handler.dart';
import 'package:ubci_bank/src/infra/network/response_handler_extensions.dart';
import 'package:ubci_bank/src/infra/session/session_expiry_coordinator.dart';
import 'package:ubci_bank/src/view/providers/retail/accounts_providers.dart';
import 'package:ubci_bank/src/view/widgets/app_bottom_sheet.dart';

/// Offered when the host's `dda/v1/enumerations/mediatype` call is
/// unavailable — mirrors the confirmed capture (csv, pdf, qif, ofx) so
/// the picker still works if that lookup ever fails.
const List<StatementFormat> _fallbackStatementFormats = [
  StatementFormat(code: 'csv', mimeType: 'text/csv', ordinal: 1),
  StatementFormat(code: 'pdf', mimeType: 'application/pdf', ordinal: 2),
  StatementFormat(code: 'qif', mimeType: 'application/qif', ordinal: 3),
  StatementFormat(code: 'ofx', mimeType: 'application/x-ofx', ordinal: 4),
];

/// OBDX's Transactions "Download": pick a format, read the password note,
/// then fetch the same transactions URL with `media`/`mediaFormat` and
/// the current filter, and save the file.
///
/// [transactionsPath] is the account type's transactions URL — CASA by
/// default, `loan/{id}/transactions` or `deposit/{id}/transactions` for
/// loans and term deposits (OBDX uses the same call for all three).
/// [onBusy] is called with true once the download starts and false when
/// it ends, for the caller's spinner.
Future<void> downloadTransactionStatement({
  required BuildContext context,
  required WidgetRef ref,
  required String accountId,
  required CasaTransactionQuery query,
  required ValueChanged<bool> onBusy,
  String? transactionsPath,
}) async {
  final l10n = AppLocalizations.of(context);
  final repository = ref.read(accountsRepositoryProvider);

  final formatsResult = await repository.fetchStatementFormats();
  if (!context.mounted) return;
  final formats = (formatsResult is Success<List<StatementFormat>> &&
          (formatsResult.data?.isNotEmpty ?? false))
      ? formatsResult.data!
      : _fallbackStatementFormats;

  final chosenFormat = await AppBottomSheet.pick<StatementFormat>(
    context: context,
    title: l10n.casaStatementFormatTitle,
    options: [
      for (final format in formats) (value: format, label: format.label),
    ],
    selected: formats.first,
  );
  if (chosenFormat == null || !context.mounted) return;

  final proceed = await AppBottomSheet.confirm(
    context,
    title: l10n.casaStatementPasswordTitle,
    message: [
      l10n.casaStatementPasswordBody,
      l10n.casaStatementPasswordExample1,
      l10n.casaStatementPasswordExample2,
    ].join('\n\n'),
    confirmLabel: l10n.casaStatementPasswordContinue,
  );
  if (!proceed || !context.mounted) return;

  onBusy(true);
  final result = await repository.downloadStatement(
    accountId,
    format: chosenFormat,
    query: query,
    transactionsPath: transactionsPath,
  );
  if (!context.mounted) return;

  if (result is Success<StatementFile> && result.data != null) {
    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      await StatementFileSaver.saveStatement(
        bytes: result.data!.bytes,
        fileName: result.data!.fileName,
        mimeType: result.data!.mimeType,
        sharePositionOrigin: origin,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.casaStatementDownloadSuccess)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.casaStatementDownloadFailed)),
        );
      }
    }
  } else if (!SessionExpiryCoordinator.instance.isHandling) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.resolveUserMessage(
            l10n: l10n,
            fallback: l10n.casaStatementDownloadFailed,
          ),
        ),
      ),
    );
  }
  onBusy(false);
}
